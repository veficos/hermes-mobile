import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/inline_content_cache.dart';

void main() {
  setUp(InlineContentCache.instance.clear);

  test('reuses immutable preprocessing and separates references', () {
    const source = 'Hello **world** @file:/tmp/example.dart';
    final first = InlineContentCache.instance.prepare(source);
    final second = InlineContentCache.instance.prepare(source);

    expect(identical(first, second), isTrue);
    expect(first.body, 'Hello **world**');
    expect(first.references, hasLength(1));
    expect(first.nodes, isNotEmpty);
  });

  test('streaming callers can bypass and cache remains bounded', () {
    final first = InlineContentCache.instance.prepare('delta', cache: false);
    final second = InlineContentCache.instance.prepare('delta', cache: false);
    expect(identical(first, second), isFalse);

    for (var i = 0; i < 300; i++) {
      InlineContentCache.instance.prepare('message $i');
    }
    expect(InlineContentCache.instance.entryCount, lessThanOrEqualTo(256));
    expect(InlineContentCache.instance.sourceChars, lessThanOrEqualTo(2000000));
  });
}
