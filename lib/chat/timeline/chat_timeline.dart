import '../../core/chat_message.dart';
import '../../core/tool_card_models.dart';

/// A renderable unit in the chat timeline. Transport messages remain immutable;
/// timeline entries are derived views and may split one assistant message into
/// independently collapsible/renderable rows.
sealed class ChatTimelineItem {
  final ChatMessage sourceMessage;
  final int sourceIndex;
  const ChatTimelineItem(this.sourceMessage, this.sourceIndex);

  String get key;
}

class ChatTimelineMessage extends ChatTimelineItem {
  final ChatMessage message;
  final ChatMessage? ownerUserMessage;
  const ChatTimelineMessage(
    this.message,
    super.sourceMessage,
    super.sourceIndex, {
    this.ownerUserMessage,
  });

  @override
  String get key => 'message:${sourceMessage.id}:${message.id}';
}

class ChatTimelineToolGroup extends ChatTimelineItem {
  final String id;
  final List<ChatPart> tools;
  final List<ChatPart> interactions;
  final ChatMessage? ownerUserMessage;
  ChatTimelineToolGroup(
    this.id,
    this.tools,
    super.sourceMessage,
    super.sourceIndex, {
    List<ChatPart>? interactions,
    this.ownerUserMessage,
  }) : interactions = interactions ?? <ChatPart>[];

  bool get running => tools.any((p) => p.tool?['running'] == true);
  bool get failed =>
      tools.any((p) => p.tool?['is_error'] == true || p.tool?['error'] != null);
  int get completedCount =>
      tools.where((p) => p.tool?['running'] != true).length;

  @override
  String get key => 'tools:$id';
}

class TurnActivity {
  final String id;
  final int startIndex;
  final int endIndex;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int toolCount;
  final int reasoningBlocks;
  final bool running;

  const TurnActivity({
    required this.id,
    required this.startIndex,
    required this.endIndex,
    required this.startedAt,
    required this.completedAt,
    required this.toolCount,
    required this.reasoningBlocks,
    required this.running,
  });

  Duration? get duration => startedAt == null || completedAt == null
      ? null
      : completedAt!.difference(startedAt!);
}

class ChatTimelineTurnActivity extends ChatTimelineItem {
  final TurnActivity activity;
  const ChatTimelineTurnActivity(
    this.activity,
    super.sourceMessage,
    super.sourceIndex,
  );

  @override
  String get key => 'turn-activity:${activity.id}';
}

class ChatTimelineChangedFiles extends ChatTimelineItem {
  final List<ChangedFileModel> files;
  const ChatTimelineChangedFiles(
    this.files,
    super.sourceMessage,
    super.sourceIndex,
  );

  @override
  String get key => 'changed-files:${sourceMessage.id}';
}

ChatMessage _partMessage(ChatMessage source, ChatPart part, int ordinal) {
  return ChatMessage(
    id: '${source.id}:part:$ordinal',
    role: source.role,
    parts: [part],
    pending: source.pending,
    interim: source.interim,
    isError: source.isError,
    errorSurface: source.errorSurface,
    durationS: source.durationS,
    attachmentRefs: source.attachmentRefs,
    rowId: source.rowId,
    historyOrdinal: source.historyOrdinal,
    timestamp: source.timestamp,
    source: source.source,
    model: source.model,
    provider: source.provider,
    usage: source.usage,
    reactions: source.reactions,
  );
}

/// Builds the actual viewport model. Tool runs may span adjacent assistant
/// message segments, while user/system boundaries always flush the group.
/// [preserveMessageId] keeps the live stream as one row so the existing
/// stream-specific repaint optimisation and scroll behaviour remain intact.
List<ChatTimelineItem> buildChatTimeline(
  Iterable<ChatMessage> messages, {
  String? preserveMessageId,
}) {
  final rows = <ChatTimelineItem>[];
  // ChatStore exposes a stable read-only List. Reuse it directly instead of
  // copying the entire transcript on every legitimate timeline invalidation.
  // Non-list callers retain the original iterable contract.
  final source = messages is List<ChatMessage>
      ? messages
      : messages.toList(growable: false);
  var toolOrdinal = 0;
  ChatTimelineToolGroup? openGroup;
  final assistantRun = <ChatMessage>[];
  ChatMessage? ownerUserMessage;

  void flushTools() => openGroup = null;
  void appendTool(ChatMessage message, int sourceIndex, ChatPart part) {
    if (openGroup != null) {
      openGroup!.tools.add(part);
      return;
    }
    final toolId =
        (part.tool?['tool_id'] ?? part.tool?['id'] ?? 'tool-${toolOrdinal++}')
            .toString();
    final group = ChatTimelineToolGroup(
      'group-$toolId',
      <ChatPart>[part],
      message,
      sourceIndex,
      ownerUserMessage: ownerUserMessage,
    );
    rows.add(group);
    openGroup = group;
  }

  for (var sourceIndex = 0; sourceIndex < source.length; sourceIndex++) {
    final message = source[sourceIndex];
    if (message.role == 'user') {
      ownerUserMessage = message.promptText.isEmpty ? null : message;
    } else if (message.role != 'assistant' &&
        message.role != 'tool' &&
        message.role != 'system' &&
        !message.interim) {
      ownerUserMessage = null;
    }
    final assistantLike = message.role == 'assistant' || message.interim;
    if (assistantLike) {
      assistantRun.add(message);
    } else {
      assistantRun.clear();
    }
    if (message.id == preserveMessageId) {
      flushTools();
      rows.add(
        ChatTimelineMessage(
          message,
          message,
          sourceIndex,
          ownerUserMessage: message.role == 'assistant'
              ? ownerUserMessage
              : null,
        ),
      );
      continue;
    }
    var partOrdinal = 0;
    for (final part in message.parts) {
      if (part.kind == 'tool' &&
          (message.role == 'assistant' || message.interim)) {
        // Every consecutive tool call — exploratory (read_file, list_files,
        // …) or dedicated (patch, generate_image, …) alike — joins the same
        // rollup group; a lone tool call is unwrapped back to a standalone
        // `ChatTimelineMessage` below so its full rich presentation (diff,
        // image preview, …) still shows without an unnecessary "使用了 1
        // 个工具" wrapper. Reached by tapping the row inside the group
        // otherwise — see `ToolGroupCard`'s `detailBuilder`.
        appendTool(message, sourceIndex, part);
      } else if (part.kind == 'interaction' &&
          (message.role == 'assistant' || message.interim)) {
        final requestId = part.interaction?['request_id']?.toString();
        final matchesOpen =
            openGroup != null &&
            (requestId == null ||
                openGroup!.tools.any(
                  (tool) =>
                      (tool.tool?['tool_id'] ?? tool.tool?['id'])?.toString() ==
                      requestId,
                ));
        if (matchesOpen) {
          openGroup!.interactions.add(part);
        } else {
          flushTools();
          final group = ChatTimelineToolGroup(
            'approval-${requestId ?? toolOrdinal++}',
            <ChatPart>[],
            message,
            sourceIndex,
            interactions: <ChatPart>[part],
            ownerUserMessage: message.role == 'assistant'
                ? ownerUserMessage
                : null,
          );
          rows.add(group);
          openGroup = group;
        }
      } else {
        flushTools();
        rows.add(
          ChatTimelineMessage(
            _partMessage(message, part, partOrdinal++),
            message,
            sourceIndex,
            ownerUserMessage: message.role == 'assistant'
                ? ownerUserMessage
                : null,
          ),
        );
      }
    }
    // A turn can emit several assistant segments. Emit one independent files
    // row at the end of the contiguous assistant run.
    final next = sourceIndex + 1 < source.length
        ? source[sourceIndex + 1]
        : null;
    final assistantRunEnds =
        (next == null || (next.role != 'assistant' && !next.interim));
    if (assistantRunEnds && assistantLike) {
      final run = assistantRun;
      final files = deriveTurnChangedFilesAcrossMessages(run);
      DateTime? startedAt;
      DateTime? completedAt;
      var toolCount = 0;
      var reasoningBlocks = 0;
      var running = false;
      for (final item in run) {
        final timestamp = item.timestamp;
        if (timestamp != null) {
          startedAt ??= timestamp;
          completedAt = timestamp;
        }
        running = running || item.pending;
        for (final part in item.parts) {
          if (part.kind == 'tool') toolCount++;
          if (part.kind == 'reasoning') reasoningBlocks++;
        }
      }
      rows.add(
        ChatTimelineTurnActivity(
          TurnActivity(
            id: 'turn-${run.first.id}-${message.id}',
            startIndex: sourceIndex - run.length + 1,
            endIndex: sourceIndex,
            startedAt: startedAt,
            completedAt: completedAt,
            toolCount: toolCount,
            reasoningBlocks: reasoningBlocks,
            running: running,
          ),
          message,
          sourceIndex,
        ),
      );
      if (files.isNotEmpty) {
        rows.add(ChatTimelineChangedFiles(files, message, sourceIndex));
      }
      assistantRun.clear();
    }
  }
  _unwrapSingletonGroups(rows);
  return rows;
}

/// A run of tool calls only reads as "使用了 N 个工具" once N ≥ 2 — a group
/// that never picked up a second tool (and carries no approval/interaction)
/// is unwrapped back to a plain [ChatTimelineMessage] so the single call
/// keeps its full rich presentation without a redundant one-item wrapper,
/// matching `_AssistantContent`'s identical `run.length > 1` gate for the
/// actively-streaming message.
void _unwrapSingletonGroups(List<ChatTimelineItem> rows) {
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    if (row is ChatTimelineToolGroup &&
        row.tools.length == 1 &&
        row.interactions.isEmpty) {
      rows[index] = ChatTimelineMessage(
        _singleToolMessage(row.sourceMessage, row.tools.single, row.id),
        row.sourceMessage,
        row.sourceIndex,
        ownerUserMessage: row.ownerUserMessage,
      );
    }
  }
}

ChatMessage _singleToolMessage(ChatMessage source, ChatPart part, String id) {
  return ChatMessage(
    id: '${source.id}:tool:$id',
    role: source.role,
    parts: [part],
    pending: source.pending,
    interim: source.interim,
    isError: source.isError,
    errorSurface: source.errorSurface,
    durationS: source.durationS,
    attachmentRefs: source.attachmentRefs,
    rowId: source.rowId,
    historyOrdinal: source.historyOrdinal,
    timestamp: source.timestamp,
    source: source.source,
    model: source.model,
    provider: source.provider,
    usage: source.usage,
    reactions: source.reactions,
  );
}
