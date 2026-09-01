import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/ssh_gateway_tunnel_io.dart';

void main() {
  const ownership = '0123456789abcdef0123456789abcdef';
  const nonce = '0123456789abcdef';

  Map<String, dynamic> validLock() => {
    'schemaVersion': 2,
    'protocolVersion': 1,
    'ownershipId': ownership,
    'spawnNonce': nonce,
    'pid': 1234,
    'port': 45123,
    'profile': 'work',
    'hermesPath': '/home/user/.local/bin/hermes',
    'hermesHome': '/home/user/.hermes',
    'logPath': '~/.hermes/desktop-ssh/$ownership/$nonce.log',
    'tokenFingerprint': 'a' * 32,
    'startedAt': '2026-08-29T00:00:00.000Z',
  };

  test('ownership artifacts use the secure Desktop SSH namespace', () {
    expect(
      sshOwnershipDirectoryForTesting(ownership),
      '~/.hermes/desktop-ssh/$ownership',
    );
    expect(
      sshSpawnTokenPathForTesting(ownership, nonce),
      '~/.hermes/desktop-ssh/$ownership/$nonce.token',
    );
  });

  test('lock parser accepts only a complete scoped identity', () {
    expect(sshParseRemoteLockForTesting(validLock(), ownership), isNotNull);

    for (final invalid in <Map<String, dynamic>>[
      {...validLock(), 'pid': 0},
      {...validLock(), 'port': 65536},
      {...validLock(), 'ownershipId': 'f' * 32},
      {...validLock(), 'spawnNonce': 'short'},
      {...validLock(), 'tokenFingerprint': 'raw-secret'},
      {...validLock(), 'protocolVersion': 99},
      {...validLock(), 'logPath': '~/.hermes/desktop-ssh/foreign.log'},
    ]) {
      expect(
        sshParseRemoteLockForTesting(invalid, ownership),
        isNull,
        reason: '$invalid',
      );
    }
  });

  test('token fingerprint is truncated SHA-256 and never stores the token', () {
    const token =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final fingerprint = sshFingerprintTokenForTesting(token);

    expect(fingerprint, hasLength(32));
    expect(fingerprint, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(fingerprint, isNot(contains(token)));
  });

  test('PowerShell commands use UTF-16LE encoded command payloads', () {
    const script = r'$value="Hermes";Write-Output $value';
    final command = sshPowerShellCommandForTesting(script);
    final encoded = command.split(' ').last;
    final bytes = base64.decode(encoded);
    final units = <int>[
      for (var i = 0; i < bytes.length; i += 2) bytes[i] | (bytes[i + 1] << 8),
    ];

    expect(String.fromCharCodes(units), script);
    expect(command, contains('-NoProfile -NonInteractive'));
  });
}
