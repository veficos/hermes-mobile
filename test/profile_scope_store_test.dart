import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';

/// Desktop parity for `SettingsProfileScope`/the Capabilities scope
/// selector: `override == null` means "follow the active profile" (the same
/// ambient default every profile-aware ApiClient call already falls back to
/// when its own `profile:` argument is omitted).
class _ProfilesApi extends ApiClient {
  _ProfilesApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int listProfilesCalls = 0;

  @override
  Future<ProfilesPayload> listProfiles() async {
    listProfilesCalls++;
    return const ProfilesPayload(
      profiles: [
        ProfileInfo(name: 'default', isActive: true),
        ProfileInfo(name: 'work'),
      ],
      active: 'default',
    );
  }
}

class _FailingProfilesApi extends ApiClient {
  _FailingProfilesApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<ProfilesPayload> listProfiles() async => throw StateError('offline');
}

class _DelayedProfilesApi extends ApiClient {
  _DelayedProfilesApi(this.name)
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final String name;
  final Completer<void> gate = Completer<void>();

  @override
  Future<ProfilesPayload> listProfiles() async {
    await gate.future;
    return ProfilesPayload(
      profiles: [ProfileInfo(name: name, isActive: true)],
      active: name,
    );
  }
}

void main() {
  test('override defaults to null (follow active) and notifies on change', () {
    final store = ProfileScopeStore();
    var notifications = 0;
    store.addListener(() => notifications++);

    expect(store.override, isNull);
    store.setOverride('work');
    expect(store.override, 'work');
    expect(notifications, 1);

    // Setting the same value again must not re-notify.
    store.setOverride('work');
    expect(notifications, 1);

    store.setOverride(null);
    expect(store.override, isNull);
    expect(notifications, 2);
  });

  test(
    'refresh populates profiles/activeProfile and dedupes concurrent calls',
    () async {
      final api = _ProfilesApi();
      final store = ProfileScopeStore()..bindApi(api);

      final first = store.refresh();
      final second = store.refresh();
      await Future.wait([first, second]);

      expect(api.listProfilesCalls, 1);
      expect(store.profiles.map((p) => p.name), ['default', 'work']);
      expect(store.activeProfile, 'default');
      expect(store.loaded, isTrue);
    },
  );

  test('ensureLoaded only fetches once loaded is true', () async {
    final api = _ProfilesApi();
    final store = ProfileScopeStore()..bindApi(api);

    await store.ensureLoaded();
    await store.ensureLoaded();

    expect(api.listProfilesCalls, 1);
  });

  test(
    'a failed refresh leaves the store usable (no profiles, no crash)',
    () async {
      final store = ProfileScopeStore()..bindApi(_FailingProfilesApi());
      await store.refresh();
      expect(store.loaded, isFalse);
      expect(store.profiles, isEmpty);
    },
  );

  test('updateProfiles adopts a payload another screen already fetched', () {
    final store = ProfileScopeStore();
    store.updateProfiles(
      const ProfilesPayload(
        profiles: [
          ProfileInfo(name: 'a'),
          ProfileInfo(name: 'b'),
        ],
        active: 'a',
      ),
    );
    expect(store.loaded, isTrue);
    expect(store.activeProfile, 'a');
    expect(store.profiles, hasLength(2));
  });

  test('bindApi to a new connection resets the override and cache', () {
    final store = ProfileScopeStore()..bindApi(_ProfilesApi());
    store.setOverride('work');
    store.updateProfiles(
      const ProfilesPayload(
        profiles: [ProfileInfo(name: 'work')],
        active: 'work',
      ),
    );
    expect(store.override, 'work');
    expect(store.loaded, isTrue);

    store.bindApi(_ProfilesApi());

    expect(store.override, isNull);
    expect(store.loaded, isFalse);
    expect(store.profiles, isEmpty);
  });

  test('binding the identical api instance is a no-op', () {
    final api = _ProfilesApi();
    final store = ProfileScopeStore()..bindApi(api);
    store.setOverride('work');
    store.bindApi(api);
    expect(store.override, 'work');
  });

  test('old connection profiles cannot overwrite a new binding', () async {
    final oldApi = _DelayedProfilesApi('old');
    final newApi = _DelayedProfilesApi('new');
    final store = ProfileScopeStore()..bindApi(oldApi);
    final oldRefresh = store.refresh();

    store.bindApi(newApi);
    final newRefresh = store.refresh();
    newApi.gate.complete();
    await newRefresh;
    expect(store.activeProfile, 'new');

    oldApi.gate.complete();
    await oldRefresh;
    expect(store.activeProfile, 'new');
  });
}
