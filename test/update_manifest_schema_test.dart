import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/update_manifest_crypto.dart';
import 'package:hermes_mobile/core/update_manifest_schema.dart';

Map<String, dynamic> _payload({
  String version = '1.2.0',
  int androidBuild = 12,
  int iosBuild = 12,
  bool artifacts = true,
}) => {
  'schema_version': 2,
  'latest_version': version,
  'minimum_supported_version': '1.0.0',
  'release_notes_url': 'https://example.test/releases/$version',
  'android': {
    'build': androidBuild,
    'minimum_build': 1,
    'url': 'https://play.google.com/store/apps/details?id=com.hermes.mobile',
    if (artifacts) ...{
      'artifact_url': 'https://example.test/hermes-mobile.apk',
      'sha256': 'a' * 64,
      'size_bytes': 1024,
    },
  },
  'ios': {
    'build': iosBuild,
    'minimum_build': 1,
    'url': 'https://apps.apple.com/app/hermes-mobile/id0000000000',
    if (artifacts) ...{
      'artifact_url': 'https://example.test/HermesMobile.ipa',
      'sha256': 'b' * 64,
      'size_bytes': 2048,
    },
  },
};

void main() {
  test('source template may omit release artifact metadata', () {
    expect(
      () => validateUpdateManifestPayload(
        _payload(artifacts: false),
        requireArtifacts: false,
      ),
      returnsNormally,
    );
  });

  test('published manifest requires complete artifact integrity metadata', () {
    final payload = _payload();
    expect(() => validateUpdateManifestPayload(payload), returnsNormally);

    (payload['android'] as Map).remove('sha256');
    expect(
      () => validateUpdateManifestPayload(payload),
      throwsA(isA<FormatException>()),
    );
  });

  test('minimum build cannot exceed released build', () {
    final payload = _payload();
    (payload['ios'] as Map)['minimum_build'] = 13;
    expect(
      () => validateUpdateManifestPayload(payload),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('cannot exceed'),
        ),
      ),
    );
  });

  test('release monotonicity checks version and platform builds', () {
    final previous = _payload(version: '1.2.0', androidBuild: 12, iosBuild: 12);
    expect(
      () => validateUpdateManifestPayload(
        _payload(version: '1.3.0', androidBuild: 13, iosBuild: 13),
        previous: previous,
      ),
      returnsNormally,
    );
    expect(
      () => validateUpdateManifestPayload(
        _payload(version: '1.1.0', androidBuild: 13, iosBuild: 13),
        previous: previous,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => validateUpdateManifestPayload(
        _payload(version: '1.3.0', androidBuild: 12, iosBuild: 13),
        previous: previous,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('signing and verification use the same canonical payload', () async {
    final privateKey = base64UrlNoPadding(List<int>.generate(32, (i) => i));
    final payload = _payload();
    final signed = await signUpdateManifestPayload(
      payload,
      privateKey: privateKey,
    );

    final verified = await verifyUpdateManifestEnvelope(
      signed.envelope,
      publicKey: signed.publicKey,
    );
    expect(canonicalJson(verified), canonicalJson(payload));
    expect(signed.keyId, hasLength(16));

    final tampered =
        jsonDecode(jsonEncode(signed.envelope)) as Map<String, dynamic>;
    (tampered['signed'] as Map<String, dynamic>)['latest_version'] = '9.9.9';
    await expectLater(
      verifyUpdateManifestEnvelope(tampered, publicKey: signed.publicKey),
      throwsA(isA<FormatException>()),
    );
  });
}
