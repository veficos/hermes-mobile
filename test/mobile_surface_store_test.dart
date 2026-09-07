import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/mobile_surface_store.dart';
import 'package:hermes_mobile/core/stores/pane_workspace_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_tour_overlay.dart';

class _SurfaceConnection extends ConnectionStore {
  final controller = StreamController<RoutedGatewayEvent>.broadcast();
  final calls = <(String, Map<String, dynamic>)>[];

  @override
  Stream<RoutedGatewayEvent> get routedEvents => controller.stream;

  @override
  Future<Map<String, dynamic>> requestForOwner(
    OwnerRoute route,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    return {};
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

class _VisibleSession extends SessionStore {
  _VisibleSession({
    required super.connection,
    required super.chat,
    required super.requests,
  });

  static const route = OwnerRoute(connectionId: ConnectionId('primary'));

  @override
  SessionOwner? get owner => const SessionOwner(
    durableId: 'durable-a',
    runtimeId: 'runtime-a',
    route: route,
  );

  @override
  String? get runtimeId => 'runtime-a';

  @override
  String? get durableId => 'durable-a';
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'native app tour exposes stable targets and navigates valid steps',
    () async {
      final connection = _SurfaceConnection();
      final chat = ChatStore()..attachRoutedEvents(connection.routedEvents);
      final requests = RequestStore()
        ..attachRoutedEvents(connection.routedEvents);
      final session = _VisibleSession(
        connection: connection,
        chat: chat,
        requests: requests,
      );
      final panes = PaneWorkspaceStore();
      final store = MobileSurfaceStore(connection, session, panes);
      final revealed = <MobileSurface>[];
      store.bindReveal(revealed.add);
      addTearDown(store.dispose);
      addTearDown(session.dispose);
      addTearDown(requests.dispose);
      addTearDown(chat.dispose);
      addTearDown(connection.dispose);

      void emit(
        Map<String, dynamic> payload, {
        String sessionId = 'runtime-a',
      }) {
        connection.controller.add(
          RoutedGatewayEvent(
            route: _VisibleSession.route,
            socketGeneration: 1,
            event: GatewayEvent(
              type: 'tour.request',
              sessionId: sessionId,
              payload: payload,
            ),
          ),
        );
      }

      emit(const {
        'request_id': 'targets',
        'surface': 'app',
        'action': 'targets',
      });
      await Future<void>.delayed(Duration.zero);
      final targets = jsonDecode(connection.calls.single.$2['text'] as String);
      expect(
        targets['targets'],
        contains(
          predicate<Map>(
            (row) => row['selector'] == 'nav.sessions' && row['stable'] == true,
          ),
        ),
      );
      expect(
        targets['targets'],
        contains(predicate<Map>((row) => row['selector'] == 'chat.composer')),
      );

      emit(const {
        'request_id': 'start',
        'surface': 'app',
        'action': 'start',
        'steps': [
          {
            'selector': 'nav.sessions',
            'title': 'History',
            'text': 'Open history',
          },
          {'selector': 'nav.tasks', 'title': 'Tasks', 'text': 'Open tasks'},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.activeTourStep?.selector, 'nav.sessions');
      expect(revealed, [MobileSurface.sessions]);

      await store.advanceTour(1);
      expect(store.activeTourStep?.selector, 'nav.tasks');
      expect(revealed.last, MobileSurface.tasks);

      emit(const {
        'request_id': 'files',
        'surface': 'app',
        'action': 'show',
        'selector': 'workspace.files',
        'title': 'Files',
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(store.activeTourStep?.selector, 'workspace.files');
      expect(revealed.last, MobileSurface.files);
      final files = panes.orderedPanes.singleWhere(
        (pane) => pane.kind == WorkspacePaneKind.files,
      );
      expect(panes.focusedPaneId, files.id);

      final before = connection.calls.length;
      emit(const {
        'request_id': 'background',
        'surface': 'app',
        'action': 'stop',
      }, sessionId: 'runtime-b');
      await Future<void>.delayed(Duration.zero);
      expect(connection.calls, hasLength(before));
    },
  );

  testWidgets('tour registry resolves a real target rectangle', (tester) async {
    final connection = _SurfaceConnection();
    final chat = ChatStore()..attachRoutedEvents(connection.routedEvents);
    final requests = RequestStore()
      ..attachRoutedEvents(connection.routedEvents);
    final session = _VisibleSession(
      connection: connection,
      chat: chat,
      requests: requests,
    );
    final store = MobileSurfaceStore(connection, session, PaneWorkspaceStore());
    addTearDown(store.dispose);
    addTearDown(session.dispose);
    addTearDown(requests.dispose);
    addTearDown(chat.dispose);
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          home: MobileTourOverlay(
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: store.targetKey('chat.composer'),
                  width: 260,
                  height: 72,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(store.targetRect('chat.composer')?.size, const Size(260, 72));

    connection.controller.add(
      RoutedGatewayEvent(
        route: _VisibleSession.route,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'tour.request',
          sessionId: 'runtime-a',
          payload: {
            'surface': 'app',
            'action': 'show',
            'selector': 'chat.composer',
            'title': 'Composer',
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Composer'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
