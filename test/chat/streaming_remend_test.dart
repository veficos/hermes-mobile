import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/streaming_remend.dart';

void main() {
  test('closes an unclosed fenced code block', () {
    expect(
      remendStreamingMarkdown('here is code:\n```dart\nvoid main() {'),
      endsWith('\n```'),
    );
  });

  test('leaves a balanced fence untouched', () {
    const balanced = 'text\n```dart\nvoid main() {}\n```\nmore';
    expect(remendStreamingMarkdown(balanced), balanced);
  });

  test('balances a dangling bold marker', () {
    expect(
      remendStreamingMarkdown('this is **important'),
      'this is **important**',
    );
  });

  test('balances a dangling inline code tick', () {
    expect(remendStreamingMarkdown('call `foo'), 'call `foo`');
  });

  test('trims a half-typed link whose target has not arrived', () {
    expect(remendStreamingMarkdown('see [the docs]('), 'see');
    expect(remendStreamingMarkdown('see [the do'), 'see');
  });

  test('keeps a completed link', () {
    const link = 'see [the docs](https://x.dev)';
    expect(remendStreamingMarkdown(link), link);
  });

  test('empty input is returned as-is', () {
    expect(remendStreamingMarkdown(''), '');
  });

  test('a closed fence containing ** is not mistaken for a dangling bold', () {
    const text = '```python\nresult = a ** b\n```\nDone.';
    expect(remendStreamingMarkdown(text), text);
  });

  test('a closed fence containing a bare [ is not trimmed away', () {
    const text = '```python\nfor i in arr[\n```\nmore';
    expect(remendStreamingMarkdown(text), text);
  });

  test('a closed fence containing backtick command substitution is untouched', () {
    const text = '```sh\necho `date`\n```\nafter';
    expect(remendStreamingMarkdown(text), text);
  });
}
