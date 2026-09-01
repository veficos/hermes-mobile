import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/pull_request_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_appearance_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/subagent_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/session_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SessionListApi extends ApiClient {
  _SessionListApi(this.rows, {this.subagentNodes = const []})
    : super(baseUrl: 'http://session-list.invalid', apiKey: 'test');

  final List<SessionRow> rows;
  final List<SubagentNode> subagentNodes;

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    return SessionPage(
      sessions: rows,
      total: rows.length,
      offset: offset,
      hasMore: false,
    );
  }

  @override
  Future<SubagentProjection> subagentProjection() async => SubagentProjection(
    sessions: rows.where((row) => row.isDelegatedChild).toList(),
    bySession: {if (subagentNodes.isNotEmpty) 'parent-session': subagentNodes},
    total: subagentNodes.length,
  );

  @override
  Future<Map<String, List<SubagentNode>>> subagentsForSessions(
    Iterable<String> sessionIds,
  ) async => {
    for (final id in sessionIds)
      id: id == 'parent-session' ? subagentNodes : const [],
  };

  @override
  Future<List<SubagentNode>> subagents(String sessionId) async =>
      sessionId == 'parent-session' ? subagentNodes : const [];

  @override
  Future<ProjectTreePayload> projectTree({int previewLimit = 3}) async {
    return const ProjectTreePayload(projects: []);
  }
}

class _RecordingSessionStore extends SessionStore {
  _RecordingSessionStore({
    required super.connection,
    required super.chat,
    required super.requests,
  });

  String? resumedId;
  String? resumedProfile;
  String? openedReadOnlyId;

  @override
  Future<void> openReadOnlySession(String durableId, {String? profile}) async {
    openedReadOnlyId = durableId;
  }

  @override
  Future<void> resumeSession(String durableId, {String? profile}) async {
    resumedId = durableId;
    resumedProfile = profile;
  }

  @override
  Future<void> setSessionViewedCount(String sid, int messageCount) async {}
}

class _OfflineCommandStore extends CommandStore {
  _OfflineCommandStore({required super.connection});

  @override
  Future<void> loadCatalog() async {}
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

class _Harness {
  _Harness({this.subagentNodes = const []}) {
    final now = DateTime.now();
    connection.api = _SessionListApi([
      SessionRow(
        id: 'parent-session',
        title: '父会话测试标题',
        messageCount: 3,
        startedAt: now,
        parentSessionId: null,
        profile: 'experts',
      ),
      SessionRow(
        id: 'child-session',
        title: '子会话测试标题',
        source: 'subagent',
        parentSessionId: 'parent-session',
        messageCount: 2,
        startedAt: now,
      ),
    ], subagentNodes: subagentNodes);
    subagents = SubagentStore(connection: connection);
    sessions = _RecordingSessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
    );
    voice = VoiceStore(connection: connection);
    commands = _OfflineCommandStore(connection: connection);
    pullRequests = PullRequestStore(api: connection.api);
  }

  final List<SubagentNode> subagentNodes;
  final ConnectionStore connection = ConnectionStore();
  final ChatStore chat = ChatStore();
  final RequestStore requests = RequestStore();
  final SessionAppearanceStore appearance = SessionAppearanceStore();
  final _RecordingNavigatorObserver observer = _RecordingNavigatorObserver();
  late final _RecordingSessionStore sessions;
  late final VoiceStore voice;
  late final CommandStore commands;
  late final PullRequestStore pullRequests;
  late final SubagentStore subagents;

  Widget build({Locale locale = const Locale('zh')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider<ChatStore>.value(value: chat),
        ChangeNotifierProvider<RequestStore>.value(value: requests),
        ChangeNotifierProvider<SessionStore>.value(value: sessions),
        ChangeNotifierProvider<SessionAppearanceStore>.value(value: appearance),
        ChangeNotifierProvider<VoiceStore>.value(value: voice),
        ChangeNotifierProvider<CommandStore>.value(value: commands),
        ChangeNotifierProvider<SubagentStore>.value(value: subagents),
        ChangeNotifierProvider<PullRequestStore>.value(value: pullRequests),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: const SessionListScreen(),
      ),
    );
  }

  void dispose() {
    sessions.dispose();
    voice.dispose();
    commands.dispose();
    pullRequests.dispose();
    subagents.dispose();
    appearance.dispose();
    requests.dispose();
    chat.dispose();
    connection.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('点击配置档会话时透传所属 profile', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('session-parent-session')));
    await tester.pump();

    expect(harness.sessions.resumedId, 'parent-session');
    expect(harness.sessions.resumedProfile, 'experts');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('session list renders English strings from the active locale', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build(locale: const Locale('en')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('会话'), findsNothing);
    expect(find.byTooltip('Expand child sessions'), findsOneWidget);
  });

  testWidgets('session list renders Arabic in RTL', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build(locale: const Locale('ar')));
    await tester.pump(const Duration(milliseconds: 100));

    final title = find.text('الجلسات');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    expect(find.byTooltip('توسيع الجلسات الفرعية'), findsOneWidget);
  });

  testWidgets('真实子会话显示后端标题、数量并以只读方式打开', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('展开子会话'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('子会话测试标题'), findsOneWidget);
    expect(find.textContaining('2 条消息'), findsOneWidget);
  });

  testWidgets('运行节点与真实 child 按 child session id 去重', (tester) async {
    final harness = _Harness(
      subagentNodes: [
        SubagentNode(
          id: 'agent-1',
          goal: '审计代码',
          sessionId: 'child-session',
          status: 'running',
          startedAt: DateTime.now(),
        ),
      ],
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('展开子会话'), findsOneWidget);
    expect(harness.subagents.forSession('parent-session'), isEmpty);
  });
  testWidgets('父会话默认收起，点击展开后显示子会话', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('父会话测试标题'), findsOneWidget);
    expect(find.text('子会话测试标题'), findsNothing);

    await tester.tap(find.byTooltip('展开子会话'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('子会话测试标题'), findsOneWidget);
    expect(find.byTooltip('收起子会话'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('展开的父会话可以再次收起', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('展开子会话'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.tap(find.byTooltip('收起子会话'));
    await tester.pump();

    expect(find.text('子会话测试标题'), findsNothing);
    expect(find.byTooltip('展开子会话'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('点击子会话会恢复该会话并跳转到聊天页', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('展开子会话'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.ensureVisible(
      find.byKey(const ValueKey('subagent-child-session')),
    );
    await tester.tap(
      find.byKey(const ValueKey('subagent-child-session')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(harness.sessions.openedReadOnlyId, 'child-session');
    expect(harness.sessions.resumedId, isNull);
    expect(harness.observer.pushedRoutes.length, 2);
    expect(
      harness.observer.pushedRoutes.last,
      isA<MaterialPageRoute<dynamic>>(),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
