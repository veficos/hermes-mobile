import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NotificationConnection extends ConnectionStore {
  final controller = StreamController<RoutedGatewayEvent>.broadcast();

  @override
  Stream<RoutedGatewayEvent> get routedEvents => controller.stream;

  void emit(String connectionId, GatewayEvent event, {String? profile}) {
    controller.add(
      RoutedGatewayEvent(
        route: OwnerRoute(
          connectionId: ConnectionId(connectionId),
          profile: profile,
        ),
        socketGeneration: 1,
        event: event,
      ),
    );
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('external kanban notifications deduplicate by key', () async {
    final connection = ConnectionStore();
    final store = NotificationStore(connection: connection);
    store.addExternal(
      key: 'kanban:b:1',
      kind: NotificationKind.success,
      title: '完成',
      message: 't',
    );
    store.addExternal(
      key: 'kanban:b:1',
      kind: NotificationKind.success,
      title: '完成',
      message: 't updated',
    );
    expect(store.items, hasLength(1));
    expect(store.items.single.message, 't updated');
    await store.flushPersistence();
    store.dispose();
    connection.dispose();
  });

  test('notification read and system delivery state survive restart', () async {
    final firstConnection = ConnectionStore();
    final first = NotificationStore(connection: firstConnection);
    await first.initialized;
    first.addExternal(
      key: 'job:1',
      kind: NotificationKind.success,
      title: '完成',
      message: 'result',
      sessionId: 'session-1',
    );
    first.markRead('job:1');
    first.markSystemShown('job:1');
    await first.flushPersistence();
    first.dispose();
    firstConnection.dispose();

    final secondConnection = ConnectionStore();
    final second = NotificationStore(connection: secondConnection);
    await second.initialized;
    expect(second.items, hasLength(1));
    expect(second.items.single.sessionId, 'session-1');
    expect(second.items.single.read, isTrue);
    expect(second.items.single.systemShown, isTrue);
    expect(second.items.single.connectionId, 'primary');
    second.dispose();
    secondConnection.dispose();
  });

  test('notification target supports structured and legacy payloads', () {
    const target = NotificationTarget(
      notificationId: 'approval:1',
      sessionId: 'session-1',
      connectionId: 'saved:work',
      profile: 'expert',
      requestId: 'request-7',
      approval: true,
    );

    final decoded = NotificationTarget.fromPayload(target.toPayload());
    expect(decoded.notificationId, 'approval:1');
    expect(decoded.sessionId, 'session-1');
    expect(decoded.connectionId, 'saved:work');
    expect(decoded.profile, 'expert');
    expect(decoded.requestId, 'request-7');
    expect(decoded.approval, isTrue);
    expect(
      NotificationTarget.fromPayload('old-session').sessionId,
      'old-session',
    );
  });

  test('notification target normalizes provider payloads for session taps', () {
    final camelCase = NotificationTarget.fromMap({
      'notificationId': 'remote-1',
      'sessionId': 'session-camel',
      'connectionId': 'saved:work',
      'profileId': 'expert',
    });
    expect(camelCase.notificationId, 'remote-1');
    expect(camelCase.sessionId, 'session-camel');
    expect(camelCase.connectionId, 'saved:work');
    expect(camelCase.profile, 'expert');

    final nested = NotificationTarget.fromMap({
      'data': {
        'stored_session_id': 'session-nested',
        'connection_id': 'primary',
        'event_type': 'approval.request',
        'request_id': 'request-2',
      },
    });
    expect(nested.sessionId, 'session-nested');
    expect(nested.connectionId, 'primary');
    expect(nested.requestId, 'request-2');
    expect(nested.approval, isTrue);

    final encoded = NotificationTarget.fromMap({
      'payload': '{"durableSessionId":"session-json"}',
    });
    expect(encoded.sessionId, 'session-json');
  });

  test(
    'gateway notifications keep owner route and clear only matching key',
    () async {
      final connection = _NotificationConnection();
      final store = NotificationStore(connection: connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      await store.initialized;

      for (final id in ['primary', 'saved:work']) {
        connection.emit(
          id,
          GatewayEvent(
            type: 'notification.show',
            payload: {'key': 'credits.low', 'text': 'Credits: Low'},
          ),
        );
      }
      await pumpEventQueue();
      expect(store.items, hasLength(2));
      expect(store.items.map((item) => item.connectionId).toSet(), {
        'primary',
        'saved:work',
      });

      connection.emit(
        'saved:work',
        GatewayEvent(
          type: 'notification.clear',
          payload: {'key': 'credits.low'},
        ),
      );
      await pumpEventQueue();
      expect(store.items.single.connectionId, 'primary');
    },
  );

  test('approval notification retains routed profile and request id', () async {
    final connection = _NotificationConnection();
    final store = NotificationStore(connection: connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    await store.initialized;

    connection.emit(
      'saved:work',
      GatewayEvent(
        type: 'approval.request',
        sessionId: 'runtime-7',
        payload: const {'request_id': 'request-7'},
      ),
      profile: 'expert',
    );
    await pumpEventQueue();

    expect(store.items.single.profile, 'expert');
    expect(store.items.single.requestId, 'request-7');
  });
}
