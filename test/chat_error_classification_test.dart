import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';

/// Weak-network regression: `GatewayClient`'s own in-flight request cap
/// (`gatewayTooManyPendingCode`, gateway.dart) throws
/// `GatewayException(-32001): too many pending gateway requests` — a burst
/// of queued sends replaying right after a reconnect is exactly the kind of
/// case that hits this. None of the pre-existing keyword buckets matched
/// that message, so it fell through to `generic` — the least informative
/// label, right when the user most needs "this is a network thing".
void main() {
  test('gateway pending-request cap classifies as network, not generic', () {
    final layer = classifyChatError(
      'GatewayException(-32001): too many pending gateway requests',
    );
    expect(layer, ChatErrorLayer.network);
  });

  test('is case-insensitive and tolerant of surrounding text', () {
    final layer = classifyChatError(
      'Failed to send: TOO MANY PENDING GATEWAY REQUESTS (please retry)',
    );
    expect(layer, ChatErrorLayer.network);
  });

  test('unrelated generic errors are unaffected', () {
    expect(classifyChatError('something went wrong'), ChatErrorLayer.generic);
  });
}
