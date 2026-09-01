import 'dart:io';

import 'package:hermes_mobile/core/update_manifest_crypto.dart';

Future<void> main() async {
  final privateKey =
      Platform.environment['HERMES_MOBILE_UPDATE_PRIVATE_KEY']?.trim() ?? '';
  if (privateKey.isEmpty) {
    stderr.writeln(
      'HERMES_MOBILE_UPDATE_PRIVATE_KEY must contain a base64-encoded '
      '32-byte Ed25519 seed.',
    );
    exitCode = 1;
    return;
  }
  try {
    final info = await signUpdateManifestPayload(
      const <String, dynamic>{},
      privateKey: privateKey,
    );
    stdout.writeln('HERMES_MOBILE_UPDATE_PUBLIC_KEY=${info.publicKey}');
    stdout.writeln('key_id=${info.keyId}');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
