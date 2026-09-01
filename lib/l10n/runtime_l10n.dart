import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';

/// Localized copy for event/store code that has no BuildContext.
///
/// UI code should still prefer `context.l10n`. The context extension keeps
/// this reference synchronized whenever a localized surface is built.
abstract final class RuntimeL10n {
  static AppLocalizations _current = AppLocalizationsEn();

  static AppLocalizations get current => _current;

  static void use(AppLocalizations value) => _current = value;
}

AppLocalizations get runtimeL10n => RuntimeL10n.current;
