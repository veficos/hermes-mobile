library;

import '../../core/chat_message.dart';

/// Revision-aware searchable projection of a rich transcript.
///
/// Normalization and recursive tool-data scans happen when the transcript
/// changes, not for every keyboard event. Unchanged immutable message bodies
/// reuse their indexed document across revisions.
class TranscriptSearchIndex {
  final Map<String, _IndexedMessage> _byId = <String, _IndexedMessage>{};
  List<_IndexedMessage> _ordered = const [];
  int _revision = -1;

  int get revision => _revision;
  int get length => _ordered.length;

  void clear() {
    _byId.clear();
    _ordered = const [];
    _revision = -1;
  }

  void synchronize(List<ChatMessage> messages, int revision) {
    if (_revision == revision && _ordered.length == messages.length) return;
    final liveIds = <String>{};
    final next = <_IndexedMessage>[];
    for (final message in messages) {
      liveIds.add(message.id);
      final fingerprint = _fingerprint(message);
      final cached = _byId[message.id];
      if (cached != null && cached.fingerprint == fingerprint) {
        final entry = identical(cached.message, message)
            ? cached
            : cached.withMessage(message);
        _byId[message.id] = entry;
        next.add(entry);
      } else {
        final entry = _IndexedMessage(
          message: message,
          fingerprint: fingerprint,
          normalized: _searchableText(message).toLowerCase(),
        );
        _byId[message.id] = entry;
        next.add(entry);
      }
    }
    _byId.removeWhere((id, _) => !liveIds.contains(id));
    _ordered = List.unmodifiable(next);
    _revision = revision;
  }

  List<TranscriptSearchHit> query(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    final candidates = query.isEmpty
        ? _ordered
        : _ordered.where((entry) => entry.normalized.contains(query));
    return List.unmodifiable(
      candidates.map(
        (entry) => TranscriptSearchHit(
          message: entry.message,
          preview: _preview(entry.message),
        ),
      ),
    );
  }
}

class TranscriptSearchHit {
  final ChatMessage message;
  final String preview;

  const TranscriptSearchHit({required this.message, required this.preview});
}

class _IndexedMessage {
  final ChatMessage message;
  final int fingerprint;
  final String normalized;

  const _IndexedMessage({
    required this.message,
    required this.fingerprint,
    required this.normalized,
  });

  _IndexedMessage withMessage(ChatMessage value) => _IndexedMessage(
    message: value,
    fingerprint: fingerprint,
    normalized: normalized,
  );
}

int _fingerprint(ChatMessage message) {
  var value = Object.hash(
    message.id,
    message.role,
    message.source,
    message.model,
    message.provider,
    Object.hashAll(message.attachmentRefs),
  );
  for (final part in message.parts) {
    value = Object.hash(
      value,
      part.kind,
      part.text,
      _deepFingerprint(part.tool),
      _deepFingerprint(part.plan),
      _deepFingerprint(part.subagent),
      _deepFingerprint(part.interaction),
    );
  }
  return value;
}

int _deepFingerprint(Object? value) {
  if (value == null) return 0;
  if (value is Map) {
    return Object.hashAll(
      value.entries.map(
        (entry) =>
            Object.hash(entry.key.toString(), _deepFingerprint(entry.value)),
      ),
    );
  }
  if (value is Iterable) return Object.hashAll(value.map(_deepFingerprint));
  return value.hashCode;
}

String _searchableText(ChatMessage message) {
  final buffer = StringBuffer()
    ..writeln(message.role)
    ..writeln(message.source ?? '')
    ..writeln(message.provider ?? '')
    ..writeln(message.model ?? '');
  for (final attachment in message.attachmentRefs) {
    buffer.writeln(attachment);
  }
  for (final part in message.parts) {
    buffer.writeln(part.kind);
    if (part.text.isNotEmpty) buffer.writeln(part.text);
    _appendValue(buffer, part.tool);
    _appendValue(buffer, part.plan);
    _appendValue(buffer, part.subagent);
    _appendValue(buffer, part.interaction);
  }
  return buffer.toString();
}

void _appendValue(StringBuffer buffer, Object? value, [int depth = 0]) {
  if (value == null || depth > 8) return;
  if (value is Map) {
    for (final entry in value.entries) {
      buffer.writeln(entry.key);
      _appendValue(buffer, entry.value, depth + 1);
    }
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      _appendValue(buffer, item, depth + 1);
    }
    return;
  }
  final text = value.toString();
  if (text.length <= 64 * 1024 && !text.startsWith('data:')) {
    buffer.writeln(text);
  }
}

String _preview(ChatMessage message) {
  final text = message.fullText.trim();
  if (text.isNotEmpty) return text;
  for (final part in message.parts) {
    if (part.text.trim().isNotEmpty) return part.text.trim();
    final tool = part.tool;
    if (tool != null) {
      for (final key in const ['name', 'tool_name', 'summary', 'path', 'url']) {
        final value = tool[key]?.toString().trim();
        if (value?.isNotEmpty == true) return value!;
      }
    }
  }
  if (message.attachmentRefs.isNotEmpty) {
    return message.attachmentRefs.join(' ');
  }
  return '';
}
