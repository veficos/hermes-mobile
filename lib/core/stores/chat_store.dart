/// ChatStore: the transcript and live streaming assembly.
///
/// Owns messages built from gateway events (same model as the desktop
/// renderer). Fixes from APP_DESIGN.md: F1 (busy set before submit), F4 (tool
/// field merge), F5 (delta text shapes), F7 (interim already_streamed),
/// F8 (session_id event filter), F11 (transcript dedupe).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/runtime_l10n.dart';

import '../chat_message.dart';
import 'chat_handlers/event_family.dart';
import '../gateway.dart';
import '../connections/connection_registry.dart';
import '../transcript_window.dart';
import 'composer_status_store.dart';

const _unscopedStreamEvents = {
  'approval.request',
  'browser.progress',
  'clarify.request',
  'error',
  'mcp.setup.request',
  'message.complete',
  'message.delta',
  'message.interim',
  'message.start',
  'reasoning.available',
  'reasoning.delta',
  'reaction',
  'secret.request',
  'status.update',
  'sudo.request',
  'thinking.delta',
  'tool.complete',
  'tool.generating',
  'tool.progress',
  'tool.start',
};
const _streamEndEvents = {'message.complete', 'error'};

bool _eventRequiresExplicitSession(String type) => type.startsWith('subagent.');

/// Lightweight recovery journal entry (desktop recovery-journal parity).
class ChatRecoveryEntry {
  final String summary;
  final String? retryText;

  /// Full, untruncated error text when available — feeds the "copy / send
  /// diagnostics" actions on the recovery banner. Falls back to [summary].
  final String? detail;
  final ChatErrorSurface? errorSurface;
  final DateTime at;

  const ChatRecoveryEntry({
    required this.summary,
    this.retryText,
    this.detail,
    this.errorSurface,
    required this.at,
  });

  String get diagnostics => (detail ?? summary).trim();

  bool get retryable => errorSurface?.retryable != false;
}

/// Desktop `errorSurface.layer` parity: a coarse classification of a failed
/// turn from its error text, so the recovery banner can name the layer and
/// offer a provider-config shortcut where that is the fix.
enum ChatErrorLayer { auth, billing, provider, network, rateLimit, generic }

ChatErrorLayer classifyChatError(String text, {ChatErrorSurface? surface}) {
  switch (surface?.layer) {
    case 'auth':
      return ChatErrorLayer.auth;
    case 'billing':
      return ChatErrorLayer.billing;
    case 'provider':
    case 'endpoint':
      return ChatErrorLayer.provider;
    case 'streaming':
    case 'gateway':
      return ChatErrorLayer.network;
  }
  final t = text.toLowerCase();
  if (RegExp(
    r'\b(401|403|unauthor|invalid api key|invalid_api_key|authentication|forbidden|no api key|missing api key)\b',
  ).hasMatch(t)) {
    return ChatErrorLayer.auth;
  }
  if (RegExp(
    r'\b(402|quota|billing|insufficient|credit|payment|out of funds|balance)\b',
  ).hasMatch(t)) {
    return ChatErrorLayer.billing;
  }
  if (RegExp(
    r'\b(429|rate limit|rate_limit|too many requests|overloaded)\b',
  ).hasMatch(t)) {
    return ChatErrorLayer.rateLimit;
  }
  if (RegExp(
    r'\b(socket|timeout|timed out|connection|network|econnreset|websocket|unreachable|dns)\b',
  ).hasMatch(t)) {
    return ChatErrorLayer.network;
  }
  if (RegExp(
    r'\b(500|502|503|504|provider|upstream|model not found|unknown model|no such model|endpoint|bad gateway)\b',
  ).hasMatch(t)) {
    return ChatErrorLayer.provider;
  }
  return ChatErrorLayer.generic;
}

/// Session-scoped activity surfaced above the composer. Gateway payloads stay
/// attached so specialized rows can progressively adopt richer fields.
class ChatStatusItem {
  final String id;
  final String kind;
  final String label;
  final String state;
  final Map<String, dynamic> payload;

  const ChatStatusItem({
    required this.id,
    required this.kind,
    required this.label,
    required this.state,
    required this.payload,
  });
}

class ChatLiveSnapshot {
  final List<ChatMessage> messages;
  final ChatMessage? streaming;
  final bool busy;
  final List<ChatStatusItem> statuses;
  final ChatBillingBlock? billingBlock;
  final DateTime? turnArmedAt;
  final bool turnLive;

  const ChatLiveSnapshot({
    required this.messages,
    required this.streaming,
    required this.busy,
    required this.statuses,
    this.billingBlock,
    this.turnArmedAt,
    this.turnLive = false,
  });
}

class ChatFallbackSettleResult {
  final bool settled;
  final bool hadAssistantPayload;

  const ChatFallbackSettleResult({
    required this.settled,
    required this.hadAssistantPayload,
  });
}

class _PinnedStreamOwner {
  final String runtimeId;
  final String? profile;
  final String? connectionId;

  const _PinnedStreamOwner({
    required this.runtimeId,
    this.profile,
    this.connectionId,
  });
}

class ChatStore extends ChangeNotifier {
  /// Coalesce streaming UI updates (~30 fps) so markdown/layout does not run
  /// on every gateway token.
  static const int _streamNotifyIntervalMs = 32;

  /// Cap on [_backgroundAssemblers]: a background session's assembler is
  /// only reclaimed by [activateRuntime] when the user foregrounds that
  /// exact session — one that never gets revisited (a finished cron run, an
  /// ephemeral subagent) would otherwise accumulate forever. Evict the
  /// oldest entry past this cap, same guard used for the data-URI decode
  /// cache in message_bubble.dart.
  static const int _backgroundAssemblerLimit = 20;

  final List<ChatMessage> _messages = [];
  final List<ChatMessage> _newerTranscriptWindow = [];
  String? _transcriptWindowAnchorId;
  MutableAssistantMessage? _streaming;
  bool _interimBoundaryPending = false;
  String? Function()? _sessionIdOf; // resolves the current runtime id (F8)
  String? Function()? _profileOf;
  String? Function()? _durableSessionIdOf;
  final Map<String, List<ChatMessage>> _slashRowsBySession = {};
  final Map<String, String> _slashOwnerById = {};
  bool _busy = false;
  DateTime? _turnArmedAt;
  bool _turnLive = false;
  ChatBillingBlock? _billingBlock;
  StreamSubscription? _sub;
  Stopwatch? _streamElapsed;
  int _textFrames = 0;
  int _textChars = 0;
  int _reasoningFrames = 0;
  int _reasoningChars = 0;
  int _lastDeltaLogMs = 0;
  final Set<String> _streamToolIds = <String>{};
  final Set<String> _streamSubagentIds = <String>{};
  int _subagentEvents = 0;
  Timer? _streamNotifyTimer;
  bool _streamNotifyPending = false;
  int _streamTick = 0;
  final List<ChatRecoveryEntry> _recoveryJournal = [];
  final Map<String, ChatStatusItem> _statusItems = {};
  final ValueNotifier<int> composerSurfaceRevision = ValueNotifier<int>(0);
  final Map<String, ChatStatusItem> _notifications = {};
  final Map<String, Timer> _statusDismissTimers = {};
  final StreamController<ChatStatusItem> _notificationController =
      StreamController<ChatStatusItem>.broadcast();
  ComposerStatusStore? _composerStatus;
  String? _providerStatus;
  String? _recoveredStreamId;
  String? _activeRuntimeCacheKey;
  final Map<String, ChatLiveSnapshot> _liveCache = {};
  final Map<String, ChatStore> _backgroundAssemblers = {};
  final Map<String, _PinnedStreamOwner> _routedStreamPins = {};
  _PinnedStreamOwner? _legacyStreamPin;

  bool get _diagnosticLogging => kDebugMode || kProfileMode;

  /// Active gateway stream id, or a journaled id after inflight recovery.
  String? get streamingMessageId => _streaming?.id ?? _recoveredStreamId;

  /// Bumps on every streaming content mutation (even between throttled notifies).
  int get streamTick => _streamTick;

  /// Monotonic signal for the lightweight affection burst emitted by the
  /// gateway's standalone `reaction` event. Unlike `message.reaction`, this
  /// event is ephemeral and deliberately does not mutate transcript rows.
  int get vibeBurstRevision => _vibeBurstRevision;
  int _vibeBurstRevision = 0;

  /// The live streaming message, materialized on demand. Text/reasoning
  /// deltas accumulate in a buffer inside [MutableAssistantMessage]; the UI
  /// reads this once per throttled notify instead of rewriting the
  /// transcript list per gateway token.
  ChatMessage? get streamingMessage => _streaming?.toChatMessage();

  void clearRecoveredStream() {
    if (_recoveredStreamId == null) return;
    _recoveredStreamId = null;
    notifyListeners();
  }

  ChatLiveSnapshot captureLiveSnapshot() => ChatLiveSnapshot(
    messages: List.unmodifiable(messages),
    streaming: streamingMessage,
    busy: _busy,
    // Terminal statuses are deliberately not cached across session switches:
    // their 4s/12s lifecycle belongs to the session while visible. Running
    // work is restored; completed/error rows must not come back immortal after
    // their timer was cancelled by a switch.
    statuses: List.unmodifiable(
      _statusItems.values.where((item) => item.state == 'running'),
    ),
    billingBlock: _billingBlock,
    turnArmedAt: _turnArmedAt,
    turnLive: _turnLive,
  );

  void activateRuntime(
    String? runtimeId, {
    String? profile,
    String? connectionId,
  }) {
    final cacheKey = _runtimeCacheKey(
      runtimeId,
      profile: profile,
      connectionId: connectionId,
    );
    final previous = _activeRuntimeCacheKey;
    if (previous == cacheKey) return;
    if (previous != null && previous.isNotEmpty) {
      _liveCache[previous] = captureLiveSnapshot();
    }
    _activeRuntimeCacheKey = cacheKey;
    final background = cacheKey == null
        ? null
        : _backgroundAssemblers.remove(cacheKey);
    final snapshot =
        background?.captureLiveSnapshot() ??
        (cacheKey == null ? null : _liveCache[cacheKey]);
    _resetSessionState(notify: false);
    if (snapshot != null) {
      _messages.addAll(snapshot.messages);
      _busy = snapshot.busy;
      _streaming = snapshot.streaming == null
          ? null
          : MutableAssistantMessage.fromChatMessage(snapshot.streaming!);
      for (final status in snapshot.statuses) {
        _statusItems[status.id] = status;
      }
      _billingBlock = snapshot.billingBlock;
      _turnArmedAt = snapshot.turnArmedAt;
      _turnLive = snapshot.turnLive;
    }
    notifyListeners();
  }

  /// Apply a session lifecycle heartbeat to either the active transcript or
  /// its background assembler. This mirrors message event routing so an idle
  /// heartbeat can release a background session without foregrounding it.
  ChatFallbackSettleResult applyRuntimeRunning(
    String runtimeId,
    bool running, {
    String? profile,
    String? connectionId,
    DateTime? occurredAt,
  }) {
    final key = _runtimeCacheKey(
      runtimeId,
      profile: profile,
      connectionId: connectionId,
    );
    if (key == null || key == _activeRuntimeCacheKey) {
      return applySessionRunning(running, occurredAt: occurredAt);
    }
    final background = _backgroundAssemblers[key];
    if (background != null) {
      return background.applySessionRunning(running, occurredAt: occurredAt);
    }
    final snapshot = _liveCache[key];
    if (snapshot == null || (!snapshot.busy && snapshot.streaming == null)) {
      return const ChatFallbackSettleResult(
        settled: false,
        hadAssistantPayload: false,
      );
    }
    final assembler = ChatStore()
      .._messages.addAll(snapshot.messages)
      .._busy = snapshot.busy
      .._streaming = snapshot.streaming == null
          ? null
          : MutableAssistantMessage.fromChatMessage(snapshot.streaming!)
      .._billingBlock = snapshot.billingBlock
      .._turnArmedAt = snapshot.turnArmedAt
      .._turnLive = snapshot.turnLive;
    final result = assembler.applySessionRunning(
      running,
      occurredAt: occurredAt,
    );
    _liveCache[key] = assembler.captureLiveSnapshot();
    assembler.dispose();
    return result;
  }

  String? _runtimeCacheKey(
    String? runtimeId, {
    String? profile,
    String? connectionId,
  }) {
    if (runtimeId == null || runtimeId.isEmpty) return null;
    if ((profile == null || profile.isEmpty) &&
        (connectionId == null || connectionId.isEmpty)) {
      return runtimeId;
    }
    return '${connectionId ?? ''}\u0000${profile ?? ''}\u0000$runtimeId';
  }

  ChatStore _backgroundAssembler(String runtimeId) {
    final existing = _backgroundAssemblers[runtimeId];
    if (existing != null) return existing;
    if (_backgroundAssemblers.length >= _backgroundAssemblerLimit) {
      final oldestKey = _backgroundAssemblers.keys.first;
      _backgroundAssemblers.remove(oldestKey)?.dispose();
    }
    final store = ChatStore();
    store.bindSessionSource(() => runtimeId);
    store.bindComposerStatus(_composerStatus);
    _backgroundAssemblers[runtimeId] = store;
    return store;
  }

  /// Fold inflight journal rows onto the REST transcript after resume/reconnect.
  void applyInflightRecovery(
    List<ChatMessage> messages, {
    String? streamId,
    bool markBusy = false,
  }) {
    _messages
      ..clear()
      ..addAll(messages);
    _recoveredStreamId = streamId;
    _streaming = null;
    _interimBoundaryPending = false;
    _busy = markBusy;
    _turnLive = markBusy;
    _turnArmedAt = markBusy ? DateTime.now() : null;
    if (_diagnosticLogging) {
      _logStream(
        'event=inflight.recovery applied=true stream_id=$streamId '
        'mark_busy=$markBusy message_count=${_messages.length}',
      );
    }
    _flushStreamNotify();
  }

  /// Append the gateway-owned live tail returned by `session.resume`. Stored
  /// history does not contain a running turn yet, so REST hydration alone can
  /// otherwise make the prompt, partial answer, queued prompt, or retained
  /// failure disappear until another event arrives.
  void applyResumeProjection(
    Map<String, dynamic> resume, {
    required bool markBusy,
  }) {
    final runtimeId = resume['session_id']?.toString() ?? 'session';
    final inflight = resume['inflight'] is Map
        ? (resume['inflight'] as Map).cast<String, dynamic>()
        : null;
    final queued = resume['queued'] is Map
        ? (resume['queued'] as Map).cast<String, dynamic>()
        : null;
    if (inflight == null && queued == null) return;

    _messages.removeWhere(
      (message) =>
          message.id.startsWith('user-inflight-$runtimeId') ||
          message.id.startsWith('inflight-assistant-') ||
          message.id == 'assistant-stream-$runtimeId' ||
          message.id == 'user-queued-$runtimeId',
    );

    final user = inflight?['user']?.toString().trim() ?? '';
    final assistant = inflight?['assistant']?.toString() ?? '';
    final error = inflight?['error']?.toString().trim() ?? '';
    final surface = ChatErrorSurface.tryParse(inflight?['error_surface']);
    final streaming = inflight?['streaming'] == true;
    final corrections = inflight?['corrections'] is List
        ? (inflight!['corrections'] as List)
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final offsets = inflight?['correction_offsets'] is List
        ? (inflight!['correction_offsets'] as List)
              .map((value) => value is num ? value.toInt() : null)
              .toList(growable: false)
        : const <int?>[];
    final queuedUser = queued?['user']?.toString().trim() ?? '';

    bool alreadyHasUser(String text) {
      final normalized = _projectionComparableText(text);
      for (final message in _messages.reversed) {
        if (message.role == 'assistant' && !message.pending) break;
        if (message.role == 'user' &&
            _projectionComparableText(message.promptText) == normalized) {
          return true;
        }
      }
      return false;
    }

    if (user.isNotEmpty && !alreadyHasUser(user)) {
      final extracted = _extractOptimisticAttachmentRefs(user);
      _messages.add(
        ChatMessage(
          id: 'user-inflight-$runtimeId',
          role: 'user',
          parts: extracted.$1.isEmpty
              ? const []
              : [ChatPart.text(extracted.$1)],
          attachmentRefs: extracted.$2,
        ),
      );
    }

    final usableOffsets =
        error.isEmpty &&
        assistant.isNotEmpty &&
        corrections.isNotEmpty &&
        offsets.length == corrections.length &&
        offsets.every((value) => value != null && value >= 0);
    var cursor = 0;
    if (usableOffsets) {
      for (var i = 0; i < corrections.length; i++) {
        final boundary = offsets[i]!.clamp(cursor, assistant.length);
        final segment = assistant.substring(cursor, boundary);
        if (segment.trim().isNotEmpty) {
          _messages.add(
            ChatMessage(
              id: 'inflight-assistant-segment-$i-$runtimeId',
              role: 'assistant',
              parts: [ChatPart.text(segment)],
              interim: true,
            ),
          );
        }
        if (!alreadyHasUser(corrections[i])) {
          final extracted = _extractOptimisticAttachmentRefs(corrections[i]);
          _messages.add(
            ChatMessage(
              id: 'user-inflight-correction-$i-$runtimeId',
              role: 'user',
              parts: extracted.$1.isEmpty
                  ? const []
                  : [ChatPart.text(extracted.$1)],
              attachmentRefs: extracted.$2,
            ),
          );
        }
        cursor = boundary;
      }
    }

    final projectedText = usableOffsets
        ? assistant.substring(cursor)
        : assistant;
    final wantsAssistant =
        projectedText.isNotEmpty ||
        streaming ||
        error.isNotEmpty ||
        (user.isNotEmpty && queuedUser.isNotEmpty);
    if (wantsAssistant) {
      final row = ChatMessage(
        id: 'assistant-stream-$runtimeId',
        role: 'assistant',
        parts: projectedText.isEmpty
            ? const []
            : [ChatPart.text(projectedText)],
        pending: streaming,
        isError: error.isNotEmpty,
        errorSurface: surface,
      );
      _messages.add(row);
      if (streaming) {
        _streaming = MutableAssistantMessage.fromChatMessage(row);
      }
    }

    if (!usableOffsets) {
      for (var i = 0; i < corrections.length; i++) {
        if (alreadyHasUser(corrections[i])) continue;
        final extracted = _extractOptimisticAttachmentRefs(corrections[i]);
        _messages.add(
          ChatMessage(
            id: 'user-inflight-correction-$i-$runtimeId',
            role: 'user',
            parts: extracted.$1.isEmpty
                ? const []
                : [ChatPart.text(extracted.$1)],
            attachmentRefs: extracted.$2,
          ),
        );
      }
    }
    if (queuedUser.isNotEmpty && !alreadyHasUser(queuedUser)) {
      final extracted = _extractOptimisticAttachmentRefs(queuedUser);
      _messages.add(
        ChatMessage(
          id: 'user-queued-$runtimeId',
          role: 'user',
          parts: extracted.$1.isEmpty
              ? const []
              : [ChatPart.text(extracted.$1)],
          attachmentRefs: extracted.$2,
        ),
      );
    }
    _busy = markBusy || streaming;
    _turnLive = _busy;
    _turnArmedAt = _busy ? DateTime.now() : null;
    if (error.isNotEmpty) {
      _recordRecovery(
        error,
        retryText: surface?.retryable == false ? null : user,
        detail: _errorDiagnostics(error, surface),
        errorSurface: surface,
      );
    }
    _flushStreamNotify();
  }

  static String _projectionComparableText(String text) => text
      .replaceAll(
        RegExp(r'^@(image|file|folder|url):[^\n]*\n?', multiLine: true),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<ChatRecoveryEntry> get recoveryJournal =>
      List<ChatRecoveryEntry>.unmodifiable(_recoveryJournal);

  void clearRecoveryJournal() {
    if (_recoveryJournal.isEmpty) return;
    _recoveryJournal.clear();
    _bumpComposerSurface();
    notifyListeners();
  }

  List<MessageReaction>? replaceMessageReactions(
    String messageId,
    List<MessageReaction> reactions, {
    int? rowId,
  }) {
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index < 0) return null;
    final current = _messages[index];
    final snapshot = current.reactions;
    _messages[index] = ChatMessage(
      id: current.id,
      role: current.role,
      parts: current.parts,
      pending: current.pending,
      interim: current.interim,
      isError: current.isError,
      errorSurface: current.errorSurface,
      durationS: current.durationS,
      attachmentRefs: current.attachmentRefs,
      rowId: rowId ?? current.rowId,
      historyOrdinal: current.historyOrdinal,
      timestamp: current.timestamp,
      source: current.source,
      model: current.model,
      provider: current.provider,
      usage: current.usage,
      reactions: List.unmodifiable(reactions),
    );
    notifyListeners();
    return snapshot;
  }

  void _recordRecovery(
    String summary, {
    String? retryText,
    String? detail,
    ChatErrorSurface? errorSurface,
  }) {
    _recoveryJournal.insert(
      0,
      ChatRecoveryEntry(
        summary: summary,
        retryText: retryText,
        detail: detail,
        errorSurface: errorSurface,
        at: DateTime.now(),
      ),
    );
    if (_recoveryJournal.length > 8) {
      _recoveryJournal.removeRange(8, _recoveryJournal.length);
    }
    _bumpComposerSurface();
  }

  void _bumpComposerSurface() {
    composerSurfaceRevision.value++;
  }

  void _cancelStreamNotifyTimer() {
    _streamNotifyTimer?.cancel();
    _streamNotifyTimer = null;
    _streamNotifyPending = false;
  }

  void _scheduleStreamNotify() {
    _streamTick++;
    if (_streamNotifyPending) return;
    _streamNotifyPending = true;
    _streamNotifyTimer ??= Timer(
      const Duration(milliseconds: _streamNotifyIntervalMs),
      () {
        _streamNotifyPending = false;
        _streamNotifyTimer = null;
        notifyListeners();
      },
    );
  }

  void _flushStreamNotify() {
    _cancelStreamNotifyTimer();
    notifyListeners();
  }

  void _logStream(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_diagnosticLogging) return;
    developer.log(
      message,
      name: 'hermes.chat.stream',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _resetStreamDiagnostics() {
    if (!_diagnosticLogging) return;
    _streamElapsed = Stopwatch()..start();
    _textFrames = 0;
    _textChars = 0;
    _reasoningFrames = 0;
    _reasoningChars = 0;
    _lastDeltaLogMs = 0;
    _streamToolIds.clear();
    _streamSubagentIds.clear();
    _subagentEvents = 0;
  }

  int get _streamElapsedMs => _streamElapsed?.elapsedMilliseconds ?? 0;

  // ---- per-turn version history (desktop BranchPicker / checkpoint parity) --
  //
  // The backend rewind is destructive (truncate-and-resubmit), so an edited or
  // regenerated turn's previous answer is kept CLIENT-SIDE here: on rewind the
  // superseded transcript tail (the anchor user row onward) is snapshotted,
  // keyed by that row's stable anchor. The picker on the user bubble navigates
  // `‹ n/total ›`; the live transcript is always the implicit last version.
  // Selecting an older version renders it read-only; "restore" re-sends it,
  // which snapshots the current tail in turn — so navigation is reversible.
  final Map<String, List<List<ChatMessage>>> _turnVersions = {};
  String? _versionPreviewAnchor;
  int? _versionPreviewIndex;

  /// Stable key for a user turn — its persisted row id when available, else
  /// the transient message id.
  static String turnAnchorKey(ChatMessage userMessage) =>
      userMessage.rowId?.toString() ?? userMessage.id;

  /// Number of selectable versions for a turn (superseded snapshots + live).
  int turnVersionCount(String anchor) =>
      (_turnVersions[anchor]?.length ?? 0) + 1;

  /// Index of the version currently shown for [anchor] (last == live).
  int turnVersionCurrent(String anchor) =>
      _versionPreviewAnchor == anchor && _versionPreviewIndex != null
      ? _versionPreviewIndex!
      : turnVersionCount(anchor) - 1;

  /// True while any turn is showing a historical (non-live) version.
  bool get previewingHistory => _versionPreviewAnchor != null;

  /// Identity of the active historical preview, for transcript-rebuild keys.
  String? get versionPreviewSignature => _versionPreviewAnchor == null
      ? null
      : '$_versionPreviewAnchor#$_versionPreviewIndex';

  /// Show version [index] of [anchor]. Selecting the last (live) index clears
  /// the preview.
  void selectTurnVersion(String anchor, int index) {
    final count = turnVersionCount(anchor);
    final clamped = index.clamp(0, count - 1);
    if (clamped == count - 1) {
      if (_versionPreviewAnchor == null) return;
      _versionPreviewAnchor = null;
      _versionPreviewIndex = null;
    } else {
      _versionPreviewAnchor = anchor;
      _versionPreviewIndex = clamped;
    }
    notifyListeners();
  }

  void clearVersionPreview() {
    if (_versionPreviewAnchor == null) return;
    _versionPreviewAnchor = null;
    _versionPreviewIndex = null;
    notifyListeners();
  }

  /// User text of the version currently previewed (for "restore this
  /// version"), or null when the live version is shown.
  String? previewedVersionText() {
    final anchor = _versionPreviewAnchor;
    final index = _versionPreviewIndex;
    if (anchor == null || index == null) return null;
    final snapshots = _turnVersions[anchor];
    if (snapshots == null || index >= snapshots.length) return null;
    final tail = snapshots[index];
    return tail.isEmpty ? null : tail.first.fullText;
  }

  // ---- artifact version registry (desktop `$artifactRegistry` parity) -------
  // Fenced html/svg/mermaid blocks are "artifacts"; the same kind reappearing
  // across a session accumulates versions. Keyed by kind, dedup'd by content.
  final Map<String, List<String>> _artifacts = {};

  /// Register [content] for artifact [kind] and return its 1-based version
  /// number. Idempotent — a replayed / re-rendered block keeps its number.
  int registerArtifact(String kind, String content) {
    final list = _artifacts.putIfAbsent(kind, () => <String>[]);
    final at = list.indexOf(content);
    if (at >= 0) return at + 1;
    if (list.isNotEmpty) {
      final lastIndex = list.length - 1;
      final last = list[lastIndex];
      // A streaming block re-registers on every token: as long as the new
      // content is the previous registration growing (or shrinking, e.g. a
      // retry) rather than genuinely different content, update the current
      // version in place instead of minting a new one per token.
      if (content.startsWith(last) || last.startsWith(content)) {
        list[lastIndex] = content;
        _bumpComposerSurface();
        return lastIndex + 1;
      }
    }
    list.add(content);
    _bumpComposerSurface();
    return list.length;
  }

  int artifactVersionCount(String kind) => _artifacts[kind]?.length ?? 0;

  /// Immutable artifact history for the current chat session. Consumers such
  /// as the preview rail can offer version switching without reaching into the
  /// renderer's mutable registry.
  List<String> artifactVersions(String kind) =>
      List<String>.unmodifiable(_artifacts[kind] ?? const []);

  Map<String, List<String>> get artifactRegistry => Map.unmodifiable({
    for (final entry in _artifacts.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  });

  /// The live (non-preview) user message for the turn currently previewed,
  /// needed to anchor the "restore this version" rewind.
  ChatMessage? previewedAnchorLiveMessage() {
    final anchor = _versionPreviewAnchor;
    if (anchor == null) return null;
    for (final m in _messages) {
      if (m.role == 'user' && turnAnchorKey(m) == anchor) return m;
    }
    return null;
  }

  void _recordSupersededTurn(int anchorIndex) {
    if (anchorIndex < 0 || anchorIndex + 1 >= _messages.length) return;
    final anchor = turnAnchorKey(_messages[anchorIndex]);
    (_turnVersions[anchor] ??= <List<ChatMessage>>[]).add(
      List<ChatMessage>.from(_messages.sublist(anchorIndex)),
    );
  }

  /// Undo the most recent [_recordSupersededTurn] for [anchor] — used when the
  /// rewind RPC that triggered it fails and the transcript is rolled back.
  void dropLastTurnVersion(String anchor) {
    final list = _turnVersions[anchor];
    if (list == null || list.isEmpty) return;
    list.removeLast();
    if (list.isEmpty) _turnVersions.remove(anchor);
  }

  /// Live read-only view of the transcript — no per-access copy (the
  /// transcript Selector evaluates this ~30 Hz while streaming).
  List<ChatMessage> get messages {
    final previewAnchor = _versionPreviewAnchor;
    final previewIndex = _versionPreviewIndex;
    if (previewAnchor != null && previewIndex != null) {
      final snapshots = _turnVersions[previewAnchor];
      if (snapshots != null && previewIndex < snapshots.length) {
        final at = _messages.indexWhere(
          (m) => m.role == 'user' && turnAnchorKey(m) == previewAnchor,
        );
        if (at >= 0) {
          return UnmodifiableListView([
            ..._messages.take(at),
            ...snapshots[previewIndex],
          ]);
        }
      }
    }
    final live = _streaming;
    if (live == null || !live.rowAdded || _messages.isEmpty) {
      return UnmodifiableListView(_messages);
    }
    final materialized = live.toChatMessage();
    final index = _messages.lastIndexWhere((message) => message.id == live.id);
    if (index < 0) return UnmodifiableListView(_messages);
    return UnmodifiableListView([
      ..._messages.take(index),
      materialized,
      ..._messages.skip(index + 1),
    ]);
  }

  bool get busy => _busy;
  bool get isStreaming => _streaming != null;
  ChatBillingBlock? get billingBlock => _billingBlock;

  void _replaceBillingBlock(ChatBillingBlock? value) {
    if (identical(_billingBlock, value)) return;
    _billingBlock = value;
    _bumpComposerSurface();
  }

  void dismissBillingBlock() {
    if (_billingBlock == null) return;
    _replaceBillingBlock(null);
    notifyListeners();
  }

  /// Reconcile the finally-edge emitted when a turn ends without a terminal
  /// message frame. A just-submitted turn gets the same 15s pre-start grace as
  /// desktop; once backend liveness was observed, running=false is immediate.
  ChatFallbackSettleResult applySessionRunning(
    bool running, {
    DateTime? occurredAt,
  }) {
    if (running) {
      if (_busy) _turnLive = true;
      return const ChatFallbackSettleResult(
        settled: false,
        hadAssistantPayload: false,
      );
    }
    final armedAt = _turnArmedAt;
    if (_busy &&
        !_turnLive &&
        armedAt != null &&
        DateTime.now().difference(armedAt) < const Duration(seconds: 15)) {
      return const ChatFallbackSettleResult(
        settled: false,
        hadAssistantPayload: false,
      );
    }
    if (!_busy && _streaming == null && _recoveredStreamId == null) {
      return const ChatFallbackSettleResult(
        settled: false,
        hadAssistantPayload: false,
      );
    }

    final live = _streaming;
    final hadAssistantPayload =
        live?.parts.isNotEmpty == true ||
        _messages.any(
          (message) =>
              message.role == 'assistant' &&
              message.pending &&
              (message.parts.isNotEmpty || message.hasText),
        );
    if (live != null && live.parts.isEmpty) {
      _messages.removeWhere((message) => message.id == live.id);
    } else if (live != null) {
      live.finalize(
        null,
        'complete',
        null,
        timestamp: occurredAt ?? DateTime.now(),
      );
      _replaceStreaming(live, false, live.rowId);
    }
    _streaming = null;
    _recoveredStreamId = null;
    _messages.removeWhere(
      (message) =>
          message.pending &&
          message.parts.isEmpty &&
          message.fullText.trim().isEmpty &&
          message.attachmentRefs.isEmpty,
    );
    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      if (message.pending) {
        _messages[index] = message.copyWith(pending: false);
      }
    }
    _busy = false;
    _turnArmedAt = null;
    _turnLive = false;
    _statusItems.remove('provider-wait');
    _providerStatus = null;
    _flushStreamNotify();
    return ChatFallbackSettleResult(
      settled: true,
      hadAssistantPayload: hadAssistantPayload,
    );
  }

  List<ChatStatusItem> get statusItems =>
      List.unmodifiable(_statusItems.values);
  List<ChatStatusItem> get notifications =>
      List.unmodifiable(_notifications.values);
  Stream<ChatStatusItem> get notificationEvents =>
      _notificationController.stream;
  String? get providerStatus => _providerStatus;

  void bindComposerStatus(ComposerStatusStore? store) {
    _composerStatus = store;
  }

  String? get _statusSessionId => _sessionIdOf?.call();

  /// A *named* wait to show on the tail "working" row, or null for the generic
  /// "thinking" line. Desktop `TurnActivityIndicator` hint parity: compaction
  /// outranks a provider wait, which outranks a tool being drafted.
  String? get tailStatusLabel {
    for (final item in _statusItems.values) {
      if (item.kind == 'compacting') return runtimeL10n.chatCompactingThread;
    }
    final provider = _providerStatus?.trim();
    if (provider != null && provider.isNotEmpty) return provider;
    for (final item in _statusItems.values) {
      if (item.kind == 'tool-drafting' &&
          item.state != 'completed' &&
          item.label.trim().isNotEmpty) {
        return item.label.trim();
      }
    }
    return null;
  }

  bool get hasNewerTranscriptWindow => _newerTranscriptWindow.isNotEmpty;
  String? get transcriptWindowAnchorId => _transcriptWindowAnchorId;

  /// Cumulative context tokens across the loaded transcript, summed from the
  /// real per-turn `usage` payloads (WebUI A17 ambient context indicator).
  /// Returns null when no loaded message carries usage data — callers must
  /// not render an indicator in that case (no fake numbers).
  int? get cumulativeUsageTokens {
    var total = 0;
    var found = false;
    for (final message in _messages) {
      final usage = message.usage;
      if (usage == null || usage.isEmpty) continue;
      final totalTurn = _usageNum(usage, const ['total_tokens', 'tokens']);
      final input = _usageNum(usage, const [
        'input_tokens',
        'prompt_tokens',
        'tokens_in',
      ]);
      final output = _usageNum(usage, const [
        'output_tokens',
        'completion_tokens',
        'tokens_out',
      ]);
      if (totalTurn == null && input == null && output == null) continue;
      found = true;
      total += (totalTurn ?? (input ?? 0) + (output ?? 0)).toInt();
    }
    return found ? total : null;
  }

  static num? _usageNum(Map<String, dynamic> usage, List<String> keys) {
    for (final key in keys) {
      final value = usage[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  // ---- transcript pagination -------------------------------------------
  bool hasMoreHistory = false;
  bool loadingHistory = false;

  /// True while the first transcript page fetch is in flight (UI shows a
  /// spinner instead of flashing the empty state).
  bool loadingTranscript = false;

  /// Last older-history page load failure, cleared on the next attempt or
  /// success. Unlike [loadingHistory] this leaves [hasMoreHistory]
  /// untouched so the user can retry.
  String? historyError;
  int get loadedCount => _messages.length;

  void startLoadingTranscript() {
    loadingTranscript = true;
    notifyListeners();
  }

  void finishLoadingTranscript() {
    if (!loadingTranscript) return;
    loadingTranscript = false;
    notifyListeners();
  }

  /// Mark an older-page load as failed without touching [hasMoreHistory] —
  /// the scroll trigger and pull-to-refresh stay armed so a retry can run.
  void failLoadingHistory(String error) {
    loadingHistory = false;
    historyError = error;
    notifyListeners();
  }

  /// Provide a source for the current runtime session id (bound by
  /// SessionStore once it exists). Events from other sessions are dropped.
  void bindSessionSource(String? Function() source) {
    _sessionIdOf = source;
  }

  void bindProfileSource(String? Function() source) {
    _profileOf = source;
  }

  void bindDurableSessionSource(String? Function() source) {
    _durableSessionIdOf = source;
  }

  String _slashStorageKey(String sessionId) => 'hm_slash_timeline_$sessionId';

  Future<void> restoreSlashStatuses(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_slashStorageKey(sessionId));
    if (raw == null) return;
    try {
      final decoded = (jsonDecode(raw) as List).whereType<Map>();
      final rows = decoded
          .map((value) {
            final json = value.cast<String, dynamic>();
            return ChatMessage(
              id: json['id'].toString(),
              role: 'system',
              parts: [ChatPart.text(json['text']?.toString() ?? '')],
              pending: false,
              isError: json['error'] == true,
              source: 'slash',
              timestamp: DateTime.tryParse(json['at']?.toString() ?? ''),
            );
          })
          .toList(growable: false);
      _slashRowsBySession[sessionId] = rows;
      for (final row in rows) {
        _slashOwnerById[row.id] = sessionId;
      }
      if (_durableSessionIdOf?.call() != sessionId) return;
      final known = _messages.map((message) => message.id).toSet();
      _messages.addAll(rows.where((row) => !known.contains(row.id)));
      _messages.sort((a, b) {
        final left = a.timestamp;
        final right = b.timestamp;
        if (left == null || right == null) return 0;
        return left.compareTo(right);
      });
      notifyListeners();
    } catch (_) {}
  }

  void _persistSlashRows(String sessionId) {
    final rows = _slashRowsBySession[sessionId] ?? const <ChatMessage>[];
    unawaited(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _slashStorageKey(sessionId),
        jsonEncode([
          for (final row in rows)
            {
              'id': row.id,
              'text': row.fullText,
              'error': row.isError,
              'at': row.timestamp?.toIso8601String(),
            },
        ]),
      );
    }());
  }

  OwnerRoute? Function()? _ownerRouteOf;

  void bindOwnerRouteSource(OwnerRoute? Function() source) {
    _ownerRouteOf = source;
  }

  /// Bind to the connection's event fan-out.
  void attachEvents(Stream<GatewayEvent> events) {
    _sub?.cancel();
    _sub = events.listen((e) {
      final current = _sessionIdOf?.call();
      final currentProfile = _profileOf?.call();
      if (e.type == 'message.start' &&
          (e.sessionId == null || e.sessionId!.isEmpty) &&
          current != null &&
          current.isNotEmpty) {
        _legacyStreamPin = _PinnedStreamOwner(
          runtimeId: current,
          profile: currentProfile,
        );
      }
      if (_eventRequiresExplicitSession(e.type) &&
          (e.sessionId == null || e.sessionId!.isEmpty)) {
        return;
      }
      // F8: ignore session-scoped events from other sessions.
      final pinEligible = _unscopedStreamEvents.contains(e.type);
      final owner = e.sessionId == null || e.sessionId!.isEmpty
          ? (pinEligible ? _legacyStreamPin : null)
          : null;
      final sid = e.sessionId?.isNotEmpty == true
          ? e.sessionId
          : owner?.runtimeId;
      if (sid != null && sid.isNotEmpty && current != null && sid != current) {
        _backgroundAssembler(sid)._handleEvent(e);
        if (_streamEndEvents.contains(e.type)) _legacyStreamPin = null;
        return;
      }
      final profile = e.profile;
      if (profile != null &&
          profile.isNotEmpty &&
          currentProfile != null &&
          profile != currentProfile) {
        return;
      }
      _handleEvent(e);
      if (_streamEndEvents.contains(e.type)) _legacyStreamPin = null;
    });
  }

  void attachRoutedEvents(Stream<RoutedGatewayEvent> events) {
    _sub?.cancel();
    _sub = events.listen((routed) {
      final expectedRoute = _ownerRouteOf?.call();
      final event = routed.event;
      final routeProfile = event.profile ?? routed.route.profile;
      final pinKey = routed.route.connectionId.value;
      if (_eventRequiresExplicitSession(event.type) &&
          (event.sessionId == null || event.sessionId!.isEmpty)) {
        return;
      }
      final current = _sessionIdOf?.call();
      final currentProfile = _profileOf?.call();
      if (event.type == 'message.start' &&
          (event.sessionId == null || event.sessionId!.isEmpty) &&
          current != null &&
          current.isNotEmpty) {
        _routedStreamPins[pinKey] = _PinnedStreamOwner(
          runtimeId: current,
          profile: currentProfile ?? routeProfile,
          connectionId: routed.route.connectionId.value,
        );
      }
      final pinEligible = _unscopedStreamEvents.contains(event.type);
      final pinned = event.sessionId == null || event.sessionId!.isEmpty
          ? (pinEligible ? _routedStreamPins[pinKey] : null)
          : null;
      final sid = event.sessionId?.isNotEmpty == true
          ? event.sessionId
          : pinned?.runtimeId;
      final profile = event.profile ?? pinned?.profile ?? routed.route.profile;
      final isForeground =
          (sid == null || sid.isEmpty || current == null || sid == current) &&
          (profile == null ||
              profile.isEmpty ||
              currentProfile == null ||
              profile == currentProfile) &&
          (expectedRoute == null ||
              routed.route.connectionId == expectedRoute.connectionId);
      if (!isForeground && sid != null && sid.isNotEmpty) {
        final key = _runtimeCacheKey(
          sid,
          profile: profile,
          connectionId: routed.route.connectionId.value,
        )!;
        _backgroundAssembler(key)._handleEvent(event);
        if (_streamEndEvents.contains(event.type)) {
          _routedStreamPins.remove(pinKey);
        }
        return;
      }
      if (!isForeground) return;
      _handleEvent(event);
      if (_streamEndEvents.contains(event.type)) {
        _routedStreamPins.remove(pinKey);
      }
    });
  }

  /// Switch to a new session: clear the transcript and streaming state.
  void resetSession() {
    if (_diagnosticLogging) {
      _logStream(
        'event=session.reset before_count=${_messages.length} '
        'had_streaming=${_streaming != null} busy=$_busy',
      );
    }
    _resetSessionState(notify: true);
  }

  void _resetSessionState({required bool notify}) {
    _cancelStreamNotifyTimer();
    _streamTick = 0;
    _recoveredStreamId = null;
    _messages.clear();
    _turnVersions.clear();
    _artifacts.clear();
    _versionPreviewAnchor = null;
    _versionPreviewIndex = null;
    _newerTranscriptWindow.clear();
    _transcriptWindowAnchorId = null;
    _streaming = null;
    _busy = false;
    _turnArmedAt = null;
    _turnLive = false;
    _billingBlock = null;
    hasMoreHistory = false;
    loadingHistory = false;
    loadingTranscript = false;
    historyError = null;
    _recoveryJournal.clear();
    _statusItems.clear();
    _notifications.clear();
    _providerStatus = null;
    if (notify) notifyListeners();
  }

  /// WebUI `/clear` parity (commands.js `cmdClear`): clear the current view
  /// only — server-side history is untouched and reloads on the next open.
  void clearView() {
    _messages.clear();
    _turnVersions.clear();
    _versionPreviewAnchor = null;
    _versionPreviewIndex = null;
    _streaming = null;
    _busy = false;
    _turnArmedAt = null;
    _turnLive = false;
    hasMoreHistory = false;
    loadingHistory = false;
    loadingTranscript = false;
    historyError = null;
    notifyListeners();
  }

  // ------------------------------------------------------------- transcript
  void loadHistory(List<ChatMessage> messages, {required bool hasMore}) {
    // F11: drop a trailing, never-completed assistant message (half stream).
    final beforeCount = _messages.length;
    final list = List<ChatMessage>.from(messages);
    if (list.isNotEmpty &&
        list.last.role == 'assistant' &&
        !list.last.interim &&
        list.last.parts.isNotEmpty) {
      final last = list.last;
      if (last.parts.any(
        (p) => p.kind == 'tool' && (p.tool?['running'] == true),
      )) {
        list.removeLast();
      }
    }
    final local = _busy
        ? List<ChatMessage>.from(this.messages)
        : const <ChatMessage>[];
    _messages
      ..clear()
      ..addAll(list);
    if (local.isNotEmpty) {
      final ids = _messages.map((message) => message.id).toSet();
      _messages.addAll(local.where((message) => !ids.contains(message.id)));
    }
    _newerTranscriptWindow.clear();
    _transcriptWindowAnchorId = list.isEmpty ? null : list.first.id;
    if (!_busy) _streaming = null;
    hasMoreHistory = hasMore;
    loadingHistory = false;
    historyError = null;
    if (_diagnosticLogging) {
      _logStream(
        'event=history.loaded input_count=${messages.length} '
        'applied_count=${list.length} dropped_count=${messages.length - list.length} '
        'before_count=$beforeCount has_more=$hasMore',
      );
    }
    notifyListeners();
  }

  /// Prepend an older page of history (scrolled-to-top pagination).
  void appendOlderHistory(List<ChatMessage> older, {required bool hasMore}) {
    final beforeCount = _messages.length;
    historyError = null;
    if (older.isEmpty) {
      hasMoreHistory = false;
      loadingHistory = false;
      if (_diagnosticLogging) {
        _logStream(
          'event=history.prepended older_count=0 before_count=$beforeCount '
          'after_count=${_messages.length} has_more=false',
        );
      }
      notifyListeners();
      return;
    }
    _messages.insertAll(0, older);
    _trimTranscriptWindowAfterPrepend();
    hasMoreHistory = hasMore || _newerTranscriptWindow.isNotEmpty;
    loadingHistory = false;
    if (_diagnosticLogging) {
      _logStream(
        'event=history.prepended older_count=${older.length} '
        'before_count=$beforeCount after_count=${_messages.length} '
        'has_more=$hasMore',
      );
    }
    notifyListeners();
  }

  void _trimTranscriptWindowAfterPrepend() {
    if (_streaming != null || _busy) return;
    final totalWeight = _messages.fold<int>(
      0,
      (sum, message) => sum + chatMessageRenderWeight(message),
    );
    // A sticky boundary avoids re-cutting for every small page/stream update.
    // The slack is only for preserving an existing sticky boundary.  A newly
    // prepended page must be windowed as soon as it crosses the real budget;
    // otherwise a page landing exactly on budget + slack remains fully
    // mounted and defeats the long-transcript guard.
    if (totalWeight <= transcriptWindowBudget) return;
    var keptWeight = 0;
    var split = 0;
    while (split < _messages.length) {
      final next = chatMessageRenderWeight(_messages[split]);
      if (split >= transcriptWindowMinMessages &&
          keptWeight + next > transcriptWindowBudget) {
        break;
      }
      keptWeight += next;
      split++;
    }
    if (split >= _messages.length) return;
    _newerTranscriptWindow.insertAll(0, _messages.sublist(split));
    _messages.removeRange(split, _messages.length);
    _transcriptWindowAnchorId = _messages.isEmpty ? null : _messages.first.id;
  }

  void restoreNewerTranscriptWindow() {
    if (_newerTranscriptWindow.isEmpty) return;
    _messages.addAll(_newerTranscriptWindow);
    _newerTranscriptWindow.clear();
    var weight = _messages.fold<int>(
      0,
      (sum, message) => sum + chatMessageRenderWeight(message),
    );
    var removeCount = 0;
    while (_messages.length - removeCount > transcriptWindowMinMessages &&
        weight > transcriptWindowBudget) {
      weight -= chatMessageRenderWeight(_messages[removeCount]);
      removeCount++;
    }
    if (removeCount > 0) {
      _messages.removeRange(0, removeCount);
      hasMoreHistory = true;
    }
    _transcriptWindowAnchorId = _messages.isEmpty ? null : _messages.first.id;
    notifyListeners();
  }

  void startLoadingHistory() {
    loadingHistory = true;
    historyError = null;
    if (_diagnosticLogging) {
      _logStream(
        'event=history.load_started message_count=${_messages.length}',
      );
    }
    notifyListeners();
  }

  /// Optimistically rewind the transcript to a user turn. Desktop performs
  /// the same transform before its truncate-and-submit RPC so stale assistant
  /// and tool rows disappear immediately. Returns a snapshot for rollback.
  List<ChatMessage> rewindToUserMessage(
    String messageId, {
    String? replacementText,
    bool recordVersion = true,
  }) {
    final before = List<ChatMessage>.from(_messages);
    final index = _messages.indexWhere(
      (message) => message.id == messageId && message.role == 'user',
    );
    if (index < 0) return before;
    // Keep the turn we are about to discard as a navigable version.
    if (recordVersion) _recordSupersededTurn(index);
    _versionPreviewAnchor = null;
    _versionPreviewIndex = null;
    final source = _messages[index];
    final replacement = replacementText == null
        ? null
        : _extractOptimisticAttachmentRefs(replacementText);
    _messages
      ..removeRange(index + 1, _messages.length)
      ..[index] = replacementText == null
          ? source
          : source.copyWith(
              parts: replacement!.$1.isEmpty
                  ? const []
                  : [ChatPart.text(replacement.$1)],
              attachmentRefs: replacement.$2,
            );
    _streaming = null;
    _busy = true;
    _turnArmedAt = DateTime.now();
    _turnLive = false;
    _replaceBillingBlock(null);
    notifyListeners();
    return before;
  }

  void restoreSnapshot(List<ChatMessage> snapshot) {
    _messages
      ..clear()
      ..addAll(snapshot);
    _streaming = null;
    _busy = false;
    _turnArmedAt = null;
    _turnLive = false;
    notifyListeners();
  }

  /// Build ChatMessages from raw session messages (REST transcript).
  /// [sessionModel] backfills `ChatMessage.model` for assistant rows whose
  /// own record carries none — this backend stores `model` on the session,
  /// not per-message, so without it the B8 footnote's model segment (and
  /// any "actual model differs from header" usage comparison) never has
  /// anything to show for historical/replayed messages.
  List<ChatMessage> fromSessionMessages(
    List<dynamic> raw, {
    String? sessionModel,
  }) {
    final resultByToolId = <String, String>{};
    final declaredToolIds = <String>{};

    // Persisted transcripts use several provider-specific shapes. Index all
    // calls and results before rendering so result rows can be joined back to
    // the assistant call that owns them.
    for (final value in raw) {
      if (value is! Map) continue;
      final message = Map<String, dynamic>.from(value);
      for (final call in _historyToolCalls(message)) {
        final id = _historyToolId(call);
        if (id.isNotEmpty) declaredToolIds.add(id);
      }
      if (message['role']?.toString() == 'tool') {
        final id = _historyToolId(message);
        final result = _historyToolResult(message);
        if (id.isNotEmpty && result.isNotEmpty) resultByToolId[id] = result;
      }
      final content = message['content'];
      if (content is List) {
        for (final block in content) {
          if (block is! Map || block['type']?.toString() != 'tool_result') {
            continue;
          }
          final normalized = Map<String, dynamic>.from(block);
          final id = _historyToolId(normalized);
          final result = _historyContentText(normalized['content']);
          if (id.isNotEmpty && result.isNotEmpty) resultByToolId[id] = result;
        }
      }
    }

    final out = <ChatMessage>[];
    var i = 0;
    var msgIndex = 0;
    for (final value in raw) {
      if (value is! Map) continue;
      final m = Map<String, dynamic>.from(value);
      if (m['display_kind']?.toString() == 'hidden') continue;
      final storedRole = m['role']?.toString() ?? 'user';
      final displayKind = m['display_kind']?.toString();
      final role =
          const {
            'model_switch',
            'auto_continue',
            'personality_switch',
            'async_delegation_complete',
          }.contains(displayKind)
          ? 'system'
          : storedRole;
      final parts = <ChatPart>[];
      if (role == 'tool') {
        final id = _historyToolId(m);
        // The result is already attached to its declared assistant call.
        if (id.isNotEmpty && declaredToolIds.contains(id)) continue;
        parts.add(
          ChatPart.toolCall(_historyToolData(m, fallbackId: 's-$msgIndex-$i')),
        );
        msgIndex++;
      } else {
        final reasoning =
            m['reasoning'] ??
            m['reasoning_content'] ??
            (m['reasoning_details'] is String ? m['reasoning_details'] : null);
        if (reasoning is String && reasoning.isNotEmpty) {
          parts.add(ChatPart.reasoning(reasoning));
        }

        final seenToolIds = <String>{};
        void addTool(Map<String, dynamic> call) {
          final id = _historyToolId(call);
          if (id.isNotEmpty && !seenToolIds.add(id)) return;
          parts.add(
            ChatPart.toolCall(
              _historyToolData(
                call,
                fallbackId: 's-$msgIndex-$i',
                pairedResult: id.isEmpty ? null : resultByToolId[id],
              ),
            ),
          );
          msgIndex++;
        }

        if (storedRole == 'assistant') {
          for (final call in _historyToolCalls(m)) {
            addTool(call);
          }
        }

        final content = switch (displayKind) {
          'model_switch' => runtimeL10n.chatModelChanged,
          'auto_continue' => runtimeL10n.chatTurnContinued,
          'personality_switch' => runtimeL10n.chatPersonalityChanged,
          'async_delegation_complete' => _delegationCompleteText(
            m['display_metadata'],
          ),
          _ => _historyDisplayContent(
            storedRole,
            m['display_content'] ??
                m['content'] ??
                m['text'] ??
                m['context'] ??
                m['name'],
          ),
        };
        final text = _stringOf(content);
        if (text.isNotEmpty) parts.add(ChatPart.text(text));
      }
      final attachmentRefs = <String>[];
      if (role == 'user') {
        for (var partIndex = 0; partIndex < parts.length; partIndex++) {
          final part = parts[partIndex];
          if (part.kind != 'text') continue;
          final extracted = _extractHistoryImageRefs(part.text);
          attachmentRefs.addAll(extracted.$2);
          parts[partIndex] = ChatPart.text(extracted.$1);
        }
        parts.removeWhere(
          (part) => part.kind == 'text' && part.text.trim().isEmpty,
        );
      }
      if (parts.isNotEmpty || attachmentRefs.isNotEmpty) {
        final ts = m['timestamp'];
        final meta = m['metadata'] is Map
            ? (m['metadata'] as Map<String, dynamic>)
            : null;
        final declaredSource =
            (m['source'] ?? m['channel'] ?? meta?['source'] ?? meta?['channel'])
                ?.toString();
        final source =
            declaredSource ??
            (role == 'system' &&
                    parts.any(
                      (part) =>
                          part.kind == 'text' &&
                          part.text.startsWith('slash:/'),
                    )
                ? 'slash'
                : null);
        final model =
            (m['model'] ?? meta?['model'])?.toString() ??
            (role == 'assistant' ? sessionModel : null);
        final provider = (m['provider'] ?? meta?['provider'])?.toString();
        final usageRaw = m['usage'] ?? meta?['usage'];
        final tokenCount = m['token_count'];
        final usage = usageRaw is Map
            ? Map<String, dynamic>.from(usageRaw)
            : (role == 'assistant' && tokenCount is num && tokenCount > 0)
            ? {'total_tokens': tokenCount}
            : null;
        final displayMetadata = _historyMetadata(m['display_metadata']);
        final reactionRaw = displayMetadata != null
            ? displayMetadata['reactions']
            : meta?['reactions'];
        final reactions = reactionRaw is List
            ? reactionRaw
                  .whereType<Map>()
                  .map(MessageReaction.fromJson)
                  .where((reaction) => reaction.emoji.isNotEmpty)
                  .toList(growable: false)
            : const <MessageReaction>[];
        final built = ChatMessage(
          id: 'h-${m['id'] ?? m['row_id'] ?? m['history_ordinal'] ?? i++}',
          role: role,
          parts: parts,
          rowId: (m['row_id'] ?? m['id']) is num
              ? ((m['row_id'] ?? m['id']) as num).toInt()
              : null,
          historyOrdinal: m['history_ordinal'] is num
              ? (m['history_ordinal'] as num).toInt()
              : null,
          // The backend reports epoch seconds as a float
          // (e.g. `1787905997.51`), not an int — an `is int` check always
          // failed here, silently dropping every historical timestamp.
          timestamp: ts is num && ts > 0
              ? DateTime.fromMillisecondsSinceEpoch((ts * 1000).round())
              : null,
          source: source,
          model: model,
          provider: provider,
          usage: usage,
          reactions: reactions,
          attachmentRefs: List.unmodifiable(attachmentRefs),
        );
        final previous = out.lastOrNull;
        final currentHasTool = built.parts.any((part) => part.kind == 'tool');
        final previousHasTool =
            previous?.parts.any((part) => part.kind == 'tool') == true;
        if (built.role == 'assistant' &&
            previous?.role == 'assistant' &&
            (currentHasTool || previousHasTool)) {
          final previousStamp = previous!.timestamp;
          final builtStamp = built.timestamp;
          out[out.length - 1] = ChatMessage(
            id: previous.id,
            role: previous.role,
            parts: _dedupeHistoryAssistantParts([
              ...previous.parts,
              ...built.parts,
            ]),
            pending: previous.pending || built.pending,
            interim: previous.interim && built.interim,
            isError: previous.isError || built.isError,
            errorSurface: built.errorSurface ?? previous.errorSurface,
            durationS: built.durationS ?? previous.durationS,
            attachmentRefs: [
              ...previous.attachmentRefs,
              for (final ref in built.attachmentRefs)
                if (!previous.attachmentRefs.contains(ref)) ref,
            ],
            rowId: previous.rowId,
            historyOrdinal: previous.historyOrdinal,
            timestamp: previousStamp == null
                ? builtStamp
                : builtStamp == null || previousStamp.isBefore(builtStamp)
                ? previousStamp
                : builtStamp,
            source: previous.source ?? built.source,
            model: previous.model ?? built.model,
            provider: previous.provider ?? built.provider,
            usage: built.usage ?? previous.usage,
            reactions: previous.reactions,
          );
        } else {
          out.add(built);
        }
      }
    }
    return [
      for (final message in out)
        if (message.role == 'assistant')
          message.copyWith(parts: _dedupeHistoryAssistantParts(message.parts))
        else
          message,
    ];
  }

  static Map<String, dynamic>? _historyMetadata(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is! String || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static String _historyDisplayContent(String role, dynamic value) {
    var text = _historyDisplayText(value);
    if (role != 'user') return text;
    final invocation = _historySkillInvocation(text);
    if (invocation != null) return invocation;
    text = text.replaceAll(
      RegExp(r'(?:^|\n)--- Context Warnings ---[\s\S]*$'),
      '',
    );
    final marker = RegExp(
      r'(?:^|\n)--- Attached Context ---\s*\n',
    ).firstMatch(text);
    if (marker == null) return text.trim();
    final visible = text.substring(0, marker.start).trim();
    final attached = text.substring(marker.end);
    final refs = RegExp(
      r'''@(file|folder|url|image|tool|terminal):(?:"[^"\n]+"|'[^'\n]+'|`[^`\n]+`|\S+)''',
    ).allMatches(attached).map((match) => match.group(0)!).toSet();
    final missing = refs.where((ref) => !visible.contains(ref)).join('\n');
    return [missing, visible].where((part) => part.isNotEmpty).join('\n\n');
  }

  static String _historyDisplayText(dynamic value) {
    if (value is List) return value.map(_historyDisplayText).join();
    if (value is Map) {
      final type = value['type']?.toString();
      if (type == 'tool_use' || type == 'tool_result') return '';
    }
    return _historyContentText(value);
  }

  static String? _historySkillInvocation(String text) {
    const prefix = '[IMPORTANT: The user has invoked the ';
    if (!text.startsWith(prefix)) return null;
    final name = RegExp(
      r'^\[IMPORTANT: The user has invoked the "([^"]*)"',
    ).firstMatch(text)?.group(1)?.trim();
    if (name == null || name.isEmpty) return null;
    final label = name.startsWith('/') ? name : '/$name';
    const bundleMarker = ' skill bundle,';
    const bundleInstruction = '\nUser instruction: ';
    const bundleEnd = '\n\n[Loaded as part of the ';
    const singleMarker = 'The full skill content is loaded below.]';
    const singleInstruction =
        'The user has provided the following instruction alongside the skill invocation: ';
    const singleEnd = '\n\n[Runtime note:';
    final marker = text.contains(bundleMarker)
        ? bundleInstruction
        : text.contains(singleMarker)
        ? singleInstruction
        : null;
    if (marker == null) return label;
    final start = marker == singleInstruction
        ? text.lastIndexOf(marker)
        : text.indexOf(marker);
    if (start < 0) return label;
    final tail = text.substring(start + marker.length);
    final endMarker = marker == bundleInstruction ? bundleEnd : singleEnd;
    final end = tail.indexOf(endMarker);
    final instruction = (end < 0 ? tail : tail.substring(0, end))
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    return instruction.isEmpty ? label : '$label $instruction';
  }

  static List<ChatPart> _dedupeHistoryAssistantParts(List<ChatPart> parts) {
    final transformed = dedupeGeneratedImageEchoesInParts(parts);
    final lastTextAt = <String, int>{};
    for (var index = 0; index < transformed.length; index++) {
      final part = transformed[index];
      if (part.kind != 'text') continue;
      final key = part.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (key.isNotEmpty) lastTextAt[key] = index;
    }
    return [
      for (var index = 0; index < transformed.length; index++)
        if (transformed[index].kind != 'text' ||
            transformed[index].text.trim().isEmpty ||
            lastTextAt[transformed[index].text
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim()] ==
                index)
          transformed[index],
    ];
  }

  static (String, List<String>) _extractHistoryImageRefs(String text) {
    final refs = <String>[];
    var cleaned = text.replaceAllMapped(
      RegExp(r'^@image:[^\n]*\n?', multiLine: true),
      (match) {
        final ref = match.group(0)!.trim();
        if (ref.isNotEmpty && !refs.contains(ref)) refs.add(ref);
        return '';
      },
    );
    if (refs.isNotEmpty) {
      cleaned = cleaned.replaceAll(
        RegExp(r'^\[screenshot\]\n?', multiLine: true),
        '',
      );
    }
    return (cleaned.trim(), refs);
  }

  static String _delegationCompleteText(dynamic metadata) {
    dynamic parsed = metadata;
    if (parsed is String) {
      try {
        parsed = jsonDecode(parsed);
      } catch (_) {
        parsed = null;
      }
    }
    final count = parsed is Map
        ? (parsed['task_count'] as num?)?.toInt()
        : null;
    return count == null
        ? runtimeL10n.chatDelegationCompleted
        : runtimeL10n.chatDelegationCountCompleted(count);
  }

  static Iterable<Map<String, dynamic>> _historyToolCalls(
    Map<String, dynamic> message, {
    bool includeContent = true,
  }) sync* {
    for (final key in ['tool_calls', 'tools', '_partial_tool_calls']) {
      final calls = message[key];
      if (calls is! List) continue;
      for (final call in calls) {
        if (call is Map) yield Map<String, dynamic>.from(call);
      }
    }
    if (!includeContent) return;
    final content = message['content'];
    if (content is! List) return;
    for (final block in content) {
      if (block is Map && block['type']?.toString() == 'tool_use') {
        yield Map<String, dynamic>.from(block);
      }
    }
  }

  static String _historyToolId(Map<dynamic, dynamic> data) {
    for (final key in [
      'tool_id',
      'tool_call_id',
      'tool_use_id',
      'call_id',
      'tid',
      'id',
    ]) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static Map<String, dynamic> _historyToolData(
    Map<String, dynamic> source, {
    required String fallbackId,
    String? pairedResult,
  }) {
    final function = source['function'] is Map
        ? Map<String, dynamic>.from(source['function'] as Map)
        : const <String, dynamic>{};
    final name =
        (source['name'] ?? source['tool_name'] ?? function['name'] ?? 'tool')
            .toString();
    final args =
        source['args'] ??
        source['input'] ??
        source['arguments'] ??
        function['arguments'] ??
        source['args_text'];
    final ownResult = _historyToolResult(source);
    final resultText = ownResult.isNotEmpty ? ownResult : (pairedResult ?? '');
    final id = _historyToolId(source);
    return {
      'tool_id': id.isEmpty ? fallbackId : id,
      'name': name.isEmpty ? 'tool' : name,
      if (args is String) 'args_text': args,
      if (args is Map) 'args': Map<String, dynamic>.from(args),
      'result_text': resultText,
      'summary': source['summary']?.toString() ?? '',
      'running': source['running'] == true || source['done'] == false,
      'is_error': source['is_error'] == true || source['error'] != null,
    };
  }

  static String _historyToolResult(Map<String, dynamic> data) {
    for (final key in [
      'result_text',
      'result',
      'content',
      'context',
      'output',
      'snippet',
      'preview',
    ]) {
      final text = _historyContentText(data[key]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _historyContentText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) {
      return value
          .map(_historyContentText)
          .where((text) => text.isNotEmpty)
          .join();
    }
    if (value is Map) {
      for (final key in ['text', 'content', 'result', 'output']) {
        final text = _historyContentText(value[key]);
        if (text.isNotEmpty) return text;
      }
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  static String _stringOf(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['text']?.toString() ?? '';
    if (value is List) return value.map(_stringOf).join();
    return value?.toString() ?? '';
  }

  // ------------------------------------------------------------------ send
  /// Append a client-owned slash status row and persist it with the session.
  /// Desktop uses the same `slash:/command\noutput` system-message contract.
  String appendSlashStatus(
    String command,
    String output, {
    bool pending = false,
    String? sessionId,
  }) {
    final id = 'slash-${DateTime.now().microsecondsSinceEpoch}';
    final row = ChatMessage(
      id: id,
      role: 'system',
      parts: [ChatPart.text('slash:$command\n${output.trim()}')],
      pending: pending,
      source: 'slash',
      timestamp: DateTime.now(),
    );
    _messages.add(row);
    final owner = sessionId ?? _durableSessionIdOf?.call();
    if (owner != null && owner.isNotEmpty) {
      (_slashRowsBySession[owner] ??= []).add(row);
      _slashOwnerById[id] = owner;
      _persistSlashRows(owner);
    }
    notifyListeners();
    return id;
  }

  bool completeSlashStatus(
    String id,
    String output, {
    bool isError = false,
    String? sessionId,
  }) {
    final index = _messages.indexWhere((message) => message.id == id);
    final owner =
        sessionId ?? _slashOwnerById[id] ?? _durableSessionIdOf?.call();
    ChatMessage? current = index < 0 ? null : _messages[index];
    final storedRows = owner == null ? null : _slashRowsBySession[owner];
    final storedIndex =
        storedRows?.indexWhere((message) => message.id == id) ?? -1;
    current ??= storedIndex < 0 ? null : storedRows![storedIndex];
    if (current == null) return false;
    final header = current.fullText.split('\n').first;
    final completed = ChatMessage(
      id: current.id,
      role: 'system',
      parts: [ChatPart.text('$header\n${output.trim()}')],
      isError: isError,
      source: 'slash',
      timestamp: current.timestamp,
    );
    if (index >= 0) {
      _messages[index] = completed;
      notifyListeners();
    }
    if (storedIndex >= 0) {
      storedRows![storedIndex] = completed;
      _persistSlashRows(owner!);
    }
    return true;
  }

  Future<void> submit(
    Future<Map<String, dynamic>> Function() sendPrompt, {
    required String text,
  }) async {
    // A fresh turn leaves any historical-version preview behind.
    _versionPreviewAnchor = null;
    _versionPreviewIndex = null;
    // F1: mark busy BEFORE the submit so the interrupt button shows.
    final optimistic = _extractOptimisticAttachmentRefs(text);
    _messages.add(
      ChatMessage(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        parts: optimistic.$1.isEmpty
            ? const <ChatPart>[]
            : [ChatPart.text(optimistic.$1)],
        attachmentRefs: optimistic.$2,
        pending: true,
        timestamp: DateTime.now(),
      ),
    );
    _busy = true;
    _turnArmedAt = DateTime.now();
    _turnLive = false;
    _replaceBillingBlock(null);
    notifyListeners();
    try {
      await sendPrompt();
      // Commit the optimistic bubble once the turn is accepted.
      for (var i = _messages.length - 1; i >= 0; i--) {
        final m = _messages[i];
        if (m.pending && m.role == 'user') {
          _messages[i] = m.copyWith(pending: false);
          break;
        }
      }
    } catch (e) {
      // The submit failed before the gateway accepted the turn — mark the
      // pending user bubble as failed and clear busy so the composer frees.
      failPendingUserMessage(e.toString());
      rethrow;
    } finally {
      // _busy is also cleared by message.complete; keep them consistent.
      notifyListeners();
    }
  }

  static (String, List<String>) _extractOptimisticAttachmentRefs(String text) {
    final refs = <String>[];
    final cleaned = text.replaceAllMapped(
      RegExp(
        r'''(?:^|\s)@(image|file|folder|url):(`[^`]+`|'[^']+'|"[^"]+"|[^\s]+)''',
        multiLine: true,
      ),
      (match) {
        final ref = '@${match.group(1)}:${match.group(2)}';
        if (!refs.contains(ref)) refs.add(ref);
        return match.group(0)!.startsWith('\n') ? '\n' : ' ';
      },
    );
    return (
      cleaned
          .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim(),
      List.unmodifiable(refs),
    );
  }

  /// Submit a durable user turn that participates in model context without
  /// adding an optimistic transcript bubble. Local HTML previews use this for
  /// `window.hermes.send(...)`; persisted history also filters the matching
  /// `display_kind=hidden` row during hydration.
  Future<void> submitHidden(
    Future<Map<String, dynamic>> Function() sendPrompt,
  ) async {
    _versionPreviewAnchor = null;
    _versionPreviewIndex = null;
    _busy = true;
    _turnArmedAt = DateTime.now();
    _turnLive = false;
    _replaceBillingBlock(null);
    notifyListeners();
    try {
      await sendPrompt();
    } catch (error) {
      _busy = false;
      _turnArmedAt = null;
      _turnLive = false;
      final detail = error.toString();
      _recordRecovery(
        detail.length > 120 ? '${detail.substring(0, 120)}…' : detail,
        detail: detail,
      );
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void markIdle() {
    _busy = false;
    _turnArmedAt = null;
    _turnLive = false;
    notifyListeners();
  }

  void failPendingUserMessage(String error) {
    String? retryText;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.pending && m.role == 'user') {
        retryText = m.fullText.trim().isEmpty ? null : m.fullText;
        _messages[i] = m.copyWith(pending: false, isError: true);
        break;
      }
    }
    _busy = false;
    _turnArmedAt = null;
    _turnLive = false;
    _recordRecovery(
      error.length > 120 ? '${error.substring(0, 120)}…' : error,
      retryText: retryText,
      detail: error,
    );
    _flushStreamNotify();
  }

  // ------------------------------------------------------------- handling
  void _handleEvent(GatewayEvent e) {
    const resumedOutputEvents = {
      'message.delta',
      'message.interim',
      'reasoning.delta',
      'thinking.delta',
      'reasoning.available',
      'moa.reference',
      'moa.progress',
      'moa.phase',
      'moa.aggregating',
      'tool.start',
      'tool.generating',
      'tool.progress',
      'tool.complete',
    };
    if (resumedOutputEvents.contains(e.type)) {
      _settleTransientWaitStatuses();
    }
    if (e.type != 'tool.generating') {
      _statusItems.removeWhere((_, item) => item.kind == 'tool-drafting');
    }
    // Classification lives outside the store so protocol growth cannot turn
    // this state owner into the sole inventory of gateway event families.
    if (chatGatewayEventFamily(e.type) == ChatGatewayEventFamily.unknown) {
      return;
    }
    switch (e.type) {
      case 'message.start':
        _startStreaming();
      case 'message.delta':
        _appendDelta(e.payload);
      case 'reasoning.delta':
      case 'thinking.delta':
        _providerWait(e.payload);
      case 'reasoning.available':
        _appendReasoningAvailable(e.payload);
      case 'message.interim':
        _addInterim(e.payload);
      case 'message.complete':
        _completeStreaming(e.payload);
      case 'message.reaction':
        _messageReaction(e.payload);
      case 'reaction':
        if ((e.payload['kind']?.toString() ?? 'vibe') == 'vibe') {
          _vibeBurstRevision++;
          notifyListeners();
        }
      case 'tool.start':
        _toolStart(e.payload);
      case 'tool.generating':
        _toolGenerating(e.payload);
      case 'tool.progress':
        _toolProgress(e.payload);
      case 'tool.complete':
        _toolComplete(e.payload);
      // Sub-agent activity (spec §137–141): the backend mirrors content as
      // message.* / tool.*; here we add an explicit activity marker so
      // sub-agent turns are visibly attributed, not merged into the parent.
      case 'subagent.start':
        _subagentActivity(e.payload, event: 'start');
      case 'subagent.spawn_requested':
        _subagentActivity(e.payload, event: 'spawn_requested');
      case 'subagent.text':
        _subagentActivity(e.payload, event: 'text');
      case 'subagent.thinking':
        _subagentActivity(e.payload, event: 'thinking');
      case 'subagent.tool':
        _subagentActivity(e.payload, event: 'tool');
      case 'subagent.progress':
        _subagentActivity(e.payload, event: 'progress');
      case 'subagent.complete':
        _subagentActivity(e.payload, event: 'complete');
      case 'moa.reference':
      case 'moa.progress':
      case 'moa.phase':
      case 'moa.aggregating':
        _moaActivity(e.type, e.payload);
      case 'status.update':
        _statusUpdate(e.payload);
      case 'review.summary':
        _reviewSummary(e.payload);
      case 'notification.show':
        _notificationShow(e.payload);
      case 'notification.clear':
        _notificationClear(e.payload);
      case 'approval.request':
      case 'clarify.request':
      case 'sudo.request':
      case 'secret.request':
      case 'mcp.setup.request':
        _interactiveRequest(e.type, e.payload);
      case 'interactive.expire':
      case 'interactive.expired':
        _interactiveExpire(e.payload);
      case 'browser.progress':
        _browserProgress(e.payload);
      case 'preview.restart.progress':
      case 'preview.restart.complete':
      case 'preview.restart.error':
        _previewRestart(e.type, e.payload);
      case 'background.complete':
        _backgroundComplete(e.payload);
      case 'session.reclaimed':
        _sessionReclaimed(e.payload);
      case 'error':
        _gatewayError(e.payload);
      default:
        break;
    }
  }

  void _settleTransientWaitStatuses() {
    _providerStatus = null;
    _statusItems.remove('provider-wait');
    _statusItems.removeWhere((_, item) => item.kind == 'compacting');
  }

  void _appendReasoningAvailable(Map<String, dynamic> payload) {
    final text = _extractDeltaText(payload['text'] ?? payload['reasoning']);
    if (text.isNotEmpty) _appendReasoning({'text': text});
  }

  void _messageReaction(Map<String, dynamic> payload) {
    final rowId = (payload['row_id'] as num?)?.toInt();
    final raw = payload['reactions'];
    if (rowId == null || raw is! List) return;
    final reactions = raw
        .whereType<Map>()
        .map(MessageReaction.fromJson)
        .where((reaction) => reaction.emoji.isNotEmpty)
        .toList(growable: false);
    var index = _messages.indexWhere((message) => message.rowId == rowId);
    if (index < 0) {
      final role = payload['role'] == 'assistant' ? 'assistant' : 'user';
      for (var i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == role && _messages[i].rowId == null) {
          index = i;
          break;
        }
      }
    }
    if (index >= 0) {
      final messageId = _messages[index].id;
      final live = _streaming;
      if (live != null && live.id == messageId) {
        live.rowId = rowId;
        live.reactions = List.unmodifiable(reactions);
      }
      replaceMessageReactions(messageId, reactions, rowId: rowId);
    }
  }

  void _providerWait(Map<String, dynamic> payload) {
    final text = _extractDeltaText(payload['text'] ?? payload['message']);
    if (text.trim().isEmpty) return;
    _providerStatus = text.trim();
    _upsertStatus('provider-wait', 'provider', _providerStatus!, {
      ...payload,
      'status': 'running',
    });
  }

  void _notificationShow(Map<String, dynamic> payload) {
    final key = (payload['key'] ?? payload['id'] ?? 'notice').toString();
    final text = (payload['message'] ?? payload['text'] ?? payload['title'])
        .toString();
    final notice = ChatStatusItem(
      id: key,
      kind: 'notification',
      label: text.isEmpty ? runtimeL10n.chatHermesNotification : text,
      state: (payload['level'] ?? payload['status'] ?? 'active').toString(),
      payload: Map.unmodifiable(payload),
    );
    _notifications[key] = notice;
    _notificationController.add(notice);
  }

  void _notificationClear(Map<String, dynamic> payload) {
    final key = (payload['key'] ?? payload['id'] ?? '').toString();
    if (key.isNotEmpty) _notifications.remove(key);
    // Transient notices are rendered by the toast channel, not this stack.
  }

  void _interactiveRequest(String type, Map<String, dynamic> payload) {
    final requestId = (payload['request_id'] ?? '').toString();
    if (requestId.isEmpty) return;
    _streaming ??= MutableAssistantMessage(
      'assistant-${DateTime.now().millisecondsSinceEpoch}',
    );
    _streaming!.upsertInteractiveRequest({
      ...payload,
      'event_type': type,
      'request_id': requestId,
      'status': 'pending',
    });
    _syncStreaming();
  }

  void _interactiveExpire(Map<String, dynamic> payload) {
    final requestId = (payload['request_id'] ?? '').toString();
    if (requestId.isEmpty) return;
    final streaming = _streaming;
    if (streaming == null) return;
    streaming.expireInteractiveRequest(requestId);
    _syncStreaming();
  }

  void _browserProgress(Map<String, dynamic> payload) {
    final url = (payload['url'] ?? payload['target'] ?? '').toString();
    final text =
        (payload['text'] ?? payload['message'] ?? payload['status'] ?? '')
            .toString();
    if (url.isEmpty && text.isEmpty) return;
    _upsertStatus(
      'browser:${payload['tool_id'] ?? payload['id'] ?? url}',
      'browser',
      text.isEmpty ? runtimeL10n.chatBrowserTask : text,
      {...payload, 'status': payload['status']?.toString() ?? 'running'},
    );
  }

  void _previewRestart(String type, Map<String, dynamic> payload) {
    final taskId = (payload['task_id'] ?? '').toString();
    final id = taskId.isEmpty ? 'preview-restart' : 'preview-restart:$taskId';
    final state = switch (type) {
      'preview.restart.complete' => 'completed',
      'preview.restart.error' => 'error',
      _ => 'running',
    };
    _upsertStatus(
      id,
      'preview-restart',
      (payload['text'] ?? payload['message'] ?? runtimeL10n.chatPreviewRestart)
          .toString(),
      {...payload, 'status': state},
    );
  }

  void _backgroundComplete(Map<String, dynamic> payload) {
    final taskId = (payload['task_id'] ?? '').toString();
    _upsertStatus(
      taskId.isEmpty ? 'background-complete' : 'background:$taskId',
      'background',
      (payload['text'] ??
              payload['message'] ??
              runtimeL10n.notificationBackgroundCompleted)
          .toString(),
      {...payload, 'status': 'completed'},
    );
  }

  void _toolProgress(Map<String, dynamic> payload) {
    final id = (payload['tool_id'] ?? payload['id'] ?? '').toString();
    if (id.isEmpty) return;
    _streaming ??= MutableAssistantMessage(
      'assistant-${DateTime.now().millisecondsSinceEpoch}',
    );
    _streaming!.upsertTool(
      id,
      payload['name']?.toString(),
      payload['args_text']?.toString(),
      summary: (payload['summary'] ?? payload['message'] ?? payload['status'])
          ?.toString(),
      running: true,
    );
    _syncStreaming();
  }

  void _toolGenerating(Map<String, dynamic> payload) {
    final name = (payload['name'] ?? payload['tool_name'] ?? '').toString();
    if (name.isEmpty) return;
    _upsertStatus(
      'tool-drafting',
      'tool-drafting',
      runtimeL10n.chatPreparingTool(name),
      {...payload, 'status': 'running'},
    );
  }

  void _moaActivity(String type, Map<String, dynamic> payload) {
    final text = switch (type) {
      'moa.reference' =>
        (payload['text'] ?? payload['reference'] ?? '').toString(),
      'moa.aggregating' => '${runtimeL10n.chatMoaAggregating}\n',
      _ =>
        (payload['text'] ?? payload['message'] ?? payload['phase'] ?? '')
            .toString(),
    };
    if (text.isNotEmpty) _appendReasoning({'text': text});
    _upsertStatus('moa', 'moa', runtimeL10n.chatMoaCollaboration, payload);
  }

  void _statusUpdate(Map<String, dynamic> payload) {
    final kind = (payload['kind'] ?? payload['type'] ?? 'status').toString();
    final id = (payload['id'] ?? payload['status_id'] ?? kind).toString();
    _providerStatus =
        (payload['message'] ?? payload['status'] ?? payload['text'])
            ?.toString();
    if (kind == 'compacted') {
      _statusItems.removeWhere((_, item) => item.kind == 'compacting');
      _providerStatus = null;
      _bumpComposerSurface();
      notifyListeners();
      return;
    }
    if (kind == 'process') {
      // Process notices are invalidation signals, not transcript statuses.
      // A registry refresh supplies the real command/output/state rows.
      unawaited(_composerStatus?.refreshBackgroundProcesses(_statusSessionId));
      _providerStatus = null;
      return;
    }
    if (kind == 'goal') {
      final goalStatus =
          (payload['goal_status'] ?? payload['status'] ?? 'active').toString();
      _composerStatus?.upsertStatus(
        _statusSessionId,
        ComposerStatusItem(
          id: 'goal:$id',
          type: ComposerStatusType.goal,
          state: goalStatus == 'done' || goalStatus == 'completed'
              ? ComposerStatusState.done
              : goalStatus == 'error' || goalStatus == 'failed'
              ? ComposerStatusState.failed
              : ComposerStatusState.running,
          title: _providerStatus ?? runtimeL10n.chatCurrentGoal,
          goalStatus: goalStatus,
          currentTool: payload['detail']?.toString(),
        ),
      );
      return;
    }
    _upsertStatus(id, kind, _providerStatus ?? kind, payload);
  }

  void _reviewSummary(Map<String, dynamic> payload) {
    // Desktop treats self-improvement reviews as transcript content, not a
    // transient/running status. The backend normally uses `text`; retain the
    // older aliases so mixed-version gateways do not silently lose the row.
    final raw =
        (payload['text'] ?? payload['summary'] ?? payload['message'] ?? '')
            .toString()
            .trim();
    if (raw.isEmpty) return;
    final text = raw.replaceFirst(RegExp(r'^[\s💾]+'), '').trim();
    if (text.isEmpty) return;
    final id = (payload['id']?.toString().trim().isNotEmpty == true)
        ? 'review-summary-${payload['id']}'
        : 'review-summary-${DateTime.now().microsecondsSinceEpoch}';
    if (_messages.any((message) => message.id == id)) return;
    _messages.add(
      ChatMessage(
        id: id,
        role: 'system',
        parts: [ChatPart.text('review:$text')],
        timestamp: DateTime.now(),
      ),
    );
    if (_streaming == null) {
      notifyListeners();
    } else {
      _syncStreaming();
    }
  }

  void _sessionReclaimed(Map<String, dynamic> payload) {
    // `session.reclaimed` is a runtime lifecycle edge, not an ongoing job.
    // Desktop drops the stale runtime binding and refreshes the session; it
    // does not render a persistent status row. Treating the payload's absent
    // state as the `_upsertStatus` default (`running`) left “会话已恢复” and a
    // spinner visible forever after entering a resumed conversation.
    _settleTransientWaitStatuses();
    _statusItems.remove('session-reclaimed');
    notifyListeners();
  }

  void _upsertStatus(
    String id,
    String kind,
    String label,
    Map<String, dynamic> payload,
  ) {
    final state = (payload['state'] ?? payload['status'] ?? 'running')
        .toString();
    final completed = const {'completed', 'complete', 'done'}.contains(state);
    if (state == 'dismissed' || state == 'removed') {
      _statusItems.remove(id);
      _statusDismissTimers.remove(id)?.cancel();
    } else if (completed) {
      // Settled generic events are notifications, not ongoing session work.
      // Goal/Todo/Subagent/Background use ComposerStatusStore and retain their
      // own 4-second success lifecycle; this branch only handles generic rows.
      _statusItems.remove(id);
      _statusDismissTimers.remove(id)?.cancel();
      final notice = ChatStatusItem(
        id: 'status:$id:${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        label: label,
        state: state,
        payload: Map.unmodifiable(payload),
      );
      _notificationController.add(notice);
    } else {
      _statusItems[id] = ChatStatusItem(
        id: id,
        kind: kind,
        label: label,
        state: state,
        payload: Map.unmodifiable(payload),
      );
      _statusDismissTimers.remove(id)?.cancel();
      if (state == 'error' || state == 'failed') {
        const delay = Duration(seconds: 12);
        _statusDismissTimers[id] = Timer(delay, () {
          _statusDismissTimers.remove(id);
          if (_statusItems.remove(id) != null) notifyListeners();
        });
      }
    }
    _bumpComposerSurface();
    notifyListeners();
  }

  void dismissStatus(String id) {
    _statusDismissTimers.remove(id)?.cancel();
    if (_statusItems.remove(id) != null) {
      _bumpComposerSurface();
      notifyListeners();
    }
  }

  void dismissNotification(String id) {
    if (_notifications.remove(id) != null) notifyListeners();
  }

  void _gatewayError(Map<String, dynamic> payload) {
    final message =
        (payload['message'] ??
                payload['error'] ??
                runtimeL10n.chatHermesRunFailed)
            .toString();
    final streaming = _streaming;
    final surface = ChatErrorSurface.tryParse(payload['error_surface']);
    _replaceBillingBlock(ChatBillingBlock.tryParse(payload['billing']));
    _streaming = null;
    _busy = false;
    _turnArmedAt = null;
    _turnLive = false;
    if (streaming != null) {
      if (message.isNotEmpty) streaming.appendDelta(message);
      streaming.errorSurface = surface;
      streaming.finalize(message, 'error', null, timestamp: DateTime.now());
      _replaceStreaming(streaming, true, null);
    } else {
      _messages.add(
        ChatMessage(
          id: 'error-${DateTime.now().microsecondsSinceEpoch}',
          role: 'assistant',
          parts: [ChatPart.text(message)],
          isError: true,
          errorSurface: surface,
          timestamp: DateTime.now(),
        ),
      );
    }
    _recordRecovery(
      message,
      retryText: surface?.retryable == false ? null : lastUserText(),
      detail: _errorDiagnostics(message, surface),
      errorSurface: surface,
    );
    _flushStreamNotify();
  }

  void _subagentActivity(
    Map<String, dynamic> payload, {
    required String event,
  }) {
    _streaming ??= MutableAssistantMessage(
      'assistant-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (_diagnosticLogging) {
      _streamElapsed ??= Stopwatch()..start();
      _subagentEvents++;
      final subagentId =
          (payload['subagent_id'] ??
                  payload['child_session_id'] ??
                  payload['id'] ??
                  '')
              .toString();
      if (subagentId.isNotEmpty) _streamSubagentIds.add(subagentId);
      final textLength = (payload['text'] ?? '').toString().length;
      final status =
          (payload['status'] ??
                  (event == 'start'
                      ? 'running'
                      : event == 'complete'
                      ? 'completed'
                      : ''))
              .toString();
      if (event != 'text' && event != 'thinking' ||
          _streamElapsedMs - _lastDeltaLogMs >= 500) {
        if (event == 'text' || event == 'thinking') {
          _lastDeltaLogMs = _streamElapsedMs;
        }
        _logStream(
          'event=subagent.activity activity=$event subagent_id=$subagentId '
          'status=$status text_length=$textLength '
          'elapsed_ms=$_streamElapsedMs event_count=$_subagentEvents',
        );
      }
    }
    final activity = <String, dynamic>{...payload, 'event': event};
    if (event == 'start') activity['status'] ??= 'running';
    if (event == 'complete') activity['status'] ??= 'completed';
    _streaming!.upsertSubagent(activity);
    final subagentId =
        (payload['subagent_id'] ?? payload['child_session_id'] ?? payload['id'])
            ?.toString() ??
        'active';
    final status = (activity['status'] ?? '').toString();
    _composerStatus?.upsertStatus(
      _statusSessionId,
      ComposerStatusItem(
        id: 'subagent:$subagentId',
        type: ComposerStatusType.subagent,
        state: status == 'error' || status == 'failed'
            ? ComposerStatusState.failed
            : status == 'completed' || status == 'done'
            ? ComposerStatusState.done
            : ComposerStatusState.running,
        title:
            (payload['task'] ?? payload['name'] ?? runtimeL10n.toolDelegateTask)
                .toString(),
        sessionId: (payload['child_session_id'] ?? payload['session_id'])
            ?.toString(),
        currentTool: (payload['tool_name'] ?? payload['tool'])?.toString(),
      ),
    );
    _syncStreaming();
  }

  void _startStreaming() {
    // Background sessions do not pass through this store's local submit()
    // path, so the gateway edge itself must establish their live-turn state.
    _busy = true;
    _turnArmedAt ??= DateTime.now();
    _turnLive = true;
    _replaceBillingBlock(null);
    _statusItems.remove('provider-wait');
    _providerStatus = null;
    _interimBoundaryPending = false;
    final compacting = _statusItems.entries
        .where((entry) => entry.value.kind == 'compacting')
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in compacting) {
      _statusItems.remove(id);
    }
    _streaming = MutableAssistantMessage(
      'assistant-${DateTime.now().millisecondsSinceEpoch}',
    );
    _resetStreamDiagnostics();
    _messages.add(_streaming!.toChatMessage());
    _streaming!.rowAdded = true;
    if (_diagnosticLogging) {
      _logStream(
        'event=message.start message_id=${_streaming!.id} '
        'session_id=${_sessionIdOf?.call() ?? ''} '
        'message_count=${_messages.length} busy=$_busy',
      );
    }
    _flushStreamNotify();
  }

  /// Extract text from the various `text` shapes the gateway emits (F5).
  String _extractDeltaText(dynamic text) {
    if (text is String) return text;
    if (text is List) {
      return text.map(_extractDeltaText).join();
    }
    if (text is Map) {
      return text['text']?.toString() ?? text['output_text']?.toString() ?? '';
    }
    return '';
  }

  void _appendDelta(Map<String, dynamic> payload) {
    final delta = _extractDeltaText(payload['text']);
    if (delta.isEmpty) return;
    _streaming ??= MutableAssistantMessage(
      'assistant-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (_diagnosticLogging) {
      _streamElapsed ??= Stopwatch()..start();
      _textFrames++;
      _textChars += delta.length;
      if (_textFrames == 1) {
        _logStream(
          'event=delta.first kind=text chars=${delta.length} '
          'elapsed_ms=$_streamElapsedMs',
        );
      } else if (_streamElapsedMs - _lastDeltaLogMs >= 500) {
        _lastDeltaLogMs = _streamElapsedMs;
        _logStream(
          'event=delta.summary text_frames=$_textFrames text_chars=$_textChars '
          'reasoning_frames=$_reasoningFrames reasoning_chars=$_reasoningChars '
          'elapsed_ms=$_streamElapsedMs',
        );
      }
    }
    _streaming!.appendDelta(delta);
    _syncStreamingDelta();
  }

  void _appendReasoning(Map<String, dynamic> payload) {
    final text = (payload['text'] ?? '').toString();
    if (text.isEmpty) return;
    _streaming ??= MutableAssistantMessage(
      'assistant-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (_diagnosticLogging) {
      _streamElapsed ??= Stopwatch()..start();
      _reasoningFrames++;
      _reasoningChars += text.length;
      if (_reasoningFrames == 1) {
        _logStream(
          'event=delta.first kind=reasoning chars=${text.length} '
          'elapsed_ms=$_streamElapsedMs',
        );
      } else if (_streamElapsedMs - _lastDeltaLogMs >= 500) {
        _lastDeltaLogMs = _streamElapsedMs;
        _logStream(
          'event=delta.summary text_frames=$_textFrames text_chars=$_textChars '
          'reasoning_frames=$_reasoningFrames reasoning_chars=$_reasoningChars '
          'elapsed_ms=$_streamElapsedMs',
        );
      }
    }
    _streaming!.appendReasoning(text);
    _syncStreamingDelta();
  }

  void _addInterim(Map<String, dynamic> payload) {
    final text = (payload['text'] ?? '').toString();
    if (text.isEmpty) {
      if (_diagnosticLogging) {
        _logStream('event=interim.skipped reason=empty length=0');
      }
      return;
    }
    final live = _streaming;
    if (live != null) {
      _messages.removeWhere((message) => message.id == live.id);
      _streaming = null;
    }
    _messages.add(
      ChatMessage(
        id: 'interim-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        parts: [ChatPart.text(text)],
        interim: true,
      ),
    );
    _interimBoundaryPending = true;
    if (_diagnosticLogging) {
      _logStream(
        'event=interim.accepted length=${text.length} '
        'message_count=${_messages.length}',
      );
    }
    notifyListeners();
  }

  void _toolStart(Map<String, dynamic> payload) {
    final toolId = (payload['tool_id'] ?? '').toString();
    if (toolId.isEmpty) return;
    _streaming ??= MutableAssistantMessage(
      'assistant-${DateTime.now().millisecondsSinceEpoch}',
    );
    // A blocking request may arrive before its generic tool.start replay.
    // The request form owns that timeline slot, so do not add a second card.
    if (_streaming!.hasInteractiveRequest(toolId)) {
      _syncStreaming();
      return;
    }
    if (_diagnosticLogging) {
      _streamElapsed ??= Stopwatch()..start();
      _streamToolIds.add(toolId);
      _logStream(
        'event=tool.start tool_id=$toolId name=${payload['name'] ?? ''} '
        'status=running args_length=${(payload['args_text'] ?? '').toString().length} '
        'elapsed_ms=$_streamElapsedMs',
      );
    }
    _streaming!.upsertTool(
      toolId,
      payload['name']?.toString(),
      payload['args_text']?.toString(),
      running: true,
    );
    _syncStreaming();
  }

  void _toolComplete(Map<String, dynamic> payload) {
    final toolId = (payload['tool_id'] ?? '').toString();
    if (toolId.isEmpty) return;
    _streaming ??= MutableAssistantMessage(
      'assistant-${DateTime.now().millisecondsSinceEpoch}',
    );
    final result = payload['result'];
    // F4: tool.complete carries `args` (not args_text) — preserve the
    // original args_text captured at tool.start.
    final argsText =
        payload['args_text']?.toString() ?? payload['args']?.toString();
    final summary = payload['summary']?.toString();
    var resultText = '';
    if (result is String) {
      resultText = result;
    } else if (result is Map || result is List) {
      resultText = const JsonEncoder.withIndent('  ').convert(result);
    }
    final payloadResultText = payload['result_text']?.toString() ?? '';
    final finalResultText = payloadResultText.isNotEmpty
        ? payloadResultText
        : (resultText.isNotEmpty ? resultText : summary);
    if (_diagnosticLogging) {
      _streamElapsed ??= Stopwatch()..start();
      _streamToolIds.add(toolId);
      _logStream(
        'event=tool.complete tool_id=$toolId name=${payload['name'] ?? ''} '
        'status=completed is_error=${payload['error'] != null} '
        'result_length=${finalResultText?.length ?? 0} '
        'elapsed_ms=$_streamElapsedMs',
      );
    }
    _streaming!.upsertTool(
      toolId,
      payload['name']?.toString(),
      argsText,
      result: result,
      summary: summary,
      running: false,
      isError: payload['error'] != null,
      resultText: finalResultText,
    );
    // HermesPlanCard (spec §28–29): the `todo` tool reports the plan — parse
    // todos/result/args the same way the desktop does (lib/todos.ts).
    if ((payload['name'] ?? '').toString() == 'todo') {
      final todos =
          _parseTodos(payload['todos']) ??
          _parseTodos(payload['result']) ??
          _parseTodos(payload['args']);
      if (todos != null && todos.isNotEmpty) {
        _streaming!.appendPart(ChatPart.plan(todos));
        _composerStatus?.replaceTodos(_statusSessionId, [
          for (var index = 0; index < todos.length; index++)
            ComposerStatusItem(
              id: 'todo:${todos[index]['id'] ?? '$toolId:$index'}',
              type: ComposerStatusType.todo,
              state: switch (todos[index]['status']) {
                'completed' || 'cancelled' => ComposerStatusState.done,
                'error' || 'failed' => ComposerStatusState.failed,
                _ => ComposerStatusState.running,
              },
              title:
                  (todos[index]['content'] ??
                          todos[index]['title'] ??
                          runtimeL10n.chatPlanItem)
                      .toString(),
              todoStatus: todos[index]['status']?.toString() ?? 'pending',
            ),
        ]);
      }
    }
    _syncStreaming();
  }

  /// Parse a TodoItem[] from `{id, content, status}` maps; null when invalid.
  static List<Map<String, dynamic>>? _parseTodos(dynamic value) {
    if (value is! List) return null;
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map) continue;
      final status = (item['status'] ?? '').toString();
      const statuses = {'pending', 'in_progress', 'completed', 'cancelled'};
      if (!statuses.contains(status)) continue;
      final id = (item['id'] ?? '').toString().trim();
      final content = (item['content'] ?? '').toString().trim();
      if (id.isEmpty || content.isEmpty) continue;
      out.add({'id': id, 'content': content, 'status': status});
    }
    return out.isEmpty ? null : out;
  }

  void _completeStreaming(Map<String, dynamic> payload) {
    final status = (payload['status'] ?? 'complete').toString();
    final usage = payload['usage'] as Map<String, dynamic>?;
    final ts = payload['timestamp'];
    // Same float-epoch-seconds shape as `fromSessionMessages` — `is int`
    // never matches, so this always fell back to DateTime.now().
    final stamp = ts is num && ts > 0
        ? DateTime.fromMillisecondsSinceEpoch((ts * 1000).round())
        : DateTime.now();
    final model = (payload['model'] ?? usage?['model'] ?? usage?['used_model'])
        ?.toString();
    final provider =
        (payload['provider'] ??
                usage?['provider'] ??
                usage?['billing_provider'])
            ?.toString();
    final source = (payload['source'] ?? payload['channel'])?.toString();
    final surface = ChatErrorSurface.tryParse(payload['error_surface']);
    final durationS = (payload['duration_s'] as num?)?.toDouble();
    _replaceBillingBlock(ChatBillingBlock.tryParse(payload['billing']));
    final isError = status == 'error';
    final partial = payload['partial'] == true;
    final finalText = _extractDeltaText(payload['text']);
    final failureText = _extractDeltaText(payload['error']).trim().isNotEmpty
        ? _extractDeltaText(payload['error']).trim()
        : finalText;
    final visibleText = isError && !partial ? failureText : finalText;
    var streaming = _streaming;
    final liveHasContent =
        streaming?.parts.any(
          (part) => part.kind != 'text' || part.text.trim().isNotEmpty,
        ) ??
        false;
    ChatMessage? settlingInterim;
    if (!liveHasContent && finalText.isNotEmpty) {
      for (var i = _messages.length - 1; i >= 0; i--) {
        final candidate = _messages[i];
        if (!candidate.interim || candidate.role != 'assistant') continue;
        final interimText = candidate.fullText.trim();
        final continuous =
            interimText.isNotEmpty &&
            (finalText == interimText ||
                finalText.startsWith(interimText) ||
                interimText.startsWith(finalText));
        if (continuous ||
            (_interimBoundaryPending &&
                payload['response_previewed'] == true)) {
          settlingInterim = candidate;
          streaming = MutableAssistantMessage.fromChatMessage(candidate);
        }
        break;
      }
    }
    _streaming = null;
    _interimBoundaryPending = false;
    _busy = false;
    _turnArmedAt = null;
    _turnLive = false;
    _statusItems.remove('provider-wait');
    _providerStatus = null;
    if (streaming == null) {
      // Error-only turn: synthesize a message with the partial/error text.
      final m = MutableAssistantMessage(
        'assistant-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (visibleText.isNotEmpty) m.appendDelta(visibleText);
      m.errorSurface = surface;
      m.durationS = durationS;
      m.finalize(
        visibleText.isEmpty ? null : visibleText,
        status,
        usage,
        model: model,
        provider: provider,
        source: source,
        timestamp: stamp,
      );
      _messages.add(
        m.toChatMessage(isError: isError, rowId: payload['row_id'] as int?),
      );
    } else {
      streaming.errorSurface = surface;
      streaming.durationS = durationS;
      streaming.finalize(
        visibleText.isEmpty ? null : visibleText,
        status,
        usage,
        model: model,
        provider: provider,
        source: source,
        timestamp: stamp,
      );
      _replaceStreaming(streaming, isError, payload['row_id'] as int?);
      if (settlingInterim != null) {
        final index = _messages.indexWhere(
          (message) => message.id == settlingInterim!.id,
        );
        if (index >= 0) {
          final settled = _messages[index];
          _messages[index] = ChatMessage(
            id: settled.id,
            role: settled.role,
            parts: settled.parts,
            pending: false,
            interim: false,
            isError: settled.isError,
            errorSurface: settled.errorSurface,
            durationS: settled.durationS,
            attachmentRefs: settled.attachmentRefs,
            rowId: settled.rowId,
            historyOrdinal: settled.historyOrdinal,
            timestamp: settled.timestamp,
            source: settled.source,
            model: settled.model,
            provider: settled.provider,
            usage: settled.usage,
            reactions: settled.reactions,
          );
        }
      }
    }
    if (_diagnosticLogging) {
      _logStream(
        'event=message.complete status=$status duration_ms=$_streamElapsedMs '
        'text_frames=$_textFrames text_chars=$_textChars '
        'reasoning_frames=$_reasoningFrames reasoning_chars=$_reasoningChars '
        'tool_count=${_streamToolIds.length} '
        'subagent_count=${_streamSubagentIds.length} '
        'subagent_events=$_subagentEvents message_count=${_messages.length} '
        'had_streaming=${streaming != null}',
      );
      _streamElapsed?.stop();
      _streamElapsed = null;
    }
    if (isError) {
      _recordRecovery(
        runtimeL10n.chatAssistantReplyFailed,
        retryText: surface?.retryable == false ? null : lastUserText(),
        detail: _errorDiagnostics(failureText, surface),
        errorSurface: surface,
      );
    }
    _flushStreamNotify();
  }

  static String _errorDiagnostics(String error, ChatErrorSurface? surface) {
    if (surface == null) return error;
    return [
      'layer: ${surface.layer}',
      'code: ${surface.code}',
      'retryable: ${surface.retryable}',
      if (surface.provider != null) 'provider: ${surface.provider}',
      if (surface.model != null) 'model: ${surface.model}',
      if (error.trim().isNotEmpty) 'error: ${error.trim()}',
    ].join('\n');
  }

  void _replaceStreaming(MutableAssistantMessage m, bool isError, int? rowId) {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].id == m.id) {
        _messages[i] = m.toChatMessage(isError: isError, rowId: rowId);
        return;
      }
    }
    _messages.add(m.toChatMessage(isError: isError, rowId: rowId));
  }

  /// Delta-only sync: pure text/reasoning accumulation does not rewrite the
  /// transcript row per token — the streaming row materializes the live
  /// buffer via [streamingMessage] once per throttled notify.
  void _syncStreamingDelta() {
    final m = _streaming;
    if (m == null) return;
    if (!m.rowAdded) {
      // First delta/reasoning frame: add the streaming message.
      _messages.add(m.toChatMessage());
      m.rowAdded = true;
    }
    _scheduleStreamNotify();
  }

  void _syncStreaming() {
    final m = _streaming;
    if (m == null) return;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].id == m.id) {
        _messages[i] = m.toChatMessage();
        m.rowAdded = true;
        _scheduleStreamNotify();
        return;
      }
    }
    // First structural frame: add the streaming message.
    _messages.add(m.toChatMessage());
    m.rowAdded = true;
    _scheduleStreamNotify();
  }

  // -------------------------------------------------------- message actions
  /// The last completed assistant message (for copy / TTS) (E3).
  ChatMessage? lastCompletedAssistant() {
    for (final m in _messages.reversed) {
      if (m.role == 'assistant' && !m.interim && !m.pending) {
        if (_streaming != null && m.id == _streaming!.id) continue;
        return m;
      }
    }
    return null;
  }

  /// The last user message text (for regenerate / retry).
  String? lastUserText() {
    for (final m in _messages.reversed) {
      if (m.role == 'user' && !m.interim) {
        final t = m.promptText;
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _cancelStreamNotifyTimer();
    _sub?.cancel();
    for (final timer in _statusDismissTimers.values) {
      timer.cancel();
    }
    _notificationController.close();
    for (final store in _backgroundAssemblers.values) {
      store.dispose();
    }
    _backgroundAssemblers.clear();
    composerSurfaceRevision.dispose();
    super.dispose();
  }
}
