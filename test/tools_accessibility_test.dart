import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/tools_screen.dart';
import 'package:provider/provider.dart';

class _ToolsApi extends ApiClient {
  _ToolsApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [
    ToolsetInfo(
      name: 'a-very-long-toolset-name-for-narrow-layout',
      enabled: true,
      toolCount: 42,
    ),
  ];

  @override
  Future<Map<String, dynamic>> terminalBackends({String? profile}) async => {
    'active': 'local',
    'backends': <dynamic>[
      {
        'name': 'local',
        'label': 'A very long terminal backend label',
        'description': 'A long backend description for narrow layout coverage',
        'status': 'ready',
      },
    ],
  };
}

void main() {
  testWidgets('tools render at 320px Arabic RTL and 2x', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final connection = ConnectionStore()..api = _ToolsApi();
    final scope = ProfileScopeStore();
    addTearDown(scope.dispose);
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<ProfileScopeStore>.value(value: scope),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const ToolsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A very long terminal backend label'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(ToolsScreen)));
    expect(find.byTooltip(l10n.commonRefresh), findsWidgets);
    expect(tester.takeException(), isNull);

    final toolset = find.text('a-very-long-toolset-name-for-narrow-layout');
    await tester.scrollUntilVisible(toolset, 200);
    expect(toolset, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
