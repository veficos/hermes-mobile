import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/plugin_contribution_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/knowledge_screen.dart';
import 'package:hermes_mobile/screens/plugins_screen.dart';
import 'package:provider/provider.dart';

void main() {
  for (final screen in <Widget>[
    const PluginsScreen(),
    const KnowledgeScreen(),
  ]) {
    testWidgets('${screen.runtimeType} renders at 320px Arabic RTL and 2x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      await _pump(tester, screen);

      expect(find.byType(screen.runtimeType), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('knowledge detail remains scrollable with large Arabic text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, const KnowledgeScreen());
    await tester.tap(find.text('Node one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  final connection = ConnectionStore()..api = _SurfaceApi();
  final scope = ProfileScopeStore();
  final contributions = PluginContributionStore(connection);
  addTearDown(() {
    contributions.dispose();
    scope.dispose();
    connection.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider<ProfileScopeStore>.value(value: scope),
        ChangeNotifierProvider<PluginContributionStore>.value(
          value: contributions,
        ),
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
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SurfaceApi extends ApiClient {
  _SurfaceApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<List<Map<String, dynamic>>> plugins({String? profile}) async => [
    {
      'id': 'plugin-one',
      'name': 'A long plugin name for narrow layout coverage',
      'description': 'Plugin description',
      'version': '1.0.0',
      'key': 'providers/example',
      'enabled': true,
    },
  ];

  @override
  Future<Map<String, dynamic>> knowledgeGraph() async => {
    'nodes': [
      {
        'id': 'node-one',
        'label': 'Node one',
        'kind': 'skill',
        'category': 'testing',
        'useCount': 3,
        'state': 'active',
      },
    ],
    'memory': const [],
  };

  @override
  Future<Map<String, dynamic>> knowledgeNode(String id) async => {
    'content': List.filled(20, 'Long editable content').join('\n'),
  };
}
