import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/app_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers the bundled Hermes Mobile license', () async {
    registerAppLicenses();

    final entry = await LicenseRegistry.licenses.firstWhere(
      (candidate) => candidate.packages.contains(appLicensePackageName),
    );
    final text = entry.paragraphs.map((paragraph) => paragraph.text).join('\n');

    expect(text, contains('MIT License'));
    expect(text, contains('Copyright (c) 2026 Hermes Mobile'));
    expect(
      text,
      contains('THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY'),
    );
  });
}
