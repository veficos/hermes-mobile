/// ChatMessageList and its row-level widgets — extracted from
/// lib/screens/chat_screen.dart (pure move, no behavior change): the
/// transcript ListView with date separators, streaming bubble and the
/// inline message editor.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/chat_message.dart';
import '../../core/stores/chat_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/chat_enter_to_send.dart';
import '../../widgets/h/hermes_badge.dart';
import '../../widgets/message_bubble.dart';
import '../tools/tool_group_card.dart';
import '../timeline/changed_files_card.dart';
import '../timeline/chat_timeline.dart';
import '../timeline/turn_activity_card.dart';
import 'chat_transcript_panel.dart';

/// Message list with date separators (Phase 6 Wave 2): a "today / yesterday /
/// date" chip is inserted whenever the message day changes.
class ChatMessageList extends StatelessWidget {
  final ChatTranscriptSnapshot snapshot;
  final List<ChatTimelineItem> timeline;
  final ScrollController scrollCtrl;
  final void Function(int messageCount, int streamTick, bool isStreaming)
  onTranscriptChanged;
  final void Function(ChatMessage) onMessageLongPress;
  final void Function(ChatMessage)? onRegenerate;
  final void Function(ChatMessage)? onBranch;
  final void Function(ChatMessage userMessage) onJumpToQuestion;
  final void Function(ChatMessage)? onQuoteMessage;
  final GlobalKey Function(ChatMessage) keyForMessage;
  final void Function(String id, bool mounted) onUserMessageMountChanged;
  final String? highlightMessageId;
  final String? editingMessageId;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final void Function(ChatMessage)? onEditSubmit;
  final VoidCallback? onEditCancel;
  final Future<void> Function()? onRestoreVersion;
  final Widget? editSuggestions;
  final VoidCallback? onEditAttach;
  final int editAttachmentCount;

  const ChatMessageList({
    super.key,
    required this.snapshot,
    required this.timeline,
    required this.scrollCtrl,
    required this.onTranscriptChanged,
    required this.onMessageLongPress,
    this.onRegenerate,
    this.onBranch,
    required this.onJumpToQuestion,
    this.onQuoteMessage,
    required this.keyForMessage,
    required this.onUserMessageMountChanged,
    required this.highlightMessageId,
    this.editingMessageId,
    this.editController,
    this.editFocusNode,
    this.onEditSubmit,
    this.onEditCancel,
    this.onRestoreVersion,
    this.editSuggestions,
    this.onEditAttach,
    this.editAttachmentCount = 0,
  });

  bool _showDateDivider(List<ChatMessage> msgs, int index) {
    final ts = msgs[index].timestamp?.toLocal();
    if (ts == null) return false;
    final day = DateTime(ts.year, ts.month, ts.day);
    if (index == 0) return true;
    final prev = msgs[index - 1].timestamp?.toLocal();
    if (prev == null) return true;
    return day != DateTime(prev.year, prev.month, prev.day);
  }

  Widget _wrapRow(BuildContext context, Widget row) {
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: ConstrainedBox(
        key: const ValueKey('transcript-content-column'),
        constraints: BoxConstraints(maxWidth: width < 600 ? width : 820),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width < 600 ? 8 : 12),
          child: row,
        ),
      ),
    );
  }

  Widget _messageRow(
    BuildContext context,
    ChatTimelineMessage item,
    List<ChatMessage> messages, {
    required bool firstForSource,
    required bool lastForSource,
  }) {
    final m = item.message;
    final logical = item.sourceMessage;
    final sourceIndex = item.sourceIndex;
    final assistantLike = logical.role == 'assistant' || logical.interim;
    final previous = sourceIndex > 0 ? messages[sourceIndex - 1] : null;
    final continues =
        previous != null &&
        (previous.role == 'assistant' || previous.interim) &&
        assistantLike;
    final question =
        logical.role == 'assistant' && !logical.interim && !logical.pending
        ? item.ownerUserMessage
        : null;
    final isEditing =
        editingMessageId == item.sourceMessage.id &&
        editController != null &&
        item.sourceMessage.role == 'user';
    final isStreaming =
        snapshot.isStreaming &&
        snapshot.streamingMessageId == item.sourceMessage.id;
    // Desktop BranchPicker / checkpoint parity: per-user-turn version nav.
    final chatStore = context.read<ChatStore>();
    final versionAnchor = logical.role == 'user'
        ? ChatStore.turnAnchorKey(logical)
        : null;
    final versionTotal = versionAnchor == null
        ? 1
        : chatStore.turnVersionCount(versionAnchor);
    final versionIndex = versionAnchor == null
        ? 0
        : chatStore.turnVersionCurrent(versionAnchor);
    final rowMessage = isStreaming
        ? (context.read<ChatStore>().streamingMessage ?? m)
        : m;
    final children = <Widget>[];
    if (firstForSource && _showDateDivider(messages, sourceIndex)) {
      children.add(
        DateDivider(
          date: item.sourceMessage.timestamp?.toLocal() ?? DateTime.now(),
        ),
      );
    }
    Widget messageRow = AnimatedContainer(
      key: firstForSource
          ? keyForMessage(logical)
          : ValueKey('timeline-row-${item.key}'),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : HermesMotion.standard,
      decoration: BoxDecoration(
        color: highlightMessageId == logical.id
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: isEditing
          ? InlineMessageEditor(
              controller: editController!,
              focusNode: editFocusNode,
              onSubmit: () => onEditSubmit?.call(logical),
              onCancel: onEditCancel,
              suggestions: editSuggestions,
              onAttach: onEditAttach,
              attachmentCount: editAttachmentCount,
            )
          : Dismissible(
              key: ValueKey('msg_dismiss_${item.key}'),
              direction: onQuoteMessage != null
                  ? DismissDirection.endToStart
                  : DismissDirection.none,
              dismissThresholds: const {DismissDirection.endToStart: .45},
              confirmDismiss: (_) async {
                HapticFeedback.lightImpact();
                onQuoteMessage?.call(logical);
                return false;
              },
              background: const SizedBox.shrink(),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: Icon(
                  Icons.reply,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              child: GestureDetector(
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  onMessageLongPress(logical);
                },
                child: isStreaming
                    ? StreamingBubble(
                        fallback: rowMessage,
                        showRoleHeader:
                            firstForSource && assistantLike && !continues,
                        onRegenerate: onRegenerate,
                        onJumpToQuestion: question == null
                            ? null
                            : () => onJumpToQuestion(question),
                        onTick: (tick) =>
                            onTranscriptChanged(messages.length, tick, true),
                      )
                    : MessageBubble(
                        message: rowMessage,
                        showFooter: lastForSource,
                        showRoleHeader:
                            firstForSource && assistantLike && !continues,
                        onRegenerate: onRegenerate,
                        onBranch: assistantLike ? onBranch : null,
                        onMore: () => onMessageLongPress(logical),
                        onJumpToQuestion: question == null
                            ? null
                            : () => onJumpToQuestion(question),
                        isActivelyStreaming: false,
                        agentReplySender:
                            (assistantLike &&
                                firstForSource &&
                                lastForSource &&
                                question != null)
                            ? agentDeliverySender(question.fullText)
                            : null,
                        turnVersionTotal: versionTotal,
                        turnVersionIndex: versionIndex,
                        onSelectTurnVersion: versionAnchor == null
                            ? null
                            : (i) =>
                                  chatStore.selectTurnVersion(versionAnchor, i),
                        onRestoreTurnVersion:
                            (versionAnchor == null ||
                                versionIndex >= versionTotal - 1)
                            ? null
                            : onRestoreVersion,
                      ),
              ),
            ),
    );
    if (logical.role == 'user' && firstForSource) {
      messageRow = UserMessageMountMarker(
        messageId: logical.id,
        onMountChanged: onUserMessageMountChanged,
        child: messageRow,
      );
    }
    children.add(messageRow);
    return _wrapRow(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = snapshot.messages;
    final itemCount = 1 + timeline.length + (snapshot.hasNewerWindow ? 1 : 0);
    return RefreshIndicator(
      onRefresh: () async {
        final session = context.read<SessionStore>();
        if (session.chat.hasMoreHistory && !session.chat.loadingHistory) {
          await session.loadOlderMessages();
        }
      },
      child: ListView.builder(
        controller: scrollCtrl,
        scrollCacheExtent: const ScrollCacheExtent.pixels(640),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _wrapRow(
              context,
              HistoryHeader(
                loadingHistory: snapshot.loadingHistory,
                hasMoreHistory: snapshot.hasMoreHistory,
                historyError: snapshot.historyError,
              ),
            );
          }
          final index = i - 1;
          if (snapshot.hasNewerWindow && index == timeline.length) {
            return _wrapRow(
              context,
              Center(
                child: OutlinedButton.icon(
                  key: const ValueKey('restore-newer-transcript-window'),
                  onPressed: () {
                    context.read<ChatStore>().restoreNewerTranscriptWindow();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (scrollCtrl.hasClients) {
                        scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
                      }
                    });
                  },
                  icon: const Icon(Icons.south),
                  label: Text(context.l10n.chatBackToNewerMessages),
                ),
              ),
            );
          }
          final item = timeline[index];
          final firstForSource =
              index == 0 || timeline[index - 1].sourceIndex != item.sourceIndex;
          final lastForSource =
              index + 1 >= timeline.length ||
              timeline[index + 1].sourceIndex != item.sourceIndex;
          if (item is ChatTimelineToolGroup) {
            return _wrapRow(
              context,
              Container(
                key: firstForSource
                    ? keyForMessage(item.sourceMessage)
                    : ValueKey('timeline-row-${item.key}'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ToolGroupCard(
                  groupId: item.id,
                  parts: item.tools,
                  interactions: item.interactions,
                  detailBuilder: buildToolCallCard,
                ),
              ),
            );
          }
          if (item is ChatTimelineTurnActivity) {
            // Unkeyed rows here used to let ListView's default index-based
            // element reuse silently attach a *different* turn's stats to a
            // recycled Element once older messages were prepended by
            // pagination — visibly wrong content at a given scroll position
            // ("错屏") once the transcript had enough messages to page.
            return _wrapRow(
              context,
              TurnActivityCard(
                key: firstForSource
                    ? keyForMessage(item.sourceMessage)
                    : ValueKey('timeline-row-${item.key}'),
                activity: item.activity,
              ),
            );
          }
          if (item is ChatTimelineChangedFiles) {
            return _wrapRow(
              context,
              Container(
                key: firstForSource
                    ? keyForMessage(item.sourceMessage)
                    : ValueKey('timeline-row-${item.key}'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ChangedFilesCard(files: item.files),
              ),
            );
          }
          return _messageRow(
            context,
            item as ChatTimelineMessage,
            messages,
            firstForSource: firstForSource,
            lastForSource: lastForSource,
          );
        },
      ),
    );
  }
}

class UserMessageMountMarker extends StatefulWidget {
  const UserMessageMountMarker({
    super.key,
    required this.messageId,
    required this.onMountChanged,
    required this.child,
  });

  final String messageId;
  final void Function(String id, bool mounted) onMountChanged;
  final Widget child;

  @override
  State<UserMessageMountMarker> createState() =>
      _UserMessageMountMarkerState();
}

class _UserMessageMountMarkerState extends State<UserMessageMountMarker> {
  @override
  void initState() {
    super.initState();
    widget.onMountChanged(widget.messageId, true);
  }

  @override
  void didUpdateWidget(covariant UserMessageMountMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId == widget.messageId &&
        oldWidget.onMountChanged == widget.onMountChanged) {
      return;
    }
    oldWidget.onMountChanged(oldWidget.messageId, false);
    widget.onMountChanged(widget.messageId, true);
  }

  @override
  void dispose() {
    widget.onMountChanged(widget.messageId, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The actively-streaming bubble: subscribes to the throttled stream tick so
/// only this row rebuilds during streaming — historical rows keep their
/// parsed Markdown/tool cards untouched. Reads the live buffer through
/// [ChatStore.streamingMessage] once per tick.
class StreamingBubble extends StatelessWidget {
  final ChatMessage fallback;
  final bool showRoleHeader;
  final void Function(ChatMessage)? onRegenerate;
  final VoidCallback? onJumpToQuestion;
  final void Function(int streamTick) onTick;

  const StreamingBubble({
    super.key,
    required this.fallback,
    required this.showRoleHeader,
    this.onRegenerate,
    this.onJumpToQuestion,
    required this.onTick,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ChatStore, int>(
      selector: (_, chat) => chat.streamTick,
      builder: (context, tick, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onTick(tick));
        final live = context.read<ChatStore>().streamingMessage;
        return AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          child: MessageBubble(
            message: live != null && live.id == fallback.id ? live : fallback,
            showRoleHeader: showRoleHeader,
            onRegenerate: onRegenerate,
            onJumpToQuestion: onJumpToQuestion,
            isActivelyStreaming: true,
          ),
        );
      },
    );
  }
}

/// WebUI `.msg-edit-area` parity: an in-place multiline editor that replaces
/// the user bubble while editing. Layout mirrors the user bubble (§6.5);
/// desktop keeps Enter/Esc shortcuts, touch platforms rely on buttons.
class InlineMessageEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;

  /// F1: slash / @path / @session completions overlay (built by the screen),
  /// an attach-image button, and the count of staged attachments.
  final Widget? suggestions;
  final VoidCallback? onAttach;
  final int attachmentCount;

  const InlineMessageEditor({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSubmit,
    this.onCancel,
    this.suggestions,
    this.onAttach,
    this.attachmentCount = 0,
  });

  static bool _isTouchPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final platform = Theme.of(context).platform;
    final touch = _isTouchPlatform(platform);
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= HermesBreakpoints.tablet
        ? HermesLayout.contentNarrow
        : width * 0.9;
    final onBubble = palette.bubbleUserText;
    final hint = touch
        ? context.l10n.chatEditMessageHint
        : context.l10n.chatEditMessageKeyboardHint;
    final cancelLabel = touch
        ? context.l10n.commonCancel
        : context.l10n.chatCancelKeyboardHint;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // F1: completions overlay sits above the edit bubble, like the
            // main composer's suggestions card.
            if (suggestions != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: suggestions,
              ),
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              decoration: BoxDecoration(
                color: palette.bubbleUser,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(HermesRadius.bubble),
                  topRight: Radius.circular(HermesRadius.bubble),
                  bottomLeft: Radius.circular(HermesRadius.bubble),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                  color: onBubble.withValues(alpha: 0.55),
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape):
                          onCancel ?? () {},
                    },
                    child: Focus(
                      onKeyEvent: (node, event) =>
                          handleChatEnterToSend(node, event, onSubmit),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 8,
                        cursorColor: onBubble,
                        textInputAction: TextInputAction.newline,
                        style: HermesType.messageBody.copyWith(
                          color: onBubble,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: HermesType.messageBody.copyWith(
                            color: onBubble.withValues(alpha: 0.55),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (onAttach != null)
                        IconButton(
                          tooltip: context.l10n.chatAddImage,
                          visualDensity: VisualDensity.compact,
                          color: onBubble,
                          onPressed: onAttach,
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              Positioned(
                                right: -6,
                                top: -4,
                                child: HermesBadge(count: attachmentCount),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: onBubble,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(cancelLabel),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.tonalIcon(
                        onPressed: onSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: onBubble.withValues(alpha: 0.18),
                          foregroundColor: onBubble,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(context.l10n.chatSendEdit),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateDivider extends StatelessWidget {
  final DateTime date;
  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    final label = switch (diff) {
      0 => context.l10n.chatToday,
      1 => context.l10n.chatYesterday,
      _ => context.l10n.chatMonthDay(date.month, date.day),
    };
    final palette = HermesPalette.of(context);
    return Padding(
      key: const ValueKey('transcript-date-divider'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: palette.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: palette.text3),
            ),
          ),
          Expanded(child: Divider(height: 1, color: palette.border)),
        ],
      ),
    );
  }
}

class HistoryHeader extends StatelessWidget {
  final bool loadingHistory;
  final bool hasMoreHistory;
  final String? historyError;

  const HistoryHeader({
    super.key,
    required this.loadingHistory,
    required this.hasMoreHistory,
    this.historyError,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    if (loadingHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.text3,
            ),
          ),
        ),
      );
    }
    if (historyError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: TextButton.icon(
            key: const ValueKey('history-retry'),
            onPressed: () => context.read<SessionStore>().loadOlderMessages(),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(context.l10n.chatOlderMessagesLoadFailed),
          ),
        ),
      );
    }
    if (hasMoreHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            context.l10n.chatLoadOlderMessagesHint,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: palette.text3),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          context.l10n.chatAllHistoryShown,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: palette.text3),
        ),
      ),
    );
  }
}
