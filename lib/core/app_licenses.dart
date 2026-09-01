import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const appLicensePackageName = 'Hermes Mobile';

bool _registered = false;

void registerAppLicenses() {
  if (_registered) return;
  _registered = true;

  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(const [appLicensePackageName], text);
  });
}
