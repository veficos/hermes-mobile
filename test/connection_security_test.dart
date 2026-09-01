import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecrets implements ConnectionSecretStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('connection metadata never persists credential values', () async {
    final secrets = _MemorySecrets();
    final store = SettingsStore(secrets: secrets);
    const settings = ConnectionSettings(
      serverUrl: 'https://gateway.example',
      apiKey: 'hm_super_secret',
      refreshToken: 'oauth-refresh-secret',
      headers: {
        'CF-Access-Client-Id': 'client-id-secret',
        'CF-Access-Client-Secret': 'client-secret-value',
      },
    );

    await store.save(settings);
    await store.saveProfile('Work', settings);

    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString('hermes_mobile_connection')!;
    final profiles = prefs.getString('hermes_mobile_server_profiles')!;
    for (final raw in [primary, profiles]) {
      expect(raw, isNot(contains('hm_super_secret')));
      expect(raw, isNot(contains('client-id-secret')));
      expect(raw, isNot(contains('client-secret-value')));
      expect(raw, isNot(contains('oauth-refresh-secret')));
    }
    expect(primary, contains('CF-Access-Client-Id'));

    final restored = await store.load();
    final restoredProfiles = await store.profiles();
    expect(restored.apiKey, 'hm_super_secret');
    expect(restored.refreshToken, 'oauth-refresh-secret');
    expect(restored.normalizedHeaders, settings.normalizedHeaders);
    expect(restoredProfiles.single.settings.apiKey, 'hm_super_secret');
    expect(
      restoredProfiles.single.settings.normalizedHeaders,
      settings.normalizedHeaders,
    );
  });

  test(
    'SSH credentials stay in secure storage while metadata round-trips',
    () async {
      final secrets = _MemorySecrets();
      final store = SettingsStore(secrets: secrets);
      const settings = ConnectionSettings(
        serverUrl: 'ssh://build.example:2222',
        kind: ConnectionKind.ssh,
        transport: ConnectionTransport.sshTunnel,
        sshHost: 'build.example',
        sshUser: 'builder',
        sshPort: 2222,
        sshPrivateKey: 'PRIVATE-KEY-MATERIAL',
        sshPrivateKeyPassphrase: 'key-passphrase',
        sshPassword: 'ssh-password',
        sshRemoteHermesPath: '~/.local/bin/hermes',
        sshRemoteProfile: 'work',
      );

      await store.save(settings);
      await store.saveProfile('SSH Work', settings);

      final prefs = await SharedPreferences.getInstance();
      final persisted = [
        prefs.getString('hermes_mobile_connection')!,
        prefs.getString('hermes_mobile_server_profiles')!,
      ].join();
      expect(persisted, isNot(contains('PRIVATE-KEY-MATERIAL')));
      expect(persisted, isNot(contains('key-passphrase')));
      expect(persisted, isNot(contains('ssh-password')));
      expect(persisted, contains('build.example'));
      expect(persisted, contains('builder'));
      expect(persisted, contains('2222'));
      expect(persisted, contains('~/.local/bin/hermes'));
      expect(persisted, contains('work'));

      final restored = await store.load();
      final restoredProfile = (await store.profiles()).single.settings;
      for (final value in [restored, restoredProfile]) {
        expect(value.sshPrivateKey, 'PRIVATE-KEY-MATERIAL');
        expect(value.sshPrivateKeyPassphrase, 'key-passphrase');
        expect(value.sshPassword, 'ssh-password');
        expect(value.sshHost, 'build.example');
        expect(value.sshUser, 'builder');
        expect(value.sshPort, 2222);
        expect(value.sshRemoteHermesPath, '~/.local/bin/hermes');
        expect(value.sshRemoteProfile, 'work');
      }
    },
  );

  test(
    'legacy plaintext settings migrate before prefs are sanitized',
    () async {
      SharedPreferences.setMockInitialValues({
        'hermes_mobile_connection': jsonEncode({
          'serverUrl': 'http://legacy.example',
          'apiKey': 'legacy-key',
          'headers': {'X-Legacy-Secret': 'legacy-header-value'},
        }),
        'hermes_mobile_server_profiles': jsonEncode([
          {
            'name': 'Legacy',
            'serverUrl': 'http://legacy.example',
            'apiKey': 'profile-key',
            'headers': {'X-Profile-Secret': 'profile-header-value'},
          },
        ]),
      });
      final secrets = _MemorySecrets();
      final store = SettingsStore(secrets: secrets);

      final primary = await store.load();
      final profiles = await store.profiles();

      expect(primary.apiKey, 'legacy-key');
      expect(
        primary.normalizedHeaders['X-Legacy-Secret'],
        'legacy-header-value',
      );
      expect(profiles.single.settings.apiKey, 'profile-key');
      final prefs = await SharedPreferences.getInstance();
      final persisted = [
        prefs.getString('hermes_mobile_connection')!,
        prefs.getString('hermes_mobile_server_profiles')!,
      ].join();
      expect(persisted, isNot(contains('legacy-key')));
      expect(persisted, isNot(contains('profile-key')));
      expect(persisted, isNot(contains('header-value')));
      expect(secrets.values.length, 2);
    },
  );

  test('deleting settings removes their secure credentials', () async {
    final secrets = _MemorySecrets();
    final store = SettingsStore(secrets: secrets);
    const settings = ConnectionSettings(
      serverUrl: 'https://gateway.example',
      apiKey: 'secret',
    );
    await store.save(settings);
    await store.saveProfile('Disposable', settings);
    expect(secrets.values, hasLength(2));

    await store.clear();
    await store.deleteProfile('Disposable');

    expect(secrets.values, isEmpty);
  });

  test('reserved and malformed headers cannot override Hermes auth', () {
    const settings = ConnectionSettings(
      headers: {
        ' X-Valid ': ' value ',
        'Authorization': 'attacker',
        'content-type': 'text/plain',
        'bad header': 'bad',
        'X-Empty': ' ',
      },
    );

    expect(settings.normalizedHeaders, {'X-Valid': 'value'});
    expect(isValidConnectionHeaderName('CF-Access-Client-Id'), isTrue);
    expect(isValidConnectionHeaderName('bad header'), isFalse);
  });

  test(
    'connection transport policy allows HTTPS and local HTTP by default',
    () {
      expect(connectionTransportAllowed('https://gateway.example'), isTrue);
      expect(connectionTransportAllowed('http://127.0.0.1:8877'), isTrue);
      expect(connectionTransportAllowed('http://192.168.1.5:8877'), isTrue);
      expect(connectionTransportAllowed('http://hermes.local:8877'), isTrue);
      expect(connectionTransportAllowed('http://gateway.example'), isFalse);
      expect(
        connectionTransportAllowed(
          'http://gateway.example',
          allowInsecure: true,
        ),
        isTrue,
      );
      expect(connectionTransportAllowed('ftp://gateway.example'), isFalse);
    },
  );

  test('release cleartext policy matches native platform capabilities', () {
    for (final url in [
      'http://localhost:8877',
      'http://127.0.0.1:8877',
      'http://10.0.2.2:8877',
      'http://build-machine.local:8877',
    ]) {
      expect(
        connectionTransportAllowed(
          url,
          policy: CleartextTransportPolicy.namedLocalHosts,
        ),
        isTrue,
        reason: url,
      );
    }
    for (final url in [
      'http://192.168.1.5:8877',
      'http://10.1.2.3:8877',
      'http://gateway.example',
    ]) {
      expect(
        connectionTransportAllowed(
          url,
          allowInsecure: true,
          policy: CleartextTransportPolicy.namedLocalHosts,
        ),
        isFalse,
        reason: url,
      );
    }

    expect(
      connectionTransportAllowed(
        'http://192.168.1.5:8877',
        policy: CleartextTransportPolicy.localHosts,
      ),
      isTrue,
    );
    expect(
      connectionTransportAllowed(
        'http://gateway.example',
        allowInsecure: true,
        policy: CleartextTransportPolicy.localHosts,
      ),
      isFalse,
    );
  });

  test('explicit insecure transport approval persists as metadata', () async {
    final store = SettingsStore(secrets: _MemorySecrets());
    const settings = ConnectionSettings(
      serverUrl: 'http://gateway.example',
      apiKey: 'secret',
      allowInsecureTransport: true,
    );

    await store.save(settings);
    final restored = await store.load();

    expect(restored.allowInsecureTransport, isTrue);
    expect(restored.apiKey, 'secret');
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(
        prefs.getString('hermes_mobile_connection')!,
      )['allowInsecureTransport'],
      isTrue,
    );
  });

  test(
    'API client forwards access headers while preserving bearer auth',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });
      final api = ApiClient(
        baseUrl: 'https://gateway.example',
        apiKey: 'real-key',
        extraHeaders: const {
          'CF-Access-Client-Id': 'access-id',
          'authorization': 'bad-key',
        },
        client: client,
      );
      addTearDown(api.close);

      await api.get('/api/v1/status');

      expect(captured.headers['authorization'], 'Bearer real-key');
      expect(captured.headers['cf-access-client-id'], 'access-id');
    },
  );
}
