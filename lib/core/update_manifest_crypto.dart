import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

String canonicalJson(Object? value) {
  Object? canonical(Object? input) {
    if (input is Map) {
      final keys = input.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: canonical(input[key]),
      };
    }
    if (input is List) return input.map(canonical).toList(growable: false);
    return input;
  }

  return jsonEncode(canonical(value));
}

String base64UrlNoPadding(List<int> bytes) =>
    base64UrlEncode(bytes).replaceAll('=', '');

List<int> decodeBase64Key(String value, {required String field}) {
  final normalized = value.trim();
  try {
    return base64Url.decode(base64Url.normalize(normalized));
  } on FormatException {
    try {
      return base64.decode(base64.normalize(normalized));
    } on FormatException {
      throw FormatException('$field is not valid base64');
    }
  }
}

Future<Map<String, dynamic>> verifyUpdateManifestEnvelope(
  Map<String, dynamic> envelope, {
  required String publicKey,
  bool allowUnsigned = false,
}) async {
  if (!envelope.containsKey('signed')) {
    if (allowUnsigned) return envelope;
    throw const FormatException('signed update manifest required');
  }
  final signed = envelope['signed'];
  if (signed is! Map) throw const FormatException('signed must be an object');
  final signatureText = envelope['signature']?.toString().trim() ?? '';
  if (publicKey.trim().isEmpty) {
    throw const FormatException('update manifest public key is not configured');
  }
  final keyBytes = decodeBase64Key(publicKey, field: 'public key');
  final signatureBytes = decodeBase64Key(
    signatureText,
    field: 'update manifest signature',
  );
  if (keyBytes.length != 32 || signatureBytes.length != 64) {
    throw const FormatException('invalid Ed25519 key or signature length');
  }
  final payload = signed.cast<String, dynamic>();
  final valid = await Ed25519().verify(
    utf8.encode(canonicalJson(payload)),
    signature: Signature(
      signatureBytes,
      publicKey: SimplePublicKey(keyBytes, type: KeyPairType.ed25519),
    ),
  );
  if (!valid) throw const FormatException('update manifest signature invalid');
  return payload;
}

Future<({Map<String, dynamic> envelope, String publicKey, String keyId})>
signUpdateManifestPayload(
  Map<String, dynamic> payload, {
  required String privateKey,
}) async {
  final seed = decodeBase64Key(privateKey, field: 'private key');
  if (seed.length != 32) {
    throw const FormatException('Ed25519 private key seed must be 32 bytes');
  }
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(seed);
  final publicKey = await keyPair.extractPublicKey();
  final signature = await algorithm.sign(
    utf8.encode(canonicalJson(payload)),
    keyPair: keyPair,
  );
  final publicKeyText = base64UrlNoPadding(publicKey.bytes);
  final keyId = crypto.sha256
      .convert(publicKey.bytes)
      .toString()
      .substring(0, 16);
  return (
    envelope: <String, dynamic>{
      'signed': payload,
      'signature': base64UrlNoPadding(signature.bytes),
      'key_id': keyId,
    },
    publicKey: publicKeyText,
    keyId: keyId,
  );
}
