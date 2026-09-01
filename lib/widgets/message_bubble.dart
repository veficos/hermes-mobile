import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import '../core/chat_message.dart';
import '../core/clipboard.dart';
import '../core/http_status_exception.dart';
import '../chat/content/code_block.dart';
import '../chat/content/diff_view.dart';
import '../chat/content/inline_content_renderer.dart';
import '../chat/content/reference_chips.dart';
import '../chat/content/resizable_markdown_table.dart';
import '../chat/content/streaming_remend.dart';
import '../chat/content/zoomable_markdown_image.dart';
import '../chat/tools/tool_group_card.dart';
import '../core/session_refs.dart';
import '../core/tool_card_models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import 'h/hermes_logo.dart';
import 'h/hermes_plan.dart';
import 'h/hermes_subagent.dart';
import 'h/hermes_thinking.dart';
import 'h/hermes_tool.dart';
import 'web_preview.dart';
import 'message_preview_attachments.dart';
import '../screens/mcp_screen.dart';
import '../screens/request_sheet.dart';

/// Renders a single chat message (user / assistant / interim) with markdown,
/// reasoning, and tool-call parts（design-system.md §6.5）：
/// user = bubbleUser 实底 + bubbleUserText 字，r-bubble 14（右下 4px 小角），
/// 最大宽 78%（手机）/720px（桌面）；assistant = 无底无边的文档流排版
///（左 40px 头像槽位）+ Hermes 翼标头像角色头。
///
/// Desktop-parity metadata (top row / bottom row): source channel badge,
/// timestamp and (for assistant) an action-friendly footer.
class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool showFooter;

  /// Whether this message starts an assistant visual turn and should render
  /// the shared role header. The transcript list hides it for continuation
  /// assistant/interim segments without changing the message protocol.
  final bool showRoleHeader;

  /// Desktop parity: assistant messages carry an inline action footer
  /// (copy / copy-as-markdown / regenerate) instead of relying solely on
  /// the long-press menu. Null hides the regenerate action.
  final void Function(ChatMessage message)? onRegenerate;

  /// Desktop parity: open a new chat that continues from this exact message.
  final void Function(ChatMessage message)? onBranch;

  /// Visible alternative to the row long-press menu.
  final VoidCallback? onMore;

  /// WebUI「回到话题」（msg-question-jump-btn，design spec §3）：assistant
  /// footer 右侧的小 pill，点击滚动定位到该回答对应的最近一条 user 消息。
  /// 由列表层在确认存在对应用户消息后才传入回调；为 null 时不显示按钮。
  final VoidCallback? onJumpToQuestion;

  /// B18 单条消息 TTS：外部可接管朗读行为（如经 VoiceStore）。为 null 时
  /// footer 播放按钮使用内置默认实现——通过 `context.read<ConnectionStore>()`
  /// 取 ApiClient 调 POST /api/v1/audio/speak 并用 audioplayers 播放。
  final FutureOr<void> Function(ChatMessage message)? onSpeak;

  /// True while this row is the live gateway stream (skip markdown layout).
  final bool isActivelyStreaming;

  /// Desktop `BranchPicker` / checkpoint parity: number of navigable versions
  /// of this user turn (edits / regenerations), the currently shown index, and
  /// callbacks to switch version / re-send a historical version. [total] <= 1
  /// hides the control entirely.
  final int turnVersionTotal;
  final int turnVersionIndex;
  final void Function(int index)? onSelectTurnVersion;
  final Future<void> Function()? onRestoreTurnVersion;

  /// Desktop `InterAgentAssistantMessage` parity: when this assistant message
  /// answers an inter-agent delivery, its sender's name — the settled reply
  /// renders collapsed under a "已回复 X" notice.
  final String? agentReplySender;

  const MessageBubble({
    super.key,
    required this.message,
    this.showFooter = true,
    this.showRoleHeader = true,
    this.onRegenerate,
    this.onBranch,
    this.onMore,
    this.onJumpToQuestion,
    this.onSpeak,
    this.isActivelyStreaming = false,
    this.turnVersionTotal = 1,
    this.turnVersionIndex = 0,
    this.onSelectTurnVersion,
    this.onRestoreTurnVersion,
    this.agentReplySender,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

/// Prototype parity (`docs/mobile-ui-prototype.html` `.heartpop` /
/// `@keyframes heartpop`): double-tapping a bubble pops an enlarging heart at
/// the tap point that fades out over ~0.7s, in addition to toggling the ❤️
/// reaction chip.
class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  Offset? _heartPosition;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _handleDoubleTap() async {
    SessionStore? session;
    try {
      session = context.read<SessionStore>();
    } catch (_) {}
    if (session?.reactionsEnabled != true) return;
    final mine = widget.message.reactions.where(
      (reaction) => reaction.author == 'user',
    );
    final adding = !mine.any((reaction) => reaction.emoji == '❤️');
    if (adding && _heartPosition != null) {
      _heartController.forward(from: 0);
    }
    try {
      await session!.reactToMessage(widget.message, adding ? '❤️' : null);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageReactionFailed('$error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: widget.message.rowId == null
          ? null
          : (details) => _heartPosition = details.localPosition,
      onDoubleTap: widget.message.rowId == null ? null : _handleDoubleTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RepaintBoundary(
            child: MessageRenderBoundary(
              messageId: widget.message.id,
              builder: (context) => _MessageBubbleBody(
                message: widget.message,
                showFooter: widget.showFooter,
                showRoleHeader: widget.showRoleHeader,
                onRegenerate: widget.onRegenerate,
                onBranch: widget.onBranch,
                onMore: widget.onMore,
                onJumpToQuestion: widget.onJumpToQuestion,
                onSpeak: widget.onSpeak,
                isActivelyStreaming: widget.isActivelyStreaming,
                turnVersionTotal: widget.turnVersionTotal,
                turnVersionIndex: widget.turnVersionIndex,
                onSelectTurnVersion: widget.onSelectTurnVersion,
                onRestoreTurnVersion: widget.onRestoreTurnVersion,
                agentReplySender: widget.agentReplySender,
              ).render(context),
            ),
          ),
          AnimatedBuilder(
            animation: _heartController,
            builder: (context, _) {
              if (_heartPosition == null || _heartController.value == 0) {
                return const SizedBox.shrink();
              }
              final t = _heartController.value;
              final double opacity;
              final double scale;
              final double liftDy;
              if (t < 0.25) {
                final local = t / 0.25;
                opacity = local;
                scale = 0.4 + (1.15 - 0.4) * local;
                liftDy = 0;
              } else if (t < 0.7) {
                final local = (t - 0.25) / 0.45;
                opacity = 1;
                scale = 1.15 - 0.15 * local;
                liftDy = 0;
              } else {
                final local = (t - 0.7) / 0.3;
                opacity = 1 - local;
                scale = 1;
                liftDy = -10 * local;
              }
              return Positioned(
                left: _heartPosition!.dx - 17,
                top: _heartPosition!.dy - 17 + liftDy,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opacity.clamp(0, 1),
                    child: Transform.scale(
                      scale: scale,
                      child: const Text('❤️', style: TextStyle(fontSize: 34)),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Localizes synchronous model/Markdown/tool rendering failures to one row.
/// Flutter already isolates descendant build failures; this boundary also
/// covers preprocessing and part dispatch performed by the message renderer.
class MessageRenderBoundary extends StatelessWidget {
  final String messageId;
  final WidgetBuilder builder;

  const MessageRenderBoundary({
    super.key,
    required this.messageId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return builder(context);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'hermes chat message renderer',
          context: ErrorDescription('while rendering message $messageId'),
        ),
      );
      return Card(
        key: ValueKey('message-render-error-$messageId'),
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(context.l10n.messageRenderFailed),
          subtitle: Text(context.l10n.messageRenderFailedDescription),
        ),
      );
    }
  }
}

class _MessageBubbleBody {
  final ChatMessage message;
  final bool showFooter;
  final bool showRoleHeader;
  final void Function(ChatMessage message)? onRegenerate;
  final void Function(ChatMessage message)? onBranch;
  final VoidCallback? onMore;
  final VoidCallback? onJumpToQuestion;
  final FutureOr<void> Function(ChatMessage message)? onSpeak;
  final bool isActivelyStreaming;
  final int turnVersionTotal;
  final int turnVersionIndex;
  final void Function(int index)? onSelectTurnVersion;
  final Future<void> Function()? onRestoreTurnVersion;
  final String? agentReplySender;

  const _MessageBubbleBody({
    required this.message,
    required this.showFooter,
    required this.showRoleHeader,
    this.onRegenerate,
    this.onBranch,
    this.onMore,
    this.onJumpToQuestion,
    this.onSpeak,
    required this.isActivelyStreaming,
    this.turnVersionTotal = 1,
    this.turnVersionIndex = 0,
    this.onSelectTurnVersion,
    this.onRestoreTurnVersion,
    this.agentReplySender,
  });

  Widget render(BuildContext context) {
    final theme = Theme.of(context);
    final palette = HermesPalette.of(context);
    final isUser = message.role == 'user';
    final isInterim = message.interim;

    if (message.role == 'system' && message.source == 'slash') {
      return _SlashStatusCard(message: message);
    }
    if (message.role == 'system') {
      return _SystemMessageCard(message: message);
    }
    if (isUser && _isProcessNotification(message.fullText)) {
      return _ProcessNotificationCard(text: message.fullText.trim());
    }
    if (isUser && _isAgentDelivery(message.fullText)) {
      return _AgentDeliveryCard(text: message.fullText);
    }

    // A settled assistant reply to an inter-agent delivery collapses under a
    // compact notice; while it streams the user should see progress.
    if (agentReplySender != null &&
        !isUser &&
        !isInterim &&
        !message.pending &&
        !isActivelyStreaming &&
        message.fullText.trim().isNotEmpty) {
      return _AgentReplyCollapsed(
        sender: agentReplySender!,
        body: message.fullText,
      );
    }

    if (isUser) {
      // §6.5 用户气泡：bubbleUser 实底 + bubbleUserText 字，r-bubble 14
      //（右下 4px 小角），最大宽 78%（手机）/720px（桌面），气泡间距 20。
      final width = MediaQuery.sizeOf(context).width;
      final maxWidth = width >= 840 ? 720.0 : width * 0.78;
      final versionBar = turnVersionTotal > 1
          ? _TurnVersionBar(
              total: turnVersionTotal,
              index: turnVersionIndex,
              onSelect: onSelectTurnVersion,
              onRestore: onRestoreTurnVersion,
            )
          : null;
      // C1: pull `@image:` / `@url:` / `@file:` refs out of the body into
      // chips / thumbnails below the bubble.
      final refs = extractMessageReferences(message.fullText);
      final bodyText = refs.isEmpty
          ? message.fullText
          : stripMessageReferences(message.fullText);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              key: const ValueKey('user-message-bubble'),
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                color: palette.bubbleUser,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(HermesRadius.bubble),
                  topRight: Radius.circular(HermesRadius.bubble),
                  bottomLeft: Radius.circular(HermesRadius.bubble),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TopMetaRow(
                    message: message,
                    isUser: true,
                    isInterim: isInterim,
                  ),
                  if (bodyText.isNotEmpty)
                    MarkdownBody(
                      data: _markdownText(context, bodyText),
                      selectable: true,
                      extensionSet: md.ExtensionSet.gitHubFlavored,
                      builders: {
                        'code': HermesCodeBlockBuilder(),
                        'table': ResizableMarkdownTableBuilder(),
                      },
                      sizedImageBuilder: hermesMarkdownImageBuilder,
                      onTapLink: (text, href, title) {
                        if (href != null && href.isNotEmpty) {
                          openChatLink(context, href);
                        }
                      },
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: HermesType.messageBody.copyWith(
                          color: palette.bubbleUserText,
                        ),
                        strong: TextStyle(
                          color: palette.bubbleUserText,
                          fontWeight: FontWeight.w700,
                        ),
                        code: HermesType.code.copyWith(
                          color: palette.bubbleUserText,
                        ),
                        listBullet: TextStyle(
                          color: palette.bubbleUserText.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  if (showFooter && !isInterim)
                    _BottomMetaRow(message: message, isUser: true),
                  if (message.reactions.isNotEmpty)
                    _MessageReactions(message: message, allowPicker: false),
                ],
              ),
            ),
          ),
          if (refs.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: MessageReferenceChips(references: refs),
            ),
          if (showFooter)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?versionBar,
                if (onMore != null)
                  IconButton(
                    tooltip: context.l10n.commonMore,
                    visualDensity: VisualDensity.compact,
                    onPressed: onMore,
                    icon: Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: palette.text3,
                    ),
                  ),
              ],
            )
          else
            ?versionBar,
        ],
      );
    }

    // Assistant role header stays outside the content bubble. The bubble
    // itself follows the prototype: surface + border, 90% on phones and a
    // readable cap on larger layouts.
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final assistantMaxWidth = narrow
        ? MediaQuery.sizeOf(context).width * .9
        : 720.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showRoleHeader) const _RoleHeader(),
          Padding(
            padding: EdgeInsets.only(left: narrow ? 0 : 40, top: 6),
            child: Container(
              key: const ValueKey('assistant-message-bubble'),
              constraints: BoxConstraints(maxWidth: assistantMaxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.border),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(HermesRadius.bubble),
                  topRight: Radius.circular(HermesRadius.bubble),
                  bottomRight: Radius.circular(HermesRadius.bubble),
                  bottomLeft: Radius.circular(5),
                ),
                boxShadow: hermesShadow(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopMetaRow(
                    message: message,
                    isUser: false,
                    isInterim: isInterim,
                  ),
                  _AssistantContent(
                    message: message,
                    partBuilder: _buildPart,
                    isActivelyStreaming: isActivelyStreaming,
                  ),
                  if (!message.pending && !isActivelyStreaming)
                    MessagePreviewAttachments(text: message.fullText),
                  // B14 流式光标（WebUI [data-live-assistant] 闪烁块光标）：
                  // 仅 pending 流式期间显示在正文末尾，完成后消失。
                  if (message.pending || isActivelyStreaming)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: _StreamingCursor(),
                    ),
                  // Desktop parity: completed assistant messages expose inline
                  // actions + timestamp (MessageAge) below the content.
                  if (showFooter &&
                      !isInterim &&
                      !message.pending &&
                      !isActivelyStreaming &&
                      message.fullText.trim().isNotEmpty)
                    _AssistantFooter(
                      message: message,
                      onRegenerate: onRegenerate,
                      onBranch: onBranch,
                      onMore: onMore,
                      onJumpToQuestion: onJumpToQuestion,
                      onSpeak: onSpeak,
                    ),
                  if (showFooter && !isInterim && !isActivelyStreaming)
                    _MessageReactions(message: message, allowPicker: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPart(BuildContext context, ChatPart part) {
    switch (part.kind) {
      case 'reasoning':
        // H3: an empty settled reasoning block (encrypted / spinner-only, no
        // visible text) is pure noise — render nothing.
        if (part.text.trim().isEmpty && !part.streaming) {
          return const SizedBox.shrink();
        }
        // H5: honor `display.reasoning_collapsed`.
        var collapsed = false;
        try {
          collapsed = context.read<SessionStore>().reasoningCollapsedByDefault;
        } catch (_) {}
        return HermesThinkingCard(
          text: part.text,
          streaming: part.streaming,
          initiallyExpanded: !collapsed || part.streaming,
        );
      case 'tool':
        return buildToolCallCard(part.tool ?? const <String, dynamic>{});
      case 'plan':
        return HermesPlanCard(todos: part.plan ?? const []);
      case 'subagent':
        return HermesSubagentCard(data: part.subagent ?? const {});
      case 'interaction':
        final requestId = part.interaction?['request_id']?.toString();
        return RequestSheet(embedded: true, requestId: requestId);
      default:
        // 流式期间也走 Markdown 排版（而非纯文本），消除「结束瞬间重排」。
        // remendStreamingMarkdown 会闭合半截构造（未闭合 ``` / ** / 链接），
        // 让每帧只在末尾追加文字；结算前禁用选择以避开选区闪烁。
        if (isActivelyStreaming && part.kind == 'text') {
          return InlineContentRenderer(
            text: remendStreamingMarkdown(_markdownText(context, part.text)),
            selectable: false,
            cachePreparedContent: false,
          );
        }
        // 正文 14px / 行高 1.75（WebUI --message-body-font-size/line-height）。
        return InlineContentRenderer(
          text: _markdownText(
            context,
            part.text.isEmpty && !message.pending ? '(…) ' : part.text,
          ),
        );
    }
  }

  String _markdownText(BuildContext context, String text) {
    SessionStore? session;
    try {
      session = context.read<SessionStore>();
    } catch (_) {}
    return linkifySessionRefs(
      text,
      titleOf: (id) {
        final rows = session?.sessions;
        if (rows == null) return null;
        for (final row in rows) {
          if (row.id == id) return row.title;
        }
        return null;
      },
    );
  }
}

/// Desktop parity: `display.timestamps` gates every transcript timestamp.
bool _timestampsEnabled(BuildContext context) {
  try {
    return context.read<SessionStore>().displayTimestamps;
  } catch (_) {
    return true;
  }
}

class _MessageReactions extends StatelessWidget {
  final ChatMessage message;
  final bool allowPicker;

  const _MessageReactions({required this.message, required this.allowPicker});

  Future<void> _toggle(BuildContext context, String? emoji) async {
    try {
      await context.read<SessionStore>().reactToMessage(message, emoji);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.messageReactionFailed('$error'))),
      );
    }
  }

  Future<void> _pickEmoji(BuildContext context) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _EmojiPickerSheet(),
    );
    if (emoji != null && context.mounted) await _toggle(context, emoji);
  }

  @override
  Widget build(BuildContext context) {
    var pickerEnabled = false;
    try {
      pickerEnabled = context.read<SessionStore>().reactionsEnabled;
    } catch (_) {}
    // Prototype parity (`.reactrow`/`.reactchip` — "❤️ 1"): same-emoji
    // reactions from different authors merge into one counted chip instead
    // of stacking a separate identical chip per author.
    final grouped = <String, List<MessageReaction>>{};
    for (final reaction in message.reactions) {
      grouped.putIfAbsent(reaction.emoji, () => []).add(reaction);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        key: ValueKey('message-reactions-${message.id}'),
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final entry in grouped.entries)
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                entry.value.length > 1
                    ? '${entry.key} ${entry.value.length}'
                    : entry.key,
              ),
              tooltip: entry.value.any((r) => r.author == 'user')
                  ? context.l10n.messageRemoveMyReaction
                  : context.l10n.messageAgentReaction,
              onPressed: entry.value.any((r) => r.author == 'user')
                  ? () => _toggle(context, null)
                  : null,
            ),
          if (allowPicker && pickerEnabled)
            IconButton(
              key: ValueKey('reaction-picker-${message.id}'),
              tooltip: context.l10n.messageAddReaction,
              icon: const Icon(Icons.add_reaction_outlined, size: 17),
              onPressed: () => _pickEmoji(context),
            ),
        ],
      ),
    );
  }
}

class _EmojiPickerSheet extends StatefulWidget {
  const _EmojiPickerSheet();

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  // Quick row kept for one-tap access to the common reactions.
  static const _quick = ['❤️', '👍', '👎', '😂', '‼️', '❓', '🔥', '🎉'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .55,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final emoji in _quick)
                    InkWell(
                      key: ValueKey('emoji-option-$emoji'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(context, emoji),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              // Full searchable emojibase-style picker (desktop `frimousse`
              // parity): categories, search ("lol" → 😂), skin tones.
              child: EmojiPicker(
                key: const ValueKey('emoji-search'),
                onEmojiSelected: (category, emoji) =>
                    Navigator.pop(context, emoji.emoji),
                config: Config(
                  height: double.infinity,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: scheme.surface,
                    columns: 8,
                    emojiSizeMax: 26,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: scheme.surface,
                    iconColor: scheme.onSurfaceVariant,
                    iconColorSelected: scheme.primary,
                    indicatorColor: scheme.primary,
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: scheme.surface,
                    buttonIconColor: scheme.onSurfaceVariant,
                    hintText: context.l10n.messageSearchEmoji,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedImageToolCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _GeneratedImageToolCard({required this.data});

  String? get _imageUrl {
    // Historical/persisted tool calls only ever carry `result_text` (see
    // ChatStore._historyToolData) — `result` alone only covers the
    // still-live streaming path, so a past session's generated images never
    // resolved a URL at all without this fallback.
    dynamic result = data['result'] ?? data['result_text'];
    if (result is String) {
      try {
        result = jsonDecode(result);
      } catch (_) {
        if (result.startsWith('http') || result.startsWith('data:image/')) {
          return result;
        }
      }
    }
    if (result is Map) {
      // `image` is what image_generate actually returns server-side; the
      // other keys are kept for other providers/shapes.
      return (result['image'] ??
              result['image_url'] ??
              result['url'] ??
              result['data_url'])
          ?.toString();
    }
    return null;
  }

  /// E1: size the frame from `aspect_ratio` BEFORE the image loads so the
  /// placeholder and resolved image occupy the same box (no layout shift).
  double get _aspectRatio {
    final args = data['args'];
    final raw =
        (args is Map ? args['aspect_ratio'] ?? args['size'] : null)
            ?.toString()
            .toLowerCase()
            .trim() ??
        '';
    return switch (raw) {
      'square' || '1:1' => 1,
      'portrait' || '9:16' || '2:3' || '3:4' => 3 / 4,
      _ => 16 / 9,
    };
  }

  // Every rebuild of this StatelessWidget (a streaming turn re-renders the
  // whole timeline on each token) used to re-run `contentAsBytes()` — a full
  // base64 decode — for every `data:` URI generated image still on screen,
  // even ones the user never touched. Cached by the URI string itself (the
  // content IS the url for a data: URI, so string equality is exact),
  // capped so a very long session with many distinct generated images can't
  // grow this unbounded.
  static final Map<String, Uint8List> _dataUriCache = {};
  static const _dataUriCacheLimit = 40;

  ImageProvider _provider(String url) {
    if (url.startsWith('data:')) {
      var bytes = _dataUriCache[url];
      if (bytes == null) {
        bytes = UriData.fromUri(Uri.parse(url)).contentAsBytes();
        if (_dataUriCache.length >= _dataUriCacheLimit) {
          _dataUriCache.remove(_dataUriCache.keys.first);
        }
        _dataUriCache[url] = bytes;
      }
      return MemoryImage(bytes);
    }
    return NetworkImage(url);
  }

  /// E1 / K1: save the generated image to the device gallery.
  Future<void> _saveToGallery(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      Uint8List bytes;
      if (url.startsWith('data:')) {
        bytes = UriData.fromUri(Uri.parse(url)).contentAsBytes();
      } else {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) {
          throw HttpStatusException(res.statusCode);
        }
        bytes = res.bodyBytes;
      }
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(
        bytes,
        name: 'hermes-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.imageSavedToGallery)),
        );
      }
    } catch (error) {
      if (context.mounted) {
        final detail = error is HttpStatusException
            ? context.l10n.httpStatusError(error.statusCode)
            : '$error';
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.messageImageSaveFailed(detail))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl;
    final running = data['running'] == true;
    final failed = data['is_error'] == true || data['error'] != null;
    if (url == null || url.isEmpty) {
      return Card(
        key: ValueKey(
          'image-generation-${data['tool_id'] ?? data['id'] ?? ''}',
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: running
              ? _DiffusionShimmer(label: context.l10n.messageGeneratingImage)
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        failed
                            ? Icons.broken_image_outlined
                            : Icons.image_outlined,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        failed
                            ? context.l10n.messageImageGenerationFailed
                            : context.l10n.messageWaitingForImage,
                      ),
                      if (data['summary']?.toString().isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(data['summary'].toString()),
                        ),
                    ],
                  ),
                ),
        ),
      );
    }
    final provider = _provider(url);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(context.l10n.messageGeneratedImage),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.l10n.imageCopyLink,
                  iconSize: 18,
                  onPressed: () => copyTextOrNotify(
                    context,
                    url,
                    successMessage: context.l10n.messageImageLinkCopied,
                  ),
                  icon: const Icon(Icons.link),
                ),
                IconButton(
                  tooltip: context.l10n.imageSave,
                  iconSize: 18,
                  onPressed: () => _saveToGallery(context, url),
                  icon: const Icon(Icons.save_alt),
                ),
                if (!url.startsWith('data:'))
                  IconButton(
                    tooltip: context.l10n.messageOpenInBrowser,
                    iconSize: 18,
                    onPressed: () => openChatLink(context, url),
                    icon: const Icon(Icons.open_in_new),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.92),
              builder: (_) => Dialog.fullscreen(
                backgroundColor: Colors.transparent,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        minScale: .5,
                        maxScale: 5,
                        child: Center(child: Image(image: provider)),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: context.l10n.commonClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: AspectRatio(
              aspectRatio: _aspectRatio,
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(url),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// E1: an animated shimmer stand-in while an image generates (desktop
/// `DiffusionCanvas`).
class _DiffusionShimmer extends StatefulWidget {
  final String label;
  const _DiffusionShimmer({required this.label});

  @override
  State<_DiffusionShimmer> createState() => _DiffusionShimmerState();
}

class _DiffusionShimmerState extends State<_DiffusionShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (MediaQuery.disableAnimationsOf(context)) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(child: Text(widget.label)),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1 + 2 * t, 1),
              colors: [
                scheme.surfaceContainerHigh,
                scheme.surfaceContainerHighest,
                scheme.primary.withValues(alpha: 0.12),
                scheme.surfaceContainerHighest,
                scheme.surfaceContainerHigh,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: scheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _McpSetupToolCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _McpSetupToolCard({required this.data});

  String get _server {
    final args = data['args'];
    if (args is Map) {
      final s = (args['server'] ?? args['name'] ?? args['id'] ?? '').toString();
      if (s.isNotEmpty) return s;
    }
    return (data['server'] ?? data['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final failed = data['is_error'] == true || data['error'] != null;
    final running = data['running'] == true;
    final server = _server;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              failed ? Icons.extension_off_outlined : Icons.extension_outlined,
            ),
            title: Text(
              server.isEmpty
                  ? context.l10n.messageMcpSetup
                  : context.l10n.messageMcpServer(server),
            ),
            subtitle: Text(
              failed
                  ? context.l10n.messageMcpSetupFailed
                  : running
                  ? context.l10n.messageMcpSetupWaiting
                  : context.l10n.messageMcpSetupComplete,
            ),
            trailing: running
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    failed ? Icons.error_outline : Icons.check_circle_outline,
                  ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 15),
                label: Text(context.l10n.messageOpenMcpSettings),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const McpScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototype/desktop parity dispatch: routes a tool-call payload to its
/// dedicated rich card (diff, terminal, generated image, MCP setup, web
/// search, delegated subagent) or the generic [HermesToolCard] fallback.
/// Public and stateless (keyed only on the tool payload) so both the live
/// message bubble and [ToolGroupCard]'s non-groupable rows render a tool
/// call identically whether it's actively streaming or already history.
Widget buildToolCallCard(Map<String, dynamic> tool) {
  final name = (tool['name'] ?? tool['tool_name'] ?? '').toString();
  if (name == 'image_generate' || name == 'generate_image') {
    return _GeneratedImageToolCard(data: tool);
  }
  if (name == 'setup_mcp' || name == 'mcp_setup') {
    return _McpSetupToolCard(data: tool);
  }
  // D2: a reaction's UI is the emoji on the bubble — a "react_to_message"
  // tool row beside it is the agent narrating its own tapback.
  final failed = tool['is_error'] == true || tool['error'] != null;
  if (name == 'react_to_message' && !failed) {
    return const SizedBox.shrink();
  }
  if (name == 'terminal' || name == 'terminal_exec' || name == 'execute') {
    // D2: an inter-agent delivery run through the terminal tool renders
    // as a compact "已发送给 X" notice, not a shell transcript.
    if (!failed) {
      final args = tool['args'];
      final command =
          (args is Map ? args['command'] : null)?.toString() ??
          (tool['command'] ?? '').toString();
      final target = _outboundDeliveryTarget(command);
      if (target != null) {
        return _OutboundDeliveryNotice(
          target: target,
          pending: tool['running'] == true,
          reply: _toolResultText(tool),
        );
      }
    }
    return _TerminalToolCard(data: tool);
  }
  if (name == 'changed_files' || name == 'git_diff' || name == 'apply_patch') {
    if (_inlineDiff(tool).isNotEmpty) {
      return _InlineDiffToolCard(data: tool);
    }
    return _ChangedFilesToolCard(data: tool);
  }
  if (name == 'edit_file' || name == 'patch' || name == 'write_file') {
    if (_inlineDiff(tool).isNotEmpty) {
      return _InlineDiffToolCard(data: tool);
    }
    // A6 (desktop parity): a settled, successful `write_file` *create*
    // with neither a diff nor any result body is a dead duplicate row
    // after a reload — drop it. In-flight writes, failures, and rows
    // that carry an actual result stay visible.
    final running = tool['running'] == true;
    if (name == 'write_file' &&
        !running &&
        !failed &&
        _toolResultText(tool).trim().isEmpty) {
      return const SizedBox.shrink();
    }
  }
  if (name == 'web_search' ||
      name == 'browser_navigate' ||
      name == 'web_fetch') {
    return _WebToolCard(data: tool);
  }
  if (name == 'delegate_task' || name == 'delegate') {
    final rows = DelegateRunModel.listFrom(tool);
    if (rows.length <= 1) {
      final delegate = rows.isNotEmpty
          ? rows.first
          : DelegateRunModel.from(tool);
      return HermesSubagentCard(
        data: {
          ...tool,
          'subagent_id': delegate.id,
          'task': delegate.task,
          'status': delegate.status,
          'model': ?delegate.model,
          'duration_ms': ?delegate.durationMs,
        },
      );
    }
    // Desktop parity: a call dispatching several children fans out into one
    // card per child instead of a single card that can only speak for one
    // of them.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final delegate in rows)
          HermesSubagentCard(
            key: ValueKey('delegate-row-${delegate.id}'),
            data: {
              ...tool,
              'subagent_id': delegate.id,
              'task': delegate.task,
              'status': delegate.status,
              'model': ?delegate.model,
              'duration_ms': ?delegate.durationMs,
            },
          ),
      ],
    );
  }
  return HermesToolCard(data: tool);
}

String _toolResultText(Map<String, dynamic> data) {
  final value = data['result_text'] ?? data['result'] ?? data['summary'] ?? '';
  if (value is String) return value;
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}

class _TerminalToolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TerminalToolCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final run = TerminalRunModel.from(data);
    final palette = HermesPalette.of(context);
    return ToolCardShell(
      key: ValueKey('tool-card-${data['tool_id'] ?? data['id'] ?? 'terminal'}'),
      icon: Icons.terminal,
      title: 'terminal',
      subtitle: run.command.isEmpty
          ? null
          : Text(
              run.command,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: palette.text3),
            ),
      trailing: run.running
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      failed: run.failed,
      initiallyExpanded: run.running,
      children: [
        if (run.command.isNotEmpty) ...[
          Text(
            context.l10n.toolCommand,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: toolCodeBoxDecoration(context),
            child: SelectableText(
              run.command,
              style: HermesType.code.copyWith(
                color: palette.text,
                fontSize: 12,
              ),
            ),
          ),
        ],
        if (run.exitCode != null || run.durationMs != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                if (run.exitCode != null)
                  context.l10n.toolExitCode(run.exitCode!),
                if (run.durationMs != null) '${run.durationMs}ms',
              ].join(' · '),
              style: TextStyle(fontSize: 11, color: palette.text3),
            ),
          ),
        if (run.output.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.toolOutput,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: toolCodeBoxDecoration(context),
            child: SingleChildScrollView(
              child: SelectableText(
                run.output,
                style: HermesType.code.copyWith(
                  color: palette.text,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChangedFilesToolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ChangedFilesToolCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final files = parseChangedFiles(data);
    final palette = HermesPalette.of(context);
    final good = hermesSemantic(
      context,
      HermesSemantic.green,
      HermesSemanticDark.green,
    );
    final bad = hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    );
    return ToolCardShell(
      icon: Icons.difference_outlined,
      title: context.l10n.toolChangedFiles(files.length),
      children: files.isEmpty
          ? [SelectableText(_toolResultText(data))]
          : [
              for (final file in files)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 15,
                        color: palette.text3,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HermesType.code.copyWith(
                            color: palette.text,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+${file.additions}',
                        style: TextStyle(
                          color: good,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '−${file.deletions}',
                        style: TextStyle(
                          color: bad,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
    );
  }
}

String _inlineDiff(Map<String, dynamic> data) {
  dynamic result = data['result'] ?? data['result_text'];
  if (result is String) {
    try {
      result = jsonDecode(result);
    } catch (_) {}
  }
  if (result is Map) {
    return (result['inline_diff'] ?? result['diff'] ?? '').toString();
  }
  return '';
}

class _InlineDiffToolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InlineDiffToolCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final diff = _inlineDiff(data);
    final args = data['args'] is Map ? data['args'] as Map : const {};
    final rawPath = args['path'] ?? args['file'] ?? data['path'];
    final path = rawPath?.toString() ?? context.l10n.messageFileChanges;
    // Desktop `FileDiffPanel` parity: a `+N −M` hunk-stats line.
    final stats = diffLineStats(diff);
    final palette = HermesPalette.of(context);
    final good = hermesSemantic(
      context,
      HermesSemantic.green,
      HermesSemanticDark.green,
    );
    final bad = hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    );
    return ToolCardShell(
      key: ValueKey('inline-diff-$path'),
      icon: Icons.difference_outlined,
      title: path,
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.messageViewDiff,
            style: TextStyle(fontSize: 10.5, color: palette.text3),
          ),
          if (stats.added > 0 || stats.removed > 0) ...[
            const SizedBox(width: 8),
            Text(
              '+${stats.added}',
              style: TextStyle(
                color: good,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '−${stats.removed}',
              style: TextStyle(
                color: bad,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      children: [
        // Syntax-highlighted diff with tint + gutter accent + line numbers.
        FileDiffView(
          diff: diff,
          path: rawPath == null ? null : path,
          showLineNumbers: true,
        ),
      ],
    );
  }
}

class _WebToolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _WebToolCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final results = parseWebResults(data);
    final args = data['args'];
    final url = (data['url'] ?? (args is Map ? args['url'] : null))?.toString();
    final query =
        (data['query'] ??
                (args is Map ? args['query'] ?? args['search_term'] : null))
            ?.toString();
    final palette = HermesPalette.of(context);
    if (results.isNotEmpty) {
      return ToolCardShell(
        key: ValueKey('tool-card-${data['tool_id'] ?? data['id'] ?? 'web'}'),
        icon: Icons.travel_explore,
        title: 'web_search',
        subtitle: Text(
          context.l10n.toolSearchResults(results.length),
          style: TextStyle(fontSize: 10.5, color: palette.text3),
        ),
        children: [
          if (query?.isNotEmpty == true) ...[
            Text(
              context.l10n.toolSearchQuery,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              query!,
              style: HermesType.code.copyWith(
                fontSize: 12,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final result in results)
            InkWell(
              onTap: result.url.isEmpty
                  ? null
                  : () => openChatLink(context, result.url),
              borderRadius: BorderRadius.circular(HermesRadius.smallCard),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: toolCodeBoxDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    if (result.url.isNotEmpty)
                      Text(
                        result.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: hermesSemantic(
                            context,
                            HermesSemantic.blue,
                            HermesSemanticDark.blue,
                          ),
                        ),
                      ),
                    if (result.snippet.isNotEmpty)
                      Text(
                        result.snippet,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: palette.text3),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    final title = query?.isNotEmpty == true
        ? query!
        : url?.isNotEmpty == true
        ? url!
        : context.l10n.messageWebFallback;
    return ToolCardShell(
      icon: Icons.travel_explore,
      title: title,
      trailing: url?.isNotEmpty == true
          ? IconButton(
              tooltip: context.l10n.messageOpenLink,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => openChatLink(context, url!),
              icon: const Icon(Icons.open_in_new),
            )
          : null,
      initiallyExpanded: true,
      children: [
        Text(
          _toolResultText(data),
          style: HermesType.code.copyWith(color: palette.text, fontSize: 12),
        ),
      ],
    );
  }
}

class _SlashStatusCard extends StatelessWidget {
  final ChatMessage message;

  const _SlashStatusCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = HermesPalette.of(context);
    final lines = message.fullText.split('\n');
    final command = lines.first.replaceFirst('slash:', '');
    final output = lines.skip(1).join('\n').trim();
    final color = message.isError
        ? theme.colorScheme.error
        : message.pending
        ? theme.colorScheme.primary
        : palette.text3;
    final at = message.timestamp?.toLocal();
    final timeLabel = at == null
        ? null
        : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('slash-status-card'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 9, 14, 10),
        constraints: const BoxConstraints(maxWidth: 680),
        decoration: BoxDecoration(
          color: color.withValues(alpha: message.isError ? 0.07 : 0.035),
          border: Border.all(color: color.withValues(alpha: .22)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.pending)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: color,
                ),
              )
            else
              Icon(
                message.isError ? Icons.error_outline : Icons.terminal,
                size: 17,
                color: color,
              ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    command,
                    style: HermesType.code.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (output.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      output,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.text2,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (timeLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      timeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.text3.withValues(alpha: .7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// B14 流式光标（design-system.md §5.4 流式输出：末尾光标闪烁 530ms
/// 周期）：正文末尾的小竖条，淡入淡出循环；由父级仅在 pending 时挂载，
/// 流式结束随 pending 复位而消失。
class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 530),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return _cursor(HermesPalette.of(context).text);
    }
    return FadeTransition(
      key: const ValueKey('streaming-cursor'),
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      child: _cursor(HermesPalette.of(context).text),
    );
  }

  Widget _cursor(Color color) => Container(
    width: 8,
    height: 16,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(1.5),
    ),
  );
}

/// Best-effort active-connection label ("当前连接的备注") — the profile name
/// or host next to the assistant avatar, so a multi-server setup shows at a
/// glance which backend answered. Absent when no [ConnectionStore] is in
/// the tree (bare widget tests) or the connection has no usable label yet.
String? _connectionLabel(BuildContext context) {
  try {
    // watch, not read: the label can resolve asynchronously shortly after
    // app start (matching a saved profile name is a background lookup —
    // see ConnectionStore._resolveActiveProfileLabel), so this must react
    // to that notifyListeners() instead of freezing whatever was known at
    // this row's first build.
    return context.watch<ConnectionStore>().activeConnectionLabel;
  } catch (_) {
    return null;
  }
}

/// Assistant 角色头（WebUI spec §3 `.msg-role`）：Hermes 翼标头像 + 当前连接
/// 备注（prototype `.grow-sub` parity：12px/text3，紧挨头像右侧一行）。
class _RoleHeader extends StatelessWidget {
  const _RoleHeader();

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final connectionLabel = _connectionLabel(context)?.trim();
    return Padding(
      key: const ValueKey('assistant-role-header'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: context.l10n.messageHermesAvatar,
            child: Container(
              key: const ValueKey('assistant-avatar-icon'),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: palette.accentBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: HermesLogo(size: 22, color: palette.accent),
            ),
          ),
          if (connectionLabel != null && connectionLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                connectionLabel,
                key: const ValueKey('assistant-connection-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: palette.text3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssistantContent extends StatelessWidget {
  final ChatMessage message;
  final Widget Function(BuildContext, ChatPart) partBuilder;
  final bool isActivelyStreaming;

  const _AssistantContent({
    required this.message,
    required this.partBuilder,
    this.isActivelyStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var index = 0;
    while (index < message.parts.length) {
      final part = message.parts[index];
      if (part.kind != 'tool') {
        children.add(partBuilder(context, part));
        index++;
        continue;
      }
      // Every consecutive run of tool calls — exploratory or dedicated
      // alike — collapses into one rollup card; a lone tool call (run
      // length 1) stays as its own standalone card so it keeps full rich
      // presentation (diff, image preview, …) without a redundant "使用了
      // 1 个工具" wrapper.
      var next = index;
      while (next < message.parts.length &&
          message.parts[next].kind == 'tool') {
        next++;
      }
      final run = message.parts.sublist(index, next);
      if (run.length > 1) {
        // Reuses the exact same rollup card the historical/settled timeline
        // uses (`ToolGroupCard`, `chat_timeline.dart`'s `ChatTimelineToolGroup`
        // rows) so a group of tool calls looks identical whether the turn
        // is still streaming or has already finished. `detailBuilder` gives
        // a tapped row the same rich presentation (diff, image preview,
        // subagent tree, …) it would have gotten rendered standalone.
        final tools = run.map((p) => p.tool ?? const <String, dynamic>{});
        final groupId =
            'tool-group-${tools.map((t) => t['tool_id'] ?? t['id'] ?? t['name']).join('-')}';
        children.add(
          ToolGroupCard(
            groupId: groupId,
            parts: run,
            detailBuilder: buildToolCallCard,
          ),
        );
      } else {
        for (final tool in run) {
          children.add(partBuilder(context, tool));
        }
      }
      index = next;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Injected background-process notifications
/// (`[IMPORTANT: Background process …]`, see the agent's
/// process_registry.format_process_notification) arrive on the user role but
/// are not something the human typed. Desktop parity: `ProcessNotificationNote`.
bool _isProcessNotification(String text) => RegExp(
  r'^\s*\[IMPORTANT:\s*Background process[\s\S]*\]\s*$',
).hasMatch(text);

class _ProcessNotificationCard extends StatelessWidget {
  final String text;
  const _ProcessNotificationCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final body = text
        .replaceFirst(RegExp(r'^\s*\[IMPORTANT:\s*'), '')
        .replaceFirst(RegExp(r'\]\s*$'), '')
        .trim();
    final newline = body.indexOf('\n');
    final headline = (newline == -1 ? body : body.substring(0, newline)).trim();
    final detail = newline == -1 ? '' : body.substring(newline + 1).trim();
    return Align(
      alignment: Alignment.center,
      child: Container(
        key: const ValueKey('process-notification-card'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terminal, size: 13, color: palette.text3),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    headline,
                    style: TextStyle(fontSize: 11, color: palette.text3),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const ValueKey('process-notification-output'),
                    tilePadding: EdgeInsets.zero,
                    minTileHeight: 28,
                    title: Text(
                      context.l10n.toolOutput,
                      style: TextStyle(fontSize: 11, color: palette.text3),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 200),
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            detail,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _isAgentDelivery(String text) => RegExp(
  r"^(?:Message from (?:🤖\s*)?[^:\n(]{1,64}(?:\s*\(@[a-z0-9][a-z0-9_-]{0,63}\))?:\s*|\[Message from agent '[^']{1,64}'\]\s*)",
  caseSensitive: false,
).hasMatch(text.trim());

/// The recipient of an outbound inter-agent delivery run through the terminal
/// tool (`hermes -p <agent> chat … -q "Message from …"`), or null.
final _outboundDeliveryRe = RegExp(
  r'''(?:^|[;&|]\s*|\bhermes\s+)-p\s+("?)([a-z0-9][a-z0-9_-]{0,63})\1\s+chat\b[\s\S]*?-q\s+["']Message from''',
  caseSensitive: false,
);
String? _outboundDeliveryTarget(String command) {
  final m = _outboundDeliveryRe.firstMatch(command);
  return m?.group(2)?.toLowerCase();
}

class _OutboundDeliveryNotice extends StatelessWidget {
  final String target;
  final bool pending;
  final String reply;
  const _OutboundDeliveryNotice({
    required this.target,
    required this.pending,
    required this.reply,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final body = reply.trim();
    return Align(
      alignment: Alignment.center,
      child: Container(
        key: const ValueKey('outbound-delivery-notice'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AgentGlyph(handle: target, size: 14),
                const SizedBox(width: 6),
                Text(
                  pending
                      ? context.l10n.messageSendingToAgent(target)
                      : context.l10n.messageSentToAgent(target),
                  style: TextStyle(fontSize: 11, color: palette.text3),
                ),
              ],
            ),
            if (!pending && body.isNotEmpty)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  minTileHeight: 26,
                  title: Text(
                    context.l10n.messageReplyFromAgent(target),
                    style: TextStyle(fontSize: 11, color: palette.text3),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        body,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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

/// Avatar for an inter-agent delivery sender: the profile's avatar if one is
/// known (desktop resolves it from `profiles.get_asset`), else the 🤖 glyph.
class AgentGlyph extends StatelessWidget {
  final String handle;
  final double size;
  const AgentGlyph({super.key, required this.handle, this.size = 16});

  String? _avatarFor(BuildContext context) {
    SessionStore? session;
    try {
      session = context.read<SessionStore>();
    } catch (_) {
      return null;
    }
    final key = handle.trim().toLowerCase();
    for (final profile in session.profiles) {
      if (profile.name.toLowerCase() != key) continue;
      final raw = profile.raw;
      final value =
          (raw['avatar'] ?? raw['avatar_url'] ?? raw['avatar_data_url'])
              ?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarFor(context);
    if (avatar != null &&
        (avatar.startsWith('http') || avatar.startsWith('data:'))) {
      return ClipOval(
        child: Image(
          image: avatar.startsWith('data:')
              ? MemoryImage(UriData.fromUri(Uri.parse(avatar)).contentAsBytes())
              : NetworkImage(avatar) as ImageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Text('🤖', style: TextStyle(fontSize: size * 0.9)),
        ),
      );
    }
    return Text('🤖', style: TextStyle(fontSize: size * 0.9));
  }
}

/// The sender name of an inter-agent delivery message, or null when [text] is
/// not one. Shared with the transcript list so an assistant *reply* to a
/// delivery can collapse under a "已回复 X" notice (desktop
/// `InterAgentAssistantMessage` parity).
String? agentDeliverySender(String text) {
  final match = RegExp(
    r"^(?:Message from (?:🤖\s*)?([^:\n(]{1,64})(?:\s*\(@[^)]*\))?:\s*|\[Message from agent '([^']{1,64})'\]\s*)",
    caseSensitive: false,
  ).firstMatch(text.trim());
  if (match == null) return null;
  return (match.group(1) ?? match.group(2) ?? 'agent').trim();
}

/// Collapsed stand-in for a settled assistant reply to an inter-agent
/// delivery — the exchange shows as an event; the reply is one tap away.
class _AgentReplyCollapsed extends StatelessWidget {
  final String sender;
  final String body;
  const _AgentReplyCollapsed({required this.sender, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Align(
      alignment: Alignment.center,
      child: Container(
        key: const ValueKey('agent-reply-collapsed'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 560),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            minTileHeight: 30,
            leading: Icon(
              Icons.subdirectory_arrow_right,
              size: 15,
              color: palette.text3,
            ),
            title: Text(
              context.l10n.messageRepliedToAgent(sender),
              style: TextStyle(fontSize: 11, color: palette.text3),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  body,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentDeliveryCard extends StatelessWidget {
  final String text;
  const _AgentDeliveryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final match = RegExp(
      r"^(?:Message from (?:🤖\s*)?([^:\n(]{1,64})(?:\s*\(@[^)]*\))?:\s*|\[Message from agent '([^']{1,64})'\]\s*)([\s\S]*)$",
    ).firstMatch(text.trim());
    final sender = (match?.group(1) ?? match?.group(2) ?? 'agent').trim();
    final body = (match?.group(3) ?? '').trim();
    final palette = HermesPalette.of(context);
    return Container(
      key: const ValueKey('agent-delivery-card'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.accentBg.withValues(alpha: .32),
        border: Border.all(color: palette.accent.withValues(alpha: .28)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgentGlyph(handle: sender, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.messageFromAgent(sender),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  SelectableText(body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemMessageCard extends StatelessWidget {
  final ChatMessage message;
  const _SystemMessageCard({required this.message});

  static final _steer = RegExp(r'^steer:\s*([\s\S]+)$');
  static final _review = RegExp(r'^review:\s*([^:\n]+):?\s*([\s\S]*)$');

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final text = message.fullText.trim();

    // C5: `steer:` — a mid-turn course correction the user injected.
    final steer = _steer.firstMatch(text);
    if (steer != null) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          key: const ValueKey('steer-note'),
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_outlined, size: 13, color: palette.text3),
              const SizedBox(width: 6),
              Text(
                context.l10n.messageSteered,
                style: TextStyle(fontSize: 11, color: palette.text3),
              ),
              const SizedBox(width: 5),
              Text('·', style: TextStyle(color: palette.text3)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  steer.group(1)!.trim(),
                  style: TextStyle(fontSize: 11, color: palette.text2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // C5: `review:` — the self-improvement pass saved something to memory /
    // skills. Brain glyph + gradient label (desktop legendary chrome).
    final review = _review.firstMatch(text);
    if (review != null) {
      return Padding(
        key: const ValueKey('review-note'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFFE5B94E), Color(0xFF9D6BE8)],
              ).createShader(rect),
              child: const Icon(Icons.psychology_outlined, size: 15),
            ),
            const SizedBox(width: 6),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFFE5B94E), Color(0xFF9D6BE8)],
              ).createShader(rect),
              child: Text(
                review.group(1)!.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (review.group(2)!.trim().isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  review.group(2)!.trim(),
                  style: TextStyle(fontSize: 12, color: HermesSemantic.purple),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('system-message-card'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: palette.text3.withValues(alpha: .06),
        border: Border.all(color: palette.text3.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 17, color: palette.text3),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(message.fullText)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 桌面版同构元数据：top row (source) + bottom row (timestamp)
// 桌面 assistant-message.tsx 里 MessageAge 显示 "2h ago" + tooltip 绝对时间。
// 渠道来源 source 用 chip 形式：weixin / feishu / cli / telegram / discord / webui …
// ---------------------------------------------------------------------------

class _TopMetaRow extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final bool isInterim;

  const _TopMetaRow({
    required this.message,
    required this.isUser,
    required this.isInterim,
  });

  /// Map raw server source identifier → (label, icon, color).
  ({String label, IconData icon, Color color}) _sourceInfo(
    BuildContext context,
    String? raw,
  ) {
    final r = (raw ?? '').toLowerCase().replaceAll(RegExp(r'[_-]'), '');
    switch (r) {
      case 'weixin':
      case 'wechat':
      case 'wx':
        return (
          label: context.l10n.messageSourceWechat,
          icon: Icons.chat,
          color: HermesProviderBrand.wechat,
        );
      case 'feishu':
      case 'lark':
        return (
          label: context.l10n.messageSourceFeishu,
          icon: Icons.send,
          color: HermesProviderBrand.feishu,
        );
      case 'telegram':
      case 'tg':
        return (
          label: 'Telegram',
          icon: Icons.send_outlined,
          color: HermesProviderBrand.telegram,
        );
      case 'discord':
      case 'dc':
        return (
          label: 'Discord',
          icon: Icons.gamepad_outlined,
          color: HermesProviderBrand.discord,
        );
      case 'imessage':
      case 'bluebubbles':
        return (
          label: 'iMessage',
          icon: Icons.message,
          color: HermesProviderBrand.imessageBubble,
        );
      case 'cli':
      case 'terminal':
        return (
          label: 'CLI',
          icon: Icons.terminal,
          color: HermesSemantic.purple,
        );
      case 'server':
        return (
          label: context.l10n.messageSourceServer,
          icon: Icons.dns_outlined,
          color: HermesSemantic.gray,
        );
      case 'webui':
      case 'web':
      case 'desktop':
        return (
          label: context.l10n.messageSourceDesktop,
          icon: Icons.laptop_chromebook_outlined,
          color: HermesSemantic.blue,
        );
      case 'mobile':
        return (
          label: context.l10n.messageSourceMobile,
          icon: Icons.smartphone_outlined,
          color: HermesPalette.of(context).accent,
        );
      default:
        if (raw == null || raw.isEmpty) {
          return (
            label: '',
            icon: Icons.bubble_chart_outlined,
            color: HermesSemantic.gray,
          );
        }
        return (
          label: raw,
          icon: Icons.bubble_chart_outlined,
          color: HermesSemantic.blue,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isInterim) return const SizedBox.shrink();
    final palette = HermesPalette.of(context);
    final source = _sourceInfo(context, message.source);
    final hasSource = source.label.isNotEmpty;

    if (!hasSource) return const SizedBox(height: 2);

    // caption 小字；用户气泡（accent 实底）内用反白叠层底，assistant 用
    // surface 底。
    final chipText = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: isUser ? palette.bubbleUserText : palette.text3,
    );
    final chipBg = isUser
        ? palette.bubbleUserText.withValues(alpha: 0.14)
        : palette.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasSource)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(source.icon, size: 12, color: chipText.color),
                  const SizedBox(width: 4),
                  Text(source.label, style: chipText),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomMetaRow extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;

  const _BottomMetaRow({required this.message, required this.isUser});

  String _relative(BuildContext context, DateTime t, DateTime now) {
    final d = now.difference(t);
    if (d.inSeconds < 60) return context.l10n.timeJustNow;
    if (d.inMinutes < 60) return context.l10n.timeMinutesAgo(d.inMinutes);
    if (d.inHours < 24) return context.l10n.timeHoursAgo(d.inHours);
    if (d.inDays < 7) return context.l10n.timeDaysAgo(d.inDays);
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    if (day == today) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _absolute(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final ts = message.timestamp;
    if (ts == null || !_timestampsEnabled(context)) {
      return const SizedBox(height: 2);
    }
    final now = DateTime.now();
    final duration = _UsageMeta.turnDuration(message);
    final local = ts.toLocal();
    final tooltip = duration == null
        ? _absolute(local)
        : '${_absolute(local)} → ${_absolute(local.add(duration))}';
    // footnote 时间戳；用户气泡内反白弱化，assistant 用 text-3。
    final muted = isUser
        ? palette.bubbleUserText.withValues(alpha: 0.8)
        : palette.text3;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Tooltip(
        message: tooltip,
        // Tooltip 规范（§6.15）：r-sm、elevated 底。
        decoration: BoxDecoration(
          color: palette.elevated,
          borderRadius: BorderRadius.circular(HermesRadius.smallCard),
          border: Border.all(color: palette.border),
        ),
        textStyle: HermesType.footnote.copyWith(color: palette.text2),
        waitDuration: const Duration(milliseconds: 400),
        child: Text(
          _relative(context, ts.toLocal(), now),
          style: TextStyle(
            fontSize: 11,
            height: 1.1,
            letterSpacing: 0.04,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
      ),
    );
  }
}

/// Desktop `BranchPicker` / checkpoint parity: `‹ n / total ›` under a user
/// bubble, navigating this turn's edit / regeneration history. While a
/// historical version is shown, a "恢复此版本" pill re-sends it as a fresh turn.
class _TurnVersionBar extends StatelessWidget {
  final int total;
  final int index;
  final void Function(int index)? onSelect;
  final Future<void> Function()? onRestore;

  const _TurnVersionBar({
    required this.total,
    required this.index,
    this.onSelect,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final muted = palette.text3;
    final atLive = index >= total - 1;
    Widget arrow(IconData icon, int target, String tip) => IconButton(
      key: ValueKey(
        'turn-version-${icon == Icons.chevron_left ? 'prev' : 'next'}',
      ),
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      color: muted,
      tooltip: tip,
      onPressed: (onSelect == null || target < 0 || target > total - 1)
          ? null
          : () => onSelect!(target),
      icon: Icon(icon),
    );
    return Padding(
      key: const ValueKey('turn-version-bar'),
      padding: const EdgeInsets.only(top: 2, right: 2, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!atLive && onRestore != null)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: TextButton.icon(
                key: const ValueKey('turn-version-restore'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: palette.accent,
                ),
                onPressed: () => onRestore!(),
                icon: const Icon(Icons.restore, size: 15),
                label: Text(
                  context.l10n.messageRestoreVersion,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          arrow(
            Icons.chevron_left,
            index - 1,
            context.l10n.messagePreviousVersion,
          ),
          Text(
            '${index + 1} / $total',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          arrow(
            Icons.chevron_right,
            index + 1,
            context.l10n.messageNextVersion,
          ),
        ],
      ),
    );
  }
}

/// Assistant action footer (desktop parity): inline copy / copy-as-markdown /
/// regenerate icons plus the message timestamp, replacing the
/// long-press-only workflow for the most common assistant actions.
class _AssistantFooter extends StatelessWidget {
  final ChatMessage message;
  final void Function(ChatMessage message)? onRegenerate;
  final void Function(ChatMessage message)? onBranch;
  final VoidCallback? onMore;
  final VoidCallback? onJumpToQuestion;
  final FutureOr<void> Function(ChatMessage message)? onSpeak;

  const _AssistantFooter({
    required this.message,
    this.onRegenerate,
    this.onBranch,
    this.onMore,
    this.onJumpToQuestion,
    this.onSpeak,
  });

  String _relative(BuildContext context, DateTime t, DateTime now) {
    final d = now.difference(t);
    if (d.inSeconds < 60) return context.l10n.timeJustNow;
    if (d.inMinutes < 60) return context.l10n.timeMinutesAgo(d.inMinutes);
    if (d.inHours < 24) return context.l10n.timeHoursAgo(d.inHours);
    if (d.inDays < 7) return context.l10n.timeDaysAgo(d.inDays);
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    if (day == today) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _absolute(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  void _copy(BuildContext context, String text, String toast) {
    if (text.isEmpty) return;
    copyTextOrNotify(context, text, successMessage: toast);
  }

  @override
  Widget build(BuildContext context) {
    final muted = HermesPalette.of(context).text3;
    final ts = _timestampsEnabled(context) ? message.timestamp : null;

    // 16px text-3 小图标，静止透明度 0.6；按下/悬停反馈为浅底圆角 hover
    // 区域（InkWell borderRadius）。
    Widget iconButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
    }) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          hoverColor: muted.withValues(alpha: 0.08),
          highlightColor: muted.withValues(alpha: 0.10),
          splashColor: muted.withValues(alpha: 0.12),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Opacity(
              opacity: 0.8,
              child: Icon(icon, size: 18, color: muted),
            ),
          ),
        ),
      );
    }

    // B8 富文本脚注：生成时间 + 使用的模型 + 执行耗时 + token 消耗合并成
    // 单行脚注，取代原先分散在操作按钮行里的时间文本 + 模型徽章 —— 一行
    // 就能读完这条回复的全部生成信息，而不是从两处拼凑。
    final duration = _UsageMeta.turnDuration(message);
    final responseModel = _UsageMeta.responseModel(message);
    final usageLine = _UsageMeta.format(message);
    final footnote = [
      if (ts != null) _relative(context, ts.toLocal(), DateTime.now()),
      ?responseModel,
      ?usageLine,
    ].join(' · ');
    final footnoteTooltip = ts == null
        ? null
        : (duration == null
              ? _absolute(ts.toLocal())
              : '${_absolute(ts.toLocal())} → ${_absolute(ts.toLocal().add(duration))}');
    final jump = onJumpToQuestion;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 2,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              iconButton(
                icon: Icons.copy_outlined,
                tooltip: context.l10n.messageCopyText,
                onTap: () => _copy(
                  context,
                  message.plainText,
                  context.l10n.commonCopied,
                ),
              ),
              iconButton(
                icon: Icons.data_object_outlined,
                tooltip: context.l10n.messageCopyMarkdown,
                onTap: () => _copy(
                  context,
                  message.fullText,
                  context.l10n.chatMarkdownCopied,
                ),
              ),
              if (onRegenerate != null)
                iconButton(
                  icon: Icons.refresh,
                  tooltip: context.l10n.chatRegenerate,
                  onTap: () => onRegenerate!(message),
                ),
              if (onBranch != null)
                iconButton(
                  icon: Icons.call_split,
                  tooltip: context.l10n.messageBranchFromHere,
                  onTap: () => onBranch!(message),
                ),
              if (onMore != null)
                iconButton(
                  icon: Icons.more_horiz,
                  tooltip: context.l10n.commonMore,
                  onTap: onMore!,
                ),
              _MessageSpeakButton(message: message, onSpeak: onSpeak),
              if (jump != null) _QuestionJumpButton(onTap: jump),
            ],
          ),
          if (footnote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 6),
              child: Tooltip(
                message: footnoteTooltip ?? footnote,
                waitDuration: const Duration(milliseconds: 400),
                child: Text(
                  footnote,
                  key: const ValueKey('msg-footnote'),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    letterSpacing: 0.04,
                    fontWeight: FontWeight.w500,
                    color: muted.withValues(alpha: 0.78),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// B18 单条消息 TTS 按钮（WebUI `ui.js:16403` 每条 assistant 消息朗读按钮）。
/// 与复制/重生成同风格的 16px muted 小图标。外部经 [onSpeak] 接管时只做
/// 触发；否则使用默认实现：ApiClient（经 ConnectionStore 注入）请求
/// /api/v1/audio/speak，audioplayers 播放；播放中图标变停止态、点击中止；
/// 失败 snackbar 提示。朗读文本为消息纯文本（`plainText`，已去 markdown）。
class _MessageSpeakButton extends StatefulWidget {
  final ChatMessage message;
  final FutureOr<void> Function(ChatMessage message)? onSpeak;

  const _MessageSpeakButton({required this.message, this.onSpeak});

  @override
  State<_MessageSpeakButton> createState() => _MessageSpeakButtonState();
}

enum _SpeakState { idle, loading, playing }

class _MessageSpeakButtonState extends State<_MessageSpeakButton> {
  AudioPlayer? _player;
  StreamSubscription<void>? _completeSub;
  var _state = _SpeakState.idle;

  // Bumped on every new speak request and on every stop/cancel. A pending
  // `audioSpeak` request checks its own snapshot against this counter before
  // touching state — otherwise tapping "stop" while the network fetch for a
  // *previous* tap is still in flight (loading state) only reset the local
  // UI to idle; the in-flight future would still land afterwards, silently
  // flip the button back to playing and start audio the user had cancelled.
  var _requestId = 0;

  AudioPlayer get _audioPlayer {
    if (_player == null) {
      final player = AudioPlayer();
      _completeSub = player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _state = _SpeakState.idle);
      });
      _player = player;
    }
    return _player!;
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    _requestId++;
    await _player?.stop();
    if (mounted) setState(() => _state = _SpeakState.idle);
  }

  Future<void> _onTap() async {
    final custom = widget.onSpeak;
    if (custom != null) {
      await custom(widget.message);
      return;
    }
    if (_state != _SpeakState.idle) {
      await _stop();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.messageSpeakDisconnected)),
      );
      return;
    }
    final text = widget.message.plainText;
    if (text.isEmpty) return;
    final requestId = ++_requestId;
    setState(() => _state = _SpeakState.loading);
    try {
      final bytes = await api.audioSpeak(text);
      if (!mounted || requestId != _requestId) return;
      if (!identical(api, connection.api)) {
        setState(() => _state = _SpeakState.idle);
        return;
      }
      final player = _audioPlayer;
      await player.stop();
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = _SpeakState.playing);
      await player.play(BytesSource(bytes));
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _state = _SpeakState.idle);
      if (!identical(api, connection.api)) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.messageSpeakFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = HermesPalette.of(context).text3;
    final playing = _state == _SpeakState.playing;
    return Tooltip(
      message: playing
          ? context.l10n.messageStopSpeaking
          : context.l10n.messageSpeak,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        key: const ValueKey('msg-speak-btn'),
        borderRadius: BorderRadius.circular(6),
        hoverColor: muted.withValues(alpha: 0.08),
        highlightColor: muted.withValues(alpha: 0.10),
        splashColor: muted.withValues(alpha: 0.12),
        onTap: _onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Opacity(
              opacity: playing ? 0.9 : 0.6,
              child: _state == _SpeakState.loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: muted,
                      ),
                    )
                  : Icon(
                      playing
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_outlined,
                      size: 16,
                      color: muted,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// B8 轮次用量元数据（WebUI `ui.js` 轮次 footer `.msg-usage` /
/// `.msg-tps-inline`）：从 `ChatMessage.usage` 提取 tokens（in/out）、
/// tps、耗时与实际使用模型，拼成紧凑单行，如 "1.2k/356 tok · 42 tok/s · 3.4s"。
/// 所有字段只做真实数据透传：usage 缺失或某字段不存在时跳过该段，
/// 完全没有可用数据时返回 null（不渲染，绝不显示假数据）。
class _UsageMeta {
  _UsageMeta._();

  static String? format(ChatMessage message) {
    final usage = message.usage;
    if (usage == null || usage.isEmpty) return null;

    final segments = <String>[];

    final input = _numOf(usage, const [
      'input_tokens',
      'prompt_tokens',
      'tokens_in',
    ]);
    final output = _numOf(usage, const [
      'output_tokens',
      'completion_tokens',
      'tokens_out',
    ]);
    final total = _numOf(usage, const ['total_tokens', 'tokens']);
    if (input != null && output != null) {
      segments.add('${_count(input)}/${_count(output)} tok');
    } else if (total != null) {
      segments.add('${_count(total)} tok');
    } else if (input != null) {
      segments.add('${_count(input)} tok in');
    } else if (output != null) {
      segments.add('${_count(output)} tok out');
    }

    final tps = _numOf(usage, const [
      'tps',
      'tokens_per_second',
      'output_tokens_per_second',
    ]);
    if (tps != null && tps > 0) {
      segments.add('${tps >= 10 ? tps.round() : tps.toStringAsFixed(1)} tok/s');
    }

    final durationMs = _numOf(usage, const [
      'duration_ms',
      'elapsed_ms',
      'latency_ms',
    ]);
    final durationS = durationMs != null
        ? durationMs / 1000
        : _numOf(usage, const ['duration_s', 'elapsed_s']);
    if (durationS != null && durationS > 0) {
      segments.add(_duration(durationS));
    }

    // 注意：实际使用的模型（`used_model`/`model_name`）不在这里追加 ——
    // `responseModel()` 已经把它作为脚注的主模型字段单独展示（且已相对
    // 头部显示模型做了优先级判断），这里再拼一次会在脚注里重复模型名。
    if (segments.isEmpty) return null;
    return segments.join(' · ');
  }

  /// Wall-clock duration of the turn from the real `usage` payload, or null
  /// when the gateway did not report one. Used to render a "start → end"
  /// timestamp range (desktop `TimelineTimestamp` parity).
  static Duration? turnDuration(ChatMessage message) {
    final usage = message.usage;
    if (usage == null || usage.isEmpty) return null;
    final ms = _numOf(usage, const ['duration_ms', 'elapsed_ms', 'latency_ms']);
    if (ms != null && ms > 0) return Duration(milliseconds: ms.round());
    final s = _numOf(usage, const ['duration_s', 'elapsed_s']);
    if (s != null && s > 0) {
      return Duration(milliseconds: (s * 1000).round());
    }
    return null;
  }

  static num? _numOf(Map<String, dynamic> usage, List<String> keys) {
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

  static String _count(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.round().toString();
  }

  static String _duration(num seconds) {
    if (seconds >= 60) {
      final m = seconds ~/ 60;
      final s = (seconds - m * 60).round();
      return s > 0 ? '${m}m${s}s' : '${m}m';
    }
    if (seconds >= 10) return '${seconds.round()}s';
    return '${seconds.toStringAsFixed(1)}s';
  }

  static String _shortModel(String model) {
    var m = model;
    final slash = m.lastIndexOf('/');
    if (slash >= 0) m = m.substring(slash + 1);
    return m;
  }

  static String? responseModel(ChatMessage message) {
    final usage = message.usage;
    final raw =
        (usage?['used_model'] ??
                usage?['model_name'] ??
                usage?['model'] ??
                message.model)
            ?.toString()
            .trim();
    if (raw == null || raw.isEmpty) return null;
    final short = _shortModel(raw);
    return short.isEmpty ? null : short;
  }
}

/// 「回到话题」按钮：32px 高 pill，surface 底 + 1px border + shadow-sm
///（dark 仅边框），12px/600 text-3 文字，r-pill；hover 为 6% 浅底反馈。
class _QuestionJumpButton extends StatelessWidget {
  final VoidCallback onTap;

  const _QuestionJumpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = palette.text3;
    final hoverOverlay = (isDark ? Colors.white : Colors.black);
    return Tooltip(
      message: context.l10n.chatJumpToTopic,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        key: const ValueKey('msg-question-jump-btn'),
        borderRadius: BorderRadius.circular(HermesRadius.capsule),
        hoverColor: hoverOverlay.withValues(alpha: 0.06),
        highlightColor: hoverOverlay.withValues(alpha: 0.08),
        splashColor: hoverOverlay.withValues(alpha: 0.08),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: palette.elevated,
            borderRadius: BorderRadius.circular(HermesRadius.capsule),
            border: Border.all(color: palette.border),
            boxShadow: hermesShadow(context, HermesShadowTier.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_upward, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                context.l10n.chatJumpToTopic,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
