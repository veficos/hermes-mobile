import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/embed_runtime_store.dart';

void main() {
  test('limits live players and releases capacity', () {
    final store = EmbedRuntimeStore(maxActive: 2);
    expect(store.acquire('a'), isTrue);
    expect(store.acquire('b'), isTrue);
    expect(store.acquire('c'), isFalse);
    store.release('a');
    expect(store.acquire('c'), isTrue);
    expect(store.activeCount, 2);
    store.releaseAll();
    expect(store.activeCount, 0);
  });
}
