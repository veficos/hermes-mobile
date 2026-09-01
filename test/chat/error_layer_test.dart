import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';

void main() {
  test('classifies common failed-turn error texts', () {
    expect(
      classifyChatError('HTTP 401 Unauthorized: invalid api key'),
      ChatErrorLayer.auth,
    );
    expect(
      classifyChatError('402 Payment Required — insufficient credit'),
      ChatErrorLayer.billing,
    );
    expect(
      classifyChatError('429 rate limit exceeded, too many requests'),
      ChatErrorLayer.rateLimit,
    );
    expect(
      classifyChatError('SocketException: Connection reset by peer'),
      ChatErrorLayer.network,
    );
    expect(
      classifyChatError('502 Bad Gateway from upstream provider'),
      ChatErrorLayer.provider,
    );
    expect(
      classifyChatError('the model returned an empty response'),
      ChatErrorLayer.generic,
    );
  });

  test('ChatRecoveryEntry.diagnostics prefers detail over summary', () {
    final entry = ChatRecoveryEntry(
      summary: 'short…',
      detail: 'the full error string',
      at: DateTime(2026),
    );
    expect(entry.diagnostics, 'the full error string');
    final noDetail = ChatRecoveryEntry(
      summary: 'only summary',
      at: DateTime(2026),
    );
    expect(noDetail.diagnostics, 'only summary');
  });
}
