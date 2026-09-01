import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/appearance_store.dart';
import 'package:hermes_mobile/core/stores/locale_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('locale tags normalize supported values and reject invalid values', () {
    expect(LocaleStore.localeFromTag(null), isNull);
    expect(LocaleStore.localeFromTag('system'), isNull);
    expect(LocaleStore.localeFromTag('unsupported'), isNull);
    expect(
      LocaleStore.localeFromTag('zh-Hant'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
    expect(
      LocaleStore.localeTag(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      'zh_Hant',
    );
  });

  test('locale preference persists and system removes the override', () async {
    final store = LocaleStore();
    await store.setLocale(const Locale('ja'));

    final restored = LocaleStore();
    await restored.load();
    expect(restored.locale, const Locale('ja'));
    expect(restored.tag, 'ja');

    await restored.setLocale(null);
    final system = LocaleStore();
    await system.load();
    expect(system.locale, isNull);
    expect(system.tag, 'system');
  });

  test('invalid persisted locale safely falls back to system', () async {
    SharedPreferences.setMockInitialValues({
      'hm_display_locale_v1': 'not-a-locale',
    });
    final store = LocaleStore();
    await store.load();

    expect(store.loaded, isTrue);
    expect(store.locale, isNull);
  });

  test('system theme mode survives a store reload', () async {
    final appearance = AppearanceStore();
    await appearance.setThemeMode(ThemeMode.system);

    final restored = AppearanceStore();
    await restored.load();
    expect(restored.themeMode, ThemeMode.system);
  });

  testWidgets('changing locale immediately rebuilds localized content', (
    tester,
  ) async {
    final store = LocaleStore();
    await store.setLocale(
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    await tester.pumpWidget(_LocalizedHarness(store: store));
    await tester.pumpAndSettle();
    expect(find.text('首頁'), findsOneWidget);

    await store.setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('首頁'), findsNothing);
  });

  testWidgets('Arabic locale applies RTL directionality', (tester) async {
    final store = LocaleStore();
    await store.setLocale(const Locale('ar'));

    await tester.pumpWidget(_LocalizedHarness(store: store));
    await tester.pumpAndSettle();
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('rtl'), findsOneWidget);
  });
}

class _LocalizedHarness extends StatelessWidget {
  const _LocalizedHarness({required this.store});

  final LocaleStore store;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LocaleStore>.value(
      value: store,
      child: Consumer<LocaleStore>(
        builder: (context, locale, _) => MaterialApp(
          locale: locale.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Column(
              children: [
                Text(context.l10n.navHome),
                Text(Directionality.of(context).name),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
