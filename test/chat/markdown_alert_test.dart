import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/inline_content.dart';

void main() {
  test('parses a GitHub alert block into an InlineAlertNode', () {
    final nodes = parseInlineContent(
      'intro line\n\n> [!WARNING]\n> be careful\n> really\n\ntrailing',
    );
    final alert = nodes.whereType<InlineAlertNode>().single;
    expect(alert.type, 'warning');
    expect(alert.body, 'be careful\nreally');
    // Surrounding prose is preserved as text nodes.
    final text = nodes.whereType<InlineTextNode>().map((n) => n.text).join();
    expect(text, contains('intro line'));
    expect(text, contains('trailing'));
  });

  test('recognises every GitHub alert kind, case-insensitively', () {
    for (final kind in ['note', 'tip', 'important', 'warning', 'caution']) {
      final nodes = parseInlineContent('> [!${kind.toUpperCase()}]\n> body');
      expect(nodes.whereType<InlineAlertNode>().single.type, kind);
    }
  });

  test('an unknown bang-directive stays plain text', () {
    final nodes = parseInlineContent('> [!QUOTE]\n> body');
    expect(nodes.whereType<InlineAlertNode>(), isEmpty);
  });

  test('alert markers inside a fenced code block are left untouched', () {
    final nodes = parseInlineContent('```\n> [!NOTE]\n> not an alert\n```');
    expect(nodes.whereType<InlineAlertNode>(), isEmpty);
    expect(nodes.whereType<InlineCodeNode>(), hasLength(1));
  });
}
