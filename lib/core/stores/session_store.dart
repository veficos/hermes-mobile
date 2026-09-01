/// SessionStore: session list, current session lifecycle and management.
///
/// The only store that knows session ids (durable only; runtime ids stay
/// internal). Fixes from APP_DESIGN.md: C3 (no null `storedSessionId!`),
/// F3 (generation guard against switch races), F8 (event isolation),
/// F9 (teardown ordering) and D8 (rename/archive/usage/compress).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/runtime_l10n.dart';

import '../api_client.dart';
import '../chat_message.dart';
import '../connections/connection_registry.dart';
import '../gateway.dart';
import '../models.dart';
import '../session_refs.dart';
import '../inflight_turn_journal.dart';
import 'cache_store.dart';
import 'chat_store.dart';
import 'composer_status_store.dart';
import 'connection_store.dart';
import 'request_store.dart';

typedef HandoffGatewayRequest =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> params,
    );
typedef ChatGatewayRequest =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> params,
    );

/// True for transient transport failures (socket drop, connect/response
/// timeout) where a single automatic resubmit is safe to attempt. Gateway
/// business errors (positive RPC codes like 4001/4009, protocol errors,
/// [StateError]) are deterministic and must NOT be retried.
bool isRetryableSendError(Object error) {
  if (error is TimeoutException) return true;
  if (error is GatewayException) {
    final code = error.code;
    return code == -1 || code == -2;
  }
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('WebSocketChannelException');
}

bool _isProvablyUnsentSendError(Object error) =>
    error is GatewayException &&
    error.code == -1 &&
    !error.requestMayHaveBeenSent;

int branchMessageCount(List<ChatMessage> messages, {String? throughMessageId}) {
  final end = throughMessageId == null
      ? messages.length
      : messages.indexWhere((message) => message.id == throughMessageId) + 1;
  if (end <= 0) return 0;
  return messages
      .take(end)
      .where(
        (message) =>
            (message.role == 'user' || message.role == 'assistant') &&
            message.fullText.trim().isNotEmpty,
      )
      .length;
}

int visibleUserOrdinal(List<ChatMessage> messages, String messageId) {
  final index = messages.indexWhere(
    (message) => message.id == messageId && message.role == 'user',
  );
  if (index < 0) return -1;
  return messages.take(index).where((message) => message.role == 'user').length;
}

ChatMessage? userTurnForMessage(List<ChatMessage> messages, String messageId) {
  final at = messages.indexWhere((item) => item.id == messageId);
  if (at < 0) return null;
  for (var index = at - 1; index >= 0; index--) {
    final candidate = messages[index];
    switch (candidate.role) {
      case 'user':
        return candidate.hasText ? candidate : null;
      case 'assistant':
        // A single turn can contain several persisted assistant rows (for
        // example tool-call/reasoning scaffolding followed by the final
        // answer).  The nearest preceding user row still owns all of them.
        continue;
      case 'tool':
      case 'system':
        continue;
      default:
        return null;
    }
  }
  return null;
}

Map<String, dynamic> truncateSubmitParams(
  String sessionId,
  String text,
  int ordinal, {
  int? rowId,
}) => {
  'session_id': sessionId,
  'text': text,
  'confirm_truncate': true,
  ...(rowId != null
      ? {'truncate_before_row_id': rowId}
      : {'truncate_before_user_ordinal': ordinal}),
  // Regenerate is an explicit destructive action. Supplying this confirmation
  // unconditionally also covers a first turn addressed by its stable row id.
  'confirm_empty_truncate': true,
};

Future<void> runChatRewind({
  required ChatGatewayRequest request,
  required String sessionId,
  required String text,
  required int ordinal,
  int? rowId,
  required bool interruptFirst,
}) async {
  final params = truncateSubmitParams(sessionId, text, ordinal, rowId: rowId);
  Future<void> interrupt() async {
    try {
      await request('session.interrupt', {'session_id': sessionId});
    } catch (_) {}
  }

  if (interruptFirst) await interrupt();
  try {
    await request('prompt.submit', params);
  } on GatewayException catch (error) {
    final busy =
        error.code == 4009 ||
        error.reason == 'busy' ||
        error.message.toLowerCase().contains('busy');
    if (!busy) rethrow;
    await interrupt();
    await request('prompt.submit', params);
  }
}

class HandoffResult {
  final bool ok;
  final String? error;

  const HandoffResult.success() : ok = true, error = null;
  const HandoffResult.failure(this.error) : ok = false;
}

/// Desktop-equivalent request/poll/timeout workflow. Kept independent from
/// the store so the gateway contract can be tested without mock UI data.
Future<HandoffResult> runHandoffFlow({
  required HandoffGatewayRequest request,
  required String sessionId,
  required String platform,
  void Function(String state)? onProgress,
  Duration timeout = const Duration(seconds: 60),
  Duration pollInterval = const Duration(milliseconds: 800),
}) async {
  final target = platform.trim().toLowerCase();
  if (target.isEmpty) {
    return HandoffResult.failure(runtimeL10n.sessionChooseHandoffPlatform);
  }

  onProgress?.call('pending');
  try {
    await request('handoff.request', {
      'platform': target,
      'session_id': sessionId,
    });
  } catch (error) {
    return HandoffResult.failure(error.toString());
  }

  final stopwatch = Stopwatch()..start();
  var lastState = 'pending';
  while (stopwatch.elapsed < timeout) {
    await Future<void>.delayed(pollInterval);
    Map<String, dynamic> record;
    try {
      record = await request('handoff.state', {'session_id': sessionId});
    } catch (error) {
      developer.log(
        'handoff.state poll failed; retrying',
        name: 'hermes.session.handoff',
        error: error,
      );
      continue;
    }
    final state = (record['state'] ?? 'pending').toString();
    if (state != lastState) {
      lastState = state;
      onProgress?.call(state);
    }
    if (state == 'completed') return const HandoffResult.success();
    if (state == 'failed') {
      return HandoffResult.failure(
        (record['error'] ?? runtimeL10n.sessionHandoffTargetFailed(target))
            .toString(),
      );
    }
  }

  final timeoutMessage = runtimeL10n.sessionHandoffTimeout;
  try {
    final cleanup = await request('handoff.fail', {
      'error': timeoutMessage,
      'session_id': sessionId,
    });
    if (cleanup['state'] == 'completed') {
      return const HandoffResult.success();
    }
  } catch (_) {
    // Desktop also treats cleanup as best-effort and still surfaces timeout.
  }
  return HandoffResult.failure(timeoutMessage);
}

class SessionInfoView {
  final String? model;
  final String? provider;
  final String? title;
  final String? cwd;
  final String? branch;
  final bool running;

  /// Desktop parity — conversation-scoped selector state.
  final String? personality;
  final String? workspace;
  final String? difficulty;
  final String? toolsConfig;

  SessionInfoView({
    this.model,
    this.provider,
    this.title,
    this.cwd,
    this.branch,
    this.running = false,
    this.personality,
    this.workspace,
    this.difficulty,
    this.toolsConfig,
  });

  factory SessionInfoView.fromJson(Map<String, dynamic> json) =>
      SessionInfoView(
        model: json['model']?.toString(),
        provider: json['provider']?.toString(),
        title: json['title']?.toString(),
        cwd: json['cwd']?.toString(),
        branch: (json['branch'] ?? json['git_branch'])?.toString(),
        running: json['running'] == true,
        personality: json['personality']?.toString(),
        workspace: json['workspace']?.toString(),
        difficulty: json['difficulty']?.toString(),
        toolsConfig: (json['tools_config'] ?? json['toolsConfig'])?.toString(),
      );

  /// Merge a partial session.info heartbeat without erasing fields omitted by
  /// the gateway. A stale `running:true` can be rejected after a terminal
  /// message edge while `running:false` is always authoritative.
  SessionInfoView mergeJson(
    Map<String, dynamic> json, {
    bool allowRunningTrue = true,
  }) {
    String? field(String key, String? current) =>
        json.containsKey(key) ? json[key]?.toString() : current;
    final hasBranch =
        json.containsKey('branch') || json.containsKey('git_branch');
    final nextRunning = json.containsKey('running')
        ? json['running'] == true
        : running;
    return SessionInfoView(
      model: field('model', model),
      provider: field('provider', provider),
      title: field('title', title),
      cwd: field('cwd', cwd),
      branch: hasBranch
          ? (json['branch'] ?? json['git_branch'])?.toString()
          : branch,
      running: nextRunning && !allowRunningTrue ? false : nextRunning,
      personality: field('personality', personality),
      workspace: field('workspace', workspace),
      difficulty: field('difficulty', difficulty),
      toolsConfig:
          json.containsKey('tools_config') || json.containsKey('toolsConfig')
          ? (json['tools_config'] ?? json['toolsConfig'])?.toString()
          : toolsConfig,
    );
  }

  SessionInfoView copyWith({
    String? model,
    String? provider,
    String? title,
    String? cwd,
    String? branch,
    bool? running,
    String? personality,
    String? workspace,
    String? difficulty,
    String? toolsConfig,
  }) {
    return SessionInfoView(
      model: model ?? this.model,
      provider: provider ?? this.provider,
      title: title ?? this.title,
      cwd: cwd ?? this.cwd,
      branch: branch ?? this.branch,
      running: running ?? this.running,
      personality: personality ?? this.personality,
      workspace: workspace ?? this.workspace,
      difficulty: difficulty ?? this.difficulty,
      toolsConfig: toolsConfig ?? this.toolsConfig,
    );
  }
}

/// Batch 2.4: queued send item (desktop parity: composer send queue).
///
/// The frontend can accept multiple submits while a previous turn is still
/// streaming; each message is enqueued and dispatched sequentially after the
/// in-flight turn completes (or fails).
@immutable
class QueuedAttachment {
  const QueuedAttachment({
    required this.kind,
    required this.label,
    this.occurrenceId,
    this.path,
    this.localPath,
    this.url,
    this.snippetText,
  });

  final String kind;
  final String label;
  final String? occurrenceId;
  final String? path;
  final String? localPath;
  final String? url;
  final String? snippetText;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'label': label,
    if (occurrenceId != null) 'occurrence_id': occurrenceId,
    if (path != null) 'path': path,
    if (localPath != null) 'local_path': localPath,
    if (url != null) 'url': url,
    if (snippetText != null) 'snippet_text': snippetText,
  };

  factory QueuedAttachment.fromJson(Map<String, dynamic> json) =>
      QueuedAttachment(
        kind: json['kind']?.toString() ?? 'file',
        label: json['label']?.toString() ?? 'attachment',
        occurrenceId: json['occurrence_id']?.toString(),
        path: json['path']?.toString(),
        localPath: json['local_path']?.toString(),
        url: json['url']?.toString(),
        snippetText: json['snippet_text']?.toString(),
      );
}

class QueuedMessage {
  final String id;
  final String text;
  final DateTime createdAt;
  final String ownerKey;
  final String? durableId;
  final bool deliveryUncertain;
  final String? displayText;
  final List<QueuedAttachment> attachments;
  QueuedMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.ownerKey,
    this.durableId,
    this.deliveryUncertain = false,
    this.displayText,
    this.attachments = const [],
  });

  QueuedMessage copyWith({
    String? text,
    bool? deliveryUncertain,
    String? displayText,
    List<QueuedAttachment>? attachments,
  }) => QueuedMessage(
    id: id,
    text: text ?? this.text,
    createdAt: createdAt,
    ownerKey: ownerKey,
    durableId: durableId,
    deliveryUncertain: deliveryUncertain ?? this.deliveryUncertain,
    displayText: displayText ?? this.displayText,
    attachments: attachments ?? this.attachments,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'owner_key': ownerKey,
    if (durableId != null) 'durable_id': durableId,
    if (deliveryUncertain) 'delivery_uncertain': true,
    if (displayText != null) 'display_text': displayText,
    if (attachments.isNotEmpty)
      'attachments': attachments.map((item) => item.toJson()).toList(),
  };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) => QueuedMessage(
    id: json['id'].toString(),
    text: json['text'].toString(),
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    ownerKey: json['owner_key']?.toString() ?? '',
    durableId: json['durable_id']?.toString(),
    deliveryUncertain: json['delivery_uncertain'] == true,
    displayText: json['display_text']?.toString(),
    attachments: json['attachments'] is List
        ? (json['attachments'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    QueuedAttachment.fromJson(item.cast<String, dynamic>()),
              )
              .toList(growable: false)
        : const [],
  );
}

class SessionStore extends ChangeNotifier implements ComposerStatusRpc {
  final ConnectionStore connection;
  final ChatStore chat;
  final RequestStore requests;
  final ComposerStatusStore? composerStatus;
  final bool persistLastSession;
  final CacheStore _cache = CacheStore();

  SessionStore({
    required this.connection,
    required this.chat,
    required this.requests,
    this.composerStatus,
    this.persistLastSession = true,
  }) {
    unawaited(restoreQueues());
    unawaited(requests.restore());
    connection.addListener(_onConnectionChanged);
    // F8: session-scoped events update our info; the chat store filters its
    // own events by the runtime id resolved through this store.
    chat.bindSessionSource(() => _runtimeId);
    chat.bindProfileSource(() => _profile);
    chat.bindDurableSessionSource(() => _durableId);
    chat.bindOwnerRouteSource(() => _owner?.route);
    chat.bindComposerStatus(composerStatus);
    requests.bindScopeResolver((runtimeId) {
      final owner = runtimeId == null
          ? _owner
          : connection.sessionOwners.byRuntime(runtimeId) ??
                (runtimeId == _runtimeId ? _owner : null);
      return (route: owner?.route, durableId: owner?.durableId);
    });
    chat.addListener(_onChatTranscriptChanged);
    requests.addListener(_onRequestsChanged);
    _eventSub = connection.routedEvents.listen((routed) {
      final e = routed.event;
      _applyListLiveEvent(e);
      final currentRoute = _owner?.route;
      if (currentRoute != null &&
          routed.route.connectionId != currentRoute.connectionId) {
        return;
      }
      final eventProfile = e.profile ?? routed.route.profile;
      if (eventProfile != null &&
          eventProfile.isNotEmpty &&
          _profile != null &&
          eventProfile != _profile) {
        return;
      }
      if (e.type == 'session.info' &&
          e.sessionId != null &&
          e.sessionId == _runtimeId) {
        _applySessionInfoEvent(e.payload);
      }
      if (e.type == 'message.start' && e.sessionId == _runtimeId) {
        _turnSettled = false;
      }
      if ((e.type == 'message.complete' || e.type == 'error') &&
          e.sessionId == _runtimeId) {
        _turnSettled = true;
      }
      if (e.type == 'session.usage' && e.sessionId == _runtimeId) {
        _liveUsage = Map.unmodifiable(e.payload);
        notifyListeners();
      }
      if (e.type == 'session.title' &&
          (e.sessionId == _runtimeId || e.sessionId == _durableId)) {
        final title = (e.payload['title'] ?? '').toString().trim();
        if (title.isNotEmpty) {
          _info = (_info ?? SessionInfoView()).copyWith(title: title);
          notifyListeners();
        }
      }
      if (e.type == 'message.complete' && e.sessionId == _runtimeId) {
        chat.clearRecoveredStream();
        final sid = _durableId;
        if (sid != null) {
          unawaited(clearInflightTurnJournal(sid));
        }
        _setInflightRecoveryNotice(false);
      }
      if (e.type == 'sessions.changed' ||
          e.type == 'session.title' ||
          e.type == 'message.start' ||
          e.type == 'message.complete' ||
          e.type == 'error' ||
          e.type == 'session.reclaimed' ||
          e.type == 'approval.request' ||
          e.type == 'clarify.request' ||
          e.type == 'secret.request' ||
          e.type == 'sudo.request' ||
          e.type == 'terminal.read.request' ||
          e.type == 'mcp.setup.request' ||
          e.type == 'interactive.expire' ||
          e.type == 'interactive.expired') {
        _scheduleListRefresh();
      }
      if (e.type == 'gateway.ready' &&
          _durableId != null &&
          currentRoute != null &&
          routed.route.connectionId == currentRoute.connectionId &&
          !_readOnly) {
        unawaited(
          _resumeSessionOnRoute(
            _durableId!,
            profile: _profile,
            ownerRoute: currentRoute,
          ),
        );
      }
    });
    _legacyEventSub = connection.events.listen((e) {
      if (connection.registry.runtimes.isNotEmpty) return;
      _applyListLiveEvent(e);
      if (e.type == 'session.info' &&
          e.sessionId != null &&
          e.sessionId == _runtimeId) {
        _applySessionInfoEvent(e.payload);
      }
      if (e.type == 'message.start' && e.sessionId == _runtimeId) {
        _turnSettled = false;
      }
      if ((e.type == 'message.complete' || e.type == 'error') &&
          e.sessionId == _runtimeId) {
        _turnSettled = true;
      }
      if (e.type == 'session.usage' && e.sessionId == _runtimeId) {
        _liveUsage = Map.unmodifiable(e.payload);
        notifyListeners();
      }
      if (e.type == 'session.title' &&
          (e.sessionId == _runtimeId || e.sessionId == _durableId)) {
        final title = (e.payload['title'] ?? '').toString().trim();
        if (title.isNotEmpty) {
          _info = (_info ?? SessionInfoView()).copyWith(title: title);
          notifyListeners();
        }
      }
      if (e.type == 'sessions.changed' ||
          e.type == 'session.title' ||
          e.type == 'message.start' ||
          e.type == 'message.complete' ||
          e.type == 'error' ||
          e.type == 'session.reclaimed' ||
          e.type.endsWith('.request') ||
          e.type == 'interactive.expire' ||
          e.type == 'interactive.expired') {
        _scheduleListRefresh();
      }
    });
    // Restore both the authoritative list and the active session after reconnect.
    _reconnectSub = connection.reconnected.listen((_) {
      unawaited(refreshList(limit: 500, profile: _sessionListProfile));
      final id = _durableId;
      if (id == null) return;
      if (_readOnly) {
        unawaited(openReadOnlySession(id, profile: _profile));
      } else {
        unawaited(resumeSession(id, profile: _profile));
      }
    });
  }

  void _onConnectionChanged() {
    if (connection.phase != ConnectionPhase.disconnected) return;
    final sid = _durableId;
    if (sid != null) unawaited(flushInflightTurnJournal(sid));
  }

  void _applySessionInfoEvent(Map<String, dynamic> payload) {
    _info = (_info ?? SessionInfoView()).mergeJson(
      payload,
      allowRunningTrue: !_turnSettled || chat.busy,
    );
    final rotated = (payload['stored_session_id'] ?? '').toString().trim();
    if (rotated.isNotEmpty && rotated != _durableId) {
      _rotateDurableIdentity(
        rotated,
        lineageRootId: payload['lineage_root_id']?.toString(),
      );
    }
    notifyListeners();
  }

  void _rotateDurableIdentity(String next, {String? lineageRootId}) {
    final previous = _durableId;
    final owner = _owner;
    if (previous == null || owner == null || next == previous) return;
    connection.sessionOwners.forget(previous);
    _durableId = next;
    _owner = SessionOwner(
      durableId: next,
      runtimeId: _runtimeId,
      lineageRootId: lineageRootId ?? owner.lineageRootId ?? previous,
      route: owner.route,
    );
    connection.sessionOwners.remember(_owner!);
    requests.rotateDurableScope(previous, next, owner.route);
    if (persistLastSession) unawaited(_saveLastSession(next));
  }

  // Durable id — the only session id the UI ever sees.
  String? _durableId;
  String? _runtimeId;
  SessionOwner? _owner;
  String? _profile;
  Map<String, dynamic> _liveUsage = const {};
  bool _turnSettled = false;
  SessionInfoView? _info;
  int _generation = 0; // F3: guards async session switches
  int _listGeneration = 0;
  int _profileGeneration = 0;
  String? _profileSwitchTarget;
  Future<void> _profileSwitchTail = Future<void>.value();
  List<ProfileInfo> _profiles = const [];
  String? _activeProfile;
  String? _runtimeCurrentProfile;
  String? _sessionListProfile;
  Map<String, dynamic> _profileConfig = const {};
  StreamSubscription? _eventSub;
  StreamSubscription? _legacyEventSub;
  StreamSubscription<void>? _reconnectSub;
  Timer? _listRefreshTimer;
  bool _readOnly = false;
  bool _inflightRecoveryNotice = false;
  final Map<String, Future<Map<String, dynamic>>> _resumeFlights = {};

  bool get inflightRecoveryNotice => _inflightRecoveryNotice;

  void clearInflightRecoveryNotice() {
    _setInflightRecoveryNotice(false);
  }

  void _setInflightRecoveryNotice(bool value) {
    if (_inflightRecoveryNotice == value) return;
    _inflightRecoveryNotice = value;
    notifyListeners();
  }

  void _onChatTranscriptChanged() {
    final sid = _durableId;
    if (sid == null || sid.isEmpty) return;
    persistInflightTurnThrottled(
      sessionId: sid,
      messages: chat.messages,
      busy: chat.busy,
      isStreaming: chat.isStreaming,
      streamId: chat.streamingMessageId,
    );
    if (connection.phase == ConnectionPhase.disconnected) {
      unawaited(flushInflightTurnJournal(sid));
    }
  }

  String? get durableId => _durableId;

  /// Profile attached to the open session. It is immutable session context,
  /// not the globally selected profile.
  String? get profile => _profile;
  List<ProfileInfo> get profiles => List.unmodifiable(_profiles);
  String? get activeProfile => _activeProfile;
  String? get runtimeCurrentProfile => _runtimeCurrentProfile;
  String? get sessionListProfile => _sessionListProfile;
  Map<String, dynamic> get profileConfig => _profileConfig;

  void applyProfileConfigPatch(String? profile, Map<String, dynamic> patch) {
    if (profile == null || profile != _activeProfile) return;
    _profileConfig = {..._profileConfig, ...patch};
    notifyListeners();
  }

  static const _lastSessionKey = 'hm_state_last_session';

  Future<void> _saveLastSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSessionKey, id);
  }

  /// Last opened session id (P5-3 state restoration), if any.
  Future<String?> lastSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSessionKey);
  }

  /// Internal runtime id — used only by protocol adapters (RequestSheet);
  /// UI code must never depend on it (D6).
  String? get runtimeId => _runtimeId;
  Map<String, dynamic> get liveUsage => Map.unmodifiable(_liveUsage);
  bool get reactionsEnabled {
    final display = _profileConfig['display'];
    return display is Map && display['message_reactions'] == true;
  }

  /// Desktop parity: `display.timestamps` in config.yaml gates every
  /// transcript timestamp. Display-only; defaults to on so older backends
  /// (no such key) keep showing message times.
  bool get displayTimestamps {
    final display = _profileConfig['display'];
    if (display is Map && display.containsKey('timestamps')) {
      return display['timestamps'] != false;
    }
    return true;
  }

  /// Desktop parity: `$reasoningCollapsedByDefault` — when set, reasoning
  /// blocks render collapsed. Reads `display.reasoning_collapsed` /
  /// `display.collapse_reasoning`; defaults to expanded.
  bool get reasoningCollapsedByDefault {
    final display = _profileConfig['display'];
    if (display is! Map) return false;
    return display['reasoning_collapsed'] == true ||
        display['collapse_reasoning'] == true;
  }

  SessionOwner? get owner => _owner;
  SessionInfoView? get info => _info;

  void applyModelSelection(String provider, String model) {
    final current = _info;
    _info = current == null
        ? SessionInfoView(provider: provider, model: model)
        : current.copyWith(provider: provider, model: model);
    notifyListeners();
  }

  /// Switch the model owned by the currently open chat session.
  ///
  /// The REST model assignment endpoint only changes the default used by new
  /// sessions. Existing sessions own a live agent and must be switched through
  /// the gateway's session-scoped `config.set` method instead.
  Future<Map<String, dynamic>> switchCurrentModel(
    String provider,
    String model,
  ) async {
    _ensureWritable();
    await connection.ensureConnected();
    final runtimeId = _runtimeId;
    if (runtimeId == null || runtimeId.isEmpty) {
      throw StateError(runtimeL10n.sessionNoActive);
    }
    final route = _requireOwnerRoute();
    final result = await connection.requestForOwner(route, 'config.set', {
      'session_id': runtimeId,
      'key': 'model',
      'value': '$model --provider $provider',
    });
    final deferred = result['deferred'] == true;
    final finalModel = (result['value'] ?? model).toString().trim();
    applyModelSelection(provider, finalModel.isEmpty ? model : finalModel);
    return {
      ...result,
      'provider': provider,
      'model': finalModel.isEmpty ? model : finalModel,
      'applied': deferred ? 'deferred' : 'now',
    };
  }

  bool get hasSession => _durableId != null;
  bool get readOnly => _readOnly;

  List<SessionRow>? _sessions;
  List<SessionRow>? get sessions =>
      _sessions?.map(_projectLiveState).toList(growable: false);

  final Map<String, bool> _liveStreamingById = {};
  final Map<String, bool> _liveCronRunningById = {};
  final Map<String, bool> _liveAttentionById = {};
  final Map<String, String?> _liveActiveStreamIdById = {};
  Set<String> _requestAttentionIds = {};

  String? _listIdForEvent(GatewayEvent event) {
    final stored =
        (event.payload['stored_session_id'] ??
                event.payload['durable_session_id'])
            ?.toString()
            .trim();
    if (stored?.isNotEmpty == true) return stored;
    final runtime = event.sessionId?.trim();
    if (runtime == null || runtime.isEmpty) return null;
    return connection.sessionOwners.byRuntime(runtime)?.durableId ?? runtime;
  }

  SessionRow _projectLiveState(SessionRow row) {
    final currentBusy = row.id == _durableId && chat.busy;
    return row.copyWith(
      isStreaming:
          currentBusy || (_liveStreamingById[row.id] ?? row.isStreaming),
      cronRunning: _liveCronRunningById[row.id] ?? row.cronRunning,
      hasPendingUserMessage:
          _requestAttentionIds.contains(row.id) ||
          (_liveAttentionById[row.id] ?? row.hasPendingUserMessage),
      activeStreamId: _liveActiveStreamIdById[row.id],
      clearActiveStreamId:
          _liveActiveStreamIdById.containsKey(row.id) &&
          _liveActiveStreamIdById[row.id] == null,
    );
  }

  void _applyListLiveEvent(GatewayEvent event) {
    final id = _listIdForEvent(event);
    if (id == null) return;
    var changed = false;
    void setStreaming(bool value) {
      if (_liveStreamingById[id] != value) {
        _liveStreamingById[id] = value;
        changed = true;
      }
    }

    switch (event.type) {
      case 'message.start':
        setStreaming(true);
        final streamId =
            event.payload['active_stream_id'] ?? event.payload['stream_id'];
        if (streamId != null) {
          _liveActiveStreamIdById[id] = streamId.toString();
          changed = true;
        }
      case 'message.complete':
      case 'error':
        setStreaming(false);
        if (!_liveActiveStreamIdById.containsKey(id) ||
            _liveActiveStreamIdById[id] != null) {
          _liveActiveStreamIdById[id] = null;
          changed = true;
        }
      case 'session.info':
        if (event.payload.containsKey('running')) {
          final running = parseHermesBool(event.payload['running']);
          setStreaming(running);
          if (!running &&
              (!_liveActiveStreamIdById.containsKey(id) ||
                  _liveActiveStreamIdById[id] != null)) {
            _liveActiveStreamIdById[id] = null;
            changed = true;
          }
        }
        if (event.payload.containsKey('cron_running')) {
          final value = parseHermesBool(event.payload['cron_running']);
          if (_liveCronRunningById[id] != value) {
            _liveCronRunningById[id] = value;
            changed = true;
          }
        }
        if (event.payload.containsKey('active_stream_id')) {
          final value = event.payload['active_stream_id']?.toString();
          if (!_liveActiveStreamIdById.containsKey(id) ||
              _liveActiveStreamIdById[id] != value) {
            _liveActiveStreamIdById[id] = value;
            changed = true;
          }
        }
        if (event.payload.containsKey('pending_user_message') ||
            event.payload.containsKey('has_pending_user_message')) {
          final value =
              parseHermesBool(event.payload['pending_user_message']) ||
              parseHermesBool(event.payload['has_pending_user_message']);
          if (_liveAttentionById[id] != value) {
            _liveAttentionById[id] = value;
            changed = true;
          }
        }
      case 'cron.start':
      case 'cron.started':
        if (_liveCronRunningById[id] != true) {
          _liveCronRunningById[id] = true;
          changed = true;
        }
      case 'cron.complete':
      case 'cron.completed':
      case 'cron.error':
        if (_liveCronRunningById[id] != false) {
          _liveCronRunningById[id] = false;
          changed = true;
        }
      case 'approval.request':
      case 'clarify.request':
      case 'secret.request':
      case 'sudo.request':
      case 'terminal.read.request':
      case 'mcp.setup.request':
        final requestId = event.payload['request_id']?.toString();
        if (requestId?.isNotEmpty == true && _liveAttentionById[id] != true) {
          _liveAttentionById[id] = true;
          changed = true;
        }
    }
    if (changed) notifyListeners();
  }

  void _onRequestsChanged() {
    final next = <String>{};
    for (final request in requests.pendingRequests) {
      final id =
          request.durableSessionId ??
          (request.sessionId == null
              ? null
              : connection.sessionOwners
                    .byRuntime(request.sessionId!)
                    ?.durableId) ??
          request.sessionId;
      if (id?.isNotEmpty == true) next.add(id!);
    }
    for (final id in _requestAttentionIds.difference(next)) {
      _liveAttentionById[id] = false;
    }
    for (final id in next) {
      _liveAttentionById[id] = true;
    }
    if (!_requestAttentionIds.containsAll(next) ||
        !next.containsAll(_requestAttentionIds)) {
      _requestAttentionIds = next;
      notifyListeners();
    }
  }

  // ------------------------------------------------------ list pagination
  /// Desktop sidebar parity: offset-window pagination with a "load more" row.
  static const int sessionPageSize = 50;
  int _listOffset = 0;
  bool _listHasMore = false;
  bool _loadingMore = false;
  bool get listHasMore => _listHasMore;
  bool get loadingMore => _loadingMore;

  // -------------------------------------------------------- list filters
  /// Desktop parity: persistent status/project/profile filter atoms.
  /// Status buckets: working / attention / idle / draft (dot-state buckets).
  final Set<String> statusFilter = {};
  bool _showArchived = false;
  bool get showArchived => _showArchived;
  bool get filtersActive => statusFilter.isNotEmpty || _showArchived;

  static const _statusFilterKey = 'hm_sidebar_status_filter';
  static const _showArchivedKey = 'hm_sidebar_show_archived';
  static const _pinnedOrderKey = 'hm_sidebar_pinned_order_v1';
  static const _groupingKey = 'hm_sidebar_grouping_v1';
  static const _sortKey = 'hm_sidebar_sort_v1';

  /// Desktop parity: `$sidebarGrouping` — 'flat' (time buckets) or
  /// 'project' (authoritative project → repo → lane tree).
  String _groupingMode = 'flat';
  String get groupingMode => _groupingMode;

  Future<void> setGroupingMode(String mode) async {
    if (_groupingMode == mode) return;
    _groupingMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groupingKey, mode);
    notifyListeners();
  }

  /// Desktop parity: `sidebar-sort.ts` — within a (non-pinned, non-running)
  /// time bucket, order by 'activity' (default, most recent first),
  /// 'created' (newest session first) or 'tokens' (heaviest first). Desktop
  /// also offers a cost key; mobile's `SessionRow` carries no reliable
  /// per-session cost figure to sort by, so that key is dropped rather than
  /// faked from a token estimate.
  String _sortMode = 'activity';
  String get sortMode => _sortMode;

  Future<void> setSortMode(String mode) async {
    if (_sortMode == mode) return;
    _sortMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortKey, mode);
    notifyListeners();
  }

  Future<void> loadSidebarPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    statusFilter
      ..clear()
      ..addAll(prefs.getStringList(_statusFilterKey) ?? const []);
    _showArchived = prefs.getBool(_showArchivedKey) ?? false;
    _groupingMode = prefs.getString(_groupingKey) ?? 'flat';
    _sortMode = prefs.getString(_sortKey) ?? 'activity';
    _pinnedOrder
      ..clear()
      ..addAll(prefs.getStringList(_pinnedOrderKey) ?? const []);
  }

  Future<void> setStatusFilter(Set<String> buckets) async {
    statusFilter
      ..clear()
      ..addAll(buckets);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_statusFilterKey, statusFilter.toList());
    notifyListeners();
  }

  Future<void> setShowArchived(bool value) async {
    if (_showArchived == value) return;
    _showArchived = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showArchivedKey, value);
    notifyListeners();
    await refreshList(profile: _sessionListProfile);
  }

  // ----------------------------------------------------- pinned ordering
  /// Desktop parity: pinned order is a pure client-side persistent atom
  /// (Hermes has no pin-order endpoint). Ids use the durable lineage id so
  /// rotated runtime ids keep their position.
  List<String> _pinnedOrder = [];
  List<String> get pinnedOrder => List.unmodifiable(_pinnedOrder);

  Future<void> setPinnedOrder(List<String> ids) async {
    _pinnedOrder = List.of(ids);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedOrderKey, _pinnedOrder);
    notifyListeners();
  }

  /// Apply the persisted pinned order to a pinned-row subset, keeping any
  /// rows absent from the stored order at the end (desktop reconcileOrderIds).
  List<SessionRow> applyPinnedOrder(List<SessionRow> pinned) {
    if (_pinnedOrder.isEmpty) return pinned;
    final rank = <String, int>{};
    for (var i = 0; i < _pinnedOrder.length; i++) {
      rank[_pinnedOrder[i]] = i;
    }
    final sorted = List<SessionRow>.of(pinned);
    sorted.sort((a, b) {
      final ra = rank[a.lineageRootId ?? a.id];
      final rb = rank[b.lineageRootId ?? b.id];
      if (ra == null && rb == null) return 0;
      if (ra == null) return 1;
      if (rb == null) return -1;
      return ra.compareTo(rb);
    });
    return sorted;
  }

  /// Status bucket for a row (desktop sessionStatusBucket parity).
  String statusBucket(SessionRow row) {
    if (row.needsAttention) return 'attention';
    if (row.isActivelyWorking) return 'working';
    return 'idle';
  }

  bool rowMatchesFilters(SessionRow row) {
    // Archived view shows only archived; normal view only non-archived.
    if (_showArchived != row.archived) return false;
    if (statusFilter.isNotEmpty && !statusFilter.contains(statusBucket(row))) {
      return false;
    }
    return true;
  }

  Future<void> loadMoreSessions() async {
    final api = connection.api;
    if (api == null || _loadingMore || !_listHasMore) return;
    _loadingMore = true;
    notifyListeners();
    final profile = _sessionListProfile;
    final requestGeneration = _listGeneration;
    try {
      final page = await api.listSessionsPage(
        limit: sessionPageSize,
        offset: _listOffset,
        includeArchived: true,
        profile: profile,
      );
      if (profile != _sessionListProfile ||
          requestGeneration != _listGeneration) {
        return;
      }
      final pageRows = profile == null
          ? page.sessions
          : page.sessions
                .map(
                  (row) => row.profile == null
                      ? row.copyWith(profile: profile)
                      : row,
                )
                .toList(growable: false);
      final existing = _sessions ?? const <SessionRow>[];
      final seen = existing.map((s) => s.id).toSet();
      final merged = List<SessionRow>.of(existing);
      for (final row in pageRows) {
        _rememberListedSession(row, profile);
        if (seen.add(row.id)) merged.add(row);
      }
      _sessions = merged;
      _listOffset += pageRows.length;
      _listHasMore = page.hasMore;
      notifyListeners();
    } catch (e) {
      connection.error = runtimeL10n.sessionLoadMoreFailed('$e');
      notifyListeners();
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------- send queue
  static const _queueStorageKey = 'hm_session_queues_v2';
  final Map<String, List<QueuedMessage>> _sendQueues = {};
  final Set<String> _parkedQueueKeys = <String>{};
  bool _drainingQueue = false;
  String? _dispatchingQueueId;

  String get _currentQueueKey =>
      _owner?.route.key ??
      '${connection.activeConnectionId.value}\u0000${_activeProfile ?? ''}';
  List<QueuedMessage> get _sendQueue =>
      _sendQueues.putIfAbsent(_currentQueueKey, () => []);
  List<QueuedMessage> _queueForKey(String key) =>
      _sendQueues.putIfAbsent(key, () => []);
  List<QueuedMessage> get sendQueue => List.unmodifiable(
    _sendQueue.where((item) => item.id != _dispatchingQueueId),
  );
  int get queueCount => sendQueue.length;
  bool get hasQueued => queueCount > 0;
  bool get queueParked => _parkedQueueKeys.contains(_currentQueueKey);

  /// Add a message to the send queue. If nothing is in flight, the message
  /// will be dispatched immediately; otherwise it waits until all earlier
  /// items have been sent (or cancelled).
  Future<void> enqueueMessage(
    String text, {
    String? displayText,
    List<QueuedAttachment> attachments = const [],
  }) async {
    if (text.trim().isEmpty) return;
    final qm = QueuedMessage(
      id: 'q-${DateTime.now().millisecondsSinceEpoch}-${_sendQueue.length}',
      text: text,
      createdAt: DateTime.now(),
      ownerKey: _currentQueueKey,
      durableId: _durableId,
      displayText: displayText,
      attachments: List.unmodifiable(attachments),
    );
    _sendQueue.add(qm);
    // A new queued prompt is fresh intent to continue this conversation.
    _parkedQueueKeys.remove(_currentQueueKey);
    await _persistQueues();
    notifyListeners();
    await _drainQueue();
  }

  Future<void> updateQueued(
    String id,
    String text, {
    String? displayText,
    List<QueuedAttachment>? attachments,
  }) async {
    final value = text.trim();
    if (value.isEmpty) return;
    final index = _sendQueue.indexWhere((item) => item.id == id);
    if (index < 0 || _dispatchingQueueId == id) return;
    _sendQueue[index] = _sendQueue[index].copyWith(
      text: value,
      deliveryUncertain: false,
      displayText: displayText,
      attachments: attachments,
    );
    await _persistQueues();
    notifyListeners();
  }

  /// Remove a pending queue item without sending it.
  void cancelQueued(String id) {
    final before = _sendQueue.length;
    _sendQueue.removeWhere((m) => m.id == id);
    if (_sendQueue.length != before) {
      unawaited(_persistQueues());
      notifyListeners();
    }
  }

  /// Drop all queued messages (does not interrupt an already in-flight turn).
  void clearQueue() {
    if (_sendQueue.isEmpty) return;
    _sendQueue.clear();
    _parkedQueueKeys.remove(_currentQueueKey);
    unawaited(_persistQueues());
    notifyListeners();
  }

  /// Stop/Esc parks pending prompts. They remain durable and visible, but no
  /// automatic drain may consume them until the user explicitly resumes or
  /// sends one now.
  void parkQueue() {
    if (_sendQueue.isEmpty || queueParked) return;
    _parkedQueueKeys.add(_currentQueueKey);
    notifyListeners();
  }

  Future<void> resumeQueue() async {
    if (!_parkedQueueKeys.remove(_currentQueueKey)) return;
    notifyListeners();
    await _drainQueue();
  }

  /// Move one pending entry to the head without dispatching it yet.
  void promoteQueued(String id) {
    final index = _sendQueue.indexWhere((item) => item.id == id);
    if (index <= 0 || _dispatchingQueueId == id) return;
    final item = _sendQueue.removeAt(index);
    _sendQueue.insert(0, item);
    unawaited(_persistQueues());
    notifyListeners();
  }

  /// Make an entry the next normal turn. If no drain is active it starts now;
  /// otherwise promotion determines the next item after the current submit.
  Future<void> sendQueuedNow(String id) async {
    promoteQueued(id);
    _parkedQueueKeys.remove(_currentQueueKey);
    notifyListeners();
    await _drainQueue();
  }

  /// Deliver a text-only queued entry into the active turn and remove it only
  /// after the gateway accepts the steer, preserving at-most-once semantics.
  Future<void> steerQueuedNow(String id) async {
    final index = _sendQueue.indexWhere((item) => item.id == id);
    if (index < 0 || _dispatchingQueueId == id) return;
    final item = _sendQueue[index];
    await steer(item.text);
    final currentIndex = _sendQueue.indexWhere((entry) => entry.id == id);
    if (currentIndex >= 0) _sendQueue.removeAt(currentIndex);
    _parkedQueueKeys.remove(_currentQueueKey);
    await _persistQueues();
    notifyListeners();
  }

  Future<void> _drainQueue() async {
    if (_drainingQueue || queueParked) return;
    final queueKey = _currentQueueKey;
    final queue = _queueForKey(queueKey);
    _drainingQueue = true;
    try {
      while (queue.isNotEmpty) {
        // Session switches never retarget an in-flight drain. Leave the old
        // owner's remaining entries durable for its next activation.
        if (_currentQueueKey != queueKey ||
            _parkedQueueKeys.contains(queueKey)) {
          break;
        }
        final next = queue.first;
        if (next.deliveryUncertain) break;
        _dispatchingQueueId = next.id;
        notifyListeners();
        try {
          await sendMessage(next.text);
          if (queue.isNotEmpty && queue.first.id == next.id) {
            queue.removeAt(0);
            _dispatchingQueueId = null;
            await _persistQueues();
            notifyListeners();
          }
        } catch (_) {
          // Keep the item durably queued. A transport error does not prove
          // whether prompt.submit reached the backend, so automatic resubmit
          // could duplicate a user turn. Reconciliation/retry is explicit.
          _dispatchingQueueId = null;
          if (queue.isNotEmpty && queue.first.id == next.id) {
            queue[0] = next.copyWith(deliveryUncertain: true);
            await _persistQueues();
          }
          notifyListeners();
          break;
        }
      }
    } finally {
      _dispatchingQueueId = null;
      _drainingQueue = false;
    }
  }

  Future<void> restoreQueues() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueStorageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map;
      _sendQueues
        ..clear()
        ..addAll(
          decoded.map(
            (key, value) => MapEntry(
              key.toString(),
              (value as List)
                  .map(
                    (item) => QueuedMessage.fromJson(
                      (item as Map).cast<String, dynamic>(),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      notifyListeners();
    } catch (_) {
      // Corrupt client cache is non-authoritative; leave it untouched on disk
      // for diagnostics and start with empty in-memory queues.
    }
  }

  Future<void> _persistQueues() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      for (final entry in _sendQueues.entries)
        if (entry.value.isNotEmpty)
          entry.key: entry.value.map((item) => item.toJson()).toList(),
    };
    await prefs.setString(_queueStorageKey, jsonEncode(payload));
  }

  /// REST domain API for the connected backend (null before configuration).
  ApiClient? get api => connection.api;

  Future<ProfilesPayload> refreshProfiles() async {
    final api = connection.api;
    if (api == null) throw StateError(runtimeL10n.sessionServerNotConnected);
    final generation = _profileGeneration;
    final payload = await api.listProfiles();
    if (generation != _profileGeneration) return payload;
    _profiles = payload.profiles;
    _activeProfile = payload.active;
    _runtimeCurrentProfile = payload.current;
    notifyListeners();
    return payload;
  }

  Future<ProfilesPayload> loadProfileContext({int listLimit = 100}) async {
    final api = connection.api;
    if (api == null) throw StateError(runtimeL10n.sessionServerNotConnected);
    final generation = _profileGeneration;
    final payload = await api.listProfiles();
    final active = payload.active;
    final config = await api.getConfig(profile: active);
    if (generation != _profileGeneration) return payload;
    await refreshList(limit: listLimit, profile: active, notify: false);
    if (generation != _profileGeneration) return payload;
    _profiles = payload.profiles;
    _activeProfile = active;
    _runtimeCurrentProfile = payload.current;
    _profileConfig = config;
    notifyListeners();
    return payload;
  }

  /// Atomically changes the sticky active profile and all profile-scoped UI
  /// data. Runtime current is recorded separately, while an open session is
  /// closed rather than relabelled with the new profile.
  Future<ProfilesPayload> switchActiveProfile(
    String name, {
    int listLimit = 100,
  }) async {
    final switchGeneration = ++_profileGeneration;
    _profileSwitchTarget = name;
    _sessionListProfile = name;
    ++_listGeneration;
    final previous = _profileSwitchTail;
    final done = Completer<void>();
    _profileSwitchTail = done.future;
    await previous;
    try {
      final api = connection.api;
      if (api == null) throw StateError(runtimeL10n.sessionServerNotConnected);
      await closeSession(notify: false);
      clearSessionList(notify: false);
      final activation = await api.activateProfile(name);
      final payload = await api.listProfiles();
      final responseActive = activation['active']?.toString().trim();
      final active =
          payload.active ??
          (responseActive == null || responseActive.isEmpty
              ? name
              : responseActive);
      if (switchGeneration != _profileGeneration) {
        return ProfilesPayload(
          profiles: payload.profiles,
          active: active,
          current: payload.current,
          source: payload.source,
        );
      }
      final config = await api.getConfig(profile: active);
      await refreshList(limit: listLimit, profile: active, notify: false);
      if (_sessionListProfile != active) {
        await refreshList(limit: listLimit, profile: active, notify: false);
      }
      _profiles = payload.profiles;
      _activeProfile = active;
      _runtimeCurrentProfile = payload.current;
      _profileConfig = config;
      if (switchGeneration == _profileGeneration) {
        _profileSwitchTarget = null;
      }
      notifyListeners();
      return ProfilesPayload(
        profiles: payload.profiles,
        active: active,
        current: payload.current,
        source: payload.source,
      );
    } finally {
      if (switchGeneration == _profileGeneration) {
        _profileSwitchTarget = null;
      }
      done.complete();
    }
  }

  // ------------------------------------------------------------ open/close
  Future<void> openNewSession({
    String? cwd,
    String? model,
    String? provider,
    String? title,
    String? projectId,
  }) async {
    await connection.ensureConnected();
    final gen = ++_generation;
    final profile = _activeProfile;
    final route = OwnerRoute(
      connectionId: connection.activeConnectionId,
      profile: profile,
    );
    final result = await connection.requestForOwner(route, 'session.create', {
      'cols': 48,
      'source': 'mobile',
      if (profile != null && profile.isNotEmpty) 'profile': profile,
      if (cwd != null && cwd.isNotEmpty) 'cwd': cwd,
      if (model != null && model.isNotEmpty) 'model': model,
      if (provider != null && provider.isNotEmpty) 'provider': provider,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (projectId != null && projectId.isNotEmpty) 'project_id': projectId,
    });
    if (gen != _generation) return; // superseded by a newer switch
    _applySession(
      durableId: result['stored_session_id']?.toString(),
      runtimeId: result['session_id']?.toString(),
      profile: profile,
      route: route,
      info: result['info'] is Map
          ? SessionInfoView.fromJson(
              (result['info'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  Future<void> resumeSession(String durableId, {String? profile}) =>
      _resumeSessionOnRoute(durableId, profile: profile);

  Future<void> openSessionReference(String reference) async {
    final parsed = parseSessionReference(reference);
    final targetProfile = parsed.profile;
    if (targetProfile != null && targetProfile != _activeProfile) {
      await switchActiveProfile(targetProfile);
    }
    await resumeSession(
      parsed.sessionId,
      profile: targetProfile ?? _activeProfile,
    );
  }

  Future<void> resumeOwnedSession(String durableId, OwnerRoute route) =>
      _resumeSessionOnRoute(
        durableId,
        profile: route.profile,
        ownerRoute: route,
      );

  Future<void> _resumeSessionOnRoute(
    String durableId, {
    String? profile,
    OwnerRoute? ownerRoute,
  }) async {
    final gen = ++_generation;
    _readOnly = false;
    final knownOwner = connection.sessionOwners.byDurable(durableId);
    final route =
        ownerRoute ??
        knownOwner?.route ??
        OwnerRoute(
          connectionId: connection.activeConnectionId,
          profile: profile,
        );
    if (connection.registry.runtime(route.connectionId) == null &&
        route.connectionId == ConnectionStore.primaryConnectionId) {
      await connection.ensureConnected();
    }
    final flightKey = '${route.key}\u0000$durableId';
    var flight = _resumeFlights[flightKey];
    if (flight == null) {
      final completer = Completer<Map<String, dynamic>>();
      flight = completer.future;
      _resumeFlights[flightKey] = flight;
      unawaited(() async {
        try {
          completer.complete(
            await connection.requestForOwner(route, 'session.resume', {
              'session_id': durableId,
              'cols': 48,
              'source': 'mobile',
              'omit_messages': true,
              if (profile != null && profile.isNotEmpty) 'profile': profile,
            }),
          );
        } catch (error, stack) {
          completer.completeError(error, stack);
        } finally {
          _resumeFlights.remove(flightKey);
        }
      }());
    }
    final result = await flight;
    if (gen != _generation) return;
    _applySession(
      durableId: durableId,
      runtimeId: result['session_id']?.toString(),
      profile: profile,
      route: route,
      info: result['info'] is Map
          ? SessionInfoView.fromJson(
              (result['info'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
    // F11: refetch the authoritative transcript after a resume.
    await refreshTranscript();
    await chat.restoreSlashStatuses(durableId);
  }

  Future<void> openReadOnlySession(String durableId, {String? profile}) async {
    final knownOwner = connection.sessionOwners.byDurable(durableId);
    final route =
        knownOwner?.route ??
        OwnerRoute(
          connectionId: connection.activeConnectionId,
          profile: profile,
        );
    final api = connection.runtimeFor(route).api;
    final gen = ++_generation;
    final detail = await api.sessionInfo(durableId, profile: profile);
    if (gen != _generation) return;
    _readOnly = true;
    _applySession(
      durableId: durableId,
      runtimeId: null,
      profile: profile,
      route: route,
      info: SessionInfoView.fromJson(detail),
    );
    await refreshTranscript();
  }

  Future<void> openReadOnlyOwnedSession(
    String durableId,
    OwnerRoute route,
  ) async {
    final api = connection.runtimeFor(route).api;
    final gen = ++_generation;
    final detail = await api.sessionInfo(durableId, profile: route.profile);
    if (gen != _generation) return;
    _readOnly = true;
    _applySession(
      durableId: durableId,
      runtimeId: null,
      profile: route.profile,
      route: route,
      info: SessionInfoView.fromJson(detail),
    );
    await refreshTranscript();
  }

  void _applySession({
    String? durableId,
    String? runtimeId,
    String? profile,
    OwnerRoute? route,
    SessionInfoView? info,
  }) {
    // Only clear pending interactive requests on an actual session SWITCH.
    // A WS reconnect re-resumes the SAME session (same durableId); wiping the
    // queue there would strand pending approvals while the agent stays
    // blocked server-side. A backend re-emit after resume is deduped by
    // request_id in RequestStore.enqueue.
    _durableId = durableId;
    _runtimeId = runtimeId;
    _profile = profile;
    _liveUsage = const {};
    if (durableId != null && route != null) {
      _owner = SessionOwner(
        durableId: durableId,
        runtimeId: runtimeId,
        route: route,
      );
      connection.sessionOwners.remember(_owner!);
    } else {
      _owner = null;
    }
    _info = info;
    chat.activateRuntime(
      runtimeId,
      profile: profile ?? route?.profile,
      connectionId: route?.connectionId.value,
    );
    // Requests are owner-scoped and may belong to background sessions. A
    // foreground switch must not discard another session's blocking prompt.
    // P5-3 state restoration: remember the open session so a later app start
    // can offer "continue last session".
    if (durableId != null && durableId.isNotEmpty) {
      if (persistLastSession) unawaited(_saveLastSession(durableId));
    }
    notifyListeners();
  }

  bool resultBusyOf(SessionInfoView? info) => info?.running == true;

  //: How many transcript messages load per page (loading speed optimization).
  static const historyPageSize = 50;
  //: Index (in the full message sequence) of the oldest message loaded so far.
  int _historyStartOffset = 0;

  Future<void> refreshTranscript() async {
    final id = _durableId;
    if (id == null) return;
    final api = _apiForStored(id);
    final gen = _generation;
    chat.startLoadingTranscript();
    try {
      // The backend's messages endpoint offsets from the OLDEST message, so
      // load the most recent page first (offset = total - pageSize) and page
      // backwards on scroll-to-top.
      final fallbackTotal = await _messageCount(id);
      var firstOffset = fallbackTotal > historyPageSize
          ? fallbackTotal - historyPageSize
          : 0;
      var page = await api.sessionMessagesPage(
        id,
        limit: historyPageSize,
        offset: firstOffset,
        profile: _profile,
      );
      final authoritativeTotal = page.total;
      if (authoritativeTotal != null) {
        final authoritativeOffset = authoritativeTotal > historyPageSize
            ? authoritativeTotal - historyPageSize
            : 0;
        if (authoritativeOffset != firstOffset) {
          firstOffset = authoritativeOffset;
          page = await api.sessionMessagesPage(
            id,
            limit: historyPageSize,
            offset: firstOffset,
            profile: _profile,
          );
        }
      }
      final msgs = page.messages;
      // A newer session may have superseded this fetch while it was in
      // flight; applying it now would overwrite the current transcript.
      if (gen != _generation) return;
      _historyStartOffset = firstOffset;
      // Offline-first: cache the newest page so a later disconnect can still
      // show the transcript read-only (spec §148–150).
      unawaited(
        _cache.cacheTranscript(
          id,
          msgs
              .map(
                (m) => m is Map
                    ? m.cast<String, dynamic>()
                    : <String, dynamic>{'raw': m},
              )
              .toList(),
          startOffset: firstOffset,
          hasMore: firstOffset > 0,
        ),
      );
      chat.loadHistory(
        chat.fromSessionMessages(msgs, sessionModel: _info?.model),
        hasMore: firstOffset > 0,
      );
      final running = resultBusyOf(_info);
      final recovery = await recoverInflightTurnJournal(
        id,
        chat.messages,
        keepPending: running,
      );
      if (recovery.applied) {
        chat.applyInflightRecovery(
          recovery.messages,
          streamId: recovery.streamId,
          markBusy: running,
        );
        _setInflightRecoveryNotice(!recovery.caughtUp);
      } else if (recovery.caughtUp) {
        _setInflightRecoveryNotice(false);
      }
    } catch (e) {
      // A newer session may have superseded this fetch while it was in
      // flight; don't touch its transcript or surface a stale error.
      if (gen != _generation) return;
      // Offline fallback: replay the cached transcript page.
      final cached = await _cache.cachedTranscript(id);
      if (cached != null) {
        final raw = cached['messages'] as List? ?? const [];
        final msgs = raw
            .map((m) => (m as Map).cast<String, dynamic>())
            .toList();
        _historyStartOffset = (cached['offset'] as num?)?.toInt() ?? 0;
        chat.loadHistory(
          chat.fromSessionMessages(msgs, sessionModel: _info?.model),
          hasMore: cached['hasMore'] == true,
        );
        final running = resultBusyOf(_info);
        final recovery = await recoverInflightTurnJournal(
          id,
          chat.messages,
          keepPending: running,
        );
        if (recovery.applied) {
          chat.applyInflightRecovery(
            recovery.messages,
            streamId: recovery.streamId,
            markBusy: running,
          );
          _setInflightRecoveryNotice(!recovery.caughtUp);
        } else if (recovery.caughtUp) {
          _setInflightRecoveryNotice(false);
        }
        connection.error = runtimeL10n.sessionOfflineTranscript;
      } else {
        connection.error = runtimeL10n.sessionTranscriptRefreshFailed('$e');
      }
    } finally {
      // A superseded fetch must not clear the newer session's spinner.
      if (gen == _generation) chat.finishLoadingTranscript();
    }
  }

  Future<int> _messageCount(String id) async {
    try {
      final api = _apiForStored(id);
      final detail = await api.sessionInfo(id, profile: _profile);
      return (detail['message_count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Load an older page of the transcript (invoked when the user scrolls to
  /// the top of the message list).
  Future<void> loadOlderMessages() async {
    final id = _durableId;
    if (id == null) return;
    final api = _apiForStored(id);
    if (chat.loadingHistory || !chat.hasMoreHistory) return;
    if (_historyStartOffset <= 0) {
      chat.appendOlderHistory(const [], hasMore: false);
      return;
    }
    chat.startLoadingHistory();
    try {
      final next = _historyStartOffset > historyPageSize
          ? _historyStartOffset - historyPageSize
          : 0;
      final msgs = await api.sessionMessagesRaw(
        id,
        limit: _historyStartOffset - next,
        offset: next,
        profile: _profile,
      );
      _historyStartOffset = next;
      chat.appendOlderHistory(
        chat.fromSessionMessages(msgs, sessionModel: _info?.model),
        hasMore: next > 0,
      );
    } catch (e) {
      connection.error = runtimeL10n.sessionOlderMessagesFailed('$e');
      // Leave hasMoreHistory untouched: marking the end of history here would
      // disarm both the scroll trigger and pull-to-refresh until the session
      // is reloaded. The header surfaces the failure with a retry affordance.
      chat.failLoadingHistory(e.toString());
    }
  }

  Future<void> closeSession({bool notify = true}) async {
    final gen = _generation;
    final id = _runtimeId;
    if (id != null) {
      try {
        await _requestCurrent('session.close', {'session_id': id});
      } catch (error) {
        developer.log(
          'session.close failed for $id; resetting locally',
          name: 'hermes.session',
          error: error,
        );
      }
    }
    // A newer session may have been opened while the close RPC was in flight;
    // resetting now would wipe it.
    if (gen != _generation) return;
    _reset(notify: notify);
  }

  Future<void> newChat() async {
    await closeSession();
    await openNewSession();
  }

  void _reset({bool notify = true}) {
    ++_generation;
    _durableId = null;
    _runtimeId = null;
    _profile = null;
    _info = null;
    _readOnly = false;
    chat.resetSession();
    requests.clear();
    if (notify) notifyListeners();
  }

  // ---------------------------------------------------------------- list
  Future<void> refreshList({
    int limit = 100,
    bool includeArchived = false,
    String? profile,
    bool notify = true,
  }) async {
    final api = connection.api;
    if (api == null) return;
    if (profile != null && _profileSwitchTarget == null) {
      _sessionListProfile = profile;
    }
    final requestGeneration = ++_listGeneration;
    final listProfile = profile ?? _sessionListProfile;
    // Cache-first is only safe for the legacy unscoped list.
    if (listProfile == null) {
      final cached = await _cache.cachedSessions();
      if (cached.isNotEmpty && _sessions == null) {
        _sessions = cached.map(SessionRow.fromJson).toList();
        if (notify) notifyListeners();
      }
    }
    try {
      final page = await api.listSessionsPage(
        limit: limit,
        offset: 0,
        includeArchived: includeArchived || _showArchived,
        profile: listProfile,
      );
      if (requestGeneration != _listGeneration ||
          listProfile != _sessionListProfile ||
          (_profileSwitchTarget != null &&
              listProfile != _profileSwitchTarget)) {
        return;
      }
      final fresh = listProfile == null
          ? page.sessions
          : page.sessions
                .map(
                  (row) => row.profile == null
                      ? row.copyWith(profile: listProfile)
                      : row,
                )
                .toList(growable: false);
      _sessionListProfile = listProfile;
      for (final row in fresh) {
        _rememberListedSession(row, listProfile);
      }
      _sessions = fresh;
      _listOffset = fresh.length;
      _listHasMore = page.hasMore;
      if (!includeArchived) {
        unawaited(_cache.cacheSessions(fresh.map((s) => s.toJson()).toList()));
      }
      // WebUI parity: snapshot streaming state and reconcile any background
      // completion transitions (streaming -> idle with new messages -> unread).
      await reconcileStreamingTransitions();
      // Record per-profile session count so subsequent profile switches can
      // decide whether to paint a full skeleton (WebUI #4717 honest skeleton).
      unawaited(
        recordSessionCountForProfile(
          listProfile ?? '__default__',
          fresh.length,
        ),
      );
      connection.error = null;
      if (notify) notifyListeners();
    } catch (e) {
      if (requestGeneration != _listGeneration) return;
      // The shared cache is only valid for the legacy unscoped list.
      if (listProfile == null && (_sessions == null || _sessions!.isEmpty)) {
        final cb = await _cache.cachedSessions();
        if (cb.isNotEmpty) {
          _sessions = cb.map(SessionRow.fromJson).toList();
        }
      }
      connection.error = runtimeL10n.sessionListLoadFailed('$e');
      if (notify) notifyListeners();
    }
  }

  void clearSessionList({bool notify = true}) {
    ++_listGeneration;
    _sessions = null;
    _listOffset = 0;
    _listHasMore = false;
    if (notify) notifyListeners();
  }

  void _scheduleListRefresh() {
    _listRefreshTimer?.cancel();
    _listRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (connection.api != null) {
        unawaited(refreshList(limit: 500, profile: _sessionListProfile));
      }
    });
  }

  void _ensureWritable() {
    if (_profileSwitchTarget != null) {
      throw StateError(runtimeL10n.sessionProfileSwitching);
    }
    if (_readOnly) throw StateError(runtimeL10n.sessionSubagentReadOnly);
  }

  void _ensureSessionOperationValid({
    required int generation,
    required int profileGeneration,
    required String? runtimeId,
    required String? profile,
  }) {
    _ensureWritable();
    if (generation != _generation ||
        profileGeneration != _profileGeneration ||
        runtimeId != _runtimeId ||
        profile != _profile) {
      throw StateError(runtimeL10n.sessionChangedRetry);
    }
  }

  // ------------------------------------------------------------ management
  void _rememberListedSession(SessionRow row, String? listProfile) {
    final existing = connection.sessionOwners.byDurable(row.id);
    if (existing != null) return;
    connection.sessionOwners.remember(
      SessionOwner(
        durableId: row.id,
        route: OwnerRoute(
          connectionId: connection.activeConnectionId,
          profile: row.profile ?? listProfile,
        ),
      ),
    );
  }

  OwnerRoute _routeForStored(String id) {
    final known = connection.sessionOwners.byDurable(id);
    if (known != null) return known.route;
    throw StateError(runtimeL10n.sessionConnectionUnknown(id));
  }

  ApiClient _apiForStored(String id) {
    final route = _routeForStored(id);
    final runtime = connection.registry.runtime(route.connectionId);
    if (runtime != null) return runtime.api;
    if (route.connectionId == ConnectionStore.primaryConnectionId &&
        connection.api != null) {
      return connection.api!;
    }
    throw StateError(
      runtimeL10n.sessionConnectionUnavailable('${route.connectionId}'),
    );
  }

  Future<void> rename(String title) async {
    _ensureWritable();
    final id = _durableId ?? _runtimeId;
    if (id == null) return;
    await renameStoredSession(id, title);
  }

  /// Rename a sidebar row with the same runtime-first behavior as desktop.
  ///
  /// A fresh chat/branch is not present in the durable sessions table until
  /// its first turn.  For the active row we know the live runtime id, so the
  /// gateway's `session.title` RPC is authoritative and persists it on demand.
  /// Background rows continue through REST so profile/session routing remains
  /// correct.  The mobile server also owns the same fallback for older apps.
  Future<void> renameStoredSession(String id, String title) async {
    final normalized = title.trim();
    final api = _apiForStored(id);

    final active = id == _durableId || id == _runtimeId;
    final runtimeId = active ? _runtimeId : null;
    if (normalized.isNotEmpty && runtimeId != null && _owner?.route != null) {
      try {
        await connection.requestForOwner(_routeForStored(id), 'session.title', {
          'session_id': runtimeId,
          'title': normalized,
        });
      } catch (error) {
        developer.log(
          'session.title RPC failed for $id; falling back to REST',
          name: 'hermes.session',
          error: error,
        );
        await api.setSessionTitle(
          id,
          normalized,
          profile: _routeForStored(id).profile,
        );
      }
    } else {
      await api.setSessionTitle(
        id,
        normalized,
        profile: _routeForStored(id).profile,
      );
    }
    _info = _info == null
        ? SessionInfoView(title: normalized)
        : SessionInfoView(
            model: _info!.model,
            provider: _info!.provider,
            title: normalized,
            cwd: _info!.cwd,
            running: _info!.running,
          );
    await refreshList(limit: 500);
    notifyListeners();
  }

  Future<void> setArchived(String id, bool archived) async {
    final api = _apiForStored(id);
    await api.setSessionArchived(
      id,
      archived,
      profile: _routeForStored(id).profile,
    );
  }

  Future<void> setPinned(String id, bool pinned) async {
    final api = _apiForStored(id);
    await api.pinSession(id, pinned);
    await refreshList(limit: 500);
  }

  Future<SessionRow> branchStoredSession(String id, {int? keepCount}) async {
    final api = _apiForStored(id);
    final row = await api.branchStoredSession(id, keepCount: keepCount);
    await refreshList(limit: 500);
    return row;
  }

  Future<SessionRow> duplicateStoredSession(String id) async {
    final api = _apiForStored(id);
    final row = await api.duplicateSession(id);
    await refreshList(limit: 500);
    return row;
  }

  Future<String> regenerateStoredSessionTitle(
    String id, {
    bool preferLatest = false,
  }) async {
    final api = _apiForStored(id);
    final title = await api.regenerateSessionTitle(
      id,
      preferLatest: preferLatest,
    );
    await refreshList(limit: 500);
    return title;
  }

  /// Regenerate the current session's title (WebUI row-menu parity,
  /// `/sessions/{id}/title/regenerate`) and immediately refresh the title
  /// shown in the chat header.
  Future<String> regenerateCurrentTitle() async {
    _ensureWritable();
    final id = _durableId;
    if (id == null) throw StateError(runtimeL10n.sessionUnsavedTitle);
    final title = (await regenerateStoredSessionTitle(
      id,
      preferLatest: true,
    )).trim();
    if (title.isNotEmpty) {
      final cur = _info;
      _info = cur == null
          ? SessionInfoView(title: title)
          : SessionInfoView(
              model: cur.model,
              provider: cur.provider,
              title: title,
              cwd: cur.cwd,
              branch: cur.branch,
              running: cur.running,
              personality: cur.personality,
              workspace: cur.workspace,
              difficulty: cur.difficulty,
              toolsConfig: cur.toolsConfig,
            );
      notifyListeners();
    }
    return title;
  }

  Future<String> createStoredSessionShare(String id) async {
    final api = _apiForStored(id);
    final result = await api.createSessionShare(id);
    final share = result['share'] as Map?;
    final url = share?['url']?.toString() ?? '';
    if (url.isEmpty) throw StateError(runtimeL10n.sessionShareLinkMissing);
    await refreshList(limit: 500);
    return url;
  }

  String storedSessionShareUrl(String token) {
    final api = connection.api;
    if (api == null) throw StateError(runtimeL10n.sessionServerNotConnected);
    return api.sessionShareUrl(token);
  }

  Future<void> revokeStoredSessionShare(String id) async {
    final api = _apiForStored(id);
    await api.revokeSessionShare(id);
    await refreshList(limit: 500);
  }

  Future<void> moveStoredSession(String id, String? projectId) async {
    final api = _apiForStored(id);
    await api.moveSession(id, projectId);
    await refreshList(limit: 500);
  }

  Future<Map<String, dynamic>> exportStoredSession(
    String id, {
    String format = 'json',
  }) async {
    final api = _apiForStored(id);
    return api.exportSession(id, format: format);
  }

  Future<void> stopStoredSession(SessionRow row) async {
    final streamId = row.activeStreamId;
    final api = _apiForStored(row.id);
    if (streamId == null || streamId.isEmpty) return;
    await api.stopSessionStream(row.id, streamId);
    if (row.id == _durableId) chat.markIdle();
    await refreshList(limit: 500);
  }

  Future<void> delete(String id) async {
    if (id == _durableId || id == _runtimeId) _ensureWritable();
    final api = _apiForStored(id);
    await api.deleteSession(id);
    if (id == _durableId) _reset();
    await refreshList();
  }

  /// Batch delete multiple sessions. Returns the count of successfully deleted.
  Future<int> deleteSessions(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final byRoute = <OwnerRoute, List<String>>{};
    for (final id in ids) {
      byRoute.putIfAbsent(_routeForStored(id), () => []).add(id);
    }
    var deleted = 0;
    var failedCount = 0;
    for (final entry in byRoute.entries) {
      final api = _apiForStored(entry.value.first);
      final result = await api.deleteSessions(entry.value);
      deleted += (result['deleted'] as List? ?? const []).length;
      failedCount += (result['failed'] as List? ?? const []).length;
    }
    if (ids.contains(_durableId ?? '')) _reset();
    await refreshList();
    if (failedCount > 0) {
      throw StateError(
        runtimeL10n.sessionBatchDeletePartial(deleted, failedCount),
      );
    }
    return deleted;
  }

  /// Compress the current session (needs the live gateway binding).
  Future<Map<String, dynamic>> compress() async {
    final runtimeId = _runtimeId;
    if (runtimeId == null) throw StateError(runtimeL10n.sessionNoActive);
    final result = await _requestCurrent('session.compress', {
      'session_id': runtimeId,
    });
    return result;
  }

  /// Context usage for the current session (WS `session.usage`).
  Future<Map<String, dynamic>> usage() async {
    final runtimeId = _runtimeId;
    if (runtimeId == null) return {};
    try {
      return await _requestCurrent('session.usage', {'session_id': runtimeId});
    } catch (_) {
      return {};
    }
  }

  // ------------------------------------------------------------- chat ops
  // Socket-bound operations live here (they need the runtime id + a live
  // connection). P4: every operation ensures connectivity first.

  OwnerRoute _requireOwnerRoute() {
    return _owner?.route ??
        OwnerRoute(
          connectionId: connection.activeConnectionId,
          profile: _profile,
        );
  }

  Future<Map<String, dynamic>> _requestCurrent(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) => connection.requestForOwner(
    _requireOwnerRoute(),
    method,
    params,
    timeout: timeout,
  );

  Future<void> sendMessage(
    String text, {
    void Function()? onAutoRetry,
    bool interrupted = false,
  }) async {
    _ensureWritable();
    final initialGeneration = _generation;
    final initialProfileGeneration = _profileGeneration;
    final initialRuntimeId = _runtimeId;
    final initialProfile = _profile;
    await connection.ensureConnected();
    _ensureSessionOperationValid(
      generation: initialGeneration,
      profileGeneration: initialProfileGeneration,
      runtimeId: initialRuntimeId,
      profile: initialProfile,
    );
    if (_runtimeId == null) {
      await openNewSession();
    }
    final generation = _generation;
    final profileGeneration = _profileGeneration;
    final rt = _runtimeId;
    final profile = _profile;
    final route = _requireOwnerRoute();
    if (rt == null) throw StateError(runtimeL10n.sessionCouldNotCreate);
    Future<Map<String, dynamic>> submit() {
      _ensureSessionOperationValid(
        generation: generation,
        profileGeneration: profileGeneration,
        runtimeId: rt,
        profile: profile,
      );
      return connection.requestForOwner(route, 'prompt.submit', {
        'session_id': rt,
        'text': text,
        if (interrupted) 'interrupted': true,
      }, timeout: const Duration(minutes: 30));
    }

    await chat.submit(() async {
      try {
        return await submit();
      } on GatewayException catch (error) {
        if (!_isProvablyUnsentSendError(error)) rethrow;
        onAutoRetry?.call();
        final runtime = connection.registry.runtime(route.connectionId);
        if (runtime != null) {
          await runtime.reconnectNow();
        } else {
          await connection.ensureConnected();
        }
        return submit();
      }
    }, text: text);
  }

  /// Send an off-screen user intent from a trusted local HTML preview.
  ///
  /// The turn is durable and reaches the model normally, but the gateway marks
  /// it `display_kind=hidden`, so neither the optimistic path nor history
  /// hydration renders a user bubble.
  Future<void> sendHiddenMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty) return;
    _ensureWritable();
    final initialGeneration = _generation;
    final initialProfileGeneration = _profileGeneration;
    final initialRuntimeId = _runtimeId;
    final initialProfile = _profile;
    await connection.ensureConnected();
    _ensureSessionOperationValid(
      generation: initialGeneration,
      profileGeneration: initialProfileGeneration,
      runtimeId: initialRuntimeId,
      profile: initialProfile,
    );
    if (_runtimeId == null) await openNewSession();
    final generation = _generation;
    final profileGeneration = _profileGeneration;
    final runtimeId = _runtimeId;
    final profile = _profile;
    final route = _requireOwnerRoute();
    if (runtimeId == null) throw StateError(runtimeL10n.sessionCouldNotCreate);

    Future<Map<String, dynamic>> submit() {
      _ensureSessionOperationValid(
        generation: generation,
        profileGeneration: profileGeneration,
        runtimeId: runtimeId,
        profile: profile,
      );
      return connection.requestForOwner(route, 'prompt.submit', {
        'session_id': runtimeId,
        'text': prompt,
        'display_kind': 'hidden',
      }, timeout: const Duration(minutes: 30));
    }

    await chat.submitHidden(() async {
      try {
        return await submit();
      } on GatewayException catch (error) {
        if (!_isProvablyUnsentSendError(error)) rethrow;
        final runtime = connection.registry.runtime(route.connectionId);
        if (runtime != null) {
          await runtime.reconnectNow();
        } else {
          await connection.ensureConnected();
        }
        return submit();
      }
    });
  }

  Future<void> reactToMessage(ChatMessage message, String? emoji) async {
    _ensureWritable();
    final runtimeId = _runtimeId;
    if (runtimeId == null) throw StateError(runtimeL10n.sessionNoActive);
    final previous = message.reactions;
    final withoutUser = previous
        .where((reaction) => reaction.author != 'user')
        .toList(growable: true);
    MessageReaction? oldUser;
    for (final reaction in previous) {
      if (reaction.author == 'user') {
        oldUser = reaction;
        break;
      }
    }
    if (emoji != null && emoji.isNotEmpty && oldUser?.emoji != emoji) {
      withoutUser.add(
        MessageReaction(
          emoji: emoji,
          author: 'user',
          at: DateTime.now().millisecondsSinceEpoch / 1000,
        ),
      );
    }
    chat.replaceMessageReactions(message.id, withoutUser);
    try {
      final result = await _requestCurrent('message.react', {
        'session_id': runtimeId,
        if (message.rowId != null)
          'row_id': message.rowId
        else
          'newest_role': message.role,
        'emoji': emoji,
        'author': 'user',
      });
      final raw = result['reactions'];
      final authoritative = raw is List
          ? raw
                .whereType<Map>()
                .map(MessageReaction.fromJson)
                .where((reaction) => reaction.emoji.isNotEmpty)
                .toList(growable: false)
          : const <MessageReaction>[];
      chat.replaceMessageReactions(
        message.id,
        authoritative,
        rowId: (result['row_id'] as num?)?.toInt(),
      );
    } catch (_) {
      chat.replaceMessageReactions(message.id, previous);
      rethrow;
    }
  }

  /// Per-session toolset list (gateway `toolsets.list` with session scope).
  /// Throws when no live session is bound.
  Future<List<ToolsetInfo>> sessionToolsets() async {
    final rt = _runtimeId;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    final result = await _requestCurrent('toolsets.list', {'session_id': rt});
    final list = (result['toolsets'] as List?) ?? const [];
    return list
        .map((e) => ToolsetInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Enable/disable one toolset for the current session only (gateway
  /// `tools.configure` with session scope — WebUI session toolsets chip
  /// parity).
  Future<void> setSessionToolsetEnabled(String name, bool enabled) async {
    final rt = _runtimeId;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    await _requestCurrent('tools.configure', {
      'action': enabled ? 'enable' : 'disable',
      'names': [name],
      'session_id': rt,
    });
  }

  Future<void> interrupt() async {
    final rt = _runtimeId;
    if (rt == null) return;
    try {
      await _requestCurrent('session.interrupt', {'session_id': rt});
    } catch (error) {
      developer.log(
        'session.interrupt failed for $rt; marking idle locally',
        name: 'hermes.session',
        error: error,
      );
    }
    parkQueue();
    chat.markIdle();
  }

  /// Regenerate: redirect the current turn with the last user prompt (D7).
  Future<void> regenerate() async {
    _ensureWritable();
    final messages = chat.messages;
    final target = messages.lastWhere(
      (message) => message.role == 'user' && message.fullText.trim().isNotEmpty,
      orElse: () => ChatMessage(id: '', role: 'user', parts: const []),
    );
    if (target.id.isEmpty) return;
    await _rewindAndSubmit(target, target.fullText.trim());
  }

  Future<void> reloadFromMessage(ChatMessage message) async {
    _ensureWritable();
    final messages = chat.messages;
    final target = userTurnForMessage(messages, message.id);
    if (target == null) throw StateError(runtimeL10n.sessionUserMessageMissing);
    await _rewindAndSubmit(target, target.fullText.trim());
  }

  Future<void> editMessage(ChatMessage message, String text) async {
    _ensureWritable();
    final next = text.trim();
    if (message.role != 'user' ||
        next.isEmpty ||
        next == message.fullText.trim()) {
      return;
    }
    await _rewindAndSubmit(message, next);
  }

  Future<void> restoreToMessage(ChatMessage message) async {
    _ensureWritable();
    if (message.role != 'user' || message.fullText.trim().isEmpty) return;
    await _rewindAndSubmit(message, message.fullText.trim());
  }

  /// Re-send [anchor]'s turn with [text] — the "restore this version" action
  /// of the per-turn version picker. Unlike [editMessage] it does not bail
  /// when the text is unchanged (regenerations keep the same prompt).
  Future<void> resendTurn(ChatMessage anchor, String text) async {
    _ensureWritable();
    final next = text.trim();
    if (anchor.role != 'user' || next.isEmpty) return;
    await _rewindAndSubmit(anchor, next);
  }

  Future<void> _rewindAndSubmit(ChatMessage target, String text) async {
    final generation = _generation;
    final profileGeneration = _profileGeneration;
    final rt = _runtimeId;
    final profile = _profile;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    final ordinal = visibleUserOrdinal(chat.messages, target.id);
    if (ordinal < 0) {
      throw StateError(runtimeL10n.sessionRestoreMessageMissing);
    }
    await connection.ensureConnected();
    _ensureSessionOperationValid(
      generation: generation,
      profileGeneration: profileGeneration,
      runtimeId: rt,
      profile: profile,
    );
    final wasBusy = chat.busy;
    final snapshot = chat.rewindToUserMessage(
      target.id,
      replacementText: text == target.fullText.trim() ? null : text,
    );
    // Rewind discards the turns that spawned these processes; they belong to an
    // abandoned timeline. Kill live ones and drop every row.
    unawaited(composerStatus?.resetSessionBackground(rt) ?? Future.value());
    try {
      await runChatRewind(
        request: (method, params) => _requestCurrent(method, params),
        sessionId: rt,
        text: text,
        ordinal: ordinal,
        rowId: target.rowId,
        interruptFirst: wasBusy,
      );
    } catch (_) {
      chat.restoreSnapshot(snapshot);
      // The rewind that recorded a superseded version never happened.
      chat.dropLastTurnVersion(ChatStore.turnAnchorKey(target));
      rethrow;
    }
  }

  // -------------------------------------------------- chat & session features
  // Batch 3.1: yolo / steer / background prompt / branch / undo / context /
  // cwd / handoff — all socket-bound, all gated by an active runtime id.

  /// Toggle YOLO mode (auto-approve tool calls) for the current connection.
  Future<void> setYoloMode(bool enabled) async {
    final route =
        _owner?.route ??
        OwnerRoute(
          connectionId: connection.activeConnectionId,
          profile: _activeProfile,
        );
    await connection.requestForOwner(route, 'config.set', {
      'key': 'yolo',
      'value': enabled,
    });
  }

  /// Inject a steering message into the running turn without interrupting it.
  Future<void> steer(String text) async {
    final rt = _runtimeId;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    await _requestCurrent('session.steer', {'session_id': rt, 'text': text});
  }

  /// Submit a background prompt that runs alongside the foreground turn.
  /// Returns the server-assigned task id (may be empty if not supported).
  Future<String> submitBackground(String text) async {
    final rt = _runtimeId;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    final result = await _requestCurrent('prompt.background', {
      'session_id': rt,
      'text': text,
    });
    // Prompt the registry poll so the new background process appears promptly.
    unawaited(composerStatus?.refreshBackgroundProcesses(rt) ?? Future.value());
    return (result['task_id'] ?? '').toString();
  }

  /// List background processes for the current session.
  /// Mirrors desktop `process.list` used by `composer-status.ts`.
  ///
  /// The [sessionId] parameter is required by [ComposerStatusRpc]; this
  /// implementation uses the store's current runtime id internally.
  @override
  Future<List<Map<String, dynamic>>> listBackgroundProcesses(
    String sessionId,
  ) async {
    final rt = _runtimeId;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    final result = await _requestCurrent('process.list', {'session_id': rt});
    final processes = result['processes'];
    if (processes is List) {
      return processes
          .map(
            (e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
          )
          .toList();
    }
    return const [];
  }

  /// Kill a background process for the current session.
  /// Mirrors desktop `process.kill` used by `composer-status.ts`.
  ///
  /// The [sessionId] parameter is required by [ComposerStatusRpc]; this
  /// implementation uses the store's current runtime id internally.
  @override
  Future<void> killBackgroundProcess(String sessionId, String processId) async {
    final rt = _runtimeId;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    await _requestCurrent('process.kill', {
      'session_id': rt,
      'process_id': processId,
    });
  }

  /// Branch the current session through a transcript message (or live HEAD).
  Future<String> branchSession({String? atMessageId}) async {
    _ensureWritable();
    final rt = _runtimeId;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    int? count;
    if (atMessageId != null) {
      final targetIndex = chat.messages.indexWhere(
        (message) => message.id == atMessageId,
      );
      if (targetIndex < 0) {
        throw StateError(runtimeL10n.sessionBranchMessageMissing);
      }
      final target = chat.messages[targetIndex];
      if (target.historyOrdinal != null) {
        count = target.historyOrdinal! + 1;
      } else if (targetIndex != chat.messages.length - 1) {
        throw StateError(runtimeL10n.sessionHistoryPositionMissing);
      }
    }
    final result = await _requestCurrent('session.branch', {
      'session_id': rt,
      'count': ?count,
    });
    final newDurable = result['stored_session_id']?.toString();
    if (newDurable != null && newDurable.isNotEmpty) {
      await resumeSession(newDurable, profile: _profile);
    }
    return newDurable ?? '';
  }

  /// Undo the last full turn (user prompt + assistant reply + tool calls).
  Future<void> undoLastTurn() async {
    final rt = _runtimeId;
    if (rt == null) return;
    await _requestCurrent('session.undo', {'session_id': rt});
    await refreshTranscript();
  }

  /// Per-section context usage for the current session (tokens by source).
  Future<Map<String, dynamic>> contextBreakdown() async {
    final rt = _runtimeId;
    if (rt == null) return {};
    try {
      return await _requestCurrent('session.context_breakdown', {
        'session_id': rt,
      });
    } catch (_) {
      return {};
    }
  }

  /// Override the session's working directory (next prompt runs there).
  Future<void> setCwd(String cwd) async {
    final rt = _runtimeId;
    if (rt == null) return;
    await _requestCurrent('session.cwd.set', {'session_id': rt, 'cwd': cwd});
  }

  /// Queue a handoff and poll the external Hermes gateway watcher to a
  /// terminal state, matching desktop's bounded workflow.
  Future<HandoffResult> handoff(
    String platform, {
    void Function(String state)? onProgress,
  }) async {
    final rt = _runtimeId;
    if (rt == null) throw StateError(runtimeL10n.sessionNoActive);
    return runHandoffFlow(
      request: (method, params) => _requestCurrent(method, params),
      sessionId: rt,
      platform: platform,
      onProgress: onProgress,
    );
  }

  /// Handoff a durable sidebar row. Hermes' handoff gateway addresses live
  /// runtime sessions, so materialise the historical row before requesting
  /// the transfer instead of incorrectly sending its durable id.
  Future<HandoffResult> handoffStoredSession(
    String durableId,
    String platform, {
    void Function(String state)? onProgress,
  }) async {
    final route = _routeForStored(durableId);
    final resumed = await connection.requestForOwner(route, 'session.resume', {
      'session_id': durableId,
      'cols': 48,
      'source': 'mobile',
      'omit_messages': true,
    });
    final runtimeId = resumed['session_id']?.toString().trim() ?? '';
    if (runtimeId.isEmpty) {
      throw StateError(runtimeL10n.sessionRuntimeIdMissing);
    }
    return runHandoffFlow(
      request: (method, params) =>
          connection.requestForOwner(route, method, params),
      sessionId: runtimeId,
      platform: platform,
      onProgress: onProgress,
    );
  }

  // ==========================================================================
  // WebUI agent-session parity: draft persistence, unread tracking,
  // streaming snapshot, and new-chat draft session remember/restore.
  // ==========================================================================

  static const _draftSaveDelayMs = 400; // matches WebUI `_DRAFT_SAVE_DELAY_MS`
  static const _draftRestoreSuppressMs = 30000; // matches WebUI 30s TTL
  static const _newChatDraftSessionKey = 'hm_new_chat_draft_session';
  static const _sessionViewedCountsKey = 'hm_session_viewed_counts';
  static const _sessionCompletionUnreadKey = 'hm_session_completion_unread';
  static const _sessionObservedStreamingKey = 'hm_session_observed_streaming';
  static const _sessionProfileCountsKey = 'hm_session_profile_counts';

  final Map<String, Timer> _draftSaveTimers = {};
  // Suppress stale draft restore for 30s after send (signature-aware).
  final Map<String, _DraftSuppression> _draftRestoreSuppress = {};
  // Signatures of payloads we already persisted to server. Used to avoid
  // clearing a just-submitted composer whose server draft was remembered
  // before the POST cleared it.
  final Set<String> _knownDraftPayloads = {};

  // ──── Draft file canonicalization helpers ────
  static List<dynamic> _canonicalizeDraftFiles(List<dynamic>? files) {
    if (files == null || files.isEmpty) return const [];
    return files.where((f) => f != null).map((f) {
      if (f is String) return f;
      if (f is! Map) return f.toString();
      final m = Map<String, dynamic>.from(f);
      final canon = <String, dynamic>{
        'name': (m['name'] ?? m['filename'] ?? '').toString(),
        'path': (m['path'] ?? '').toString(),
        'kind': (m['kind'] ?? m['type'] ?? m['mime'] ?? '').toString(),
        'url': m['url'],
        'snippet': m['snippet'],
        'local_path': m['local_path'],
      };
      final sz = m['size'];
      if (sz is num) canon['size'] = sz.toInt();
      final lm = m['lastModified'];
      if (lm is num) canon['lastModified'] = lm.toInt();
      return canon;
    }).toList();
  }

  static String _draftSignature(String text, List<dynamic>? files) {
    final normFiles = _canonicalizeDraftFiles(files).map((f) {
      if (f is String) return {'value': f};
      if (f is! Map) return {'value': f.toString()};
      final m = Map<String, dynamic>.from(f);
      return {
        'name': m['name'] ?? '',
        'path': m['path'] ?? '',
        'size': m['size'],
        'kind': m['kind'] ?? '',
        'url': m['url'],
        'snippet': m['snippet'],
        'local_path': m['local_path'],
      };
    }).toList();
    return jsonEncode({'text': text, 'files': normFiles});
  }

  /// Schedule a debounced draft save (400 ms). Safe to call on every keystroke.
  /// Matches WebUI `_saveComposerDraft(sid, text, files)`.
  void scheduleDraftSave(String sid, String text, List<dynamic>? files) {
    if (sid.isEmpty) return;
    _draftSaveTimers.remove(sid)?.cancel();
    final normText = text;
    final normFiles = _canonicalizeDraftFiles(files);
    if (normText.isNotEmpty || normFiles.isNotEmpty) {
      _draftRestoreSuppress.remove(sid);
      _knownDraftPayloads.add(sid);
    }
    _draftSaveTimers[sid] = Timer(
      const Duration(milliseconds: _draftSaveDelayMs),
      () {
        _draftSaveTimers.remove(sid);
        unawaited(
          connection.api
              ?.saveDraft(sid, text: normText, files: normFiles)
              .then((d) {
                _rememberDraftPayloadState(sid, normText, normFiles);
              })
              .catchError((error) {
                developer.log(
                  'draft save failed for $sid',
                  name: 'hermes.session.draft',
                  error: error,
                );
              }),
        );
      },
    );
  }

  /// Flush any pending draft save immediately (called before a session switch
  /// so the composer contents survive the navigation hop).
  Future<void> flushDraftNow(
    String sid, {
    required String currentText,
    required List<dynamic> currentFiles,
    required ComposerDraft? serverDraft,
  }) async {
    if (sid.isEmpty) return;
    _draftSaveTimers.remove(sid)?.cancel();
    final normText = currentText;
    final normFiles = _canonicalizeDraftFiles(currentFiles);
    if (normText.isNotEmpty || normFiles.isNotEmpty) {
      _draftRestoreSuppress.remove(sid);
    }
    final hasLocal = normText.isNotEmpty || normFiles.isNotEmpty;
    final hasServer = serverDraft != null && serverDraft.hasPayload;
    final hasKnown = _knownDraftPayloads.contains(sid);
    if (!hasLocal && !hasServer && !hasKnown) return; // no-op: nothing to clear
    try {
      final saved = await connection.api?.saveDraft(
        sid,
        text: normText,
        files: normFiles,
      );
      if (saved != null) {
        _rememberDraftPayloadState(sid, normText, normFiles);
      }
    } catch (_) {}
  }

  void _rememberDraftPayloadState(
    String sid,
    String text,
    List<dynamic> files,
  ) {
    if (sid.isEmpty) return;
    if (text.isNotEmpty || files.isNotEmpty) {
      _knownDraftPayloads.add(sid);
    } else {
      _knownDraftPayloads.remove(sid);
    }
  }

  /// Call AFTER a successful user submit. Prevents a stale server draft from
  /// repopulating the composer for 30 s (matches WebUI's 30 s TTL with
  /// signature-aware suppression so a genuine cross-tab new draft still loads).
  void suppressDraftRestoreAfterSubmit(
    String sid, {
    String? submittedText,
    List<dynamic>? submittedFiles,
    ComposerDraft? rememberedServerDraft,
  }) {
    if (sid.isEmpty) return;
    _draftSaveTimers.remove(sid)?.cancel();
    final sigs = <String>[];
    void addSig(String s) {
      if (s.isNotEmpty && !sigs.contains(s)) sigs.add(s);
    }

    if (rememberedServerDraft != null) {
      addSig(
        _draftSignature(
          rememberedServerDraft.text,
          rememberedServerDraft.files,
        ),
      );
    }
    if (submittedText != null) {
      addSig(_draftSignature(submittedText, submittedFiles));
    }
    _draftRestoreSuppress[sid] = _DraftSuppression(
      until: DateTime.now().millisecondsSinceEpoch + _draftRestoreSuppressMs,
      signatures: sigs.isEmpty ? null : sigs,
    );
    // Local state must reflect the cleared composer immediately; a same-session
    // list refresh could otherwise race in and repopulate the textarea.
    _rememberDraftPayloadState(sid, '', const []);
    // Also clear any remembered "new chat draft session" for this sid.
    unawaited(_clearRememberedNewChatDraftSession(sid));
  }

  /// Returns true if this draft payload should be skipped (suppressed restore).
  /// Mirrors WebUI `_isComposerDraftRestoreSuppressed`.
  bool isDraftRestoreSuppressed(String sid, String text, List<dynamic>? files) {
    if (sid.isEmpty) return false;
    final sup = _draftRestoreSuppress[sid];
    if (sup == null) return false;
    if (DateTime.now().millisecondsSinceEpoch > sup.until) {
      _draftRestoreSuppress.remove(sid);
      return false;
    }
    final sigs = sup.signatures;
    if (sigs == null || sigs.isEmpty) return true; // legacy closed TTL
    if (sigs.contains(_draftSignature(text, files))) return true;
    _draftRestoreSuppress.remove(sid);
    return false;
  }

  // ──── New-chat draft session remember/restore ────

  Future<void> rememberNewChatDraftSession(String sid) async {
    final row = (_sessions ?? const []).where((r) => r.id == sid).firstOrNull;
    if (row == null) return;
    if ((row.messageCount ?? 0) != 0) return;
    if (row.effectivelyStreaming) return;
    final title = row.title ?? 'Untitled';
    if (title != 'Untitled' && title != 'New Chat') return;
    if (!row.composerDraft.hasPayload) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_newChatDraftSessionKey, sid);
  }

  Future<void> _clearRememberedNewChatDraftSession(String sid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_newChatDraftSessionKey) == sid) {
      await prefs.remove(_newChatDraftSessionKey);
    }
  }

  /// If a "new chat" session with a saved draft exists, return its id so the
  /// UI can auto-restore into it. Mirrors WebUI
  /// `_restoreRememberedNewChatDraftSession`.
  Future<String?> recalledNewChatDraftSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final sid = prefs.getString(_newChatDraftSessionKey);
    if (sid == null || sid.isEmpty) return null;
    if (_durableId == sid) return null; // already open
    // Verify the session still exists and still qualifies as a restorable
    // new-chat draft; otherwise drop the stale pointer silently.
    try {
      final detail = await connection.api?.sessionInfo(sid);
      if (detail == null) return null;
      final msgCount = (detail['message_count'] as num?)?.toInt() ?? 0;
      if (msgCount != 0) {
        await prefs.remove(_newChatDraftSessionKey);
        return null;
      }
      final title = (detail['title'] as String?) ?? 'Untitled';
      if (title != 'Untitled' && title != 'New Chat') {
        await prefs.remove(_newChatDraftSessionKey);
        return null;
      }
      return sid;
    } catch (_) {
      await prefs.remove(_newChatDraftSessionKey);
      return null;
    }
  }

  // ──── Session viewed counts + completion unread (WebUI sidebar dots) ────

  Future<Map<String, int>> _loadStringIntMap(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0),
        );
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveStringIntMap(String key, Map<String, int> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _loadJsonMap(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  Future<void> _saveJsonMap(String key, Map<String, dynamic> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {}
  }

  /// True when `row` shows a new unread indicator (red dot).
  /// Mirrors WebUI `_hasUnreadForSession`.
  Future<bool> hasUnreadForSession(SessionRow row) async {
    if (row.id.isEmpty) return false;
    if (await _hasCompletionUnread(row.id)) return true;
    final counts = await _loadStringIntMap(_sessionViewedCountsKey);
    if (!counts.containsKey(row.id)) {
      await setSessionViewedCount(row.id, row.messageCount ?? 0);
      return false;
    }
    final msgCount = row.messageCount ?? 0;
    return msgCount > (counts[row.id] ?? 0);
  }

  Future<bool> _hasCompletionUnread(String sid) async {
    final m = await _loadJsonMap(_sessionCompletionUnreadKey);
    return m.containsKey(sid);
  }

  /// Mark the viewed message count for a session (clears the message-count
  /// unread dot AND any stale completion-unread marker — WebUI #3020).
  Future<void> setSessionViewedCount(String sid, int messageCount) async {
    final m = await _loadStringIntMap(_sessionViewedCountsKey);
    m[sid] = messageCount;
    await _saveStringIntMap(_sessionViewedCountsKey, m);
    await _clearCompletionUnread(sid);
  }

  Future<void> _clearCompletionUnread(String sid) async {
    final m = await _loadJsonMap(_sessionCompletionUnreadKey);
    if (!m.containsKey(sid)) return;
    m.remove(sid);
    await _saveJsonMap(_sessionCompletionUnreadKey, m);
  }

  /// Background/async turn completion: mark this session with a completion
  /// unread entry so the next sidebar render paints a dot. Mirrors WebUI
  /// `_markSessionCompletionUnreadIfBackground` (without the tab-visibility
  /// check — mobile foreground state is tracked by the routing layer instead).
  Future<void> markCompletionUnreadIfNeeded(
    String sid,
    int messageCount,
  ) async {
    if (sid.isEmpty) return;
    if (_durableId == sid) {
      await setSessionViewedCount(sid, messageCount);
      notifyListeners();
      return;
    }
    final m = await _loadJsonMap(_sessionCompletionUnreadKey);
    m[sid] = {
      'message_count': messageCount,
      'completed_at': DateTime.now().millisecondsSinceEpoch,
    };
    await _saveJsonMap(_sessionCompletionUnreadKey, m);
    notifyListeners();
  }

  // ──── Observed streaming snapshots (phantom-completion unread prevention) ──

  /// Remember a session that was observed mid-streaming. When a later list
  /// poll shows it stopped streaming AND the message count advanced, treat
  /// it as a background completion that deserves an unread dot.
  Future<void> rememberObservedStreaming(SessionRow row) async {
    if (row.id.isEmpty) return;
    final m = await _loadJsonMap(_sessionObservedStreamingKey);
    m[row.id] = {
      'message_count': row.messageCount ?? 0,
      'last_message_at': row.lastMessageAt ?? 0,
      'observed_at': DateTime.now().millisecondsSinceEpoch,
    };
    await _saveJsonMap(_sessionObservedStreamingKey, m);
  }

  Future<void> forgetObservedStreaming(String sid) async {
    final m = await _loadJsonMap(_sessionObservedStreamingKey);
    if (!m.containsKey(sid)) return;
    m.remove(sid);
    await _saveJsonMap(_sessionObservedStreamingKey, m);
  }

  /// Snapshot id → streaming flag for sidebar rows (mirrors `_sessionStreamingById`).
  final Map<String, bool> _streamingById = {};

  void syncStreamingFromRows() {
    for (final r in _sessions ?? const []) {
      _streamingById[r.id] = r.effectivelyStreaming;
    }
  }

  /// Called after `refreshList()` resolves. Detects any session that moved
  /// from streaming → idle with an increased message count and marks a
  /// completion unread for it (WebUI #4946 equivalent on mobile).
  Future<void> reconcileStreamingTransitions() async {
    final rows = sessions ?? const [];
    for (final r in rows) {
      final wasStreaming = _streamingById[r.id] ?? false;
      final nowStreaming = r.effectivelyStreaming;
      if (wasStreaming && !nowStreaming) {
        await markCompletionUnreadIfNeeded(r.id, r.messageCount ?? 0);
        await forgetObservedStreaming(r.id);
      }
      if (nowStreaming) {
        await rememberObservedStreaming(r);
      }
      _streamingById[r.id] = nowStreaming;
    }
  }

  // Per-profile session count cache (#4717 — honest skeleton on profile switch).
  Future<int?> knownSessionCountForProfile(String profile) async {
    final counts = await _loadJsonMap(_sessionProfileCountsKey);
    final v = counts[profile];
    return v is int ? v : null;
  }

  Future<void> recordSessionCountForProfile(String profile, int count) async {
    final counts = await _loadJsonMap(_sessionProfileCountsKey);
    if (counts[profile] == count) return;
    counts[profile] = count;
    await _saveJsonMap(_sessionProfileCountsKey, counts);
  }

  @override
  void dispose() {
    connection.removeListener(_onConnectionChanged);
    chat.removeListener(_onChatTranscriptChanged);
    requests.removeListener(_onRequestsChanged);
    final sid = _durableId;
    if (sid != null && sid.isNotEmpty) {
      cancelInflightPersistTimer(sid);
    }
    _listRefreshTimer?.cancel();
    for (final timer in _draftSaveTimers.values) {
      timer.cancel();
    }
    _draftSaveTimers.clear();
    _eventSub?.cancel();
    _legacyEventSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }
}

/// Helper: draft-restore suppression entry (matches WebUI `{until, signatures}` Map).
class _DraftSuppression {
  final int until;
  final List<String>? signatures;
  _DraftSuppression({required this.until, this.signatures});
}
