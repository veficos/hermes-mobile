import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/session_view_state_store.dart';

void main() {
  test('weighted LRU evicts oldest unprotected session', () {
    final store = SessionViewStateStore(maxCount: 2, maxBytes: 10000);
    store.put('a', const SessionViewState(scrollOffset: 1));
    store.put('b', const SessionViewState(scrollOffset: 2));
    expect(store.get('a')?.scrollOffset, 1);
    store.put('c', const SessionViewState(scrollOffset: 3));
    expect(store.get('b'), isNull);
    expect(store.get('a'), isNotNull);
    expect(store.get('c'), isNotNull);
  });

  test('protected session survives byte pruning', () {
    final store = SessionViewStateStore(maxCount: 10, maxBytes: 250);
    store.put('live', const SessionViewState(anchorMessageId: 'live'));
    store.protect(['live']);
    store.put('old', SessionViewState(anchorMessageId: 'x' * 200));
    expect(store.get('live'), isNotNull);
    expect(store.get('old'), isNull);
  });
}
