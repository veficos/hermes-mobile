import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_palette_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/core/stores/pet_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_appearance_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/app_shell.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ShellStores {
  _ShellStores() {
    connection.settings = const ConnectionSettings(
      serverUrl: 'https://shell.invalid',
      apiKey: 'test',
    );
  }

  final ConnectionStore connection = ConnectionStore();
  final ChatStore chat = ChatStore();
  final RequestStore requests = RequestStore();
  late final SessionStore sessions = SessionStore(
    connection: connection,
    chat: chat,
    requests: requests,
  );
  late final NotificationStore notifications = NotificationStore(
    connection: connection,
  );
  late final PetStore pet = PetStore(connection: connection);
  late final VoiceStore voice = VoiceStore(connection: connection);
  late final CommandStore commands = CommandStore(connection: connection);
  late final CommandPaletteStore palette = CommandPaletteStore(
    session: sessions,
    commands: commands,
  );
  final SessionAppearanceStore sessionAppearance = SessionAppearanceStore();

  List<SingleChildWidget> get providers => [
    ChangeNotifierProvider<ConnectionStore>.value(value: connection),
    ChangeNotifierProvider<ChatStore>.value(value: chat),
    ChangeNotifierProvider<RequestStore>.value(value: requests),
    ChangeNotifierProvider<SessionStore>.value(value: sessions),
    ChangeNotifierProvider<NotificationStore>.value(value: notifications),
    ChangeNotifierProvider<PetStore>.value(value: pet),
    ChangeNotifierProvider<VoiceStore>.value(value: voice),
    ChangeNotifierProvider<CommandStore>.value(value: commands),
    ChangeNotifierProvider<CommandPaletteStore>.value(value: palette),
    ChangeNotifierProvider<SessionAppearanceStore>.value(
      value: sessionAppearance,
    ),
  ];

  void dispose() {
    sessionAppearance.dispose();
    voice.dispose();
    pet.dispose();
    notifications.dispose();
    sessions.dispose();
    requests.dispose();
    chat.dispose();
    commands.dispose();
    palette.dispose();
    connection.dispose();
  }
}

Widget _app(_ShellStores stores, {required TextScaler textScaler}) {
  return MultiProvider(
    providers: stores.providers,
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const AppShell(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'hm_onboarding_seen_v1': true});
  });

  testWidgets('AppShell supports Arabic RTL, responsive widths, and scaling', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cases = <({Size size, TextScaler scaler, String navigationKey})>[
      (
        size: const Size(320, 640),
        scaler: const TextScaler.linear(2),
        navigationKey: 'app-shell-phone-navigation',
      ),
      (
        size: const Size(900, 700),
        scaler: const TextScaler.linear(1.6),
        navigationKey: 'app-shell-tablet-navigation',
      ),
      (
        size: const Size(1280, 800),
        scaler: const TextScaler.linear(1.6),
        navigationKey: 'app-shell-xl-navigation',
      ),
    ];

    for (final testCase in cases) {
      tester.view.physicalSize = testCase.size;
      tester.view.devicePixelRatio = 1;
      final stores = _ShellStores();

      await tester.pumpWidget(_app(stores, textScaler: testCase.scaler));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey(testCase.navigationKey)), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
      expect(find.text('الرئيسية'), findsWidgets);
      expect(
        tester.takeException(),
        isNull,
        reason: 'unexpected layout error at ${testCase.size}',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      stores.dispose();
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    semantics.dispose();
  });
}
