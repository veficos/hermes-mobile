import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline caches are isolated by connection and profile', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = CacheStore();

    await cache.cacheSessions([
      {'id': 'work-session'},
    ], scope: 'saved:work\u0000expert');
    await cache.cacheSessions([
      {'id': 'home-session'},
    ], scope: 'saved:home\u0000default');
    await cache.cacheTranscript('same-id', [
      {'text': 'work secret'},
    ], scope: 'saved:work\u0000expert');

    expect(
      (await cache.cachedSessions(
        scope: 'saved:work\u0000expert',
      )).single['id'],
      'work-session',
    );
    expect(
      (await cache.cachedSessions(
        scope: 'saved:home\u0000default',
      )).single['id'],
      'home-session',
    );
    expect(
      await cache.cachedTranscript('same-id', scope: 'saved:home\u0000default'),
      isNull,
    );
  });
}
