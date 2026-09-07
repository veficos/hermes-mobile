library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/content/compact_markdown.dart';
import '../core/composer_reference_completion.dart';
import '../core/composer_tokens.dart';
import '../core/stores/command_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_composer.dart';

/// Phone-native counterpart of Desktop's floating composer. This route edits
/// the exact same controller and attachment list as the docked composer, so
/// dismissing it never creates a second draft or loses structured references.
class FocusComposerScreen extends StatefulWidget {
  final TextEditingController controller;
  final List<ComposerAttachment> attachments;
  final ValueChanged<ComposerAttachment>? onRemoveAttachment;
  final ValueChanged<String> onSend;
  final bool readOnly;
  final String? modelLabel;
  final String? profileLabel;

  const FocusComposerScreen({
    super.key,
    required this.controller,
    required this.attachments,
    this.onRemoveAttachment,
    required this.onSend,
    this.readOnly = false,
    this.modelLabel,
    this.profileLabel,
  });

  @override
  State<FocusComposerScreen> createState() => _FocusComposerScreenState();
}

class _FocusComposerScreenState extends State<FocusComposerScreen> {
  bool _preview = false;
  Timer? _completionDebounce;
  ComposerReferenceQuery? _referenceQuery;
  ({int start, int end, String query})? _emojiQuery;
  List<ComposerReferenceSuggestion> _references = const [];
  List<ComposerEmojiSuggestion> _emoji = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleCompletions);
  }

  @override
  void dispose() {
    _completionDebounce?.cancel();
    widget.controller.removeListener(_scheduleCompletions);
    super.dispose();
  }

  void _scheduleCompletions() {
    _completionDebounce?.cancel();
    _completionDebounce = Timer(
      const Duration(milliseconds: 180),
      _refreshCompletions,
    );
  }

  Future<void> _refreshCompletions() async {
    final value = widget.controller.value;
    final caret = value.selection.isValid
        ? value.selection.extentOffset
        : value.text.length;
    final emoji = composerEmojiQuery(value.text, caret: caret);
    if (emoji != null) {
      if (!mounted) return;
      setState(() {
        _emojiQuery = emoji;
        _emoji = composerEmojiSuggestions(emoji.query);
        _referenceQuery = null;
        _references = const [];
      });
      return;
    }
    final query = composerReferenceQuery(value.text, caret: caret);
    if (query == null) {
      if (mounted && (_references.isNotEmpty || _emoji.isNotEmpty)) {
        setState(() {
          _referenceQuery = null;
          _emojiQuery = null;
          _references = const [];
          _emoji = const [];
        });
      }
      return;
    }
    var suggestions = query.isTyped
        ? <ComposerReferenceSuggestion>[]
        : composerReferenceStarters(query.query);
    if (query.raw.length > 1) {
      final session = context.read<SessionStore>();
      final paths = await context.read<CommandStore>().completePath(
        query.raw,
        sessionId: session.durableId,
        cwd: session.info?.cwd,
      );
      if (!mounted || widget.controller.text != value.text) return;
      suggestions = paths
          .map((item) => referenceSuggestionFromPath(item, query))
          .toList(growable: false);
      if (suggestions.isEmpty && !query.isTyped) {
        suggestions = composerReferenceStarters(query.query);
      }
    }
    setState(() {
      _referenceQuery = query;
      _references = suggestions;
      _emojiQuery = null;
      _emoji = const [];
    });
  }

  void _applyReference(ComposerReferenceSuggestion suggestion) {
    final query = _referenceQuery;
    if (query == null) return;
    final next = replaceComposerReference(
      widget.controller.text,
      query,
      suggestion,
      descend: suggestion.isContainer && !suggestion.insertText.endsWith(':'),
    );
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() => _references = const []);
    if (suggestion.isContainer) unawaited(_refreshCompletions());
  }

  void _applyEmoji(ComposerEmojiSuggestion suggestion) {
    final query = _emojiQuery;
    if (query == null) return;
    final next = widget.controller.text.replaceRange(
      query.start,
      query.end,
      suggestion.emoji,
    );
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: query.start + suggestion.emoji.length,
      ),
    );
    setState(() => _emoji = const []);
  }

  void _send() {
    final text = widget.controller.text;
    if (widget.readOnly ||
        (text.trim().isEmpty && widget.attachments.isEmpty)) {
      return;
    }
    Navigator.of(context).pop();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.l10n.commonClose,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        title: Text(context.l10n.chatEditMessageHint),
        actions: [
          IconButton(
            tooltip: context.l10n.previewTitle,
            onPressed: () => setState(() => _preview = !_preview),
            icon: Icon(_preview ? Icons.edit_outlined : Icons.preview_outlined),
          ),
          TextButton(
            onPressed: widget.readOnly ? null : _send,
            child: Text(context.l10n.commonSend),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.modelLabel != null || widget.profileLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  [widget.modelLabel, widget.profileLabel]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(fontSize: 12, color: palette.text3),
                ),
              ),
            if (widget.attachments.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, index) => Chip(
                    avatar: Icon(widget.attachments[index].icon, size: 16),
                    label: Text(widget.attachments[index].label),
                    onDeleted: widget.readOnly ||
                            widget.onRemoveAttachment == null
                        ? null
                        : () => widget.onRemoveAttachment!(
                            widget.attachments[index],
                          ),
                  ),
                ),
              ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (_, value, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Text(
                  '${value.text.characters.length} chars · ${_estimateTokens(value.text)} tokens · ${parseComposerTokens(value.text).where((token) => token.atomic).length} refs',
                  style: TextStyle(fontSize: 11, color: palette.text3),
                ),
              ),
            ),
            const Divider(height: 1),
            if (!_preview && (_references.isNotEmpty || _emoji.isNotEmpty))
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in _references.take(8))
                      ListTile(
                        dense: true,
                        leading: Icon(
                          item.isContainer
                              ? Icons.folder_outlined
                              : Icons.alternate_email,
                        ),
                        title: Text(item.display),
                        subtitle: item.description == null
                            ? null
                            : Text(item.description!, maxLines: 1),
                        onTap: () => _applyReference(item),
                      ),
                    for (final item in _emoji)
                      ListTile(
                        dense: true,
                        leading: Text(
                          item.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(':${item.shortcode}:'),
                        onTap: () => _applyEmoji(item),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _preview
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder: (_, value, _) => CompactMarkdown(
                          text: value.text,
                          selectable: true,
                        ),
                      ),
                    )
                  : TextField(
                      key: const ValueKey('focus-composer-input'),
                      controller: widget.controller,
                      autofocus: true,
                      readOnly: widget.readOnly,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 17, height: 1.55),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(18),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _estimateTokens(String text) =>
      text.trim().isEmpty ? 0 : (text.characters.length / 3.5).ceil();
}
