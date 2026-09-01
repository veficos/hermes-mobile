import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/code_highlighter.dart';

void main() {
  test('highlights a supported language into multiple colored spans', () {
    final span = CodeHighlighter.instance.highlight(
      'void main() { final x = 1; } // hi',
      'dart',
      false,
    );
    expect(span, isNotNull);
    final colors = <Color?>{};
    void walk(InlineSpan s) {
      if (s is TextSpan) {
        colors.add(s.style?.color);
        s.children?.forEach(walk);
      }
    }

    walk(span!);
    expect(colors.length, greaterThan(1));
  });

  test('resolves aliases and rejects unknown languages', () {
    expect(CodeHighlighter.instance.supports('ts'), isTrue);
    expect(CodeHighlighter.instance.supports('py'), isTrue);
    expect(CodeHighlighter.instance.supports('brainfuck'), isFalse);
    expect(CodeHighlighter.instance.highlight('x', 'brainfuck', false), isNull);
  });
}
