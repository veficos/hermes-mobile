import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/appearance_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/locale_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/core/stores/terminal_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/schema_config_screen.dart';
import 'package:hermes_mobile/screens/settings_hub_screen.dart';
import 'package:hermes_mobile/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('settings hub renders localized English navigation', (
    tester,
  ) async {
    await _pumpSettings(tester, locale: const Locale('en'));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Personalization'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('个性化'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic settings use RTL and tolerate 1.6x text', (tester) async {
    await _pumpSettings(
      tester,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(1.6),
    );

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
    expect(find.text('التخصيص'), findsOneWidget);
    expect(find.text('المظهر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system settings render English without Chinese fallbacks', (
    tester,
  ) async {
    await _pumpLocalizedScreen(
      tester,
      locale: const Locale('en'),
      child: const SettingsScreen(),
      includeTerminal: true,
    );

    expect(find.text('System and connection'), findsOneWidget);
    expect(find.text('Terminal font'), findsOneWidget);
    expect(find.text('Change connection'), findsOneWidget);
    expect(find.text('系统与连接'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system settings expose config loading failures', (tester) async {
    final connection = ConnectionStore()..api = _FailingConfigApi();
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider(
            create: (_) => TerminalStore(connection: connection),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('config unavailable'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
  });

  testWidgets('Arabic system settings tolerate RTL and 1.6x text', (
    tester,
  ) async {
    await _pumpLocalizedScreen(
      tester,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(1.6),
      child: const SettingsScreen(),
      includeTerminal: true,
    );

    expect(find.text('النظام والاتصال'), findsOneWidget);
    expect(find.text('خط الطرفية'), findsOneWidget);
    expect(find.text('تغيير الاتصال'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schema config scope and loading state localize to Arabic', (
    tester,
  ) async {
    await _pumpLocalizedScreen(
      tester,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(1.6),
      child: const SchemaConfigScreen(),
      includeProfileScope: true,
      settle: false,
    );

    expect(find.text('الاتصال'), findsOneWidget);
    expect(find.text('ينطبق على ملف التعريف'), findsOneWidget);
    expect(find.text('جارٍ تحميل الإعداد وschema…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FailingConfigApi extends ApiClient {
  _FailingConfigApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test-key');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    throw ApiException(503, 'config unavailable');
  }
}

Future<void> _pumpLocalizedScreen(
  WidgetTester tester, {
  required Locale locale,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
  bool includeTerminal = false,
  bool includeProfileScope = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final connection = ConnectionStore();
  addTearDown(connection.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            if (includeTerminal)
              ChangeNotifierProvider(
                create: (_) => TerminalStore(connection: connection),
              ),
            if (includeProfileScope)
              ChangeNotifierProvider(create: (_) => ProfileScopeStore()),
          ],
          child: child,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required Locale locale,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final localeStore = LocaleStore();
  await localeStore.setLocale(locale);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppearanceStore()),
            ChangeNotifierProvider.value(value: localeStore),
          ],
          child: const SettingsHubScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
