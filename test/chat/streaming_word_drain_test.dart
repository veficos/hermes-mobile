import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/streaming_word_drain.dart';

void main() {
  test('reveals a burst one word unit at a time', () {
    const source = 'alpha beta gamma delta';
    expect(StreamingWordDrain.unitCount(source), 4);
    expect(
      source.substring(0, StreamingWordDrain.splitOffset(source, 1)),
      'alpha ',
    );
  });

  test('all split positions preserve the source byte-for-byte', () {
    const source =
        'The 👩‍👩‍👧‍👦 family and 🇫🇷 flag.\r\ntabs\tand  doubles café fin';
    final units = StreamingWordDrain.unitCount(source);
    for (var count = 0; count <= units; count++) {
      final offset = StreamingWordDrain.splitOffset(source, count);
      final head = source.substring(0, offset);
      final tail = source.substring(offset);
      expect(head + tail, source);
    }
  });

  test('a trailing in-progress word is drainable', () {
    expect(StreamingWordDrain.unitCount('unfinished'), 1);
    expect(StreamingWordDrain.splitOffset('unfinished', 1), 10);
  });

  test('large backlog scales quota to stay within lag bound', () {
    expect(
      StreamingWordDrain.drainQuota(
        backlogUnitCount: 60,
        cadence: const Duration(milliseconds: 100),
        maxLag: const Duration(milliseconds: 300),
      ),
      20,
    );
  });

  test('normal backlog drains one unit', () {
    expect(
      StreamingWordDrain.drainQuota(
        backlogUnitCount: 4,
        cadence: const Duration(milliseconds: 42),
        maxLag: const Duration(seconds: 1),
      ),
      1,
    );
  });
}
