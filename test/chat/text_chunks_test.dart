import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/text_chunks.dart';

void main() {
  test('chunks preserve text, newlines and surrogate pairs at every boundary', () {
    const source = 'ab😀cd\r\nef 👩‍👩‍👧‍👦 gh\nlast';
    for (var size = 2; size < source.length; size++) {
      final chunks = boundedTextChunks(source, maxChars: size);
      expect(chunks.join(), source);
      expect(chunks.every((chunk) => chunk.length <= size), isTrue);
      for (final chunk in chunks) {
        expect(chunk.runes.contains(0xFFFD), isFalse);
      }
    }
  });
  test('very long single line remains bounded and reconstructable', () {
    final source = 'x' * 1000000;
    final chunks = boundedTextChunks(source);
    expect(chunks.length, 500);
    expect(chunks.join(), source);
  });
}
