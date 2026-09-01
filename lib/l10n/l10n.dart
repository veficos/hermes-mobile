import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'generated/app_localizations_zh.dart';
import 'runtime_l10n.dart';

export 'generated/app_localizations.dart';

extension HermesLocalizations on BuildContext {
  AppLocalizations get l10n {
    final value =
        Localizations.of<AppLocalizations>(this, AppLocalizations) ??
        AppLocalizationsZh();
    RuntimeL10n.use(value);
    return value;
  }
}
