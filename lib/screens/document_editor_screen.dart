library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/json_document.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_confirm_dialog.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

/// In-memory code/JSON editor for generated artifacts. The caller owns
/// persistence (usually a composer handoff), matching Desktop semantics.
class DocumentEditorScreen extends StatefulWidget {
  const DocumentEditorScreen({
    super.key,
    required this.title,
    required this.initialValue,
    this.json = false,
  });

  final String title;
  final String initialValue;
  final bool json;

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  bool get _dirty => _controller.text != widget.initialValue;
  bool _confirmingExit = false;
  bool _allowExit = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _format() {
    try {
      final text = JsonDocument.parse(_controller.text).formatted();
      setState(() {
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      });
    } catch (error) {
      showHermesErrorSnackBar(
        context,
        error,
        fallback: context.l10n.configInvalidJson('$error'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowExit || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _confirmingExit) return;
        _confirmingExit = true;
        final discard = await showHermesConfirmDialog(
          context: context,
          title: context.l10n.fileEditorDiscardQuestion,
          message: context.l10n.fileEditorDiscardDescription,
          confirmLabel: context.l10n.fileEditorDiscard,
          cancelLabel: context.l10n.fileEditorKeepEditing,
          destructive: true,
        );
        _confirmingExit = false;
        if (!discard || !mounted) return;
        setState(() => _allowExit = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      },
      child: HermesPageScaffold(
        title: _dirty ? '● ${widget.title}' : widget.title,
        actions: [
          if (widget.json)
            IconButton(
              tooltip: context.l10n.configFullJson,
              onPressed: _format,
              icon: const Icon(Icons.data_object),
            ),
          IconButton(
            tooltip: context.l10n.commonCopy,
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: _controller.text)),
            icon: const Icon(Icons.copy_outlined),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(context.l10n.commonDone),
          ),
        ],
        body: ColoredBox(
          color: HermesPalette.of(context).codeBg,
          child: TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: HermesType.code.copyWith(height: 1.5),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
    );
  }
}
