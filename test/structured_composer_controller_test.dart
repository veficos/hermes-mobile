import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/structured_composer_controller.dart';

void main() {
  test('structured references keep native editable offsets', () {
    final controller = StructuredComposerController(
      text: 'open @file:`lib/main.dart` now',
    );
    addTearDown(controller.dispose);

    expect(controller.value.text, 'open @file:`lib/main.dart` now');
    expect(controller.text, 'open @file:`lib/main.dart` now');
    expect(controller.nodes.single.source, '@file:`lib/main.dart`');
    expect(controller.selection.baseOffset, controller.text.length);
  });

  test('native edits and selections stay in the same coordinate system', () {
    final controller = StructuredComposerController(
      text: 'a @file:`one.dart` @url:`https://example.com` z',
    );
    addTearDown(controller.dispose);
    final source = controller.value.text;
    final editAt = source.indexOf('one.dart');

    controller.value = TextEditingValue(
      text: source.replaceRange(editAt, editAt + 3, 'two'),
      selection: TextSelection.collapsed(offset: editAt + 3),
    );

    expect(controller.text, 'a @file:`two.dart` @url:`https://example.com` z');
    expect(controller.value.text, controller.text);
    expect(controller.selection.baseOffset, editAt + 3);
  });

  test('IME pre-edit remains literal until composition commits', () {
    final controller = StructuredComposerController(text: '/help ');
    addTearDown(controller.dispose);
    final display = '${controller.value.text}你';

    controller.value = TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
      composing: TextRange(start: display.length - 1, end: display.length),
    );
    expect(controller.value.composing, isNot(TextRange.empty));

    controller.value = TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
    expect(controller.text, '/help 你');
  });

  test('structured undo restores the canonical value', () {
    final controller = StructuredComposerController(text: 'before');
    addTearDown(controller.dispose);
    controller.text = 'after @folder:`lib`';

    expect(controller.undoStructuredEdit(), isTrue);
    expect(controller.text, 'before');
  });
}
