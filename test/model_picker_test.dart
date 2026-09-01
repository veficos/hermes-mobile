import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/model_catalog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/widgets/model_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        ),
        ModelInfo(slug: 'moa', name: 'MoA', isCurrent: false, models: ['fast']),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
