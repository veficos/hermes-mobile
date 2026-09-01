import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/inline_content.dart';

void main() {
  test('splits a display equation into an InlineMathNode', () {
    final nodes = parseInlineContent(r'Before.$$E = mc^2$$After.');
    final math = nodes.whereType<InlineMathNode>().single;
    expect(math.tex, 'E = mc^2');
    final text = nodes.whereType<InlineTextNode>().map((n) => n.text).join();
    expect(text, contains('Before.'));
    expect(text, contains('After.'));
  });

  test(r'recognises \[ … \] display math', () {
    final nodes = parseInlineContent(r'\[ a^2 + b^2 = c^2 \]');
    expect(nodes.whereType<InlineMathNode>().single.tex, 'a^2 + b^2 = c^2');
  });

  test('inline math folds the whole run into one InlineRichNode', () {
    final nodes = parseInlineContent(r'The value $x_i$ is bounded by $n$.');
    final rich = nodes.whereType<InlineRichNode>().single;
    expect(rich.segments.where((s) => s.isMath).map((s) => s.value), [
      'x_i',
      'n',
    ]);
    expect(rich.segments.first.value, 'The value ');
  });

  test('prose with no math stays a plain text node (markdown preserved)', () {
    final nodes = parseInlineContent('Just **bold** prose, no math.');
    expect(nodes.whereType<InlineRichNode>(), isEmpty);
    expect(nodes.whereType<InlineMathNode>(), isEmpty);
    expect(nodes.whereType<InlineTextNode>(), isNotEmpty);
  });

  test('a bare dollar amount is not treated as math', () {
    final nodes = parseInlineContent('It costs \$5 today.');
    expect(nodes.whereType<InlineMathNode>(), isEmpty);
    expect(nodes.whereType<InlineRichNode>(), isEmpty);
  });

  test('math inside a fenced code block is left alone', () {
    final nodes = parseInlineContent('```\n\$\$x\$\$\n```');
    expect(nodes.whereType<InlineMathNode>(), isEmpty);
    expect(nodes.whereType<InlineCodeNode>(), hasLength(1));
  });
}
