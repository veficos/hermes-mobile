import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_palette_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_ar.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('palette rebuilds navigation entries and search index for locale', () {
    final connection = ConnectionStore();
    final chat = ChatStore();
    final requests = RequestStore();
    final sessions = SessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
    );
    final commands = CommandStore(connection: connection);
    final palette = CommandPaletteStore(session: sessions, commands: commands);
    addTearDown(palette.dispose);
    addTearDown(sessions.dispose);
    addTearDown(requests.dispose);
    addTearDown(chat.dispose);
    addTearDown(connection.dispose);

    palette.setLocalizations(AppLocalizationsEn());
    palette.open();
    expect(palette.results.any((result) => result.title == 'Settings'), isTrue);
    palette.setQuery('settings');
    expect(palette.results.map((result) => result.title), contains('Settings'));

    palette.setLocalizations(AppLocalizationsAr());
    expect(
      palette.results.any((result) => result.title == 'Settings'),
      isFalse,
    );
    palette.setQuery('الإعدادات');
    expect(
      palette.results.map((result) => result.title),
      contains('الإعدادات'),
    );
    expect(
      palette.results
          .singleWhere((result) => result.title == 'الإعدادات')
          .routeName,
      'settings',
    );
  });
}
