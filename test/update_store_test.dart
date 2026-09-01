import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/update_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _manifest(Map<String, dynamic> value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

Future<({Map<String, dynamic> envelope, String publicKey})> _signedManifest(
  Map<String, dynamic> payload,
) async {
  final android = <String, dynamic>{
    'build': 14,
    'minimum_build': 1,
    'url': 'https://example.test/android',
    'artifact_url': 'https://example.test/hermes-mobile.apk',
    'sha256': 'a' * 64,
    'size_bytes': 1024,
    ...?payload['android'] as Map<String, dynamic>?,
  };
  final ios = <String, dynamic>{
    'build': 14,
    'minimum_build': 1,
    'url': 'https://example.test/ios',
    'artifact_url': 'https://example.test/HermesMobile.ipa',
    'sha256': 'b' * 64,
    'size_bytes': 2048,
    ...?payload['ios'] as Map<String, dynamic>?,
  };
  final completePayload = <String, dynamic>{
    'schema_version': 2,
    'latest_version': '1.4.0',
    'minimum_supported_version': '1.0.0',
    'release_notes_url': 'https://example.test/notes',
    ...payload,
    'android': android,
    'ios': ios,
  };
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final signature = await algorithm.sign(
    utf8.encode(canonicalJson(completePayload)),
    keyPair: keyPair,
  );
  return (
    envelope: {
      'signed': completePayload,
      'signature': base64UrlEncode(signature.bytes).replaceAll('=', ''),
    },
    publicKey: base64UrlEncode(publicKey.bytes).replaceAll('=', ''),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'version comparison handles prefixes missing segments and build suffixes',
    () {
      expect(compareAppVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(compareAppVersions('v1.2', '1.2.0+42'), 0);
      expect(compareAppVersions('1.2.0', '2.0.0'), lessThan(0));
    },
  );

  test('manifest selects platform URL and reports optional update', () async {
    final store = UpdateStore(
      client: MockClient(
        (_) async => _manifest({
          'latest_version': '1.2.0',
          'minimum_supported_version': '0.9.0',
          'android': {'url': 'https://example.test/android'},
          'ios': {'url': 'https://example.test/ios'},
          'release_notes_url': 'https://example.test/notes',
        }),
      ),
      manifestUri: Uri.parse('https://example.test/update.json'),
      currentVersion: '1.0.0',
      currentBuild: '10',
      platform: TargetPlatform.android,
    );

    expect(await store.check(force: true), isTrue);
    expect(store.updateAvailable, isTrue);
    expect(store.requiresUpdate, isFalse);
    expect(store.updateUri.toString(), 'https://example.test/android');
    expect(store.releaseNotesUri.toString(), 'https://example.test/notes');
    store.dispose();
  });

  test('minimum version and equal-version build can require update', () async {
    final responses = [
      {'latest_version': '2.0.0', 'minimum_supported_version': '1.1.0'},
      {
        'latest_version': '1.0.0',
        'minimum_supported_version': '1.0.0',
        'minimum_build': 11,
      },
    ];
    var index = 0;
    final store = UpdateStore(
      client: MockClient((_) async => _manifest(responses[index++])),
      currentVersion: '1.0.0',
      currentBuild: '10',
      platform: TargetPlatform.android,
    );

    await store.check(force: true);
    expect(store.requiresUpdate, isTrue);
    await store.check(force: true);
    expect(store.requiresUpdate, isTrue);
    store.dispose();
  });

  test(
    'invalid manifest is rejected without replacing cached good state',
    () async {
      var valid = true;
      final store = UpdateStore(
        client: MockClient(
          (_) async => valid
              ? _manifest({
                  'latest_version': '1.1.0',
                  'minimum_supported_version': '1.0.0',
                })
              : _manifest({'latest_version': 'tomorrow'}),
        ),
        currentVersion: '1.0.0',
        currentBuild: '1',
      );
      await store.check(force: true);
      expect(store.manifest?.latestVersion, '1.1.0');

      valid = false;
      expect(await store.check(force: true), isFalse);
      expect(store.manifest?.latestVersion, '1.1.0');
      expect(store.error, contains('invalid latest version'));
      store.dispose();
    },
  );

  test('manifest rejects insecure update and release-note URLs', () async {
    final payloads = [
      {
        'latest_version': '1.1.0',
        'android': {'url': 'http://downloads.example/app.apk'},
      },
      {'latest_version': '1.1.0', 'release_notes_url': 'javascript:alert(1)'},
    ];
    var index = 0;
    final store = UpdateStore(
      client: MockClient((_) async => _manifest(payloads[index++])),
      currentVersion: '1.0.0',
      currentBuild: '1',
      platform: TargetPlatform.android,
    );

    expect(await store.check(force: true), isFalse);
    expect(store.error, contains('HTTPS URL'));
    expect(await store.check(force: true), isFalse);
    expect(store.error, contains('HTTPS URL'));
    store.dispose();
  });

  test('manifest rejects a minimum version newer than latest', () async {
    final store = UpdateStore(
      client: MockClient(
        (_) async => _manifest({
          'latest_version': '1.1.0',
          'minimum_supported_version': '2.0.0',
        }),
      ),
      currentVersion: '1.0.0',
      currentBuild: '1',
    );

    expect(await store.check(force: true), isFalse);
    expect(store.error, contains('cannot exceed'));
    store.dispose();
  });

  test(
    'initialize restores cached manifest inside automatic interval',
    () async {
      var calls = 0;
      final first = UpdateStore(
        client: MockClient((_) async {
          calls++;
          return _manifest({
            'latest_version': '1.3.0',
            'minimum_supported_version': '1.0.0',
          });
        }),
        currentVersion: '1.0.0',
        currentBuild: '1',
      );
      await first.check(force: true);
      first.dispose();

      final second = UpdateStore(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
        currentVersion: '1.0.0',
        currentBuild: '1',
      );
      await second.initialize();
      expect(second.manifest?.latestVersion, '1.3.0');
      expect(second.updateAvailable, isTrue);
      expect(calls, 1);
      second.dispose();
    },
  );

  test('signed Ed25519 manifest is accepted', () async {
    final signed = await _signedManifest({
      'latest_version': '1.4.0',
      'minimum_supported_version': '1.0.0',
      'android': {'url': 'https://example.test/android'},
      'release_notes_url': 'https://example.test/notes',
    });
    final store = UpdateStore(
      client: MockClient((_) async => _manifest(signed.envelope)),
      currentVersion: '1.0.0',
      currentBuild: '1',
      platform: TargetPlatform.android,
      manifestPublicKey: signed.publicKey,
      allowUnsignedManifest: false,
    );

    expect(await store.check(force: true), isTrue);
    expect(store.manifest?.latestVersion, '1.4.0');
    store.dispose();
  });

  test('tampered signed payload is rejected', () async {
    final signed = await _signedManifest({
      'latest_version': '1.4.0',
      'minimum_supported_version': '1.0.0',
    });
    (signed.envelope['signed'] as Map<String, dynamic>)['latest_version'] =
        '9.9.9';
    final store = UpdateStore(
      client: MockClient((_) async => _manifest(signed.envelope)),
      currentVersion: '1.0.0',
      currentBuild: '1',
      manifestPublicKey: signed.publicKey,
      allowUnsignedManifest: false,
    );

    expect(await store.check(force: true), isFalse);
    expect(store.error, contains('signature invalid'));
    store.dispose();
  });

  test('invalid Ed25519 key and signature lengths are rejected', () async {
    final envelope = {
      'signed': {
        'latest_version': '1.4.0',
        'minimum_supported_version': '1.0.0',
      },
      'signature': base64UrlEncode(List<int>.filled(8, 1)),
    };

    await expectLater(
      verifyUpdateManifestEnvelope(
        envelope,
        publicKey: base64UrlEncode(List<int>.filled(8, 2)),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'unsigned manifest is rejected when release policy is enabled',
    () async {
      final store = UpdateStore(
        client: MockClient(
          (_) async => _manifest({
            'latest_version': '1.4.0',
            'minimum_supported_version': '1.0.0',
          }),
        ),
        currentVersion: '1.0.0',
        currentBuild: '1',
        allowUnsignedManifest: false,
      );

      expect(await store.check(force: true), isFalse);
      expect(store.error, contains('signed update manifest required'));
      store.dispose();
    },
  );

  test('initialize re-verifies cached signed envelope', () async {
    final signed = await _signedManifest({
      'latest_version': '1.4.0',
      'minimum_supported_version': '1.0.0',
    });
    final first = UpdateStore(
      client: MockClient((_) async => _manifest(signed.envelope)),
      currentVersion: '1.0.0',
      currentBuild: '1',
      manifestPublicKey: signed.publicKey,
      allowUnsignedManifest: false,
    );
    expect(await first.check(force: true), isTrue);
    first.dispose();

    final cached =
        jsonDecode(
              (await SharedPreferences.getInstance()).getString(
                'hm_update_manifest_v1',
              )!,
            )
            as Map<String, dynamic>;
    (cached['signed'] as Map<String, dynamic>)['latest_version'] = '9.9.9';
    await (await SharedPreferences.getInstance()).setString(
      'hm_update_manifest_v1',
      jsonEncode(cached),
    );

    final second = UpdateStore(
      client: MockClient((_) async => http.Response('', 500)),
      currentVersion: '1.0.0',
      currentBuild: '1',
      manifestPublicKey: signed.publicKey,
      allowUnsignedManifest: false,
    );
    await second.initialize();

    expect(second.manifest, isNull);
    second.dispose();
  });
}
