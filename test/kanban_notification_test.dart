import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      approval: true,
    );

    final decoded = NotificationTarget.fromPayload(target.toPayload());
    expect(decoded.notificationId, 'approval:1');
    expect(decoded.sessionId, 'session-1');
    expect(decoded.connectionId, 'saved:work');
    expect(decoded.profile, 'expert');
    expect(decoded.approval, isTrue);
    expect(
      NotificationTarget.fromPayload('old-session').sessionId,
      'old-session',
    );
  });
}
