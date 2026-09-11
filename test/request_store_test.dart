import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:hermes_mobile/chat/widgets/request_banner.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/widgets/glass/glass_alert_dialog.dart';
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

class _McpConfigApi extends _FakeApi {
  var installCalls = 0;
  @override
  Future<List<Map<String, dynamic>>> mcpServers({String? profile}) async => [];
  @override
  Future<List<Map<String, dynamic>>> mcpCatalog({String? profile}) async => [
    {
      'name': 'example-mcp',
      'required_env': List.generate(
        12,
        (i) => {
          'name': 'KEY_$i',
          'prompt': 'Secret configuration $i',
          'required': true,
        },
      ),
    },
  ];
  @override
  Future<Map<String, dynamic>> mcpInstallCatalog(
    String name, {
    Map<String, String> env = const {},
    String? profile,
  }) async {
    installCalls++;
    return {};
  }
}

class _FakeGateway extends GatewayClient {
  _FakeGateway()
    : super(serverBaseUrl: 'http://requests.invalid', apiKey: 'test');

  final calls = <(String, Map<String, dynamic>)>[];
  Object? promptSubmitError;
  Completer<Map<String, dynamic>>? approvalResponse;

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    if (method == 'approval.respond' && approvalResponse != null) {
      return approvalResponse!.future;
    }
    if (method == 'prompt.submit' && promptSubmitError != null) {
      throw promptSubmitError!;
    }
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
  Completer<void>? ensureGate;

  @override
  Stream<GatewayEvent> get events => eventController.stream;

  @override
  Stream<void> get reconnected => reconnectController.stream;

  @override
  Future<void> ensureConnected() async {
    final gate = ensureGate;
    ensureGate = null;
    await gate?.future;
  }

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

  test(
    'failed hidden intent leaves no user bubble and releases busy',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = _FakeGateway()
        ..promptSubmitError = StateError('rejected');
      final connection = _FakeConnection(apiClient: _FakeApi(), gw: gateway);
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
      await expectLater(
        store.sendHiddenMessage('update preview'),
        throwsStateError,
      );

      expect(chat.messages, isEmpty);
      expect(chat.busy, isFalse);
      expect(chat.recoveryJournal, hasLength(1));
    },
  );

  test(
    'hidden intent cannot cross a session switch while connecting',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = _FakeGateway();
      final connection = _FakeConnection(apiClient: _FakeApi(), gw: gateway);
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
      final gate = Completer<void>();
      connection.ensureGate = gate;
      final sending = store.sendHiddenMessage('stale preview intent');
      await Future<void>.delayed(Duration.zero);
      await store.resumeSession('other-session');
      gate.complete();

      await expectLater(sending, throwsStateError);
      expect(
        gateway.calls.where((call) => call.$1 == 'prompt.submit'),
        isEmpty,
      );
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

    test('expiry retains terminal result for the matching session', () async {
      final controller = StreamController<GatewayEvent>();
      final store = RequestStore()..attachEvents(controller.stream);
      addTearDown(() async {
        store.dispose();
        await controller.close();
      });
      for (final session in ['a', 'b']) {
        store.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: 'same',
            sessionId: session,
          ),
        );
      }
      controller.add(
        GatewayEvent(
          type: 'interactive.expire',
          payload: const {'request_id': 'same'},
          sessionId: 'b',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.byId('same', sessionId: 'a'), isNotNull);
      expect(store.byId('same', sessionId: 'b'), isNull);
      expect(store.resolution('same', sessionId: 'b')?.status, 'expired');
    });

    for (final fails in [false, true]) {
      test('inflight replay cannot duplicate approval fail=$fails', () async {
        final store = RequestStore();
        addTearDown(store.dispose);
        final response = Completer<Map<String, dynamic>>();
        PendingRequest request() => PendingRequest(
          kind: RequestKind.approval,
          requestId: 'same',
          sessionId: 'session',
        );
        store.enqueue(request());
        final pending = store.respondById(
          'same',
          (_) => response.future,
          sessionId: 'session',
        );
        final outcome = fails
            ? expectLater(pending, throwsStateError)
            : expectLater(pending, completion(isTrue));
        store.enqueue(request());
        expect(store.pendingCount, 0);
        var duplicateSends = 0;
        expect(
          await store.respondById('same', (_) async {
            duplicateSends++;
            return {};
          }, sessionId: 'session'),
          isFalse,
        );
        expect(duplicateSends, 0);
        if (fails) {
          response.completeError(StateError('retry'));
        } else {
          response.complete({});
        }
        await outcome;
        expect(store.pendingCount, fails ? 1 : 0);
      });
    }

    test('routed expiry isolates owners and ignores expired replay', () async {
      final events = StreamController<RoutedGatewayEvent>();
      final store = RequestStore()..attachRoutedEvents(events.stream);
      addTearDown(() async {
        store.dispose();
        await events.close();
      });
      const a = OwnerRoute(connectionId: ConnectionId('a'), profile: 'work');
      const b = OwnerRoute(connectionId: ConnectionId('b'), profile: 'work');
      void emit(OwnerRoute route, String type) => events.add(
        RoutedGatewayEvent(
          route: route,
          socketGeneration: 1,
          event: GatewayEvent(
            type: type,
            sessionId: 'same-session',
            payload: const {'request_id': 'same-request'},
          ),
        ),
      );
      emit(a, 'approval.request');
      emit(b, 'approval.request');
      await Future<void>.delayed(Duration.zero);
      emit(b, 'interactive.expired');
      await Future<void>.delayed(Duration.zero);
      expect(store.byId('same-request', ownerRoute: a), isNotNull);
      expect(store.byId('same-request', ownerRoute: b), isNull);
      expect(
        store.resolution('same-request', ownerRoute: b)?.status,
        'expired',
      );
      emit(b, 'approval.request');
      await Future<void>.delayed(Duration.zero);
      expect(store.byId('same-request', ownerRoute: b), isNull);
      expect(store.pendingCount, 1);
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
    test(
      'socket request inherits known profile only on its own connection',
      () {
        final requests = RequestStore();
        addTearDown(requests.dispose);
        const owner = OwnerRoute(
          connectionId: ConnectionId('a'),
          profile: 'work',
        );
        requests.bindScopeResolver((_) => (route: owner, durableId: 'stored'));
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: 'r',
            sessionId: 'runtime',
            ownerRoute: const OwnerRoute(connectionId: ConnectionId('a')),
          ),
        );
        expect(
          requests.byId('r', ownerRoute: owner, sessionId: 'stored'),
          isNotNull,
        );
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: 'other',
            sessionId: 'runtime',
            ownerRoute: const OwnerRoute(connectionId: ConnectionId('b')),
          ),
        );
        expect(requests.byId('other', ownerRoute: owner), isNull);
        expect(requests.pendingRequests.last.durableSessionId, isNull);
      },
    );
    Future<
      ({
        Widget app,
        _FakeGateway gateway,
        _FakeConnection connection,
        RequestStore requests,
        SessionStore session,
      })
    >
    buildApp({
      required RequestStore requests,
      Locale locale = const Locale('zh'),
      TextScaler textScaler = TextScaler.noScaling,
      bool embedded = false,
      bool liquidInline = false,
      Brightness brightness = Brightness.light,
      bool liquidRoute = false,
      void Function(PendingRequest)? bannerOpen,
      EdgeInsets? safePadding,
      double keyboardInset = 300,
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
          theme: liquidRoute || liquidInline
              ? buildHermesTheme(
                  brightness: brightness,
                  visualStyle: HermesVisualStyle.liquid,
                )
              : null,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler,
              padding: safePadding,
              viewInsets: liquidRoute
                  ? EdgeInsets.only(bottom: keyboardInset)
                  : null,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: bannerOpen != null
                ? Builder(
                    builder: (context) => Align(
                      alignment: Alignment.topCenter,
                      child: buildChatRequestBanner(
                        context,
                        onOpen: bannerOpen,
                      ),
                    ),
                  )
                : liquidRoute
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showRequestSheet(context),
                      child: const Text('Open'),
                    ),
                  )
                : RequestSheet(
                    embedded: embedded,
                    requestId: embedded ? 'inline-approval' : null,
                  ),
          ),
        ),
      );
      return (
        app: app,
        gateway: gateway,
        connection: connection,
        requests: requests,
        session: session,
      );
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('background request banner touch target scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final requests = RequestStore();
        addTearDown(requests.dispose);
        PendingRequest? opened;
        final ctx = await buildApp(
          requests: requests,
          liquidInline: true,
          locale: const Locale('ar'),
          textScaler: TextScaler.linear(scale),
          bannerOpen: (req) => opened = req,
        );
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: 'background',
            sessionId: 'runtime-background',
          ),
        );
        await tester.pumpWidget(ctx.app);
        await tester.pumpAndSettle();
        final target = find.byType(InkWell);
        expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
        final label = tester.widget<Text>(
          find.descendant(of: target, matching: find.byType(Text)),
        );
        expect(label.maxLines, isNull);
        await tester.tap(target);
        expect(opened?.requestId, 'background');
        expect(tester.takeException(), isNull);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('banner readable and keyboard actionable $brightness', (
        tester,
      ) async {
        final requests = RequestStore();
        addTearDown(requests.dispose);
        var opened = 0;
        final ctx = await buildApp(
          requests: requests,
          liquidInline: true,
          brightness: brightness,
          bannerOpen: (_) => opened++,
        );
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: 'bg',
            sessionId: 'background',
          ),
        );
        await tester.pumpWidget(ctx.app);
        await tester.pumpAndSettle();
        final target = find.byType(InkWell);
        final label = tester.widget<Text>(
          find.descendant(of: target, matching: find.byType(Text)),
        );
        final decoration =
            tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: target,
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        final theme = Theme.of(tester.element(target));
        final bg = Color.alphaBlend(
          decoration.color!,
          theme.scaffoldBackgroundColor,
        );
        final a = label.style!.color!.computeLuminance();
        final semantics = tester.ensureSemantics();
        expect(
          tester.getSemantics(target),
          matchesSemantics(
            label: label.data!,
            isButton: true,
            hasTapAction: true,
            isFocusable: true,
            hasFocusAction: true,
          ),
        );
        semantics.dispose();
        final b = bg.computeLuminance();
        expect(
          ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
          greaterThanOrEqualTo(4.5),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('foreground request does not hide queued background request', (
      tester,
    ) async {
      final requests = RequestStore();
      addTearDown(requests.dispose);
      PendingRequest? opened;
      final ctx = await buildApp(
        requests: requests,
        bannerOpen: (req) => opened = req,
      );
      for (final id in ['current-session', 'background']) {
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: id,
            sessionId: 'runtime-$id',
          ),
        );
      }
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(opened?.requestId, 'background');
    });

    for (final differentServer in [true, false]) {
      testWidgets(
        'banner distinguishes identical session ids by owner server=$differentServer',
        (tester) async {
          final requests = RequestStore();
          addTearDown(requests.dispose);
          PendingRequest? opened;
          final ctx = await buildApp(
            requests: requests,
            bannerOpen: (req) => opened = req,
          );
          final currentRoute = ctx.session.owner!.route;
          final otherRoute = OwnerRoute(
            connectionId: differentServer
                ? const ConnectionId('other-server')
                : currentRoute.connectionId,
            profile: differentServer ? currentRoute.profile : 'other-profile',
          );
          for (final route in [currentRoute, otherRoute]) {
            requests.enqueue(
              PendingRequest(
                kind: RequestKind.approval,
                requestId: 'same-request',
                sessionId: ctx.session.runtimeId,
                ownerRoute: route,
              ),
            );
          }
          await tester.pumpWidget(ctx.app);
          await tester.pumpAndSettle();
          await tester.tap(find.byType(InkWell));
          expect(opened?.ownerRoute, otherRoute);
          requests.dismissById('same-request', ownerRoute: otherRoute);
          await tester.pumpAndSettle();
          expect(find.byType(InkWell), findsNothing);
          expect(requests.pendingCount, 1);
        },
      );
    }

    testWidgets('banner updates when the foreground session changes', (
      tester,
    ) async {
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final ctx = await buildApp(requests: requests, bannerOpen: (_) {});
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'background',
          sessionId: 'runtime-background',
          ownerRoute: ctx.session.owner!.route,
        ),
      );
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsOneWidget);
      await tester.runAsync(() => ctx.session.resumeSession('background'));
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsNothing);
      expect(requests.pendingCount, 1);
    });

    for (final keyboard in [0.0, 300.0]) {
      testWidgets(
        'Liquid request route respects safe areas (keyboard=$keyboard)',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final requests = RequestStore()
            ..enqueue(
              PendingRequest(
                kind: RequestKind.approval,
                requestId: 'glass',
                question: List.filled(
                  30,
                  'Please review this operation before approving.',
                ).join(' '),
              ),
            );
          addTearDown(requests.dispose);
          final bottomSafe = keyboard == 0 ? 34.0 : 0.0;
          final ctx = await buildApp(
            requests: requests,
            liquidRoute: true,
            keyboardInset: keyboard,
            textScaler: const TextScaler.linear(2),
            safePadding: EdgeInsets.fromLTRB(20, 47, 20, bottomSafe),
          );
          await tester.pumpWidget(ctx.app);
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final panel = tester.getRect(find.byType(GlassSurface));
          expect(panel.bottom, closeTo(844 - keyboard - bottomSafe - 12, 1));
          expect(panel.left, 32);
          expect(panel.top, greaterThanOrEqualTo(59));
          final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
          expect(sheet.enableDrag, isFalse);
          expect(sheet.showDragHandle, isFalse);
          expect(tester.takeException(), isNull);
          final scroll = find
              .descendant(
                of: find.byType(RequestSheet),
                matching: find.byType(Scrollable),
              )
              .first;
          final position = tester.state<ScrollableState>(scroll).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          final close = find.text('关闭');
          expect(close.hitTestable(), findsOneWidget);
          expect(tester.getBottomLeft(close).dy, lessThan(panel.bottom));
        },
      );
    }

    for (final longContent in [false, true]) {
      testWidgets(
        'wide Liquid request uses one keyboard inset (long=$longContent)',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.binding.setSurfaceSize(const Size(1280, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final requests = RequestStore()
            ..enqueue(
              PendingRequest(
                kind: RequestKind.approval,
                requestId: 'wide',
                question: longContent
                    ? List.filled(
                        30,
                        'Review the requested operation.',
                      ).join(' ')
                    : 'Proceed?',
              ),
            );
          addTearDown(requests.dispose);
          final ctx = await buildApp(
            requests: requests,
            liquidRoute: true,
            textScaler: const TextScaler.linear(2),
          );
          await tester.pumpWidget(ctx.app);
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          expect(
            tester
                .widget<RequestSheet>(find.byType(RequestSheet))
                .keyboardInsetsHandled,
            isTrue,
          );
          final panel = tester.getRect(find.byType(GlassSurface));
          expect(panel.width, 560);
          expect(panel.bottom, lessThanOrEqualTo(600));
          final scroll = find
              .descendant(
                of: find.byType(RequestSheet),
                matching: find.byType(Scrollable),
              )
              .first;
          final position = tester.state<ScrollableState>(scroll).position;
          if (longContent) {
            expect(position.maxScrollExtent, greaterThan(0));
          } else {
            expect(position.maxScrollExtent, 0);
            expect(panel.height, lessThan(500));
          }
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(find.text('关闭').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Liquid MCP configuration scrolls above keyboard and cancels safely',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final requests = RequestStore();
        addTearDown(requests.dispose);
        final ctx = await buildApp(
          requests: requests,
          liquidRoute: true,
          keyboardInset: 300,
          textScaler: const TextScaler.linear(2),
        );
        final api = _McpConfigApi();
        ctx.connection.api = api;
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.mcpSetup,
            requestId: 'mcp-config',
            sessionId: 'runtime-background',
            payload: const {'server': 'example-mcp'},
          ),
        );
        await tester.pumpWidget(ctx.app);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('安装并启用'));
        await tester.tap(find.text('安装并启用'));
        await tester.pumpAndSettle();
        final dialog = find.byType(GlassAlertDialog);
        expect(dialog, findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        final fields = find.descendant(
          of: dialog,
          matching: find.byType(TextField),
        );
        expect(fields, findsNWidgets(12));
        expect(
          tester
              .widgetList<TextField>(fields)
              .every((field) => field.obscureText),
          isTrue,
        );
        final cancel = find.descendant(of: dialog, matching: find.text('取消'));
        expect(cancel.hitTestable(), findsOneWidget);
        expect(tester.getRect(cancel).bottom, lessThan(544));
        await tester.ensureVisible(fields.last);
        await tester.pumpAndSettle();
        expect(fields.last.hitTestable(), findsOneWidget);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(api.installCalls, 0);
        expect(requests.pendingCount, 1);
        expect(tester.takeException(), isNull);
      },
    );

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

    for (final liquid in [false, true]) {
      testWidgets(
        'inline approval resolves runtime scope and missing choices liquid=$liquid',
        (tester) async {
          if (liquid) {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
          }
          final requests = RequestStore();
          addTearDown(requests.dispose);
          final ctx = await buildApp(
            requests: requests,
            embedded: true,
            liquidInline: liquid,
            textScaler: liquid
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
          );
          requests.enqueue(
            PendingRequest(
              kind: RequestKind.approval,
              requestId: 'inline-approval',
              sessionId: 'runtime-current-session',
              command: 'echo approved',
            ),
          );
          await tester.pumpWidget(ctx.app);
          await tester.pumpAndSettle();
          if (liquid) {
            final card = tester.widget<Container>(
              find.byKey(const ValueKey('inline-request-card')),
            );
            final decoration = card.decoration! as ShapeDecoration;
            expect(decoration.shape, isA<RoundedSuperellipseBorder>());
            expect(decoration.color!.a, 1);
            final command = tester.widget<Container>(
              find.byKey(const ValueKey('request-command')),
            );
            expect((command.decoration! as BoxDecoration).color!.a, 1);
          }
          await tester.tap(find.text('允许一次'));
          await tester.pumpAndSettle();
          final call = ctx.gateway.calls.firstWhere(
            (c) => c.$1 == 'approval.respond',
          );
          expect(call.$2['session_id'], 'runtime-current-session');
          expect(call.$2['request_id'], 'inline-approval');
          expect(call.$2['choice'], 'once');
          expect(requests.pendingCount, 0);
          if (liquid) {
            final resolved = tester.widget<Container>(
              find.byKey(const ValueKey('inline-request-resolved')),
            );
            final decoration = resolved.decoration! as ShapeDecoration;
            expect(decoration.shape, isA<RoundedSuperellipseBorder>());
            expect(decoration.color!.a, 1);
          }
        },
      );
    }

    testWidgets('inline approval keeps controls during failure and retry', (
      tester,
    ) async {
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final ctx = await buildApp(
        requests: requests,
        embedded: true,
        liquidInline: true,
      );
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'inline-approval',
          sessionId: 'runtime-current-session',
          command: 'echo review',
          choices: const ['once', 'deny'],
        ),
      );
      ctx.gateway.approvalResponse = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('允许一次'));
      await tester.pump();
      expect(find.byKey(const ValueKey('inline-request-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inline-request-resolved')),
        findsNothing,
      );
      final allow = find.widgetWithText(FilledButton, '允许一次');
      expect(tester.widget<FilledButton>(allow).onPressed, isNull);
      await tester.tap(allow);
      await tester.pump();
      expect(
        ctx.gateway.calls.where((c) => c.$1 == 'approval.respond'),
        hasLength(1),
      );
      ctx.gateway.approvalResponse!.completeError(
        StateError('approval unavailable'),
      );
      await tester.pumpAndSettle();
      expect(requests.pendingCount, 1);
      expect(tester.widget<FilledButton>(allow).onPressed, isNotNull);
      expect(find.byType(SnackBar), findsOneWidget);
      ctx.gateway.approvalResponse = Completer<Map<String, dynamic>>();
      await tester.tap(allow);
      await tester.pump();
      ctx.gateway.approvalResponse!.complete({});
      await tester.pumpAndSettle();
      expect(requests.pendingCount, 0);
      expect(
        find.byKey(const ValueKey('inline-request-resolved')),
        findsOneWidget,
      );
      expect(
        ctx.gateway.calls.where((c) => c.$1 == 'approval.respond'),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    });

    for (final fails in [false, true]) {
      testWidgets(
        'expiry replaces submitting card before RPC finishes fail=$fails',
        (tester) async {
          final requests = RequestStore();
          final events = StreamController<GatewayEvent>();
          requests.attachEvents(events.stream);
          addTearDown(() async {
            requests.dispose();
            await events.close();
          });
          final ctx = await buildApp(
            requests: requests,
            embedded: true,
            liquidInline: true,
          );
          requests.enqueue(
            PendingRequest(
              kind: RequestKind.approval,
              requestId: 'inline-approval',
              sessionId: 'runtime-current-session',
            ),
          );
          ctx.gateway.approvalResponse = Completer<Map<String, dynamic>>();
          await tester.pumpWidget(ctx.app);
          await tester.pumpAndSettle();
          await tester.tap(find.text('允许一次'));
          await tester.pump();
          events.add(
            GatewayEvent(
              type: 'interactive.expire',
              payload: const {'request_id': 'inline-approval'},
              sessionId: 'runtime-current-session',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('请求已过期'), findsOneWidget);
          expect(find.text('允许一次'), findsNothing);
          if (fails) {
            ctx.gateway.approvalResponse!.completeError(
              StateError('late failure'),
            );
          } else {
            ctx.gateway.approvalResponse!.complete({});
          }
          await tester.pumpAndSettle();
          expect(find.text('请求已过期'), findsOneWidget);
          expect(requests.pendingCount, 0);
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('expired inline request shows terminal label without actions', (
      tester,
    ) async {
      final requests = RequestStore();
      final events = StreamController<GatewayEvent>();
      requests.attachEvents(events.stream);
      addTearDown(() async {
        requests.dispose();
        await events.close();
      });
      final ctx = await buildApp(
        requests: requests,
        embedded: true,
        liquidInline: true,
      );
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'inline-approval',
          sessionId: 'runtime-current-session',
        ),
      );
      await tester.pumpWidget(ctx.app);
      await tester.pumpAndSettle();
      events.add(
        GatewayEvent(
          type: 'interactive.expired',
          payload: const {'request_id': 'inline-approval'},
          sessionId: 'runtime-current-session',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('请求已过期'), findsOneWidget);
      expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
      expect(find.text('允许一次'), findsNothing);
      expect(find.text('待处理请求'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final choice in ['once', 'deny', 'session']) {
      for (final locale in ['zh', 'en', 'ar']) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'resolved approval localizes choice $choice $locale $brightness',
            (tester) async {
              tester.view.physicalSize = const Size(320, 640);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final requests = RequestStore();
              addTearDown(requests.dispose);
              final ctx = await buildApp(
                requests: requests,
                embedded: true,
                liquidInline: true,
                locale: Locale(locale),
                brightness: brightness,
                textScaler: const TextScaler.linear(2),
              );
              requests.enqueue(
                PendingRequest(
                  kind: RequestKind.approval,
                  requestId: 'inline-approval',
                  sessionId: 'runtime-current-session',
                  choices: const ['once', 'deny', 'session'],
                ),
              );
              await tester.pumpWidget(ctx.app);
              await tester.pumpAndSettle();
              final l10n = AppLocalizations.of(
                tester.element(find.byType(RequestSheet)),
              );
              final label = switch (choice) {
                'once' => l10n.requestAllowOnce,
                'deny' => l10n.agentDeny,
                _ => l10n.requestAllowSession,
              };
              await tester.tap(find.text(label));
              await tester.pumpAndSettle();
              final result = find.byKey(
                const ValueKey('inline-request-resolved'),
              );
              final bounds = tester.getRect(result);
              for (final text
                  in find
                      .descendant(of: result, matching: find.byType(Text))
                      .evaluate()) {
                final rect = tester.getRect(find.byWidget(text.widget));
                expect(rect.left, greaterThanOrEqualTo(bounds.left));
                expect(rect.right, lessThanOrEqualTo(bounds.right));
                expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
              }
              expect(tester.takeException(), isNull);
              expect(
                find.descendant(of: result, matching: find.text(label)),
                findsOneWidget,
              );
              expect(find.text(choice), findsNothing);
              expect(
                find.descendant(
                  of: result,
                  matching: find.byIcon(
                    choice == 'deny'
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                  ),
                ),
                findsOneWidget,
              );
            },
          );
        }
      }
    }

    testWidgets(
      'always confirmation cannot authorize the next queued request',
      (tester) async {
        final requests = RequestStore();
        addTearDown(requests.dispose);
        final ctx = await buildApp(requests: requests, liquidInline: true);
        for (final id in ['first', 'second']) {
          requests.enqueue(
            PendingRequest(
              kind: RequestKind.approval,
              requestId: id,
              sessionId: 'runtime-current-session',
              command: 'echo $id',
              choices: const ['once', 'always', 'deny'],
            ),
          );
        }
        await tester.pumpWidget(ctx.app);
        await tester.pumpAndSettle();
        await tester.tap(find.text('始终允许'));
        await tester.pumpAndSettle();
        expect(find.byType(GlassAlertDialog), findsOneWidget);
        requests.dismissById('first');
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(GlassAlertDialog),
            matching: find.text('始终允许'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          ctx.gateway.calls.where((call) => call.$1 == 'approval.respond'),
          isEmpty,
        );
        expect(requests.byId('second'), isNotNull);
        // Fresh consent for the visible request must still work.
        await tester.tap(find.text('始终允许'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(GlassAlertDialog),
            matching: find.text('始终允许'),
          ),
        );
        await tester.pumpAndSettle();
        final sent = ctx.gateway.calls
            .where((call) => call.$1 == 'approval.respond')
            .toList();
        expect(sent, hasLength(1));
        expect(sent.single.$2['request_id'], 'second');
        expect(sent.single.$2['choice'], 'always');
        expect(requests.pendingCount, 0);
        expect(tester.takeException(), isNull);
      },
    );

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

  test('overlapping restores preserve a clear already requested', () async {
    SharedPreferences.setMockInitialValues({
      'hm_pending_interactive_requests_v1': jsonEncode({
        'pending': [
          {
            'event_type': 'approval.request',
            'payload': {'request_id': 'old'},
          },
        ],
      }),
    });
    final store = RequestStore();
    addTearDown(store.dispose);
    final first = store.restore();
    store.clear();
    final second = store.restore();
    await Future.wait([first, second]);
    expect(store.pendingCount, 0);
  });

  for (final snapshot in [null, '{broken', '{"pending":false}']) {
    test(
      'unusable snapshot remains untouched without live changes=$snapshot',
      () async {
        SharedPreferences.setMockInitialValues({
          'hm_pending_interactive_requests_v1': ?snapshot,
        });
        final store = RequestStore();
        addTearDown(store.dispose);
        await store.restore();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('hm_pending_interactive_requests_v1'), snapshot);
      },
    );
    test(
      'live request persists after unusable recovery snapshot=$snapshot',
      () async {
        SharedPreferences.setMockInitialValues({
          'hm_pending_interactive_requests_v1': ?snapshot,
        });
        final first = RequestStore();
        addTearDown(first.dispose);
        final recovery = first.restore();
        first.enqueue(
          PendingRequest.fromEvent(
            GatewayEvent(
              type: 'approval.request',
              sessionId: 'live-session',
              payload: {'request_id': 'live'},
            ),
          ),
        );
        await recovery;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final second = RequestStore();
        addTearDown(second.dispose);
        await second.restore();
        expect(second.pendingCount, 1);
        expect(second.current!.requestId, 'live');
      },
    );
  }

  test(
    'expiry during restore closes only the matching recovered session',
    () async {
      SharedPreferences.setMockInitialValues({
        'hm_pending_interactive_requests_v1': jsonEncode({
          'pending': [
            for (final session in ['closed', 'background'])
              {
                'event_type': 'approval.request',
                'session_id': session,
                'payload': {'request_id': 'same'},
              },
          ],
        }),
      });
      final events = StreamController<GatewayEvent>(sync: true);
      final store = RequestStore()..attachEvents(events.stream);
      addTearDown(store.dispose);
      addTearDown(events.close);
      store.addListener(() {
        expect(
          store.pendingRequests.where(
            (request) => request.sessionId == 'closed',
          ),
          isEmpty,
          reason: 'Expired recovery must never flash actionable',
        );
      });
      final recovery = store.restore();
      events.add(
        GatewayEvent(
          type: 'interactive.expired',
          sessionId: 'closed',
          payload: {'request_id': 'same'},
        ),
      );
      await recovery;
      expect(store.pendingCount, 1);
      expect(store.current!.sessionId, 'background');
      expect(store.resolution('same', sessionId: 'closed')?.status, 'expired');
    },
  );

  for (final all in [false, true]) {
    test('clear during restore excludes old pending scope all=$all', () async {
      SharedPreferences.setMockInitialValues({
        'hm_pending_interactive_requests_v1': jsonEncode({
          'pending': [
            for (final session in ['closed', 'background'])
              {
                'event_type': 'approval.request',
                'connection_id': 'server',
                'session_id': session,
                'payload': {'request_id': session},
              },
          ],
        }),
      });
      final store = RequestStore();
      addTearDown(store.dispose);
      final loading = store.restore();
      if (all) {
        store.clear();
      } else {
        store.clearScope(
          ownerRoute: const OwnerRoute(connectionId: ConnectionId('server')),
          sessionId: 'closed',
        );
      }
      await loading;
      expect(
        store.pendingRequests.map((r) => r.requestId).toList(),
        all ? <String>[] : ['background'],
      );
    });
  }

  test('live request during restore keeps its newer command', () async {
    SharedPreferences.setMockInitialValues({
      'hm_pending_interactive_requests_v1': jsonEncode({
        'pending': [
          {
            'event_type': 'approval.request',
            'session_id': 's',
            'payload': {'request_id': 'r', 'command': 'old command'},
          },
        ],
      }),
    });
    final store = RequestStore();
    addTearDown(store.dispose);
    final loading = store.restore();
    store.enqueue(
      PendingRequest.fromEvent(
        GatewayEvent(
          type: 'approval.request',
          sessionId: 's',
          payload: const {'request_id': 'r', 'command': 'new command'},
        ),
      ),
    );
    await loading;
    expect(store.pendingCount, 1);
    expect(store.current!.command, 'new command');
  });

  test('disposed store cannot restore persisted pending requests', () async {
    SharedPreferences.setMockInitialValues({
      'hm_pending_interactive_requests_v1': jsonEncode({
        'pending': [
          {
            'event_type': 'approval.request',
            'payload': {'request_id': 'old'},
          },
        ],
      }),
    });
    final store = RequestStore();
    final loading = store.restore();
    store.dispose();
    await loading;
    expect(store.pendingCount, 0);
  });

  test(
    'restore never exposes pending rows already expired in the snapshot',
    () async {
      SharedPreferences.setMockInitialValues({
        'hm_pending_interactive_requests_v1': jsonEncode({
          'pending': [
            {
              'event_type': 'approval.request',
              'session_id': 's',
              'payload': {'request_id': 'r'},
            },
          ],
          'resolved': [
            {
              'request_id': 'r',
              'scope_key': ['legacy', '', 's'].join('\u0000'),
              'kind': 'approval',
              'status': 'expired',
              'result': {'status': 'expired'},
            },
          ],
        }),
      });
      final store = RequestStore();
      addTearDown(store.dispose);
      var exposed = false;
      store.addListener(() {
        exposed |= store.pendingCount > 0;
      });
      await store.restore();
      expect(store.pendingCount, 0);
      expect(exposed, isFalse);
      expect(store.resolution('r')?.status, 'expired');
    },
  );

  test('restore preserves resolutions while loading pending rows', () async {
    SharedPreferences.setMockInitialValues({
      'hm_pending_interactive_requests_v1': jsonEncode({
        'pending': [
          {
            'event_type': 'approval.request',
            'session_id': 's',
            'payload': {'request_id': 'pending'},
          },
        ],
        'resolved': [
          {
            'request_id': 'expired',
            'scope_key': 'scope',
            'kind': 'approval',
            'status': 'expired',
            'result': {'status': 'expired'},
          },
        ],
      }),
    });
    final first = RequestStore();
    await first.restore();
    expect(first.pendingCount, 1);
    expect(first.resolution('expired')?.status, 'expired');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    first.dispose();
    final second = RequestStore();
    addTearDown(second.dispose);
    await second.restore();
    expect(second.pendingCount, 1);
    expect(second.resolution('expired')?.status, 'expired');
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

  test(
    'same request id is responded and dismissed within its owner scope',
    () async {
      const routeA = OwnerRoute(
        connectionId: ConnectionId('server-a'),
        profile: 'default',
      );
      const routeB = OwnerRoute(
        connectionId: ConnectionId('server-b'),
        profile: 'work',
      );
      final requests = RequestStore();
      addTearDown(requests.dispose);
      for (final route in [routeA, routeB]) {
        requests.enqueue(
          PendingRequest(
            kind: RequestKind.approval,
            requestId: 'r1',
            sessionId: 'runtime-1',
            ownerRoute: route,
          ),
        );
      }

      PendingRequest? sent;
      await requests.respondById(
        'r1',
        (request) async {
          sent = request;
          return const {'ok': true};
        },
        ownerRoute: routeB,
        sessionId: 'runtime-1',
      );

      expect(sent?.ownerRoute, routeB);
      expect(requests.pendingRequests.single.ownerRoute, routeA);
      expect(
        requests.resolution('r1', ownerRoute: routeB)?.scopeKey,
        startsWith(routeB.key),
      );
      requests.dismissById('r1', ownerRoute: routeA);
      expect(requests.pendingCount, 0);
    },
  );

  test('same request id and scope remains distinct by request kind', () async {
    const route = OwnerRoute(
      connectionId: ConnectionId('server-a'),
      profile: 'default',
    );
    final requests = RequestStore();
    addTearDown(requests.dispose);
    for (final kind in [RequestKind.approval, RequestKind.secret]) {
      requests.enqueue(
        PendingRequest(
          kind: kind,
          requestId: 'shared-id',
          sessionId: 'runtime-1',
          ownerRoute: route,
        ),
      );
    }

    await requests.respondById(
      'shared-id',
      (_) async => const {'ok': true},
      ownerRoute: route,
      sessionId: 'runtime-1',
      kind: RequestKind.secret,
    );

    expect(requests.pendingRequests.single.kind, RequestKind.approval);
    expect(
      requests.resolution(
        'shared-id',
        ownerRoute: route,
        sessionId: 'runtime-1',
        kind: RequestKind.secret,
      ),
      isNotNull,
    );
  });

  test(
    'clearing a scope prevents late failure from reviving its request',
    () async {
      const route = OwnerRoute(connectionId: ConnectionId('server-a'));
      final requests = RequestStore();
      addTearDown(requests.dispose);
      final response = Completer<Map<String, dynamic>>();
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'old',
          sessionId: 'closed',
          ownerRoute: route,
        ),
      );
      final pending = requests.respondById(
        'old',
        (_) => response.future,
        ownerRoute: route,
        sessionId: 'closed',
      );
      final failed = expectLater(pending, throwsStateError);
      requests.clearScope(ownerRoute: route, sessionId: 'closed');
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'new',
          sessionId: 'background',
          ownerRoute: route,
        ),
      );
      response.completeError(StateError('late failure'));
      await failed;
      expect(requests.pendingRequests.map((r) => r.requestId), ['new']);
    },
  );

  for (final cancel in ['clear', 'dismiss', 'dispose']) {
    test('late success after $cancel does not record approval', () async {
      final requests = RequestStore();
      if (cancel != 'dispose') addTearDown(requests.dispose);
      final response = Completer<Map<String, dynamic>>();
      requests.enqueue(
        PendingRequest(kind: RequestKind.approval, requestId: 'r'),
      );
      final pending = requests.respond((_) => response.future);
      switch (cancel) {
        case 'clear':
          requests.clear();
        case 'dismiss':
          requests.dismissById('r');
        case 'dispose':
          requests.dispose();
      }
      response.complete({'choice': 'once'});
      expect(await pending, isFalse);
      expect(requests.pendingCount, 0);
      expect(requests.resolution('r'), isNull);
    });
  }

  test('clearScope preserves requests owned by background sessions', () {
    const route = OwnerRoute(
      connectionId: ConnectionId('server-a'),
      profile: 'default',
    );
    final requests = RequestStore();
    addTearDown(requests.dispose);
    for (final session in ['foreground', 'background']) {
      requests.enqueue(
        PendingRequest(
          kind: RequestKind.approval,
          requestId: 'request-$session',
          durableSessionId: session,
          ownerRoute: route,
        ),
      );
    }

    requests.clearScope(ownerRoute: route, sessionId: 'foreground');

    expect(requests.pendingRequests.single.durableSessionId, 'background');
  });
}
