import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/streaming_remend.dart';

void main() {
  test('stable split keeps a bounded mutable tail', () {
    final source = '${'paragraph text.\n\n' * 600}final paragraph';
    final split = splitStableStreamingMarkdown(source, tailChars: 1000);
    expect(split.stablePrefix, isNotEmpty);
    expect(split.stablePrefix + split.mutableTail, source);
    expect(split.mutableTail.length, lessThanOrEqualTo(1020));
  });

  test('stable split does not cut through an open fence', () {
    final source = '${'intro ' * 200}\n\n```dart\n${'code ' * 1500}';
    final split = splitStableStreamingMarkdown(source, tailChars: 1000);
    expect(split.mutableTail, contains('```dart'));
    expect(split.stablePrefix + split.mutableTail, source);
  });

  test(
    'incremental scanner emits completed blocks without rescanning tail',
    () {
      final scanner = IncrementalStreamingMarkdownScanner(tailChars: 8);
      expect(scanner.update('first block\n\nshort'), isEmpty);
      final added = scanner.update('first block\n\nshort and now long enough');
      expect(added, ['first block\n\n']);
      expect(scanner.tail(scanner.source), 'short and now long enough');
    },
  );

  test('incremental scanner keeps open fenced content mutable', () {
    final scanner = IncrementalStreamingMarkdownScanner(tailChars: 4);
    scanner.update('intro\n\n```dart\ncode\n\nmore');
    expect(scanner.stableEnd, greaterThan(0));
    expect(scanner.tail(scanner.source), contains('```dart'));
  });

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

  test(
    'a closed fence containing backtick command substitution is untouched',
    () {
      const text = '```sh\necho `date`\n```\nafter';
      expect(remendStreamingMarkdown(text), text);
    },
  );
}
