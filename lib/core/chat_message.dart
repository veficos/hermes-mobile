/// UI model for a chat message built from gateway events + session history.
///
/// Mirrors the desktop renderer's ``ChatMessage``: parts instead of a single
/// string, so tool calls and reasoning interleave naturally with text.
library;

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
      ..model = message.model
      ..provider = message.provider
      ..source = message.source
      ..timestamp = message.timestamp
      ..usage = message.usage;
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
    String? result,
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
    if (text != null && text.isNotEmpty) {
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
        ChatPart.text(text),
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
      parts: parts,
      isError: isError,
      rowId: rowId,
      source: source,
      model: model,
      provider: provider,
      timestamp: timestamp,
      usage: usage,
    );
  }
}
