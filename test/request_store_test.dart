import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/request_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://requests.invalid', apiKey: 'test');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (path.endsWith('/messages')) return {'messages': <dynamic>[]};
    return {'id': path.split('/').last, 'message_count': 0};
  }

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    return SessionPage(
      sessions: const [],
      total: 0,
      offset: offset,
      hasMore: false,
    );
  }
}

class _FakeGateway extends GatewayClient {
  _FakeGateway()
    : super(serverBaseUrl: 'http://requests.invalid', apiKey: 'test');

  final calls = <(String, Map<String, dynamic>)>[];

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    if (method == 'session.resume') {
      return {'session_id': 'runtime-${params['session_id']}'};
    }
    if (method == 'session.create') {
      return {'session_id': 'runtime-new'};
    }
    return {};
  }
}

class _FakeConnection extends ConnectionStore {
  _FakeConnection({required ApiClient apiClient, required GatewayClient gw}) {
    api = apiClient;
    gateway = gw;
  }

  final eventController = StreamController<GatewayEvent>.broadcast();
  final reconnectController = StreamController<void>.broadcast();

  @override
  Stream<GatewayEvent> get events => eventController.stream;

  @override
  Stream<void> get reconnected => reconnectController.stream;

  @override
  Future<void> ensureConnected() async {}

  @override
  void dispose() {
    eventController.close();
    reconnectController.close();
    super.dispose();
  }
}

SessionStore _newSessionStore(
  _FakeConnection connection,
  RequestStore requests,
) {
  return SessionStore(
    connection: connection,
    chat: ChatStore(),
    requests: requests,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local preview intent is durable but absent from visible chat',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeApi();
      final gateway = _FakeGateway();
      final connection = _FakeConnection(apiClient: api, gw: gateway);
      final requests = RequestStore();
      final chat = ChatStore();
      final store = SessionStore(
        connection: connection,
        chat: chat,
        requests: requests,
      );
      addTearDown(() {
        store.dispose();
        requests.dispose();
        connection.dispose();
      });

      await store.openNewSession();
      await store.sendHiddenMessage('  update the chart  ');

      final submit = gateway.calls.singleWhere(
        (call) => call.$1 == 'prompt.submit',
      );
      expect(submit.$2, {
        'session_id': 'runtime-new',
        'text': 'update the chart',
        'display_kind': 'hidden',
      });
      expect(chat.messages, isEmpty);
    },
  );

  group('RequestStore', () {
    test('fromEvent carries the event session id', () {
      final req = PendingRequest.fromEvent(
        GatewayEvent(
          type: 'approval.request',
          payload: const {'request_id': 'r1', 'command': 'rm -rf /'},
          sessionId: 'runtime-bg',
        ),
      );
      expect(req.kind, RequestKind.approval);
      expect(req.requestId, 'r1');
      expect(req.sessionId, 'runtime-bg');
    });

    test('enqueue dedups a re-emitted request_id (same kind)', () {
      final store = RequestStore();
      addTearDown(store.dispose);
      store.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'r1',
          sessionId: 'runtime-a',
          question: 'first',
        ),
      );
      store.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'r1',
          sessionId: 'runtime-a',
          question: 're-emitted',
        ),
      );
      expect(store.pendingCount, 1);
      expect(store.current!.question, 're-emitted');
    });

    test('same request_id with a different kind queues separately', () {
      final store = RequestStore();
      addTearDown(store.dispose);
      store.enqueue(
        PendingRequest(kind: RequestKind.approval, requestId: 'r1'),
      );
      store.enqueue(PendingRequest(kind: RequestKind.clarify, requestId: 'r1'));
      expect(store.pendingCount, 2);
    });

    test('attachEvents dedups re-emitted gateway events', () async {
      final controller = StreamController<GatewayEvent>();
      final store = RequestStore()..attachEvents(controller.stream);
      addTearDown(() async {
        store.dispose();
        await controller.close();
      });
      GatewayEvent event() => GatewayEvent(
        type: 'approval.request',
        payload: const {'request_id': 'r1', 'command': 'make test'},
        sessionId: 'runtime-a',
      );
      controller.add(event());
      controller.add(event());
      await Future<void>.delayed(Duration.zero);
      expect(store.pendingCount, 1);
    });
  });

  group('RequestSheet', () {
    Future<
      ({
        Widget app,
        _FakeGateway gateway,
        _FakeConnection connection,
        RequestStore requests,
      })
    >
    buildApp({
      required RequestStore requests,
      Locale locale = const Locale('zh'),
      TextScaler textScaler = TextScaler.noScaling,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final api = _FakeApi();
      final gateway = _FakeGateway();
      final connection = _FakeConnection(apiClient: api, gw: gateway);
      final session = _newSessionStore(connection, requests);
      addTearDown(() {
        session.dispose();
        connection.dispose();
      });
      // Give the session a CURRENT runtime id distinct from the request's.
      await session.resumeSession('current-session');
      final app = MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<SessionStore>.value(value: session),
          ChangeNotifierProvider<RequestStore>.value(value: requests),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: const Scaffold(body: RequestSheet()),
        ),
      );
      return (
        app: app,
        gateway: gateway,
        connection: connection,
        requests: requests,
      );
    }

    testWidgets('MCP setup reports a connection lost after rendering', (
      tester,
    ) async {
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final ctx = await buildApp(requests: requests);
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.mcpSetup,
          requestId: 'mcp-offline',
          sessionId: 'runtime-background',
          payload: const {'server': 'example-mcp'},
        ),
      );
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();

      ctx.connection.api = null;
      await tester.tap(find.text('安装并启用'));
      await tester.pumpAndSettle();

      expect(find.text('请求所属连接不可用'), findsOneWidget);
      expect(requests.pendingCount, 1);
    });

    testWidgets('request sheet supports Arabic RTL at 320px and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final ctx = await buildApp(
        requests: requests,
        locale: const Locale('ar'),
        textScaler: const TextScaler.linear(2),
      );
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.clarify,
          requestId: 'rtl-request',
          sessionId: 'runtime-background',
          question: 'اختر الإجراء المناسب لهذا الطلب الطويل',
          choices: const ['الخيار الأول الطويل', 'الخيار الثاني الطويل'],
        ),
      );

      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(RequestSheet))),
        TextDirection.rtl,
      );
      semantics.dispose();
    });

    testWidgets('respond targets the request own session id', (tester) async {
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final ctx = await buildApp(requests: requests);
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'r-bg',
          sessionId: 'runtime-background',
          question: 'allow?',
          choices: const ['once', 'deny'],
        ),
      );
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('允许一次'));
      await tester.pumpAndSettle();

      final respond = ctx.gateway.calls.firstWhere(
        (c) => c.$1 == 'approval.respond',
      );
      expect(respond.$2['session_id'], 'runtime-background');
      expect(respond.$2['request_id'], 'r-bg');
      expect(respond.$2['choice'], 'once');
      expect(ctx.requests.pendingCount, 0);
    });

    testWidgets('legacy request without session id falls back to current', (
      tester,
    ) async {
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final ctx = await buildApp(requests: requests);
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'r-legacy',
          choices: const ['once', 'deny'],
        ),
      );
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('允许一次'));
      await tester.pumpAndSettle();

      final respond = ctx.gateway.calls.firstWhere(
        (c) => c.$1 == 'approval.respond',
      );
      expect(respond.$2['session_id'], 'runtime-current-session');
    });

    testWidgets('关闭 on an approval sends an explicit deny', (tester) async {
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final ctx = await buildApp(requests: requests);
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'r-close',
          sessionId: 'runtime-background',
          choices: const ['once', 'deny'],
        ),
      );
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      final respond = ctx.gateway.calls.firstWhere(
        (c) => c.$1 == 'approval.respond',
      );
      expect(respond.$2['choice'], 'deny');
      expect(respond.$2['session_id'], 'runtime-background');
      expect(ctx.requests.pendingCount, 0);
    });

    testWidgets('关闭 on a clarify asks for confirmation before discarding', (
      tester,
    ) async {
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final ctx = await buildApp(requests: requests);
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.clarify,
          requestId: 'r-clarify',
          sessionId: 'runtime-background',
          question: 'which one?',
          choices: const ['a', 'b'],
        ),
      );
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('关闭后该请求将无法恢复，agent 将保持等待。'), findsOneWidget);
      expect(ctx.requests.pendingCount, 1);

      // Cancel keeps the request.
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(ctx.requests.pendingCount, 1);

      // Confirm discards locally without any RPC.
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '关闭'));
      await tester.pumpAndSettle();
      expect(ctx.requests.pendingCount, 0);
      expect(
        ctx.gateway.calls.where((c) => c.$1 == 'clarify.respond'),
        isEmpty,
      );
    });
  });

  group('SessionStore request retention', () {
    test(
      'reconnect-resume of the same session keeps pending requests',
      () async {
        SharedPreferences.setMockInitialValues({});
        final api = _FakeApi();
        final gateway = _FakeGateway();
        final connection = _FakeConnection(apiClient: api, gw: gateway);
        final requests = RequestStore();
        final store = _newSessionStore(connection, requests);
        addTearDown(() {
          store.dispose();
          requests.dispose();
          connection.dispose();
        });

        await store.resumeSession('session-a');
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: 'r1',
            sessionId: 'runtime-session-a',
          ),
        );
        expect(requests.pendingCount, 1);

        // Simulate a WS reconnect: the store re-resumes the SAME durable id.
        final resumeCalls = gateway.calls
            .where((c) => c.$1 == 'session.resume')
            .length;
        connection.reconnectController.add(null);
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(Duration.zero);
          final now = gateway.calls
              .where((c) => c.$1 == 'session.resume')
              .length;
          if (now > resumeCalls) break;
        }
        // Flush the rest of the resume tail (transcript refresh).
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(requests.pendingCount, 1);
        expect(store.runtimeId, 'runtime-session-a');
      },
    );

    test(
      'switching foreground retains owner-scoped background requests',
      () async {
        SharedPreferences.setMockInitialValues({});
        final api = _FakeApi();
        final gateway = _FakeGateway();
        final connection = _FakeConnection(apiClient: api, gw: gateway);
        final requests = RequestStore();
        final store = _newSessionStore(connection, requests);
        addTearDown(() {
          store.dispose();
          requests.dispose();
          connection.dispose();
        });

        await store.resumeSession('session-a');
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: 'r1',
            sessionId: 'runtime-session-a',
          ),
        );
        expect(requests.pendingCount, 1);

        await store.resumeSession('session-b');
        expect(requests.pendingCount, 1);
        expect(requests.current!.durableSessionId, 'session-a');
      },
    );
  });

  test('resolved result is retained with its owner scope', () async {
    SharedPreferences.setMockInitialValues({});
    final requests = RequestStore()
      ..bindScopeResolver(
        (_) => (
          route: const OwnerRoute(
            connectionId: ConnectionId('remote'),
            profile: 'work',
          ),
          durableId: 'stored-a',
        ),
      );
    addTearDown(requests.dispose);
    requests.enqueue(
      PendingRequest(
        kind: RequestKind.approval,
        requestId: 'approve-1',
        sessionId: 'runtime-a',
      ),
    );
    await requests.respondById(
      'approve-1',
      (_) async => const {'ok': true},
      resolution: const {'choice': 'once', 'status': 'completed'},
    );
    final resolution = requests.resolution('approve-1')!;
    expect(resolution.result['choice'], 'once');
    expect(resolution.scopeKey, contains('remote'));
    expect(resolution.scopeKey, contains('work'));
    expect(resolution.scopeKey, contains('stored-a'));
  });

  test('resolved result survives a RequestStore restore', () async {
    SharedPreferences.setMockInitialValues({});
    final first = RequestStore()
      ..bindScopeResolver(
        (_) => (
          route: const OwnerRoute(
            connectionId: ConnectionId('remote'),
            profile: 'work',
          ),
          durableId: 'stored-a',
        ),
      );
    first.enqueue(
      PendingRequest(
        kind: RequestKind.approval,
        requestId: 'approve-persisted',
        sessionId: 'runtime-a',
      ),
    );
    await first.respondById(
      'approve-persisted',
      (_) async => const {'ok': true},
      resolution: const {'choice': 'once', 'status': 'completed'},
    );
    // Persistence is intentionally fire-and-forget in production.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    first.dispose();

    final restored = RequestStore();
    addTearDown(restored.dispose);
    await restored.restore();

    final resolution = restored.resolution('approve-persisted');
    expect(resolution, isNotNull);
    expect(resolution!.result['choice'], 'once');
    expect(resolution.scopeKey, contains('remote'));
    expect(resolution.scopeKey, contains('work'));
    expect(resolution.scopeKey, contains('stored-a'));
  });

  test('compaction durable id rotation migrates pending request scope', () {
    final route = const OwnerRoute(
      connectionId: ConnectionId('local'),
      profile: 'work',
    );
    final requests = RequestStore()
      ..bindScopeResolver((_) => (route: route, durableId: 'stored-before'));
    addTearDown(requests.dispose);
    requests.enqueue(
      PendingRequest(
        kind: RequestKind.clarify,
        requestId: 'clarify-rotate',
        sessionId: 'runtime-a',
      ),
    );
    requests.rotateDurableScope('stored-before', 'stored-after', route);
    expect(requests.current!.durableSessionId, 'stored-after');
  });
}
