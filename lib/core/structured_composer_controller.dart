library;

import 'package:flutter/material.dart';

import 'composer_tokens.dart';

class StructuredComposerNode {
  final ComposerTokenKind kind;
  final String source;

  const StructuredComposerNode(this.kind, this.source);
}

/// Plain-text editing controller with structured-token metadata.
///
/// The editable value intentionally remains the exact gateway text. Older
/// versions replaced each structured token with U+FFFC and painted a
/// WidgetSpan chip. That made [text], [value.text], selection offsets and the
/// browser IME use different coordinate systems, which displaced the caret and
/// composing text on Flutter Web. Token presentation now lives outside the
/// RenderEditable contract; this controller only provides metadata and undo.
class StructuredComposerController extends TextEditingController {
  final List<String> _undo = <String>[];
  final List<String> _redo = <String>[];
  bool _internal = false;

  StructuredComposerController({String? text}) : super() {
    setCanonicalText(text ?? '', recordUndo: false);
  }

  List<StructuredComposerNode> get nodes => parseComposerTokens(text)
      .where((token) => token.atomic)
      .map((token) => StructuredComposerNode(token.kind, token.value))
      .toList(growable: false);

  void setCanonicalText(
    String next, {
    TextSelection? selection,
    bool recordUndo = true,
  }) {
    if (recordUndo && next != text) _remember(text);
    _internal = true;
    value = TextEditingValue(
      text: next,
      selection: selection ?? TextSelection.collapsed(offset: next.length),
    );
    _internal = false;
  }

  @override
  set text(String next) => setCanonicalText(next);

  @override
  set value(TextEditingValue next) {
    if (!_internal && next.text != super.text) _remember(super.text);
    super.value = next;
  }

  bool undoStructuredEdit() {
    if (_undo.isEmpty) return false;
    _redo.add(text);
    final previous = _undo.removeLast();
    setCanonicalText(previous, recordUndo: false);
    return true;
  }

  bool redoStructuredEdit() {
    if (_redo.isEmpty) return false;
    _undo.add(text);
    final next = _redo.removeLast();
    setCanonicalText(next, recordUndo: false);
    return true;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void _remember(String source) {
    if (_undo.isNotEmpty && _undo.last == source) return;
    _undo.add(source);
    _redo.clear();
    if (_undo.length > 100) _undo.removeAt(0);
  }
}
