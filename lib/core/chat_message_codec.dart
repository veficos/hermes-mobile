/// JSON codec for [ChatMessage] / [ChatPart] (in-flight turn journal).
library;

import 'chat_message.dart';

Map<String, dynamic> chatMessageToJson(ChatMessage message) {
  return {
    'id': message.id,
    'role': message.role,
    'parts': message.parts.map(chatPartToJson).toList(growable: false),
    'pending': message.pending,
    'interim': message.interim,
    'isError': message.isError,
    if (message.rowId != null) 'rowId': message.rowId,
    if (message.historyOrdinal != null)
      'historyOrdinal': message.historyOrdinal,
    if (message.timestamp != null)
      'timestamp': message.timestamp!.millisecondsSinceEpoch,
    if (message.source != null) 'source': message.source,
    if (message.model != null) 'model': message.model,
    if (message.provider != null) 'provider': message.provider,
    if (message.usage != null) 'usage': message.usage,
  };
}

ChatMessage chatMessageFromJson(Map<String, dynamic> json) {
  final partsRaw = json['parts'];
  final parts = <ChatPart>[];
  if (partsRaw is List) {
    for (final raw in partsRaw) {
      if (raw is Map) {
        final part = chatPartFromJson(raw.cast<String, dynamic>());
        if (part != null) parts.add(part);
      }
    }
  }
  final ts = json['timestamp'];
  return ChatMessage(
    id: json['id']?.toString() ?? '',
    role: json['role']?.toString() ?? 'user',
    parts: parts,
    pending: json['pending'] == true,
    interim: json['interim'] == true,
    isError: json['isError'] == true || json['is_error'] == true,
    rowId: (json['rowId'] ?? json['row_id']) as int?,
    historyOrdinal: (json['historyOrdinal'] ?? json['history_ordinal']) as int?,
    timestamp: ts is num
        ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
        : null,
    source: json['source']?.toString(),
    model: json['model']?.toString(),
    provider: json['provider']?.toString(),
    usage: json['usage'] is Map
        ? (json['usage'] as Map).cast<String, dynamic>()
        : null,
  );
}

Map<String, dynamic> chatPartToJson(ChatPart part) {
  switch (part.kind) {
    case 'reasoning':
      return {
        'kind': 'reasoning',
        'text': part.text,
        'streaming': part.streaming,
      };
    case 'tool':
      return {'kind': 'tool', 'tool': part.tool ?? const {}};
    case 'plan':
      return {'kind': 'plan', 'plan': part.plan ?? const []};
    case 'subagent':
      return {'kind': 'subagent', 'subagent': part.subagent ?? const {}};
    case 'interaction':
      return {
        'kind': 'interaction',
        'interaction': part.interaction ?? const {},
      };
    default:
      return {'kind': 'text', 'text': part.text, 'streaming': part.streaming};
  }
}

ChatPart? chatPartFromJson(Map<String, dynamic> json) {
  final kind = json['kind']?.toString() ?? 'text';
  switch (kind) {
    case 'reasoning':
      return ChatPart.reasoning(
        json['text']?.toString() ?? '',
        streaming: json['streaming'] == true,
      );
    case 'tool':
      final tool = json['tool'];
      if (tool is Map) return ChatPart.toolCall(tool.cast<String, dynamic>());
      return null;
    case 'plan':
      final plan = json['plan'];
      if (plan is List) {
        return ChatPart.plan(
          plan
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList(growable: false),
        );
      }
      return null;
    case 'subagent':
      final sub = json['subagent'];
      if (sub is Map) {
        return ChatPart.subagentActivity(sub.cast<String, dynamic>());
      }
      return null;
    case 'interaction':
      final interaction = json['interaction'];
      if (interaction is Map) {
        return ChatPart.interactiveRequest(interaction.cast<String, dynamic>());
      }
      return null;
    default:
      return ChatPart.text(
        json['text']?.toString() ?? '',
        streaming: json['streaming'] == true,
      );
  }
}
