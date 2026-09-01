import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';

void main() {
  test('streaming speech cuts complete Chinese and Latin sentences', () {
    final cut = splitSpeechSentences('你好。How are you? 还没说完');

    expect(cut.sentences, ['你好。', 'How are you?']);
    expect(cut.rest, ' 还没说完');
  });

  test('streaming speech keeps an incomplete sentence until flush', () {
    final pending = splitSpeechSentences('still generating');
    expect(pending.sentences, isEmpty);
    expect(pending.rest, 'still generating');

    final flushed = splitSpeechSentences(pending.rest, flush: true);
    expect(flushed.sentences, ['still generating']);
    expect(flushed.rest, isEmpty);
  });
}
