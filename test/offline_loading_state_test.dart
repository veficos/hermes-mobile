import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/model_catalog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/bot_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/plugin_contribution_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/terminal_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/agent_screen.dart';
import 'package:hermes_mobile/screens/cron_screen.dart';
import 'package:hermes_mobile/screens/config_screen.dart';
import 'package:hermes_mobile/screens/history_screen.dart';
import 'package:hermes_mobile/screens/insights_screen.dart';
import 'package:hermes_mobile/screens/knowledge_screen.dart';
import 'package:hermes_mobile/screens/memory_screen.dart';
import 'package:hermes_mobile/screens/mcp_screen.dart';
import 'package:hermes_mobile/screens/plugins_screen.dart';
import 'package:hermes_mobile/screens/skill_hub_screen.dart';
import 'package:hermes_mobile/screens/skills_screen.dart';
import 'package:hermes_mobile/screens/settings_screen.dart';
import 'package:hermes_mobile/screens/starmap_screen.dart';
import 'package:hermes_mobile/screens/tools_screen.dart';
import 'package:hermes_mobile/screens/webhooks_screen.dart';
import 'package:provider/provider.dart';

class _ReloadApi extends ApiClient {
  _ReloadApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<List<SkillInfo>> skills({String? profile}) async => [];

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [];

  @override
  Future<Map<String, dynamic>> terminalBackends({String? profile}) async => {};

  @override
  Future<List<Map<String, dynamic>>> plugins({String? profile}) async => [];

  @override
  Future<List<Map<String, dynamic>>> mcpServers({String? profile}) async => [];

  @override
  Future<List<Map<String, dynamic>>> mcpCatalog({String? profile}) async => [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String?>? query,
    Duration? timeout,
  }) async => {
    'totals': <String, dynamic>{},
    'daily': <dynamic>[],
    'by_model': <dynamic>[],
    'tools': <dynamic>[],
  };

  @override
  Future<SkillHubSources> skillHubSources() async => SkillHubSources(
    sources: const [],
    indexAvailable: false,
    featured: const [],
    installed: const {},
  );

  @override
  Future<Map<String, dynamic>> status() async => {
    'backend': <String, dynamic>{'running': true},
    'runtime': <String, dynamic>{},
    'server': <String, dynamic>{},
  };

  @override
  Future<({String baseUrl, bool enabled, List<Webhook> items})>
  webhooks() async => (items: const <Webhook>[], enabled: true, baseUrl: '');

  @override
  Future<Map<String, dynamic>> memoryStatus({String? profile}) async => {
    'providers': <dynamic>[],
    'builtin_files': <String, dynamic>{},
  };

  @override
  Future<Map<String, dynamic>> curatorStatus() async => {};

  @override
  Future<Map<String, dynamic>> knowledgeGraph() async => {
    'nodes': <dynamic>[],
    'memory': <dynamic>[],
  };

  @override
  Future<List<CronJob>> cronJobs() async => const [];

  @override
  Future<StarmapGraph> starmapGraph() async => StarmapGraph();

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async =>
      SessionPage(sessions: const [], total: 0, offset: offset, hasMore: false);
}

class _ReloadConnection extends ConnectionStore {
  void exposeApi(ApiClient? next) {
    api = next;
    notifyListeners();
  }
}

class _DeferredWebhookEnableApi extends _ReloadApi {
  final enabled = Completer<Map<String, dynamic>>();

  @override
  Future<({String baseUrl, bool enabled, List<Webhook> items})>
  webhooks() async => (items: const <Webhook>[], enabled: false, baseUrl: '');

  @override
  Future<Map<String, dynamic>> enableWebhooks() => enabled.future;
}

class _DetailSkillApi extends _ReloadApi {
  @override
  Future<List<SkillInfo>> skills({String? profile}) async => [
    SkillInfo(
      name: 'offline-detail',
      description: 'Detail reconnect coverage',
      enabled: true,
      category: 'test',
    ),
  ];
}

class _DeferredKnowledgeApi extends _ReloadApi {
  final graph = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> knowledgeGraph() => graph.future;
}

class _NamedKnowledgeApi extends _ReloadApi {
  _NamedKnowledgeApi(this.label);

  final String label;

  @override
  Future<Map<String, dynamic>> knowledgeGraph() async => {
    'nodes': <dynamic>[
      {'id': label, 'label': label, 'kind': 'skill'},
    ],
    'memory': <dynamic>[],
  };
}

class _DeferredCronApi extends _ReloadApi {
  final jobs = Completer<List<CronJob>>();

  @override
  Future<List<CronJob>> cronJobs() => jobs.future;
}

class _NamedCronApi extends _ReloadApi {
  _NamedCronApi(this.label);

  final String label;

  @override
  Future<List<CronJob>> cronJobs() async => [
    CronJob(id: label, name: label, enabled: true),
  ];
}

class _DeferredSkillsApi extends _ReloadApi {
  final result = Completer<List<SkillInfo>>();

  @override
  Future<List<SkillInfo>> skills({String? profile}) => result.future;
}

class _NamedSkillsApi extends _ReloadApi {
  _NamedSkillsApi(this.label);

  final String label;

  @override
  Future<List<SkillInfo>> skills({String? profile}) async => [
    SkillInfo(name: label, enabled: true),
  ];
}

class _DeferredToolsApi extends _ReloadApi {
  final result = Completer<List<ToolsetInfo>>();

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) => result.future;
}

class _NamedToolsApi extends _ReloadApi {
  _NamedToolsApi(this.label);

  final String label;

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [
    ToolsetInfo(name: label, enabled: true),
  ];
}

class _DeferredConfigApi extends _ReloadApi {
  final result = Completer<ModelCatalog>();

  @override
  Future<ModelCatalog> modelCatalog({bool refresh = false}) => result.future;
}

class _NamedConfigApi extends _ReloadApi {
  _NamedConfigApi(this.label);

  final String label;

  @override
  Future<ModelCatalog> modelCatalog({bool refresh = false}) async =>
      ModelCatalog(
        currentProvider: label,
        currentModel: '$label-model',
        providers: [
          ModelInfo(
            slug: label,
            name: label,
            isCurrent: true,
            models: ['$label-model'],
          ),
        ],
      );
}

class _DeferredSkillHubApi extends _ReloadApi {
  final result = Completer<SkillHubSearchResult>();

  @override
  Future<SkillHubSearchResult> searchSkillsHub(
    String query, {
    int? limit,
    String? source,
  }) => result.future;
}

class _NamedSkillHubApi extends _ReloadApi {
  _NamedSkillHubApi(this.label);

  final String label;

  @override
  Future<SkillHubSearchResult> searchSkillsHub(
    String query, {
    int? limit,
    String? source,
  }) async => _hubResult(label);
}

SkillHubSearchResult _hubResult(String label) => SkillHubSearchResult(
  results: [
    SkillHubResult(
      name: label,
      description: '$label description',
      source: 'test',
      identifier: 'test/$label',
      trustLevel: 'verified',
    ),
  ],
  sourceCounts: const {'test': 1},
  timedOut: const [],
  installed: const {},
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  _ReloadConnection connection, {
  bool settle = true,
  Locale locale = const Locale('zh'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final chat = ChatStore();
  final requests = RequestStore();
  final sessions = SessionStore(
    connection: connection,
    chat: chat,
    requests: requests,
  );
  final scope = ProfileScopeStore();
  final contributions = PluginContributionStore(connection);
  final bots = BotStore(connection);
  final terminal = TerminalStore(connection: connection);
  addTearDown(() {
    contributions.dispose();
    terminal.dispose();
    bots.dispose();
    scope.dispose();
    sessions.dispose();
    requests.dispose();
    chat.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider.value(value: sessions),
        ChangeNotifierProvider.value(value: scope),
        ChangeNotifierProvider.value(value: contributions),
        ChangeNotifierProvider.value(value: bots),
        ChangeNotifierProvider.value(value: terminal),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  final screens = <String, Widget>{
    'skills': const SkillsScreen(),
    'plugins': const PluginsScreen(),
    'tools': const ToolsScreen(),
    'mcp': const McpScreen(),
    'skill hub': const SkillHubScreen(),
    'insights': const InsightsScreen(),
    'agent': const AgentScreen(),
    'webhooks': const WebhooksScreen(),
    'memory': const MemoryScreen(),
    'knowledge': const KnowledgeScreen(),
    'cron': const CronScreen(),
    'config': const ConfigScreen(),
    'starmap': const StarmapScreen(),
    'history': const HistoryScreen(),
    'settings': const SettingsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets(
      '${entry.key} shows an offline error instead of loading forever',
      (tester) async {
        final connection = _ReloadConnection();
        addTearDown(connection.dispose);
        await _pump(tester, entry.value, connection);

        expect(find.text('后端未连接'), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      '${entry.key} renders connected empty state at 320px Arabic RTL and 2x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();

        final connection = _ReloadConnection()..exposeApi(_ReloadApi());
        addTearDown(connection.dispose);
        await _pump(
          tester,
          entry.value,
          connection,
          settle: entry.key != 'agent',
          locale: const Locale('ar'),
          textScaler: const TextScaler.linear(2),
        );
        if (entry.key == 'agent') await tester.pump();

        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          TextDirection.rtl,
        );
        semantics.dispose();
      },
    );
  }

  testWidgets('a screen reloads automatically when an API becomes available', (
    tester,
  ) async {
    final connection = _ReloadConnection();
    addTearDown(connection.dispose);
    await _pump(tester, const SkillsScreen(), connection);
    expect(find.text('后端未连接'), findsWidgets);

    connection.exposeApi(_ReloadApi());
    await tester.pumpAndSettle();

    expect(find.text('后端未连接'), findsNothing);
    expect(find.text('没有技能'), findsOneWidget);
  });

  testWidgets('knowledge reloads automatically after reconnect', (
    tester,
  ) async {
    final connection = _ReloadConnection();
    addTearDown(connection.dispose);
    await _pump(tester, const KnowledgeScreen(), connection, settle: false);
    expect(find.text('后端未连接'), findsOneWidget);

    connection.exposeApi(_ReloadApi());
    await tester.pumpAndSettle();

    expect(find.text('后端未连接'), findsNothing);
    expect(find.text('暂无数据'), findsNothing);
  });

  testWidgets('late knowledge response cannot overwrite reconnected data', (
    tester,
  ) async {
    final stale = _DeferredKnowledgeApi();
    final connection = _ReloadConnection()..exposeApi(stale);
    addTearDown(connection.dispose);
    await _pump(tester, const KnowledgeScreen(), connection, settle: false);

    connection.exposeApi(_NamedKnowledgeApi('current-node'));
    await tester.pumpAndSettle();
    expect(find.text('current-node'), findsOneWidget);

    stale.graph.complete({
      'nodes': <dynamic>[
        {'id': 'stale', 'label': 'stale-node', 'kind': 'skill'},
      ],
      'memory': <dynamic>[],
    });
    await tester.pumpAndSettle();

    expect(find.text('current-node'), findsOneWidget);
    expect(find.text('stale-node'), findsNothing);
  });

  testWidgets('late cron response cannot overwrite reconnected jobs', (
    tester,
  ) async {
    final stale = _DeferredCronApi();
    final connection = _ReloadConnection()..exposeApi(stale);
    addTearDown(connection.dispose);
    await _pump(tester, const CronScreen(), connection, settle: false);

    connection.exposeApi(_NamedCronApi('current-cron'));
    await tester.pumpAndSettle();
    expect(find.text('current-cron'), findsOneWidget);

    stale.jobs.complete([
      CronJob(id: 'stale-cron', name: 'stale-cron', enabled: true),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('current-cron'), findsOneWidget);
    expect(find.text('stale-cron'), findsNothing);
  });

  testWidgets('late skills response cannot overwrite reconnected skills', (
    tester,
  ) async {
    final stale = _DeferredSkillsApi();
    final connection = _ReloadConnection()..exposeApi(stale);
    addTearDown(connection.dispose);
    await _pump(tester, const SkillsScreen(), connection, settle: false);

    connection.exposeApi(_NamedSkillsApi('current-skill'));
    await tester.pumpAndSettle();
    expect(find.text('current-skill'), findsOneWidget);

    stale.result.complete([SkillInfo(name: 'stale-skill', enabled: true)]);
    await tester.pumpAndSettle();

    expect(find.text('current-skill'), findsOneWidget);
    expect(find.text('stale-skill'), findsNothing);
  });

  testWidgets('late tools response cannot overwrite reconnected toolsets', (
    tester,
  ) async {
    final stale = _DeferredToolsApi();
    final connection = _ReloadConnection()..exposeApi(stale);
    addTearDown(connection.dispose);
    await _pump(tester, const ToolsScreen(), connection, settle: false);

    connection.exposeApi(_NamedToolsApi('current-tools'));
    await tester.pumpAndSettle();
    expect(find.text('current-tools'), findsOneWidget);

    stale.result.complete([ToolsetInfo(name: 'stale-tools', enabled: true)]);
    await tester.pumpAndSettle();

    expect(find.text('current-tools'), findsOneWidget);
    expect(find.text('stale-tools'), findsNothing);
  });

  testWidgets('late config catalog cannot overwrite the new connection', (
    tester,
  ) async {
    final stale = _DeferredConfigApi();
    final connection = _ReloadConnection()..exposeApi(stale);
    addTearDown(connection.dispose);
    await _pump(tester, const ConfigScreen(), connection, settle: false);

    connection.exposeApi(_NamedConfigApi('current-config'));
    await tester.pumpAndSettle();
    expect(find.text('current-config-model'), findsWidgets);

    stale.result.complete(
      const ModelCatalog(
        currentProvider: 'stale-config',
        currentModel: 'stale-config-model',
        providers: [
          ModelInfo(
            slug: 'stale-config',
            name: 'stale-config',
            isCurrent: true,
            models: ['stale-config-model'],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('current-config-model'), findsWidgets);
    expect(find.text('stale-config-model'), findsNothing);
  });

  testWidgets('empty disabled Webhooks exposes enable without stale success', (
    tester,
  ) async {
    final stale = _DeferredWebhookEnableApi();
    final connection = _ReloadConnection()..exposeApi(stale);
    addTearDown(connection.dispose);
    await _pump(tester, const WebhooksScreen(), connection);

    expect(find.text('Webhook 平台尚未启用 · 点击启用'), findsOneWidget);
    await tester.tap(find.text('Webhook 平台尚未启用 · 点击启用'));
    await tester.pump();

    connection.exposeApi(_ReloadApi());
    await tester.pumpAndSettle();
    stale.enabled.complete({'needs_restart': false});
    await tester.pumpAndSettle();

    expect(find.text('没有 Webhook'), findsOneWidget);
    expect(find.text('Webhook 已启用'), findsNothing);
  });

  testWidgets('late skill hub search cannot overwrite reconnected results', (
    tester,
  ) async {
    final stale = _DeferredSkillHubApi();
    final connection = _ReloadConnection()..exposeApi(stale);
    addTearDown(connection.dispose);
    await _pump(tester, const SkillHubScreen(), connection);

    await tester.enterText(find.byType(TextField), 'stale');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    connection.exposeApi(_NamedSkillHubApi('current-hub'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'current');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('current-hub'), findsOneWidget);

    stale.result.complete(_hubResult('stale-hub'));
    await tester.pumpAndSettle();

    expect(find.text('current-hub'), findsOneWidget);
    expect(find.text('stale-hub'), findsNothing);
  });

  testWidgets('cron editor ends option spinners while offline', (tester) async {
    final connection = _ReloadConnection();
    addTearDown(connection.dispose);
    await _pump(tester, const CronScreen(), connection);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('后端未连接'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cached skill detail has an explicit offline state', (
    tester,
  ) async {
    final connection = _ReloadConnection()..exposeApi(_DetailSkillApi());
    addTearDown(connection.dispose);
    await _pump(tester, const SkillsScreen(), connection);
    expect(find.text('offline-detail'), findsOneWidget);

    await tester.tap(find.text('offline-detail'));
    await tester.pump();

    connection.exposeApi(null);
    await tester.pumpAndSettle();

    expect(find.text('后端未连接'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
