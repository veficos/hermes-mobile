/// ChatTranscriptPanel — extracted from lib/screens/chat_screen.dart (pure
/// move, no behavior change): the Selector-driven transcript panel, its
/// snapshot type, and the empty / load-error / background-resume states.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat_message.dart';
import '../../core/performance_metrics.dart';
import '../../core/stores/chat_store.dart';
import '../../core/stores/composer_status_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../widgets/provider_maybe.dart';
import 'chat_message_list.dart';
import '../timeline/chat_timeline.dart';
import 'scroll_coordinator.dart';

/// Snapshot for transcript list rebuilds (counts + streaming lifecycle).
///
/// `streamTick` is deliberately EXCLUDED from equality: it bumps ~30 Hz while
/// streaming, and rebuilding the whole list per tick re-ran Markdown parsing
/// for every visible historical bubble. The actively-streaming row subscribes
/// to the tick itself ([StreamingBubble]); the list only rebuilds when its
/// structure changes.
class ChatTranscriptSnapshot {
  const ChatTranscriptSnapshot({
    required this.messages,
    required this.isStreaming,
    required this.busy,
    required this.streamingMessageId,
    required this.streamTick,
    required this.loadingHistory,
    required this.hasMoreHistory,
    required this.loadingTranscript,
    required this.historyError,
    required this.hasNewerWindow,
    required this.versionPreviewSignature,
    required this.tailStatusLabel,
    required this.transcriptRevision,
    required this.transcriptStructureRevision,
  });

  final List<ChatMessage> messages;
  final bool isStreaming;
  final bool busy;
  final String? streamingMessageId;
  final int streamTick;
  final bool loadingHistory;
  final bool hasMoreHistory;
  final bool loadingTranscript;
  final String? historyError;
  final bool hasNewerWindow;
  final String? versionPreviewSignature;
  final String? tailStatusLabel;
  final int transcriptRevision;
  final int transcriptStructureRevision;

  factory ChatTranscriptSnapshot.from(ChatStore chat) {
    return ChatTranscriptSnapshot(
      messages: chat.transcriptStructure,
      isStreaming: chat.isStreaming,
      busy: chat.busy,
      streamingMessageId: chat.streamingMessageId,
      streamTick: chat.streamTick,
      loadingHistory: chat.loadingHistory,
      hasMoreHistory: chat.hasMoreHistory,
      loadingTranscript: chat.loadingTranscript,
      historyError: chat.historyError,
      hasNewerWindow: chat.hasNewerTranscriptWindow,
      versionPreviewSignature: chat.versionPreviewSignature,
      tailStatusLabel: chat.tailStatusLabel,
      transcriptRevision: chat.transcriptRevision,
      transcriptStructureRevision: chat.transcriptStructureRevision,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatTranscriptSnapshot &&
        other.isStreaming == isStreaming &&
        other.busy == busy &&
        other.streamingMessageId == streamingMessageId &&
        other.loadingHistory == loadingHistory &&
        other.hasMoreHistory == hasMoreHistory &&
        other.loadingTranscript == loadingTranscript &&
        other.historyError == historyError &&
        other.hasNewerWindow == hasNewerWindow &&
        other.versionPreviewSignature == versionPreviewSignature &&
        other.tailStatusLabel == tailStatusLabel &&
        other.transcriptRevision == transcriptRevision &&
        other.transcriptStructureRevision == transcriptStructureRevision &&
        other.messages.length == messages.length &&
        (messages.isEmpty || other.messages.last.id == messages.last.id);
  }

  @override
  int get hashCode => Object.hash(
    isStreaming,
    busy,
    streamingMessageId,
    loadingHistory,
    hasMoreHistory,
    loadingTranscript,
    historyError,
    hasNewerWindow,
    versionPreviewSignature,
    tailStatusLabel,
    transcriptRevision,
    transcriptStructureRevision,
    messages.length,
    messages.isEmpty ? null : messages.last.id,
  );
}

class ChatTranscriptPanel extends StatefulWidget {
  final ScrollController scrollCtrl;
  final ChatScrollCoordinator scrollCoordinator;
  final void Function(int messageCount, int streamTick, bool isStreaming)
  onTranscriptChanged;
  final void Function(ChatMessage) onMessageLongPress;
  final void Function(ChatMessage)? onRegenerate;
  final void Function(ChatMessage)? onBranch;
  final void Function(ChatMessage) onJumpToQuestion;
  final void Function(ChatMessage)? onQuoteMessage;
  final GlobalKey Function(ChatMessage) keyForMessage;
  final void Function(String id, bool mounted) onUserMessageMountChanged;
  final String? highlightMessageId;
  final String? editingMessageId;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final void Function(ChatMessage)? onEditSubmit;
  final VoidCallback? onEditCancel;

  /// Re-send the turn version currently previewed (desktop BranchPicker /
  /// checkpoint "restore" parity).
  final Future<void> Function()? onRestoreVersion;

  /// F1: inline-edit completions overlay + attach button + staged count.
  final Widget? editSuggestions;
  final VoidCallback? onEditAttach;
  final int editAttachmentCount;

  /// Last transcript/session load failure (ConnectionStore.error). Rendered
  /// in place of the empty state so a failed load doesn't masquerade as an
  /// empty session.
  final String? loadError;
  final VoidCallback? onRetryLoad;
  final ValueChanged<String>? onPromptSelected;

  const ChatTranscriptPanel({
    super.key,
    required this.scrollCtrl,
    required this.scrollCoordinator,
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
    this.loadError,
    this.onRetryLoad,
    this.onPromptSelected,
  });

  @override
  State<ChatTranscriptPanel> createState() => _ChatTranscriptPanelState();
}

class _ChatTranscriptPanelState extends State<ChatTranscriptPanel> {
  int _lastMessageCount = -1;
  List<ChatTimelineItem> _timeline = const [];
  int _timelineMessageCount = -1;
  ChatMessage? _timelineFirst;
  ChatMessage? _timelineLast;
  String? _timelineStreamingId;
  String? _timelineVersionSignature;
  int _timelineRevision = -1;

  List<ChatTimelineItem> _timelineFor(ChatTranscriptSnapshot snapshot) {
    final messages = snapshot.messages;
    final first = messages.firstOrNull;
    final last = messages.lastOrNull;
    if (_timelineMessageCount == messages.length &&
        identical(_timelineFirst, first) &&
        identical(_timelineLast, last) &&
        _timelineStreamingId == snapshot.streamingMessageId &&
        _timelineVersionSignature == snapshot.versionPreviewSignature &&
        _timelineRevision == snapshot.transcriptRevision) {
      return _timeline;
    }
    _timelineMessageCount = messages.length;
    _timelineFirst = first;
    _timelineLast = last;
    _timelineStreamingId = snapshot.streamingMessageId;
    _timelineVersionSignature = snapshot.versionPreviewSignature;
    _timelineRevision = snapshot.transcriptRevision;
    final started = Stopwatch()..start();
    _timeline = buildChatTimeline(
      messages,
      preserveMessageId: snapshot.streamingMessageId,
    );
    started.stop();
    final metrics = ClientPerformanceMetrics.instance;
    if (started.elapsedMicroseconds > metrics.maxTimelineBuildMicros) {
      metrics.maxTimelineBuildMicros = started.elapsedMicroseconds;
    }
    return _timeline;
  }

  void _notifyTranscriptChanged(ChatTranscriptSnapshot snapshot) {
    if (_lastMessageCount != snapshot.messages.length) {
      _lastMessageCount = snapshot.messages.length;
      widget.onTranscriptChanged(
        snapshot.messages.length,
        snapshot.streamTick,
        snapshot.isStreaming,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ChatStore, ChatTranscriptSnapshot>(
      selector: (_, chat) => ChatTranscriptSnapshot.from(chat),
      builder: (context, snapshot, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _notifyTranscriptChanged(snapshot);
        });
        if (snapshot.messages.isEmpty && !snapshot.busy) {
          if (snapshot.loadingTranscript) {
            return const Center(
              key: ValueKey('transcript-loading'),
              child: CircularProgressIndicator(),
            );
          }
          final loadError = widget.loadError;
          if (loadError != null) {
            return TranscriptLoadError(
              message: loadError,
              onRetry: widget.onRetryLoad,
            );
          }
          return EmptyChat(onPromptSelected: widget.onPromptSelected);
        }
        return Column(
          children: [
            Expanded(
              child: ChatMessageList(
                snapshot: snapshot,
                timeline: _timelineFor(snapshot),
                scrollCtrl: widget.scrollCtrl,
                onTranscriptChanged: widget.onTranscriptChanged,
                onMessageLongPress: widget.onMessageLongPress,
                onRegenerate: widget.onRegenerate,
                onBranch: widget.onBranch,
                onJumpToQuestion: widget.onJumpToQuestion,
                onQuoteMessage: widget.onQuoteMessage,
                keyForMessage: widget.keyForMessage,
                onUserMessageMountChanged: widget.onUserMessageMountChanged,
                highlightMessageId: widget.highlightMessageId,
                editingMessageId: widget.editingMessageId,
                editController: widget.editController,
                editFocusNode: widget.editFocusNode,
                onEditSubmit: widget.onEditSubmit,
                onEditCancel: widget.onEditCancel,
                onRestoreVersion: widget.onRestoreVersion,
                editSuggestions: widget.editSuggestions,
                onEditAttach: widget.onEditAttach,
                editAttachmentCount: widget.editAttachmentCount,
              ),
            ),
            const BackgroundResumeNotice(),
          ],
        );
      },
    );
  }
}

/// Desktop `BackgroundResumeNotice` parity: while the session is idle but a
/// top-level delegated agent is still running in the background, a slim
/// shimmer line reminds the user the turn will resume when it finishes.
class BackgroundResumeNotice extends StatelessWidget {
  const BackgroundResumeNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final busy = context.select<ChatStore, bool>((chat) => chat.busy);
    final status = context.maybeRead<ComposerStatusStore>();
    if (busy || status == null) return const SizedBox.shrink();
    final sid = context.select<SessionStore, String?>(
      (session) => session.runtimeId ?? session.durableId,
    );
    return ListenableBuilder(
      listenable: status,
      builder: (context, _) => _buildNotice(context, status, sid),
    );
  }

  Widget _buildNotice(
    BuildContext context,
    ComposerStatusStore status,
    String? sid,
  ) {
    final running = status
        .itemsFor(sid)
        .where(
          (item) =>
              item.type == ComposerStatusType.subagent &&
              item.state == ComposerStatusState.running,
        )
        .toList();
    if (running.isEmpty) return const SizedBox.shrink();
    final palette = HermesPalette.of(context);
    return Container(
      key: const ValueKey('background-resume-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: palette.text3,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              running.length == 1
                  ? context.l10n.chatBackgroundAgentRunning
                  : context.l10n.chatBackgroundAgentsRunning(running.length),
              style: TextStyle(fontSize: 11, color: palette.text3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class TranscriptLoadError extends StatelessWidget {
  const TranscriptLoadError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 42, color: palette.text3),
            const SizedBox(height: 12),
            Text(context.l10n.chatTranscriptLoadFailed),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const ValueKey('transcript-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonReload),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyChat extends StatelessWidget {
  const EmptyChat({super.key, this.onPromptSelected});

  final ValueChanged<String>? onPromptSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_alt_outlined,
              size: 56,
              color: HermesSemantic.purple.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.chatEmptyTitle),
            const SizedBox(height: 4),
            Text(
              context.l10n.chatEmptyDescription,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onPromptSelected != null) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in [
                    (
                      context.l10n.chatStarterExplainProject,
                      context.l10n.chatStarterExplainProjectPrompt,
                    ),
                    (
                      context.l10n.chatStarterReviewChanges,
                      context.l10n.chatStarterReviewChangesPrompt,
                    ),
                    (
                      context.l10n.chatStarterDebugIssue,
                      context.l10n.chatStarterDebugIssuePrompt,
                    ),
                  ])
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: Text(prompt.$1),
                      onPressed: () => onPromptSelected!(prompt.$2),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
