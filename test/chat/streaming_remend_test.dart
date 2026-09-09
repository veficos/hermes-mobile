import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/streaming_remend.dart';

void main() {
  test('repair matches fence character and length without touching code', () {
    for (final fence in ['~~~~', '````']) {
      final open = '$fence text\n** [ ` literal\n${fence.substring(1)}';
      expect(remendStreamingMarkdown(open), '$open\n$fence');
      final closed = '$open\n$fence\nfinished';
      expect(remendStreamingMarkdown(closed), closed);
    }
    const mixed = '~~~text\n```\n** [\n~~~\nend';
    expect(remendStreamingMarkdown(mixed), mixed);
  });

  test(
    'trusted append scans match validated updates and reset on replacement',
    () {
      final trusted = IncrementalStreamingMarkdownScanner(tailChars: 4);
      final validated = IncrementalStreamingMarkdownScanner(tailChars: 4);
      const source = 'first\n\nsecond\n\nthird block';
      for (var i = 1; i <= source.length; i++) {
        final prefix = source.substring(0, i);
        expect(
          trusted.update(prefix, appendOnly: true),
          validated.update(prefix),
        );
        expect(trusted.stableEnd, validated.stableEnd);
      }
      trusted.reset();
      const replacement = 'other\n\nremaining text';
      expect(
        trusted.update(replacement, appendOnly: true),
        validated.update(replacement),
      );
      expect(trusted.tail(replacement), validated.tail(replacement));
    },
  );

  test(
    'inline code uses matching delimiter lengths and literal backslashes',
    () {
      const source = 'text ``code ` ** [ \\`` done\n\nnext paragraph';
      for (var split = 0; split <= source.length; split++) {
        final scanner = IncrementalStreamingMarkdownScanner(tailChars: 2);
        final blocks = [...scanner.update(source.substring(0, split))];
        blocks.addAll(scanner.update(source));
        expect(blocks.join(), 'text ``code ` ** [ \\`` done\n\n');
        expect(scanner.tail(source), 'next paragraph');
      }
    },
  );

  test('fences survive every provider split and only matching runs close', () {
    for (final fence in ['````', '~~~~']) {
      final other = fence.startsWith('`') ? '~~~' : '```';
      final source =
          'intro\n\n${fence}dart\ncode\n\n$other\n\n'
          '${fence.substring(1)}\n\nmore\n$fence\n\nafter text';
      for (var split = 0; split <= source.length; split++) {
        final scanner = IncrementalStreamingMarkdownScanner(tailChars: 2);
        final blocks = <String>[...scanner.update(source.substring(0, split))];
        blocks.addAll(scanner.update(source));
        expect(blocks.join() + scanner.tail(source), source);
        for (final block in blocks) {
          if (block.contains('${fence}dart')) {
            expect(block, contains('more\n$fence\n'));
          }
        }
        expect(scanner.tail(source), 'after text');
      }
    }
  });

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

  test('scanner treats a fence indented up to 3 spaces as a fence', () {
    for (final indent in ['', ' ', '  ', '   ']) {
      final scanner = IncrementalStreamingMarkdownScanner(tailChars: 4);
      final source =
          '- list item\n\n$indent```dart\n${indent}code\n\n${indent}more';
      scanner.update(source);
      // The blank line inside the indented fence must not become a safe
      // boundary — the fence opener stays in the mutable tail.
      expect(scanner.tail(scanner.source), contains('```dart'));
    }
  });

  test('scanner treats a tab-indented fence marker as plain text', () {
    // A tab is not valid fence indent (matches package:markdown's
    // `^([ ]{0,3})`), so the blank line after it IS a safe boundary.
    final scanner = IncrementalStreamingMarkdownScanner(tailChars: 4);
    final added = scanner.update('para\n\n\t``` not a fence\n\nafter text');
    expect(added, ['para\n\n']);
  });

  test('split does not cut through an indented fence inside a list item', () {
    final source =
        '${'intro ' * 200}\n\n- item\n\n  ```dart\n  ${'code ' * 1500}';
    final split = splitStableStreamingMarkdown(source, tailChars: 1000);
    expect(split.mutableTail, contains('```dart'));
    expect(split.stablePrefix + split.mutableTail, source);
  });

  test('remend closes an indented fence opened inside a list item', () {
    expect(
      remendStreamingMarkdown('- item\n\n  ```dart\n  void main() {'),
      endsWith('\n```'),
    );
  });

  test('remend leaves a balanced indented fence untouched', () {
    const balanced = '- item\n\n  ```dart\n  code();\n  ```\nafter';
    expect(remendStreamingMarkdown(balanced), balanced);
  });

  test('scanner keeps open tilde-fenced content mutable', () {
    final scanner = IncrementalStreamingMarkdownScanner(tailChars: 4);
    scanner.update('intro\n\n~~~dart\ncode\n\nmore');
    expect(scanner.stableEnd, greaterThan(0));
    expect(scanner.tail(scanner.source), contains('~~~dart'));
  });

  test('tilde fences never freeze safe boundaries as strikethrough', () {
    // Regression: `~~~` was parsed as a `~~` strike toggle plus a stray `~`,
    // leaving `_strike` on and suppressing every later boundary.
    final scanner = IncrementalStreamingMarkdownScanner(tailChars: 8);
    final added = scanner.update(
      '~~~\ncode\n~~~\n\ntrailing paragraph that is long enough',
    );
    expect(added, ['~~~\ncode\n~~~\n\n']);
  });

  test('a backtick fence does not close a tilde fence and vice versa', () {
    expect(
      remendStreamingMarkdown('~~~\ncode\n```\nstill code'),
      endsWith('\n~~~'),
    );
    expect(
      remendStreamingMarkdown('```\ncode\n~~~\nstill code'),
      endsWith('\n```'),
    );
  });

  test('a fence closed by a longer run is not read as a dangling strike', () {
    const text = '~~~\ncode\n~~~~\nafter';
    expect(remendStreamingMarkdown(text), text);
  });

  test('remend closes an unclosed tilde fence with tildes', () {
    expect(
      remendStreamingMarkdown('here is code:\n~~~python\nprint(1)'),
      endsWith('\n~~~'),
    );
  });

  test('leaves a balanced tilde fence untouched', () {
    const balanced = 'text\n~~~python\nprint(1)\n~~~\nmore';
    expect(remendStreamingMarkdown(balanced), balanced);
  });

  test('a mid-line tilde run is not read as a dangling strike', () {
    // `~~~` mid-line is literal text, not a fence and not a `~~` toggle.
    expect(remendStreamingMarkdown('a ~~~ b'), 'a ~~~ b');
  });

  test('trims a half-typed image without leaving a stray bang', () {
    expect(remendStreamingMarkdown('see ![the diagram]('), 'see');
    expect(remendStreamingMarkdown('see ![the dia'), 'see');
  });

  test('keeps a completed image', () {
    const image = 'see ![the diagram](https://x.dev/a.png)';
    expect(remendStreamingMarkdown(image), image);
  });

  test('keeps a bang that is not adjacent to the trimmed bracket', () {
    // The `!` is only part of an image marker when directly before `[`.
    expect(remendStreamingMarkdown('wow! [label]('), 'wow!');
  });
}
