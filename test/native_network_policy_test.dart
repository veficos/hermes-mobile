import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release denies cleartext except named local companions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final config = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(config, contains('<base-config cleartextTrafficPermitted="false"'));
    expect(config, contains('>localhost</domain>'));
    expect(config, contains('>127.0.0.1</domain>'));
    expect(config, contains('>10.0.2.2</domain>'));
    expect(config, contains('includeSubdomains="true">local</domain>'));
    expect(config, isNot(contains('192.168.')));
  });

  test('Android debug and profile retain development cleartext access', () {
    for (final mode in ['debug', 'profile']) {
      final manifest = File(
        'android/app/src/$mode/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:usesCleartextTraffic="true"'));
      expect(
        manifest,
        contains('tools:remove="android:networkSecurityConfig"'),
      );
    }
  });

  test('iOS allows local networking without arbitrary cleartext loads', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final atsStart = plist.indexOf('<key>NSAppTransportSecurity</key>');
    final atsEnd = plist.indexOf('</dict>', atsStart);
    expect(atsStart, greaterThanOrEqualTo(0));
    expect(atsEnd, greaterThan(atsStart));
    final ats = plist.substring(atsStart, atsEnd);

    expect(ats, contains('<key>NSAllowsArbitraryLoads</key>'));
    expect(ats, contains('<false/>'));
    expect(ats, contains('<key>NSAllowsLocalNetworking</key>'));
    expect(ats, contains('<true/>'));
  });
}
