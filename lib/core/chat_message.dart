/// UI model for a chat message built from gateway events + session history.
///
/// Mirrors the desktop renderer's ``ChatMessage``: parts instead of a single
/// string, so tool calls and reasoning interleave naturally with text.
library;

import 'dart:convert';

/// Every path or URL that a successful image-generation tool result may be
/// echoed into assistant prose. The tool card is the canonical image slot.
List<String> generatedImageEchoSources(Iterable<ChatPart> parts) {
  final sources = <String>{};
  for (final part in parts) {
    if (part.kind != 'tool' || part.tool?['name'] != 'image_generate') continue;
    dynamic result = part.tool?['result'] ?? part.tool?['result_text'];
    if (result is String) {
      try {
        result = jsonDecode(result);
      } catch (_) {}
    }
    if (result is! Map || result['success'] == false) continue;
    for (final key in const ['host_image', 'image', 'agent_visible_image']) {
      final source = result[key]?.toString().trim();
      if (source?.isNotEmpty == true) sources.add(source!);
    }
  }
  return sources.toList(growable: false);
}

/// Remove image/media echoes once the same generated image has a successful
/// tool result. This mirrors desktop's generated-images projection.
String stripGeneratedImageEchoes(String text, Iterable<String> sources) {
  final uniqueSources = sources.where((source) => source.isNotEmpty).toSet();
  if (text.isEmpty || uniqueSources.isEmpty) return text;
  var next = text
      .replaceAll(RegExp(r'!\[[^\]\n]*\]\([^)\n]*\)'), '')
      .replaceAll(RegExp(r'\[[^\]\n]*\]\(\s*#media:[^)\n]*\)'), '');
  for (final source in uniqueSources) {
    next = next.replaceAll(source, '');
  }
  return next
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}

List<ChatPart> dedupeGeneratedImageEchoesInParts(Iterable<ChatPart> parts) {
  final materialized = parts.toList(growable: false);
  final sources = generatedImageEchoSources(materialized);
  if (sources.isEmpty) return materialized;
  return [
    for (final part in materialized)
      if (part.kind != 'text')
        part
      else
        ...[
          stripGeneratedImageEchoes(part.text, sources),
        ].where((text) => text.isNotEmpty).map(ChatPart.text),
  ];
}

class MessageReaction {
  final String emoji;
  final String author;
  final double at;

  const MessageReaction({
    required this.emoji,
    required this.author,
    required this.at,
  });

  factory MessageReaction.fromJson(Map<dynamic, dynamic> json) =>
      MessageReaction(
        emoji: (json['emoji'] ?? '').toString(),
        author: (json['author'] ?? '').toString(),
        at: (json['at'] as num?)?.toDouble() ?? 0,
      );
}

/// Structured inference-credit wall forwarded by the gateway on a terminal
/// frame. This is deliberately separate from the account-wide BillingStore:
/// third-party providers have their own billing URL and the block belongs to
/// the session/turn that raised it.
class ChatBillingBlock {
  final String provider;
  final String providerLabel;
  final String? model;
  final Uri? billingUrl;
  final bool isNous;
  final String message;

  const ChatBillingBlock({
    required this.provider,
    required this.providerLabel,
    this.model,
    this.billingUrl,
    required this.isNous,
    required this.message,
  });

  static ChatBillingBlock? tryParse(dynamic value) {
    if (value is! Map) return null;
    final provider = value['provider']?.toString().trim() ?? '';
    if (provider.isEmpty) return null;
    final rawLabel = value['provider_label']?.toString().trim();
    final rawModel = value['model']?.toString().trim();
    final rawUrl = value['billing_url']?.toString().trim();
    final uri = rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl);
    return ChatBillingBlock(
      provider: provider,
      providerLabel: rawLabel?.isNotEmpty == true ? rawLabel! : provider,
      model: rawModel?.isNotEmpty == true ? rawModel : null,
      billingUrl: uri?.hasScheme == true ? uri : null,
      isNous: value['is_nous'] == true,
      message: value['message']?.toString().trim() ?? '',
    );
  }
}

const chatErrorSurfaceLayers = {
  'provider',
  'endpoint',
  'streaming',
  'auth',
  'billing',
  'gateway',
  'runtime',
  'disk',
};

/// Structured descriptor attached to a failed turn by newer gateways.
/// Older servers omit it, so callers must retain their text fallback.
class ChatErrorSurface {
  final String layer;
  final String code;
  final bool retryable;
  final String? provider;
  final String? model;

  const ChatErrorSurface({
    required this.layer,
    required this.code,
    required this.retryable,
    this.provider,
    this.model,
  });

  static ChatErrorSurface? tryParse(dynamic value) {
    if (value is! Map) return null;
    final layer = value['layer']?.toString() ?? '';
    if (!chatErrorSurfaceLayers.contains(layer)) return null;
    final provider = value['provider']?.toString().trim();
    final model = value['model']?.toString().trim();
    return ChatErrorSurface(
      layer: layer,
      code: value['code']?.toString().trim().isNotEmpty == true
          ? value['code'].toString().trim()
          : 'unknown',
      retryable: value['retryable'] != false,
      provider: provider?.isEmpty == true ? null : provider,
      model: model?.isEmpty == true ? null : model,
    );
  }

  Map<String, dynamic> toJson() => {
    'layer': layer,
    'code': code,
    'retryable': retryable,
    if (provider != null) 'provider': provider,
    if (model != null) 'model': model,
  };
}

class ChatPart {
  final String kind; // text | reasoning | tool | plan | subagent | interaction
  final String text;
  final Map<String, dynamic>? tool;
  final List<Map<String, dynamic>>? plan;
  final Map<String, dynamic>? subagent;
  final Map<String, dynamic>? interaction;
  final bool streaming;

  ChatPart.text(this.text, {this.streaming = false})
    : kind = 'text',
      tool = null,
      plan = null,
      subagent = null,
      interaction = null;
  ChatPart.reasoning(this.text, {this.streaming = false})
    : kind = 'reasoning',
      tool = null,
      plan = null,
      subagent = null,
      interaction = null;

  ChatPart.toolCall(this.tool)
    : kind = 'tool',
      text = '',
      plan = null,
      subagent = null,
      interaction = null,
      streaming = false;

  ChatPart.plan(this.plan)
    : kind = 'plan',
      text = '',
      tool = null,
      subagent = null,
      interaction = null,
      streaming = false;

  /// Structured live activity for one delegated agent.
  ChatPart.subagentActivity(this.subagent)
    : kind = 'subagent',
      text = '',
      tool = null,
      plan = null,
      interaction = null,
      streaming = false;

  ChatPart.interactiveRequest(this.interaction)
    : kind = 'interaction',
      text = '',
      tool = null,
      plan = null,
      subagent = null,
      streaming = false;

  static ChatPart? fromToolCallJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['tool_name'] ?? '').toString();
    if (name.isEmpty && json['tool_id'] == null) return null;
    return ChatPart.toolCall(json);
  }
}

class ChatMessage {
  final String id;
  final String role; // user | assistant | tool | system
  final List<ChatPart> parts;
  final bool pending; // optimistic user bubble
  final bool interim; // assistant comment between tool calls
  final bool isError;
  final ChatErrorSurface? errorSurface;
  final double? durationS;
  final List<String> attachmentRefs;
  final int? rowId;
  final int? historyOrdinal;
  final DateTime? timestamp;
  // ── 桌面版同构元数据 ──
  final String?
  source; // webui / weixin / feishu / cli / telegram / discord / server
  final String? model;
  final String? provider;

  /// Per-turn usage payload from message.complete / transcript metadata
  /// (tokens in/out, tps, duration, used model). Null when the gateway did
  /// not report usage for this turn — UI must not render fake values.
  final Map<String, dynamic>? usage;
  final List<MessageReaction> reactions;

  ChatMessage({
    required this.id,
    required this.role,
    required this.parts,
    this.pending = false,
    this.interim = false,
    this.isError = false,
    this.errorSurface,
    this.durationS,
    this.attachmentRefs = const [],
    this.rowId,
    this.historyOrdinal,
    this.timestamp,
    this.source,
    this.model,
    this.provider,
    this.usage,
    this.reactions = const [],
  });

  String get fullText =>
      parts.where((p) => p.kind == 'text').map((p) => p.text).join('');

  /// Exact prompt shape expected by the gateway when this user turn is
  /// retried. Attachment refs are presentation metadata in the timeline but
  /// remain part of the submitted prompt contract.
  String get promptText => [
    ...attachmentRefs,
    if (fullText.trim().isNotEmpty) fullText,
  ].join('\n').trim();

  /// True when any text part has non-whitespace content. Unlike
  /// `fullText.trim().isNotEmpty` this short-circuits on the first non-empty
  /// part instead of joining every text part (hot path: per-row turn lookup).
  bool get hasText =>
      parts.any((p) => p.kind == 'text' && p.text.trim().isNotEmpty);

  /// Plain-text rendering of the message (desktop "Copy text" parity):
  /// strips markdown syntax — code fences, emphasis, headers, list markers,
  /// and collapses links to their label — while `fullText` keeps the raw
  /// markdown source ("Copy as Markdown").
  String get plainText {
    var text = fullText;
    // Fenced code blocks: drop the fence lines, keep the code body.
    text = text.replaceAllMapped(
      RegExp(r'```[^\n]*\n([\s\S]*?)```', multiLine: true),
      (m) => m.group(1) ?? '',
    );
    // Inline code.
    text = text.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1)!);
    // Images: keep the alt text.
    text = text.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
      (m) => m.group(1) ?? '',
    );
    // Links: keep the label.
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'),
      (m) => m.group(1)!,
    );
    // Bold / italic / strikethrough markers. (Dart's String.replaceAll does
    // NOT expand `$1` group references — replaceAllMapped is required.)
    text = text
        .replaceAllMapped(RegExp(r'\*\*([^*]*)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'__([^_]*)__'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'~~([^~]*)~~'), (m) => m.group(1)!)
        .replaceAllMapped(
          RegExp(r'(?<!\w)\*([^*\n]+)\*(?!\w)'),
          (m) => m.group(1)!,
        )
        .replaceAllMapped(
          RegExp(r'(?<!\w)_([^_\n]+)_(?!\w)'),
          (m) => m.group(1)!,
        );
    // Per-line: headers, blockquotes, list bullets and task checkboxes.
    final lines = text.split('\n').map((line) {
      var l = line
          .replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
          .replaceFirst(RegExp(r'^\s{0,3}>\s?'), '')
          .replaceFirst(RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+'), '')
          .replaceFirst(RegExp(r'^\s*([-*+]|\d+[.)])\s+'), '');
      return l;
    });
    return lines.join('\n').trim();
  }

  ChatMessage copyWith({
    List<ChatPart>? parts,
    bool? pending,
    bool? interim,
    bool? isError,
    ChatErrorSurface? errorSurface,
    double? durationS,
    List<String>? attachmentRefs,
    String? source,
    List<MessageReaction>? reactions,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      parts: parts ?? this.parts,
      pending: pending ?? this.pending,
      interim: interim ?? this.interim,
      isError: isError ?? this.isError,
      errorSurface: errorSurface ?? this.errorSurface,
      durationS: durationS ?? this.durationS,
      attachmentRefs: attachmentRefs ?? this.attachmentRefs,
      rowId: rowId,
      historyOrdinal: historyOrdinal,
      timestamp: timestamp,
      source: source ?? this.source,
      model: model,
      provider: provider,
      usage: usage,
      reactions: reactions ?? this.reactions,
    );
  }
}

/// Serialize an assistant message into a mutable working form.
class MutableAssistantMessage {
  final String id;

  /// Committed parts (everything except the still-open text/reasoning run).
  final List<ChatPart> _parts = [];
  String? finalText; // set by message.complete
  bool completed = false;
  String? status;
  Map<String, dynamic>? usage;
  ChatErrorSurface? errorSurface;
  double? durationS;
  int? rowId;
  List<MessageReaction> reactions = const [];
  // 元数据字段（由 message.complete / session.info 事件填充）
  String? model;
  String? provider;
  String? source;
  DateTime? timestamp;

  // Streaming text/reasoning accumulates into buffers: Dart strings are
  // immutable, so `last.text + delta` per token copied quadratically. The
  // buffer is flushed into [_parts] only when a different part kind starts
  // (or on read via [parts]/[toChatMessage]).
  final StringBuffer _textRun = StringBuffer();
  final StringBuffer _reasoningRun = StringBuffer();
  bool _textOpen = false;
  bool _reasoningOpen = false;

  /// Whether a placeholder row for this message exists in the transcript
  /// list (ChatStore sets it; pure text deltas then skip the row rewrite).
  bool rowAdded = false;

  MutableAssistantMessage(this.id);

  factory MutableAssistantMessage.fromChatMessage(ChatMessage message) {
    final mutable = MutableAssistantMessage(message.id)
      ..rowAdded = true
      ..completed = !message.pending
      ..model = message.model
      ..provider = message.provider
      ..source = message.source
      ..timestamp = message.timestamp
      ..usage = message.usage
      ..errorSurface = message.errorSurface
      ..durationS = message.durationS
      ..rowId = message.rowId
      ..reactions = message.reactions;
    mutable._parts.addAll(message.parts);
    return mutable;
  }

  /// All parts with the open streaming run materialized at the end.
  List<ChatPart> get parts {
    if (!_textOpen && !_reasoningOpen) return List.of(_parts);
    return [
      ..._parts,
      if (_reasoningOpen) ChatPart.reasoning(_reasoningRun.toString()),
      if (_textOpen) ChatPart.text(_textRun.toString()),
    ];
  }

  String get streamedText {
    final buffer = StringBuffer();
    for (final p in _parts) {
      if (p.kind == 'text') buffer.write(p.text);
    }
    if (_textOpen) buffer.write(_textRun);
    return buffer.toString();
  }

  /// Flush any open text/reasoning run into [_parts]. At most one run is
  /// open at a time: starting one kind flushes the other first, preserving
  /// the interleaved append order of the delta stream.
  void _flushOpenRun() {
    if (_reasoningOpen) {
      _parts.add(ChatPart.reasoning(_reasoningRun.toString()));
      _reasoningRun.clear();
      _reasoningOpen = false;
    }
    if (_textOpen) {
      _parts.add(ChatPart.text(_textRun.toString()));
      _textRun.clear();
      _textOpen = false;
    }
  }

  /// Append a non-text part (plan etc.) after the open streaming run.
  void appendPart(ChatPart part) {
    _flushOpenRun();
    _parts.add(part);
  }

  /// Keep a blocking request and its tool lifecycle in one timeline slot.
  /// Gateway reconnects may deliver `tool.start` and `clarify.request` in
  /// either order; rendering both leaves a duplicate spinner beside the form.
  void upsertInteractiveRequest(Map<String, dynamic> request) {
    _flushOpenRun();
    final requestId = request['request_id']?.toString() ?? '';
    if (requestId.isEmpty) return;
    _parts.removeWhere(
      (part) =>
          part.kind == 'tool' &&
          (part.tool?['tool_id'] ?? part.tool?['id'])?.toString() == requestId,
    );
    final index = _parts.indexWhere(
      (part) =>
          part.kind == 'interaction' &&
          part.interaction?['request_id']?.toString() == requestId,
    );
    final next = ChatPart.interactiveRequest(request);
    if (index < 0) {
      _parts.add(next);
    } else {
      _parts[index] = next;
    }
  }

  bool hasInteractiveRequest(String requestId) => _parts.any(
    (part) =>
        part.kind == 'interaction' &&
        part.interaction?['request_id']?.toString() == requestId,
  );

  void appendDelta(String delta) {
    if (!_textOpen) {
      _flushOpenRun();
      _textOpen = true;
    }
    _textRun.write(delta);
  }

  void appendReasoning(String delta) {
    if (!_reasoningOpen) {
      _flushOpenRun();
      _reasoningOpen = true;
    }
    _reasoningRun.write(delta);
  }

  /// Update or insert a tool-call part by tool id.
  ///
  /// F4: merges fields — null args (e.g. tool.complete without `args_text`)
  /// never clobber values captured at tool.start.
  void upsertTool(
    String toolId,
    String? name,
    String? argsText, {
    dynamic result,
    String? summary,
    bool running = false,
    bool isError = false,
    String? resultText,
  }) {
    _flushOpenRun();
    final idx = _parts.indexWhere(
      (p) => p.kind == 'tool' && p.tool?['tool_id'] == toolId,
    );
    if (idx >= 0) {
      final existing = Map<String, dynamic>.from(_parts[idx].tool ?? {});
      if (name != null) existing['name'] = name;
      if (argsText != null) existing['args_text'] = argsText;
      if (result != null) existing['result'] = result;
      if (summary != null) existing['summary'] = summary;
      if (resultText != null) existing['result_text'] = resultText;
      existing['running'] = running;
      existing['is_error'] = isError;
      _parts[idx] = ChatPart.toolCall(existing);
    } else {
      _parts.add(
        ChatPart.toolCall({
          'tool_id': toolId,
          'name': name ?? '',
          'args_text': argsText,
          'result': result,
          'summary': summary,
          'running': running,
          'is_error': isError,
          'result_text': resultText,
        }),
      );
    }
  }

  /// Mark an in-flight interactive request as expired by [requestId].
  void expireInteractiveRequest(String requestId) {
    final idx = _parts.indexWhere(
      (p) =>
          p.kind == 'interaction' &&
          p.interaction?['request_id'].toString() == requestId,
    );
    if (idx < 0) return;
    _parts[idx] = ChatPart.interactiveRequest({
      ..._parts[idx].interaction!,
      'status': 'expired',
    });
  }

  /// Merge all activity emitted by one child agent into one timeline part.
  void upsertSubagent(Map<String, dynamic> event) {
    _flushOpenRun();
    final id = (event['subagent_id'] ?? event['id'] ?? event['name'] ?? '')
        .toString();
    final idx = _parts.indexWhere(
      (p) => p.kind == 'subagent' && p.subagent?['subagent_id'] == id,
    );
    if (idx >= 0) {
      _parts[idx] = ChatPart.subagentActivity({
        ..._parts[idx].subagent!,
        ...event,
        'subagent_id': id,
      });
    } else {
      _parts.add(ChatPart.subagentActivity({...event, 'subagent_id': id}));
    }
  }

  /// Finalize: replace streamed text with the authoritative final text.
  void finalize(
    String? text,
    String status,
    Map<String, dynamic>? usage, {
    String? model,
    String? provider,
    String? source,
    DateTime? timestamp,
  }) {
    finalText = text;
    this.status = status;
    this.usage = usage;
    completed = true;
    _flushOpenRun();
    // Usage / session-info metadata: prefer explicit args over usage map fields
    // so session.info events (which carry full authoritative model data) win.
    if (model != null) this.model = model;
    if (provider != null) this.provider = provider;
    if (source != null) this.source = source;
    if (timestamp != null) this.timestamp = timestamp;
    this.timestamp ??= DateTime.now();
    if (usage != null) {
      this.model ??=
          (usage['model'] ?? usage['used_model'] ?? usage['model_name'])
              ?.toString();
      this.provider ??= (usage['provider'] ?? usage['billing_provider'])
          ?.toString();
    }
    final visibleText = text == null
        ? null
        : stripGeneratedImageEchoes(text, generatedImageEchoSources(_parts));
    if (visibleText != null && visibleText.isNotEmpty) {
      // Drop streamed text parts, keep tool/reasoning, then append final.
      _parts.removeWhere((p) => p.kind == 'text');
      // Mark all tools complete.
      for (var i = 0; i < _parts.length; i++) {
        if (_parts[i].kind == 'tool') {
          _parts[i] = ChatPart.toolCall({..._parts[i].tool!, 'running': false});
        }
      }
      final finalParts = <ChatPart>[
        for (final p in _parts) p,
        ChatPart.text(visibleText),
      ];
      _parts
        ..clear()
        ..addAll(finalParts);
    } else {
      for (var i = 0; i < _parts.length; i++) {
        if (_parts[i].kind == 'tool') {
          _parts[i] = ChatPart.toolCall({..._parts[i].tool!, 'running': false});
        }
      }
    }
  }

  ChatMessage toChatMessage({bool isError = false, int? rowId}) {
    return ChatMessage(
      id: id,
      role: 'assistant',
      parts: dedupeGeneratedImageEchoesInParts(parts),
      pending: !completed,
      isError: isError,
      errorSurface: errorSurface,
      durationS: durationS,
      rowId: rowId ?? this.rowId,
      source: source,
      model: model,
      provider: provider,
      timestamp: timestamp,
      usage: usage,
      reactions: reactions,
    );
  }
}
