import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_appearance_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HomeApi extends ApiClient {
  _HomeApi(this.rows) : super(baseUrl: 'http://home.invalid', apiKey: 'test');

  final List<SessionRow> rows;
  final List<String?> sessionProfiles = [];
  final List<String?> configProfiles = [];
  int? requestedLimit;
  String activeProfile = 'default';

  @override
  Future<ProfilesPayload> listProfiles() async => ProfilesPayload(
    profiles: const [
      ProfileInfo(name: 'default'),
      ProfileInfo(name: 'experts'),
    ],
    active: activeProfile,
    current: 'default',
    source: 'upstream',
  );

  @override
  Future<Map<String, dynamic>> activateProfile(String name) async {
    activeProfile = name;
    return {'active': name, 'current': 'default'};
  }

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async {
    configProfiles.add(profile);
    return {'model': profile};
  }

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    requestedLimit = limit;
    sessionProfiles.add(profile);
    final selectedRows = profile == 'experts'
        ? [SessionRow(id: 'expert-session', title: '专家会话')]
        : rows;
    return SessionPage(
      sessions: selectedRows,
      total: selectedRows.length,
      offset: offset,
      hasMore: false,
    );
  }
}

class _RecordingSessionStore extends SessionStore {
  _RecordingSessionStore({
    required this.rows,
    required super.connection,
    required super.chat,
    required super.requests,
  });

  final List<SessionRow> rows;
  int? requestedLimit;
  String? resumedId;
  String? resumedProfile;
  String? readOnlyId;
  final List<String?> refreshedProfiles = [];

  @override
  List<SessionRow>? get sessions => rows;

  @override
  Future<void> refreshList({
    int limit = 100,
    bool includeArchived = false,
    String? profile,
    bool notify = true,
  }) async {
    requestedLimit = limit;
    refreshedProfiles.add(profile);
  }

  @override
  Future<void> resumeSession(String durableId, {String? profile}) {
    resumedId = durableId;
    resumedProfile = profile;
    return Completer<void>().future;
  }

  @override
  Future<void> openReadOnlySession(String durableId, {String? profile}) {
    readOnlyId = durableId;
    return Completer<void>().future;
  }
}

class _ReconnectConnection extends ConnectionStore {
  int reconnectCount = 0;

  @override
  Future<void> reconnectAfterResume({bool refreshSocket = false}) async {
    reconnectCount++;
    expect(refreshSocket, isTrue);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home app bar can force a connection refresh', (tester) async {
    final api = _HomeApi([]);
    final connection = _ReconnectConnection()
      ..settings = const ConnectionSettings(
        serverUrl: 'http://home.invalid',
        apiKey: 'test',
      )
      ..api = api;
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    final notifications = NotificationStore(connection: connection);
    addTearDown(() {
      notifications.dispose();
      store.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: store),
          ChangeNotifierProvider<SessionAppearanceStore>.value(
            value: SessionAppearanceStore(),
          ),
          ChangeNotifierProvider<NotificationStore>.value(value: notifications),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-reconnect')), findsOneWidget);
    expect(find.byTooltip('重新连接到服务器'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-reconnect')));
    await tester.pumpAndSettle();

    expect(connection.reconnectCount, 1);
    expect(find.text('已连接'), findsOneWidget);
  });

  testWidgets('quick tools render first and persist editable order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hm_home_quick_tool_order': [
        'git',
        'terminal',
        'projects',
        'files',
        'kanban',
      ],
    });
    final api = _HomeApi([]);
    final connection = ConnectionStore()..api = api;
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    final notifications = NotificationStore(connection: connection);
    addTearDown(() {
      notifications.dispose();
      store.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: store),
          ChangeNotifierProvider<SessionAppearanceStore>.value(
            value: SessionAppearanceStore(),
          ),
          ChangeNotifierProvider<NotificationStore>.value(value: notifications),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('常用工具')).dy,
      lessThan(tester.getTopLeft(find.text('当前工作')).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('quick-tool-git'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('quick-tool-projects'))).dx,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('edit-quick-tools')));
    await tester.pumpAndSettle();
    expect(find.byType(ReorderableListView), findsOneWidget);
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(5, 0);
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('hm_home_quick_tool_order'), [
      'agent',
      'git',
      'terminal',
      'projects',
      'files',
      'kanban',
      'settings',
      'subagents',
      'knowledge',
      'artifacts',
      'cron',
      'insights',
    ]);
    expect(find.byKey(const ValueKey('quick-tool-agent')), findsOneWidget);
  });

  testWidgets('phone home does not overflow its status and tool containers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _HomeApi([]);
    final connection = ConnectionStore()..api = api;
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    final notifications = NotificationStore(connection: connection);
    addTearDown(() {
      notifications.dispose();
      store.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: store),
          ChangeNotifierProvider<SessionAppearanceStore>.value(
            value: SessionAppearanceStore(),
          ),
          ChangeNotifierProvider<NotificationStore>.value(value: notifications),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('常用工具'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('645px home does not overflow its responsive containers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(645, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _HomeApi([]);
    final connection = ConnectionStore()..api = api;
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    final notifications = NotificationStore(connection: connection);
    addTearDown(() {
      notifications.dispose();
      store.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: store),
          ChangeNotifierProvider<SessionAppearanceStore>.value(
            value: SessionAppearanceStore(),
          ),
          ChangeNotifierProvider<NotificationStore>.value(value: notifications),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('常用工具'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home switches profile and reloads config and sessions explicitly',
    (tester) async {
      final api = _HomeApi([SessionRow(id: 'default-session', title: '默认会话')]);
      final connection = ConnectionStore()..api = api;
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      final notifications = NotificationStore(connection: connection);
      addTearDown(() {
        notifications.dispose();
        store.dispose();
        connection.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: store),
            ChangeNotifierProvider<SessionAppearanceStore>.value(
              value: SessionAppearanceStore(),
            ),
            ChangeNotifierProvider<NotificationStore>.value(
              value: notifications,
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.configProfiles, ['default']);
      expect(api.sessionProfiles, ['default']);
      expect(store.sessions?.single.profile, 'default');
      expect(find.byTooltip('配置档：default'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-profile-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('experts').last);
      await tester.pumpAndSettle();

      expect(api.configProfiles, ['default', 'experts']);
      expect(api.sessionProfiles, ['default', 'experts']);
      await tester.scrollUntilVisible(
        find.text('专家会话'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('专家会话'), findsOneWidget);
    },
  );

  testWidgets('home resumes a default profile history with its profile', (
    tester,
  ) async {
    final rows = [
      SessionRow(id: 'default-session', title: '默认历史会话', profile: 'default'),
    ];
    final api = _HomeApi(rows)..activeProfile = 'experts';
    final connection = ConnectionStore()..api = api;
    final store = _RecordingSessionStore(
      rows: rows,
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    final notifications = NotificationStore(connection: connection);
    addTearDown(() {
      notifications.dispose();
      store.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: store),
          ChangeNotifierProvider<SessionAppearanceStore>.value(
            value: SessionAppearanceStore(),
          ),
          ChangeNotifierProvider<NotificationStore>.value(value: notifications),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('default').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('默认历史会话'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('默认历史会话'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('默认历史会话'));
    await tester.pump();

    expect(store.refreshedProfiles, ['experts', 'default']);
    expect(store.resumedId, 'default-session');
    expect(store.resumedProfile, 'default');
  });

  testWidgets('home recent sessions expand children without opening parent', (
    tester,
  ) async {
    final rows = [
      SessionRow(id: 'parent', title: '父会话'),
      SessionRow(
        id: 'child',
        title: '只读子会话',
        parentSessionId: 'parent',
        source: 'subagent',
        readOnly: true,
      ),
      for (var i = 2; i < 8; i++) SessionRow(id: 'root-$i', title: '根会话 $i'),
    ];
    final api = _HomeApi(rows);
    final connection = ConnectionStore()..api = api;
    final store = _RecordingSessionStore(
      rows: rows,
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    final notifications = NotificationStore(connection: connection);
    addTearDown(() {
      notifications.dispose();
      store.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: store),
          ChangeNotifierProvider<SessionAppearanceStore>.value(
            value: SessionAppearanceStore(),
          ),
          ChangeNotifierProvider<NotificationStore>.value(value: notifications),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('父会话'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(store.requestedLimit, 20);
    expect(find.text('父会话'), findsOneWidget);
    expect(find.text('只读子会话'), findsNothing);
    expect(find.text('根会话 6'), findsNothing); // at most five roots

    final toggle = find.byKey(const ValueKey('home-session-toggle-parent'));
    expect(toggle, findsOneWidget);
    expect(
      tester.getTopLeft(toggle).dx,
      greaterThan(tester.getTopLeft(find.text('父会话')).dx),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pump();

    expect(find.text('只读子会话'), findsOneWidget);
    expect(store.resumedId, isNull);
    expect(store.readOnlyId, isNull);
    expect(
      tester.getTopLeft(find.text('只读子会话')).dx,
      greaterThan(tester.getTopLeft(find.text('父会话')).dx),
    );

    await tester.tap(find.text('只读子会话'));
    await tester.pump();
    expect(store.readOnlyId, 'child');
    expect(store.resumedId, isNull);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('只读子会话'), findsNothing);
  });
}
