import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/notifications_service.dart';
import 'package:hermes_mobile/core/remote_push.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/locale_store.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecrets implements ConnectionSecretStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakePushPlatform implements RemotePushPlatformAdapter {
  RemotePushToken? token = const RemotePushToken(
    platform: 'android',
    value: 'android-device-token-0001',
  );
  bool deleted = false;

  @override
  void Function(RemotePushToken)? onToken;
  @override
  void Function(Map<String, dynamic>)? onMessage;
  @override
  void Function(Map<String, dynamic>)? onTap;

  @override
  Future<void> deleteToken() async => deleted = true;

  @override
  void dispose() {}

  @override
  Future<RemotePushToken?> getToken() async => token;

  @override
  Future<void> initialize() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'hm_display_locale_v1': 'en'});
  });

  test(
    'registers, rotates, routes payloads, and unregisters before clear',
    () async {
      final requests = <http.Request>[];
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.body.isNotEmpty) {
          bodies.add((jsonDecode(request.body) as Map).cast<String, dynamic>());
        }
        return http.Response(
          request.method == 'POST'
              ? '{"ok":true,"rotated":false}'
              : '{"ok":true,"removed":1}',
          200,
        );
      });
      final api = ApiClient(
        baseUrl: 'https://gateway.example',
        apiKey: 'key',
        client: client,
      );
      final connection =
          ConnectionStore(store: SettingsStore(secrets: _MemorySecrets()))
            ..settings = const ConnectionSettings(
              serverUrl: 'https://gateway.example',
              apiKey: 'key',
            )
            ..api = api;
      final chat = ChatStore();
      final approvals = RequestStore();
      final session = SessionStore(
        connection: connection,
        chat: chat,
        requests: approvals,
      );
      final locale = LocaleStore();
      await locale.load();
      final notificationStore = NotificationStore(connection: connection);
      final notifications = NotificationsService(store: notificationStore);
      await notificationStore.initialized;
      final pushPlatform = _FakePushPlatform();
      final service = RemotePushService(
        connection: connection,
        session: session,
        locale: locale,
        notifications: notifications,
        platform: pushPlatform,
        packageInfoLoader: () async => PackageInfo(
          appName: 'Hermes Mobile',
          packageName: 'com.hermes.mobile',
          version: '1.2.3',
          buildNumber: '45',
        ),
      );

      await service.start();
      expect(service.registered, isTrue);
      final registrations = requests
          .where(
            (request) =>
                request.method == 'POST' &&
                request.url.path == '/api/v1/push/devices',
          )
          .toList();
      expect(registrations, hasLength(1));
      expect(bodies.single['platform'], 'android');
      expect(bodies.single['connection_id'], 'primary');
      expect(bodies.single['locale'], 'en');
      expect(bodies.single['app_version'], '1.2.3+45');
      expect(bodies.single['device_id'], startsWith('mobile-'));

      pushPlatform.onToken?.call(
        const RemotePushToken(
          platform: 'android',
          value: 'android-device-token-0002',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path == '/api/v1/push/devices',
        ),
        hasLength(2),
      );
      expect(bodies.last['token'], endsWith('0002'));

      NotificationTarget? tapped;
      notifications.onTapTarget = (target) => tapped = target;
      pushPlatform.onMessage?.call({
        'notification_id': 'remote-1',
        'event_type': 'message.complete',
        'title': 'Finished',
        'body': 'The response is ready.',
        'session_id': 'session-1',
        'connection_id': 'primary',
        'profile': 'work',
      });
      expect(notificationStore.items.first.id, 'remote-1');
      expect(notificationStore.items.first.kind, NotificationKind.success);
      expect(notificationStore.items.first.profile, 'work');

      pushPlatform.onTap?.call({
        'notification_id': 'remote-1',
        'session_id': 'session-1',
        'connection_id': 'primary',
        'profile': 'work',
      });
      expect(tapped?.sessionId, 'session-1');
      expect(tapped?.connectionId, 'primary');
      expect(tapped?.profile, 'work');

      await connection.clearConnection();
      expect(requests.last.method, 'DELETE');
      expect(
        requests.last.url.path,
        startsWith('/api/v1/push/devices/mobile-'),
      );
      expect(service.registered, isFalse);

      service.dispose();
      notifications.dispose();
      notificationStore.dispose();
      session.dispose();
      approvals.dispose();
      chat.dispose();
      connection.dispose();
      api.close();
    },
  );

  test('explicit unregister can delete the native provider token', () async {
    final client = MockClient((request) async => http.Response('{}', 200));
    final api = ApiClient(
      baseUrl: 'https://gateway.example',
      apiKey: 'key',
      client: client,
    );
    final connection =
        ConnectionStore(store: SettingsStore(secrets: _MemorySecrets()))
          ..settings = const ConnectionSettings(
            serverUrl: 'https://gateway.example',
            apiKey: 'key',
          )
          ..api = api;
    final chat = ChatStore();
    final approvals = RequestStore();
    final session = SessionStore(
      connection: connection,
      chat: chat,
      requests: approvals,
    );
    final locale = LocaleStore();
    await locale.load();
    final store = NotificationStore(connection: connection);
    final notifications = NotificationsService(store: store);
    final platform = _FakePushPlatform();
    final service = RemotePushService(
      connection: connection,
      session: session,
      locale: locale,
      notifications: notifications,
      platform: platform,
      packageInfoLoader: () async => PackageInfo(
        appName: 'Hermes',
        packageName: 'com.hermes.mobile',
        version: '1',
        buildNumber: '1',
      ),
    );
    await service.start();

    await service.unregister(deletePlatformToken: true);

    expect(platform.deleted, isTrue);
    service.dispose();
    notifications.dispose();
    store.dispose();
    session.dispose();
    approvals.dispose();
    chat.dispose();
    connection.dispose();
    api.close();
  });
}
