import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/model_catalog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/widgets/model_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final refreshCalls = <bool>[];

  @override
  Future<ModelCatalog> modelCatalog({bool refresh = false}) async {
    refreshCalls.add(refresh);
    return const ModelCatalog(
      currentProvider: 'zeta',
      currentModel: 'current',
      providers: [
        ModelInfo(
          slug: 'beta',
          name: 'Zulu',
          isCurrent: false,
          models: ['other'],
        ),
        ModelInfo(
          slug: 'zeta',
          name: 'Alpha',
          isCurrent: true,
          models: ['current'],
          pricing: {'current': ModelPricing(free: true)},
        ),
        ModelInfo(slug: 'moa', name: 'MoA', isCurrent: false, models: ['fast']),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Liquid model highlights the current row and keeps refresh working',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeApi();
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.dark,
            visualStyle: HermesVisualStyle.liquid,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ModelPickerSheet(
              api: api,
              initialCatalog: await api.modelCatalog(),
              visibilityStore: ModelVisibilityStore(preferences),
            ),
          ),
        ),
      );
      final row = find.ancestor(
        of: find.text('current'),
        matching: find.byType(ListTile),
      );
      expect(tester.widget<ListTile>(row).selected, isTrue);
      final free = find.descendant(of: row, matching: find.text('Free'));
      expect(free, findsOneWidget);
      expect(
        tester.widget<Text>(free).style!.color,
        Theme.of(tester.element(free)).colorScheme.onPrimaryContainer,
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh models'));
      await tester.pumpAndSettle();
      expect(api.refreshCalls, [false, true]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('picker separates MoA and refreshes catalog with refresh=true', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _FakeApi();
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ModelPickerSheet(
            api: api,
            initialCatalog: await api.modelCatalog(),
            visibilityStore: ModelVisibilityStore(preferences),
          ),
        ),
      ),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Zulu'), findsOneWidget);
    expect(find.text('MoA presets'), findsOneWidget);
    expect(find.text('MoA: fast'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh models'));
    await tester.pumpAndSettle();

    expect(api.refreshCalls, [false, true]);
  });
}
