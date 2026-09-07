import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/embed_consent_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to ask and persists per-provider consent', () async {
    final store = EmbedConsentStore();
    await store.load();
    expect(store.mode, EmbedMode.ask);
    expect(store.allows('youtube'), isFalse);

    await store.allowProvider('YouTube');
    expect(store.allows('youtube'), isTrue);

    final restored = EmbedConsentStore();
    await restored.load();
    expect(restored.allows('YOUTUBE'), isTrue);
  });

  test('off overrides grants and clear removes all provider grants', () async {
    final store = EmbedConsentStore();
    await store.load();
    await store.allowProvider('youtube');
    await store.setMode(EmbedMode.off);
    expect(store.allows('youtube'), isFalse);

    await store.setMode(EmbedMode.ask);
    await store.clearAllowedProviders();
    expect(store.allowedProviders, isEmpty);
    expect(store.allows('youtube'), isFalse);
  });

  test('always permits every provider without storing a grant', () async {
    final store = EmbedConsentStore();
    await store.load();
    await store.setMode(EmbedMode.always);
    expect(store.allows('spotify'), isTrue);
    expect(store.allowedProviders, isEmpty);
  });
}
