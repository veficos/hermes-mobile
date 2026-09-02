import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/screens/config_center_screen.dart';
import 'package:provider/provider.dart';

class _MutationApi extends ApiClient {
  _MutationApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> mcpServers({String? profile}) async => [
    {
      'id': 'mcp-1',
      'name': 'docs',
      'transport': 'stdio',
      'command': 'docs-server',
      'enabled': true,
    },
  ];

  @override
  Future<List<SkillInfo>> skills({String? profile}) async => [
    SkillInfo(name: 'review', description: 'Review changes', enabled: true),
  ];

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [];

  @override
  Future<List<Map<String, dynamic>>> plugins({String? profile}) async => [
    {
      'id': 'plugin-1',
      'name': 'reviewer',
      'version': '1.0.0',
      'enabled': true,
      'installed': true,
    },
  ];

  @override
  Future<Map<String, dynamic>> knowledgeGraph() async => {
    'nodes': [
      {'id': 'node-1', 'name': 'Notes', 'type': 'file', 'indexed': true},
    ],
  };

  @override
  Future<void> mcpSetEnabled(
    String name,
    bool enabled, {
    String? profile,
  }) async {
    calls.add('mcp-toggle:$name:$enabled');
  }

  @override
  Future<Map<String, dynamic>> mcpCreate(
    Map<String, dynamic> server, {
    String? profile,
  }) async {
    calls.add('mcp-create:${server['name']}');
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> knowledgeNodeDelete(String id) async {
    calls.add('knowledge-delete:$id');
    return {'ok': true};
  }

  @override
  Future<void> setPluginEnabled(
    String name,
    bool enabled, {
    String? profile,
  }) async {
    calls.add('plugin-toggle:$name:$enabled');
  }

  @override
  Future<void> toggleSkill(String name, bool enabled, {String? profile}) async {
    calls.add('skill-toggle:$name:$enabled');
  }
}

class _MutationConnection extends ConnectionStore {
  final List<String> installCalls = [];

  void exposeApi(ApiClient? next) {
    api = next;
    notifyListeners();
  }

  @override
  Future<Map<String, dynamic>> installPlugin(
    String identifier, {
    bool force = false,
    bool enable = true,
    String? profile,
  }) async {
    installCalls.add(identifier);
    return {'ok': true};
  }
}

class _LoadFailureApi extends _MutationApi {
  @override
  Future<Map<String, dynamic>> knowledgeGraph() async {
    throw StateError('knowledge load failed');
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _MutationConnection connection,
  _MutationApi api,
) async {
  connection.api = api;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider(
          create: (_) => ProfileScopeStore()..bindApi(api),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ConfigCenterScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final zh = AppLocalizationsZh();

  testWidgets('capability center delegates canonical management surfaces', (
    tester,
  ) async {
    final api = _MutationApi();
    final connection = _MutationConnection();
    addTearDown(connection.dispose);
    await _pumpScreen(tester, connection, api);

    expect(find.byType(Switch), findsNothing);
    expect(find.text(zh.commonOpen), findsOneWidget);

    await tester.tap(find.text(zh.configCenterKnowledgeTab));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(zh.commonDelete).first);
    await tester.pumpAndSettle();
    expect(api.calls, contains('knowledge-delete:node-1'));

    await tester.tap(find.text(zh.featureSkills));
    await tester.pumpAndSettle();
    expect(find.text(zh.commonOpen), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    await tester.tap(find.text(zh.featurePlugins));
    await tester.pumpAndSettle();
    expect(find.text(zh.commonOpen), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('load failure renders an error instead of an empty state', (
    tester,
  ) async {
    final api = _LoadFailureApi();
    final connection = _MutationConnection();
    addTearDown(connection.dispose);
    await _pumpScreen(tester, connection, api);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('knowledge load failed'), findsWidgets);
    expect(find.text(zh.commonRetry), findsOneWidget);
  });
}
