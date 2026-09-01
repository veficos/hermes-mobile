import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/code_highlighter.dart';

void main() {
  setUp(() {
    CodeHighlighter.instance.clearCache();
    HermesSyntaxHighlighter.clearCache();
  });
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

  test('reuses highlighted spans and keeps the cache bounded', () {
    final first = CodeHighlighter.instance.highlight(
      'final x = 1;',
      'dart',
      false,
    );
    final second = CodeHighlighter.instance.highlight(
      'final x = 1;',
      'dart',
      false,
    );
    expect(identical(first, second), isTrue);

    for (var i = 0; i < 100; i++) {
      CodeHighlighter.instance.highlight('final value$i = $i;', 'dart', false);
    }
    expect(CodeHighlighter.instance.cacheEntryCount, lessThanOrEqualTo(64));
    expect(
      CodeHighlighter.instance.cachedSourceChars,
      lessThanOrEqualTo(1000000),
    );
  });

  test('fallback highlighter also reuses immutable spans', () {
    final first = HermesSyntaxHighlighter.highlight('value = 1', '', false);
    final second = HermesSyntaxHighlighter.highlight('value = 1', '', false);
    expect(identical(first, second), isTrue);
  });
}
