import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/ansi_text.dart';

String _plainText(List<InlineSpan> spans) =>
    spans.map((s) => s is TextSpan ? (s.text ?? '') : '').join();

void main() {
  test('renders a complete SGR sequence without escape noise', () {
    final spans = parseAnsi(
      '\x1B[31mred\x1B[0m plain',
      const TextStyle(),
      false,
    );
    expect(_plainText(spans), 'red plain');
  });

  test('drops a dangling truncated CSI sequence at the tail', () {
    // Simulates a long ANSI-colored tool result hard-cut mid escape, e.g.
    // "...\x1B[38;5;123m" chopped to "...\x1B[38;5;123".
    final spans = parseAnsi(
      'before \x1B[38;5;123',
      const TextStyle(),
      false,
    );
    expect(_plainText(spans), 'before ');
  });

  test('drops a dangling bare ESC at the tail', () {
    final spans = parseAnsi('trailing \x1B', const TextStyle(), false);
    expect(_plainText(spans), 'trailing ');
  });
}
