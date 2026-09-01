/// Crash-survivable in-flight turn journal (desktop `inflight-turn-journal.ts`).
///
/// Persists the visible tail of a running turn while streaming; on session
/// resume or reconnect, folds it back onto the REST transcript.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'chat_message.dart';
import 'chat_message_codec.dart';

const _storagePrefix = 'hm_inflight_journal_v1:';
const _persistThrottleMs = 400;
const _maxJournalMessages = 24;
const _maxTextChars = 64 * 1024;
const _maxAgeMs = 7 * 24 * 60 * 60 * 1000;

class InFlightRecoveryResult {
  final bool applied;
  final bool caughtUp;
  final List<ChatMessage> messages;
  final String? streamId;

  const InFlightRecoveryResult({
    required this.applied,
    required this.caughtUp,
    required this.messages,
    this.streamId,
  });
}

class InflightSnapshot {
  final List<ChatMessage> messages;
  final String? streamId;
  final int updatedAt;

  const InflightSnapshot({
    required this.messages,
    this.streamId,
    required this.updatedAt,
  });
}

final Map<String, Timer> _persistTimers = {};
final Map<String, _PendingPersist> _pendingPersist = {};

class _PendingPersist {
  final List<ChatMessage> messages;
  final bool busy;
  final String? streamId;

  _PendingPersist({required this.messages, required this.busy, this.streamId});
}

/// Throttled persist while a turn is in flight.
void persistInflightTurnThrottled({
  required String sessionId,
  required List<ChatMessage> messages,
  required bool busy,
  required bool isStreaming,
  String? streamId,
}) {
  if (sessionId.isEmpty) return;
  if (!busy && !isStreaming && streamId == null) {
    unawaited(clearInflightTurnJournal(sessionId));
    return;
  }
  _pendingPersist[sessionId] = _PendingPersist(
    messages: messages,
    busy: busy || isStreaming,
    streamId: streamId,
  );
  if (_persistTimers.containsKey(sessionId)) return;
  _persistTimers[sessionId] = Timer(
    const Duration(milliseconds: _persistThrottleMs),
    () {
      _persistTimers.remove(sessionId);
      final pending = _pendingPersist.remove(sessionId);
      if (pending == null) return;
      unawaited(
        _writeSnapshot(
          sessionId,
          messages: pending.messages,
          streamId: pending.streamId,
        ),
      );
    },
  );
}

void cancelInflightPersistTimer(String sessionId) {
  if (sessionId.isEmpty) return;
  _persistTimers.remove(sessionId)?.cancel();
  _pendingPersist.remove(sessionId);
}

Future<void> flushInflightTurnJournal(String sessionId) async {
  if (sessionId.isEmpty) return;
  _persistTimers.remove(sessionId)?.cancel();
  final pending = _pendingPersist.remove(sessionId);
  if (pending == null) return;
  await _writeSnapshot(
    sessionId,
    messages: pending.messages,
    streamId: pending.streamId,
  );
}

Future<void> clearInflightTurnJournal(String sessionId) async {
  if (sessionId.isEmpty) return;
  cancelInflightPersistTimer(sessionId);
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('$_storagePrefix$sessionId');
}

/// Fold journaled tail onto [baseMessages] (async read from disk).
Future<InFlightRecoveryResult> recoverInflightTurnJournal(
  String? sessionId,
  List<ChatMessage> baseMessages, {
  bool keepPending = false,
}) async {
  if (sessionId == null || sessionId.isEmpty) {
    return InFlightRecoveryResult(
      applied: false,
      caughtUp: false,
      messages: baseMessages,
    );
  }
  final snapshot = await readInflightSnapshot(sessionId);
  if (snapshot == null) {
    return InFlightRecoveryResult(
      applied: false,
      caughtUp: false,
      messages: baseMessages,
    );
  }
  final result = _mergeTail(
    baseMessages,
    snapshot.messages,
    keepPending: keepPending,
  );
  if (result.caughtUp) {
    await clearInflightTurnJournal(sessionId);
  }
  return InFlightRecoveryResult(
    applied: result.applied,
    caughtUp: result.caughtUp,
    messages: result.messages,
    streamId: result.applied && keepPending ? snapshot.streamId : null,
  );
}

Future<void> _writeSnapshot(
  String sessionId, {
  required List<ChatMessage> messages,
  String? streamId,
}) async {
  final tail = _recoverableTail(messages, streamId);
  if (tail.isEmpty) return;
  final bounded = _boundMessages(tail);
  if (bounded.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final payload = jsonEncode({
    'version': 1,
    'streamId': streamId,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
    'messages': bounded.map(chatMessageToJson).toList(growable: false),
  });
  await prefs.setString('$_storagePrefix$sessionId', payload);
}

Future<InflightSnapshot?> readInflightSnapshot(String sessionId) async {
  if (sessionId.isEmpty) return null;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_storagePrefix$sessionId');
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final updatedAt = (json['updatedAt'] as num?)?.toInt() ?? 0;
    if (updatedAt > 0 &&
        DateTime.now().millisecondsSinceEpoch - updatedAt > _maxAgeMs) {
      await clearInflightTurnJournal(sessionId);
      return null;
    }
    final list = json['messages'];
    if (list is! List) return null;
    final messages = <ChatMessage>[];
    for (final item in list) {
      if (item is Map) {
        messages.add(chatMessageFromJson(item.cast<String, dynamic>()));
      }
    }
    if (messages.isEmpty) return null;
    return InflightSnapshot(
      messages: messages,
      streamId: json['streamId']?.toString(),
      updatedAt: updatedAt,
    );
  } catch (_) {
    await clearInflightTurnJournal(sessionId);
    return null;
  }
}

class _MergeResult {
  final bool applied;
  final bool caughtUp;
  final List<ChatMessage> messages;

  const _MergeResult({
    required this.applied,
    required this.caughtUp,
    required this.messages,
  });
}

_MergeResult _mergeTail(
  List<ChatMessage> base,
  List<ChatMessage> tail, {
  required bool keepPending,
}) {
  final normalizedTail = tail
      .map(
        (m) => m.role == 'assistant'
            ? m.copyWith(pending: keepPending ? (m.pending || true) : false)
            : m.copyWith(pending: false),
      )
      .toList(growable: false);

  if (!normalizedTail.any(_assistantHasContent)) {
    return _MergeResult(applied: false, caughtUp: false, messages: base);
  }

  final tailUserIdx = normalizedTail.indexWhere((m) => m.role == 'user');
  final tailUser = tailUserIdx >= 0 ? normalizedTail[tailUserIdx] : null;
  final tailAssistants = tailUserIdx >= 0
      ? normalizedTail.sublist(tailUserIdx + 1)
      : normalizedTail.where((m) => m.role == 'assistant').toList();
  final lastJournalRow = tailAssistants
      .where(_assistantHasContent)
      .fold<ChatMessage?>(null, (_, m) => m);

  if (tailAssistants.isEmpty || lastJournalRow == null) {
    return _MergeResult(applied: false, caughtUp: false, messages: base);
  }

  if (_tailAlreadyCommitted(tailAssistants, base)) {
    return _MergeResult(applied: false, caughtUp: true, messages: base);
  }

  if (tailUser != null) {
    final matchIdx = base.lastIndexWhere(
      (m) => m.role == 'user' && _userTextMatches(m, tailUser),
    );
    if (matchIdx >= 0) {
      final afterUser = base.sublist(matchIdx + 1);
      final completedReply = afterUser.any(
        (m) => _assistantHasContent(m) && !_isLiveProjectionRow(m),
      );
      if (completedReply) {
        return _MergeResult(applied: false, caughtUp: true, messages: base);
      }

      var projectionIdx = -1;
      for (var i = matchIdx + 1; i < base.length; i++) {
        final m = base[i];
        if (m.role == 'assistant' && _isLiveProjectionRow(m)) {
          projectionIdx = i;
          break;
        }
      }
      if (projectionIdx >= 0) {
        final projection = base[projectionIdx];
        final merged = _overlayProjectionRow(projection, lastJournalRow);
        final sealedRows = tailAssistants
            .where((m) => m != lastJournalRow && _assistantHasContent(m))
            .where((m) => !base.any((b) => b.id == m.id))
            .toList(growable: false);
        final messages = [
          ...base.sublist(0, projectionIdx),
          ...sealedRows,
          merged,
          ...base.sublist(projectionIdx + 1),
        ];
        return _MergeResult(applied: true, caughtUp: false, messages: messages);
      }

      final baseIds = base.map((m) => m.id).toSet();
      final toAppend = normalizedTail
          .where((m) => !baseIds.contains(m.id))
          .toList(growable: false);
      if (toAppend.isEmpty) {
        return _MergeResult(applied: false, caughtUp: false, messages: base);
      }
      return _MergeResult(
        applied: true,
        caughtUp: false,
        messages: [...base, ...toAppend],
      );
    }
  }

  final baseIds = base.map((m) => m.id).toSet();
  final toAppend = normalizedTail
      .where((m) => !baseIds.contains(m.id))
      .toList(growable: false);
  if (toAppend.isEmpty) {
    return _MergeResult(applied: false, caughtUp: false, messages: base);
  }
  return _MergeResult(
    applied: true,
    caughtUp: false,
    messages: [...base, ...toAppend],
  );
}

bool _isLiveProjectionRow(ChatMessage message) {
  return message.pending ||
      message.id.startsWith('assistant-stream-') ||
      message.id.startsWith('inflight-assistant-');
}

bool _hasStructuralParts(ChatMessage message) {
  return message.parts.any(
    (p) => p.kind == 'tool' || p.kind == 'reasoning' || p.kind == 'subagent',
  );
}

ChatMessage _overlayProjectionRow(
  ChatMessage projection,
  ChatMessage journalRow,
) {
  ChatMessage merged = ChatMessage(
    id: projection.id,
    role: journalRow.role,
    parts: journalRow.parts,
    pending: projection.pending,
    interim: journalRow.interim,
    isError: journalRow.isError || projection.isError,
    rowId: journalRow.rowId,
    historyOrdinal: journalRow.historyOrdinal,
    timestamp: journalRow.timestamp,
    source: journalRow.source,
    model: journalRow.model,
    provider: journalRow.provider,
    usage: journalRow.usage,
  );
  if (projection.fullText.length <= journalRow.fullText.length) {
    return merged;
  }

  final projectionText = projection.fullText;
  final journalText = journalRow.fullText.trim();
  if (_hasStructuralParts(journalRow)) {
    final next = projectionText.trim();
    if (journalText.isNotEmpty && !next.startsWith(journalText)) {
      return merged;
    }
  }

  final parts = <ChatPart>[];
  var textReplaced = false;
  for (final part in journalRow.parts) {
    if (part.kind != 'text') {
      parts.add(part);
    } else if (!textReplaced) {
      parts.add(ChatPart.text(projectionText, streaming: part.streaming));
      textReplaced = true;
    }
  }
  if (!textReplaced) {
    parts.add(ChatPart.text(projectionText));
  }
  return ChatMessage(
    id: projection.id,
    role: merged.role,
    parts: parts,
    pending: merged.pending,
    interim: merged.interim,
    isError: merged.isError,
    rowId: merged.rowId,
    historyOrdinal: merged.historyOrdinal,
    timestamp: merged.timestamp,
    source: merged.source,
    model: merged.model,
    provider: merged.provider,
    usage: merged.usage,
  );
}

bool _assistantHasContent(ChatMessage message) {
  if (message.role != 'assistant') return false;
  if (message.isError) return true;
  if (message.fullText.trim().isNotEmpty) return true;
  return message.parts.any(
    (p) => p.kind == 'tool' || p.kind == 'reasoning' || p.kind == 'subagent',
  );
}

bool _userTextMatches(ChatMessage a, ChatMessage b) {
  return a.fullText.trim() == b.fullText.trim() && a.fullText.trim().isNotEmpty;
}

bool _tailAlreadyCommitted(
  List<ChatMessage> tailAssistants,
  List<ChatMessage> base,
) {
  final recoverable = tailAssistants.where(_assistantHasContent).toList();
  if (recoverable.isEmpty) return false;
  final baseTexts = base
      .where((m) => m.role == 'assistant' && !m.interim)
      .map((m) => m.fullText.trim())
      .where((t) => t.isNotEmpty)
      .toSet();
  return recoverable.every((m) {
    final t = m.fullText.trim();
    return t.isNotEmpty && baseTexts.contains(t);
  });
}

List<ChatMessage> _recoverableTail(
  List<ChatMessage> messages,
  String? streamId,
) {
  final visible = List<ChatMessage>.from(messages);
  int assistantIndex = -1;
  if (streamId != null) {
    assistantIndex = visible.indexWhere(
      (m) => m.id == streamId && _assistantHasContent(m),
    );
  }
  if (assistantIndex < 0) {
    for (var i = visible.length - 1; i >= 0; i--) {
      final m = visible[i];
      if (m.role == 'user') break;
      if (_assistantHasContent(m)) {
        assistantIndex = i;
        break;
      }
    }
  }
  if (assistantIndex < 0) return const [];
  var start = assistantIndex;
  for (var i = assistantIndex - 1; i >= 0; i--) {
    if (visible[i].role == 'user') {
      start = i;
      while (start > 0 && visible[start - 1].role == 'user') {
        start -= 1;
      }
      break;
    }
  }
  return visible.sublist(start);
}

List<ChatMessage> _boundMessages(List<ChatMessage> tail) {
  if (tail.length > _maxJournalMessages) {
    tail = tail.sublist(tail.length - _maxJournalMessages);
  }
  final out = <ChatMessage>[];
  for (final message in tail) {
    final parts = <ChatPart>[];
    for (final part in message.parts) {
      if (part.kind == 'text' || part.kind == 'reasoning') {
        final text = part.text.length > _maxTextChars
            ? part.text.substring(0, _maxTextChars)
            : part.text;
        parts.add(
          part.kind == 'reasoning'
              ? ChatPart.reasoning(text, streaming: part.streaming)
              : ChatPart.text(text, streaming: part.streaming),
        );
      } else {
        parts.add(part);
      }
    }
    out.add(
      ChatMessage(
        id: message.id,
        role: message.role,
        parts: parts,
        pending: message.pending,
        interim: message.interim,
        isError: message.isError,
        rowId: message.rowId,
        historyOrdinal: message.historyOrdinal,
        timestamp: message.timestamp,
        source: message.source,
        model: message.model,
        provider: message.provider,
        usage: message.usage,
      ),
    );
  }
  return out;
}
