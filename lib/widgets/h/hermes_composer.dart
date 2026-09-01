/// HermesComposer — desktop-parity chat input bar
///
/// Matches the hermes-agent desktop composer design:
/// - Single rounded container with text input + circular send button
/// - Integrated toolbar row: attachment buttons + selector pills
///   (personality, workspace, model, difficulty, tools config)
/// - Simplified bottom bar for essential controls
/// - Draft auto-save/restore
///
/// The tools-config pill (`toolsLabel`/`onToolsTap`) opens ChatScreen's own
/// `_showToolsConfig` bottom sheet, which understands session-scoped vs.
/// global CLI toolsets — a richer model than this widget tracks, so the
/// sheet lives there rather than as a reusable widget in this file.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/composer_tokens.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/chat_enter_to_send.dart';

// =====================================================================
// Data models
// =====================================================================

/// Compact cumulative context-usage label for the composer (WebUI A17
/// `_syncCtxIndicator` parity), e.g. `12.3k ctx`. Pure formatting — the
/// caller passes the real accumulated token count from the chat store.
String formatCtxUsageLabel(int tokens) {
  if (tokens >= 1000000) {
    return '${(tokens / 1000000).toStringAsFixed(1)}M ctx';
  }
  if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k ctx';
  return '$tokens ctx';
}

/// Attachment types supported in the composer (mirrors hermes-agent desktop).
enum ComposerAttachmentKind { file, folder, image, url, snippet }

/// Simple data class for a composer attachment.
///
/// [path] is a server-side reference (already uploaded). [localPath] is a
/// staged local file that still needs to be uploaded at send time (WebUI
/// `S.pendingFiles` semantics: stage in the tray, upload on submit).
class ComposerAttachment {
  /// Identity of this specific add/remove occurrence. Two chips may point at
  /// the same path but must not share async preview/upload completion state.
  final String? occurrenceId;
  final ComposerAttachmentKind kind;
  final String label;
  final String? path;
  final String? localPath;
  final String? url;
  final String? snippetText;

  const ComposerAttachment({
    required this.kind,
    required this.label,
    this.occurrenceId,
    this.path,
    this.localPath,
    this.url,
    this.snippetText,
  });

  ComposerAttachment copyWith({
    String? occurrenceId,
    String? path,
    String? localPath,
  }) => ComposerAttachment(
    occurrenceId: occurrenceId ?? this.occurrenceId,
    kind: kind,
    label: label,
    path: path ?? this.path,
    localPath: localPath ?? this.localPath,
    url: url,
    snippetText: snippetText,
  );

  /// True once the attachment points at a server-side path.
  bool get isUploaded => path != null && path!.isNotEmpty;

  IconData get icon {
    switch (kind) {
      case ComposerAttachmentKind.file:
        return Icons.insert_drive_file_outlined;
      case ComposerAttachmentKind.folder:
        return Icons.folder_outlined;
      case ComposerAttachmentKind.image:
        return Icons.image_outlined;
      case ComposerAttachmentKind.url:
        return Icons.link_outlined;
      case ComposerAttachmentKind.snippet:
        return Icons.notes;
    }
  }
}

// =====================================================================
// Main Composer Widget
// =====================================================================

class HermesComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool busy;
  final bool readOnly;
  final String? modelLabel;
  final ValueChanged<String> onSend;
  final VoidCallback? onStop;

  /// WebUI `getComposerPrimaryAction` parity: while busy with draft text the
  /// primary button steers the running turn instead of queuing/stopping.
  final ValueChanged<String>? onSteer;
  final VoidCallback? onModelTap;
  final VoidCallback? onSpeak;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final Widget? contextMenu;

  /// Desktop-parity: personality pill label + callback
  final String? personalityLabel;
  final VoidCallback? onPersonalityTap;

  /// Desktop-parity: workspace pill label + callback
  final String? workspaceLabel;
  final VoidCallback? onWorkspaceTap;

  /// Desktop-parity: difficulty pill label + callback
  final String? difficultyLabel;
  final VoidCallback? onDifficultyTap;

  /// Desktop-parity: tools config button label + callback
  final String? toolsLabel;
  final bool toolsSelected;
  final VoidCallback? onToolsTap;

  /// Session-level autonomous execution mode. Null hides the control when the
  /// connected backend does not expose the setting.
  final bool? yoloEnabled;
  final VoidCallback? onYoloTap;

  /// WebUI `providerQuotaChip` parity: ambient provider quota/usage label
  /// (e.g. `$3.50` / `73%`). Rendered only when the backend reported real
  /// quota data; [onQuotaTap] refreshes / opens details.
  final String? quotaLabel;
  final VoidCallback? onQuotaTap;

  /// Left-side action buttons (attachment, image, link, etc.)
  final List<Widget> leadingActions;

  /// Optional overlay rendered above the input when non-empty (slash /
  /// mention autocomplete).
  final Widget? suggestions;
  final KeyEventResult Function(FocusNode, KeyEvent)? onSuggestionKeyEvent;

  /// Desktop-parity: attachments row above the text field
  final List<ComposerAttachment> attachments;
  final ValueChanged<List<ComposerAttachment>>? onAttachmentsChanged;

  /// Extra icon buttons rendered in the footer between the emoji toggle and
  /// the send button (queue / voice / TTS / more menu live here).
  final List<Widget> footerActions;

  /// Compact cumulative context-usage label (e.g. `12.3k ctx`) rendered at
  /// the composer card's top-right. Null when the session has no real usage
  /// data — the indicator is not rendered at all (no fake numbers).
  final String? ctxUsageLabel;

  const HermesComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.busy = false,
    this.readOnly = false,
    this.modelLabel,
    this.onStop,
    this.onSteer,
    this.onModelTap,
    this.onSpeak,
    this.onUndo,
    this.onRedo,
    this.contextMenu,
    this.personalityLabel,
    this.onPersonalityTap,
    this.workspaceLabel,
    this.onWorkspaceTap,
    this.difficultyLabel,
    this.onDifficultyTap,
    this.toolsLabel,
    this.toolsSelected = false,
    this.onToolsTap,
    this.yoloEnabled,
    this.onYoloTap,
    this.quotaLabel,
    this.onQuotaTap,
    this.leadingActions = const [],
    this.suggestions,
    this.onSuggestionKeyEvent,
    this.attachments = const [],
    this.onAttachmentsChanged,
    this.footerActions = const [],
    this.ctxUsageLabel,
  });

  @override
  State<HermesComposer> createState() => _HermesComposerState();
}

class _HermesComposerState extends State<HermesComposer> {
  bool _canSend = false;
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _focused = false;
  bool _emojiOpen = false;
  bool _mobileEnterSends = true;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _canSend = _hasDraft;
    _loadEnterMode();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        _focused = _focusNode.hasFocus;
      });
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() => _canSend = _hasDraft);
    }
  }

  bool get _hasDraft =>
      widget.controller.text.trim().isNotEmpty || widget.attachments.isNotEmpty;

  @override
  void didUpdateWidget(covariant HermesComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) _focusNode.dispose();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.attachments.length != widget.attachments.length ||
        oldWidget.controller != widget.controller) {
      _canSend = _hasDraft;
    }
  }

  /// Insert an emoji as plain text at the cursor (selection is replaced;
  /// an invalid/lost selection appends at the end) and keep editing.
  void _insertEmoji(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _focusNode.requestFocus();
  }

  /// WebUI `getComposerPrimaryAction` parity (ui.js:7831):
  /// - idle + text      → send
  /// - busy  + text     → steer the running turn (default busy mode)
  /// - busy  + no text  → stop the running turn
  void _onSendTap() {
    if (widget.readOnly) return;
    // Let the IME commit the active composing range first (e.g. Chinese
    // pinyin). Sending a pre-edit buffer would submit incomplete text.
    final composing = widget.controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    final text = widget.controller.text.trim();
    if (widget.busy) {
      if ((text.isNotEmpty || widget.attachments.isNotEmpty) &&
          widget.onSteer != null) {
        HapticFeedback.lightImpact();
        widget.controller.clear();
        widget.onSteer!(text);
      } else {
        HapticFeedback.mediumImpact();
        widget.onStop?.call();
      }
      return;
    }
    if (text.isEmpty && widget.attachments.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.controller.clear();
    widget.onSend(text);
  }

  void _toggleMobileEnterMode() {
    setState(() => _mobileEnterSends = !_mobileEnterSends);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('hm_composer_enter_sends', _mobileEnterSends),
    );
  }

  Future<void> _loadEnterMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () =>
          _mobileEnterSends = prefs.getBool('hm_composer_enter_sends') ?? true,
    );
  }

  /// Enter-to-send is a hardware-keyboard affordance; on touch platforms the
  /// soft keyboard owns Enter (newline), so the [Focus] key-event interceptor
  /// is skipped entirely and the child renders unwrapped.
  Widget _wrapWithEnterToSend(Widget child) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia) {
      return child;
    }
    return Focus(
      onKeyEvent: (node, event) {
        final suggestionResult = widget.onSuggestionKeyEvent?.call(node, event);
        if (suggestionResult == KeyEventResult.handled) {
          return KeyEventResult.handled;
        }
        final composing = widget.controller.value.composing;
        if (composing.isValid && !composing.isCollapsed) {
          return KeyEventResult.ignored;
        }
        return handleChatEnterToSend(
          node,
          event,
          _onSendTap,
          enabled: !widget.readOnly,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final platform = Theme.of(context).platform;
    final mobilePlatform =
        platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;
    // §6.6：r-xl 16 容器、surface 底 + 1px border；聚焦 border=accent +
    // shadow-md。
    final borderColor = palette.border;
    final accent = palette.accent;
    final muted = palette.text3;
    final showAttachments = widget.attachments.isNotEmpty;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    final sendButton = _SendButton(
      key: const ValueKey('composer-send'),
      busy: widget.busy,
      busyWillSteer: widget.busy && _canSend && widget.onSteer != null,
      enabled: !widget.readOnly && _canSend,
      accent: accent,
      onTap: _onSendTap,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, keyboardInset > 0 ? 6 : 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Suggestions overlay (slash / @mention autocomplete) ──
            if (widget.suggestions != null) widget.suggestions!,
            // ── Composer tools row: every tool (selectors, quota, emoji
            // toggle, undo/redo, leading/footer actions) lives above the
            // edit box at every width — prototype parity: `.pillrow` /
            // `.attachrow` sit above `.composerbox`, never inside it. ──
            _buildToolsRow(context, mobilePlatform: mobilePlatform),
            if (_emojiOpen) _buildEmojiPanel(context),
            if (showAttachments)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: _AttachmentsRow(
                  attachments: widget.attachments,
                  onChanged: widget.onAttachmentsChanged,
                ),
              ),
            // ── Main composer input surface (edit box): mention chips,
            // the text field and the send button only. ──
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: palette.codeBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _focused ? accent : borderColor),
                boxShadow: _focused
                    ? hermesShadow(context, HermesShadowTier.md)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      final tokens = parseComposerTokens(
                        value.text,
                      ).where((token) => token.atomic).toList();
                      if (tokens.isEmpty) return const SizedBox.shrink();
                      return SizedBox(
                        height: 38,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          scrollDirection: Axis.horizontal,
                          itemCount: tokens.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final token = tokens[index];
                            return InputChip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(switch (token.kind) {
                                ComposerTokenKind.file =>
                                  Icons.description_outlined,
                                ComposerTokenKind.folder =>
                                  Icons.folder_outlined,
                                ComposerTokenKind.image => Icons.image_outlined,
                                ComposerTokenKind.session =>
                                  Icons.forum_outlined,
                                ComposerTokenKind.slash => Icons.terminal,
                                _ => Icons.link,
                              }, size: 15),
                              label: Text(
                                token.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onDeleted: widget.readOnly
                                  ? null
                                  : () {
                                      final source = widget.controller.text;
                                      widget.controller.value =
                                          TextEditingValue(
                                            text: source.replaceRange(
                                              token.start,
                                              token.end,
                                              '',
                                            ),
                                            selection: TextSelection.collapsed(
                                              offset: token.start,
                                            ),
                                          );
                                    },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  // ── Text field + send button (prototype `.composerbox`) ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _wrapWithEnterToSend(
                          TextField(
                            key: const ValueKey('composer-input'),
                            controller: widget.controller,
                            focusNode: _focusNode,
                            readOnly: widget.readOnly,
                            enabled: !widget.readOnly,
                            minLines: 1,
                            maxLines: keyboardInset > 0 ? 5 : 8,
                            textInputAction: mobilePlatform && _mobileEnterSends
                                ? TextInputAction.send
                                : TextInputAction.newline,
                            onSubmitted: mobilePlatform && _mobileEnterSends
                                ? (_) => _onSendTap()
                                : null,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 16,
                              height: 1.5,
                            ),
                            strutStyle: const StrutStyle(
                              fontSize: 16,
                              height: 1.5,
                              forceStrutHeight: true,
                            ),
                            textAlignVertical: TextAlignVertical.center,
                            contextMenuBuilder: (context, editableTextState) {
                              final items = <ContextMenuButtonItem>[
                                ...editableTextState.contextMenuButtonItems,
                                if (widget.onUndo != null)
                                  ContextMenuButtonItem(
                                    label: context.l10n.composerUndoInput,
                                    onPressed: () {
                                      widget.onUndo!.call();
                                      editableTextState.hideToolbar();
                                    },
                                  ),
                                if (widget.onRedo != null)
                                  ContextMenuButtonItem(
                                    label: context.l10n.composerRedoInput,
                                    onPressed: () {
                                      widget.onRedo!.call();
                                      editableTextState.hideToolbar();
                                    },
                                  ),
                              ];
                              return AdaptiveTextSelectionToolbar.buttonItems(
                                anchors: editableTextState.contextMenuAnchors,
                                buttonItems: items,
                              );
                            },
                            decoration: InputDecoration(
                              hintText: widget.readOnly
                                  ? context.l10n.composerReadOnly
                                  : context.l10n.composerMessageHint,
                              hintStyle: TextStyle(
                                color: muted,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                9,
                                8,
                                9,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: sendButton,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildInfoLine(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPrimarySelectorButtons(BuildContext context) => [
    if (widget.onPersonalityTap != null || widget.personalityLabel != null)
      _SelectorIconButton(
        icon: Icons.person_outline,
        tooltip: widget.personalityLabel?.isNotEmpty == true
            ? context.l10n.composerProfileValue(widget.personalityLabel!)
            : context.l10n.composerSelectProfile,
        onTap: widget.onPersonalityTap,
      ),
    if (widget.onWorkspaceTap != null || widget.workspaceLabel != null)
      _SelectorIconButton(
        icon: Icons.folder_outlined,
        tooltip: widget.workspaceLabel?.isNotEmpty == true
            ? context.l10n.composerWorkspaceValue(widget.workspaceLabel!)
            : context.l10n.composerSelectWorkspace,
        onTap: widget.onWorkspaceTap,
      ),
    if (widget.onModelTap != null || widget.modelLabel != null)
      _SelectorIconButton(
        icon: Icons.smart_toy_outlined,
        tooltip: widget.modelLabel?.isNotEmpty == true
            ? context.l10n.composerModelValue(widget.modelLabel!)
            : context.l10n.composerSelectModel,
        onTap: widget.onModelTap,
      ),
    if (widget.onDifficultyTap != null || widget.difficultyLabel != null)
      _SelectorIconButton(
        icon: Icons.timer_outlined,
        tooltip: context.l10n.composerDifficultyValue(
          widget.difficultyLabel ?? context.l10n.commonDefault,
        ),
        onTap: widget.onDifficultyTap,
      ),
    if (widget.yoloEnabled != null)
      _SelectorIconButton(
        icon: Icons.flash_on_outlined,
        tooltip: context.l10n.composerYoloModeValue(
          widget.yoloEnabled!
              ? context.l10n.composerEnabled
              : context.l10n.composerDisabled,
        ),
        onTap: widget.onYoloTap,
        selected: widget.yoloEnabled!,
        showStatusDot: widget.yoloEnabled!,
      ),
    if (widget.onToolsTap != null)
      _SelectorIconButton(
        icon: Icons.handyman_outlined,
        tooltip: widget.toolsLabel?.isNotEmpty == true
            ? widget.toolsLabel!
            : context.l10n.composerConfigureToolsets,
        onTap: widget.onToolsTap,
        selected: widget.toolsSelected,
      ),
  ];

  /// Unified composer tools row: every "tool" — leading actions, the
  /// persona/workspace/model/difficulty/yolo/toolset selectors, the quota
  /// pill, the emoji toggle, the undo/redo menu and any footer actions —
  /// renders here, above the edit box, at every screen width. Prototype
  /// parity: `docs/mobile-ui-prototype.html`'s `.pillrow` sits above
  /// `.composerbox`, never inside it; it never wraps to a second line,
  /// only scrolls horizontally, so this does the same instead of the old
  /// per-breakpoint "+"-panel / stacked-row split.
  Widget _buildToolsRow(BuildContext context, {required bool mobilePlatform}) {
    final palette = HermesPalette.of(context);
    final muted = palette.text3;
    final hasLeading = widget.leadingActions.isNotEmpty;
    final primarySelectors = _buildPrimarySelectorButtons(context);

    final children = <Widget>[
      ...widget.leadingActions,
      if (hasLeading && primarySelectors.isNotEmpty)
        Container(
          width: 1,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: palette.border,
        ),
      ...primarySelectors,
      // Provider quota chip (WebUI providerQuotaChip): rendered only with
      // real backend quota data.
      if (widget.quotaLabel != null)
        _SelectorPill(
          icon: Icons.speed_outlined,
          label: widget.quotaLabel!,
          onTap: widget.onQuotaTap,
        ),
      if (!widget.readOnly)
        _SelectorIconButton(
          icon: _emojiOpen
              ? Icons.emoji_emotions
              : Icons.emoji_emotions_outlined,
          tooltip: _emojiOpen
              ? context.l10n.composerCloseEmojiPanel
              : context.l10n.composerEmoji,
          onTap: () => setState(() => _emojiOpen = !_emojiOpen),
          selected: _emojiOpen,
        ),
      if (widget.onUndo != null || widget.onRedo != null)
        PopupMenuButton<String>(
          tooltip: context.l10n.composerEditorActions,
          icon: const Icon(Icons.more_horiz, size: 20),
          onSelected: (value) {
            if (value == 'undo') widget.onUndo?.call();
            if (value == 'redo') widget.onRedo?.call();
            if (value == 'clear') widget.controller.clear();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'undo',
              enabled: widget.onUndo != null,
              child: Text(context.l10n.composerUndoInput),
            ),
            PopupMenuItem(
              value: 'redo',
              enabled: widget.onRedo != null,
              child: Text(context.l10n.composerRedoInput),
            ),
            PopupMenuItem(
              value: 'clear',
              child: Text(context.l10n.composerClearInput),
            ),
          ],
        ),
      ...widget.footerActions,
      if (mobilePlatform)
        IconButton(
          tooltip: _mobileEnterSends
              ? context.l10n.composerEnterSendsTooltip
              : context.l10n.composerEnterNewlineTooltip,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Icon(
            _mobileEnterSends ? Icons.keyboard_return : Icons.wrap_text,
            color: muted.withValues(alpha: 0.75),
          ),
          onPressed: _toggleMobileEnterMode,
        ),
    ];

    if (children.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 1, right: 1, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoLine(BuildContext context) {
    final palette = HermesPalette.of(context);
    final parts = <String>[
      if (widget.modelLabel?.isNotEmpty == true) widget.modelLabel!,
      if (widget.personalityLabel?.isNotEmpty == true) widget.personalityLabel!,
      if (widget.ctxUsageLabel?.isNotEmpty == true) widget.ctxUsageLabel!,
      _mobileEnterSends
          ? context.l10n.composerEnterSends
          : context.l10n.composerEnterNewline,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          parts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: palette.text3,
          ),
        ),
      ),
    );
  }

  /// Inline emoji panel: a grid of common emojis inserted as plain text at
  /// the composer cursor. Stays open for multiple inserts; closed via the
  /// toggle button or the close icon.
  Widget _buildEmojiPanel(BuildContext context) {
    final palette = HermesPalette.of(context);
    final muted = palette.text3;
    return Container(
      height: 168,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Text(
                  context.l10n.composerEmoji,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.l10n.composerCloseEmojiPanel,
                  visualDensity: VisualDensity.compact,
                  iconSize: 14,
                  onPressed: () => setState(() => _emojiOpen = false),
                  icon: Icon(Icons.close, color: muted),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 8,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final emoji in _commonEmojis)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _insertEmoji(emoji),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _commonEmojis = [
    '😀',
    '😄',
    '😂',
    '🤣',
    '😊',
    '😍',
    '😘',
    '🤔',
    '😅',
    '😉',
    '😎',
    '🥳',
    '😴',
    '😭',
    '😱',
    '🤯',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '🤝',
    '✌️',
    '👌',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🔥',
    '✨',
    '🎉',
    '🚀',
    '⭐',
    '⚡',
    '💡',
    '✅',
    '❌',
    '⚠️',
    '❓',
    '❗',
    '💬',
    '📝',
    '🔍',
    '🛠️',
    '🐛',
    '💻',
    '📱',
    '📦',
    '🔗',
    '📌',
    '🕐',
    '🍀',
  ];
}

// =====================================================================
// Selector controls (toolbar items)
// =====================================================================

class _SelectorIconButton extends StatelessWidget {
  const _SelectorIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.showStatusDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  final bool showStatusDot;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final foreground = selected
        ? colors.primary
        : colors.onSurfaceVariant.withValues(alpha: enabled ? 0.75 : 0.38);
    return Semantics(
      button: true,
      label: tooltip,
      selected: selected,
      enabled: enabled,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Material(
              color: selected
                  ? colors.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              shape: CircleBorder(
                side: selected
                    ? BorderSide(color: colors.primary, width: 1.5)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                hoverColor: colors.onSurface.withValues(alpha: 0.06),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, size: 18, color: foreground),
                      if (showStatusDot)
                        Positioned(
                          right: 3,
                          top: 3,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SelectorPill({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = palette.text3;
    final accentBg = palette.accentBg;
    // §5.4 Ghost hover：rgba 黑/白 6% 底。
    final hoverBg = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.06,
    );

    // design-system.md §6.6：选择器 pill 高 28、px12、r-pill。
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
          hoverColor: hoverBg,
          splashColor: accentBg,
          highlightColor: accentBg,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: muted),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: label, child: child);
  }
}

// =====================================================================
// Circular send button
// =====================================================================

class _SendButton extends StatefulWidget {
  final bool busy;

  /// Busy with draft text: the primary action steers the running turn
  /// (WebUI default busy mode) instead of stopping it.
  final bool busyWillSteer;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  const _SendButton({
    super.key,
    required this.busy,
    required this.busyWillSteer,
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = widget.enabled || widget.busy;
    // design-system.md §6.6：34px accent 实底圆形发送钮 + 白箭头；busy +
    // draft → steer（罗盘）；busy + 无 draft → stop（error 实底）；
    // disabled → 35% 透明度（§6.1）。
    final bg = widget.busy && !widget.busyWillSteer
        ? hermesSemantic(context, HermesSemantic.red, HermesSemanticDark.red)
        : widget.accent;
    final icon = widget.busy
        ? (widget.busyWillSteer ? Icons.explore_outlined : Icons.stop)
        : Icons.arrow_upward;

    return Listener(
      onPointerDown: active ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        // §6.1：pressed → 缩放 0.97
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: active ? 1 : 0.35,
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            // §5.3：深色主题不使用投影。
            elevation: active && !widget.busy && !isDark ? 2 : 0,
            child: InkWell(
              onTap: active ? widget.onTap : null,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Attachment chips row
// =====================================================================

class _AttachmentsRow extends StatelessWidget {
  final List<ComposerAttachment> attachments;
  final ValueChanged<List<ComposerAttachment>>? onChanged;

  const _AttachmentsRow({required this.attachments, required this.onChanged});

  void _removeAttachment(int index) {
    final newList = List<ComposerAttachment>.from(attachments);
    newList.removeAt(index);
    onChanged?.call(newList);
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final chipBg = palette.codeBg;
    final chipBorder = palette.border;
    final chipText = palette.text3;
    BoxDecoration chipDecoration() => BoxDecoration(
      color: chipBg,
      border: Border.all(color: chipBorder),
      borderRadius: BorderRadius.circular(999),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...attachments.asMap().entries.map((entry) {
            final index = entry.key;
            final att = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: chipDecoration(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(att.icon, size: 14, color: chipText),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      att.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: chipText),
                    ),
                  ),
                  if (att.kind == ComposerAttachmentKind.folder) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: context.l10n.composerFolderNotUploaded,
                      child: Icon(
                        Icons.link_off,
                        size: 12,
                        color: chipText.withValues(alpha: 0.7),
                      ),
                    ),
                  ] else if (!att.isUploaded && att.localPath != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 12,
                      color: chipText.withValues(alpha: 0.7),
                    ),
                  ],
                  IconButton(
                    tooltip: context.l10n.composerRemoveAttachment(att.label),
                    onPressed: onChanged == null
                        ? null
                        : () => _removeAttachment(index),
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.close,
                      color: chipText.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

