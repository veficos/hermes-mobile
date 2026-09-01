import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/plugin_contributions.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/core/stores/plugin_contribution_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/widgets/plugin_contribution_surface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingConnection extends ConnectionStore {
  final List<(String, Map<String, dynamic>)> calls = [];
  Map<String, dynamic> response;
  Map<String, dynamic> Function(String, Map<String, dynamic>)? responder;

  _RecordingConnection({this.response = const {'count': 4}, this.responder});

  @override
  Future<Map<String, dynamic>> requestForOwner(
    OwnerRoute route,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    return responder?.call(method, params) ?? response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget localizedApp(PluginContributionStore store, {Locale? locale}) =>
      ChangeNotifierProvider<PluginContributionStore>.value(
        value: store,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: PluginContributionSurface(
              area: MobileContributionArea.detail,
            ),
          ),
        ),
      );

  test('pluginToneColor maps known HermesSemantic names, else null', () {
    expect(pluginToneColor('green'), isNotNull);
    expect(pluginToneColor('purple'), isNotNull);
    expect(pluginToneColor('not-a-color'), isNull);
    expect(pluginToneColor(null), isNull);
  });

  test('fromJson parses color and badge_action', () {
    final store = PluginContributionStore(ConnectionStore());
    store.adaptPluginInventory([
      {
        'id': 'kanban',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'open',
            'area': 'navigation',
            'title': 'Board',
            'color': 'purple',
            'badge_action': {'kind': 'rest', 'path': 'badge'},
          },
        ],
      },
    ]);
    final item = store.contributions.single;
    expect(item.color, 'purple');
    expect(item.badgeAction, {'kind': 'rest', 'path': 'badge'});
  });

  test(
    'declarative view bounds fields, actions, polling and locale bundles',
    () {
      final store = PluginContributionStore(ConnectionStore());
      addTearDown(store.dispose);
      store.adaptPluginInventory([
        {
          'id': 'deploy',
          'enabled': true,
          'mobile_locales': {
            'ar': {'deploy.title': 'النشر'},
          },
          'mobile_contributions': [
            {
              'id': 'configure',
              'title': 'Deploy',
              'title_key': 'deploy.title',
              'action': {'kind': 'gateway', 'method': 'deploy.run'},
              'view': {
                'type': 'form',
                'poll_seconds': 1,
                'persist_inputs': true,
                'fields': [
                  {
                    'id': 'environment',
                    'label': 'Environment',
                    'type': 'select',
                    'required': true,
                    'options': ['staging', 'production'],
                  },
                  {'id': 'bad field', 'label': 'Bad'},
                ],
                'actions': [
                  {
                    'id': 'dry-run',
                    'title': 'Dry run',
                    'action': {'kind': 'gateway', 'method': 'deploy.preview'},
                  },
                ],
              },
            },
          ],
        },
      ]);

      final item = store.contributions.single;
      expect(item.view.type, MobileContributionViewType.form);
      expect(item.view.pollSeconds, 5);
      expect(item.view.fields.map((field) => field.id), ['environment']);
      expect(item.view.actions.single.id, 'dry-run');
      expect(item.localizedTitle(const Locale('ar')), 'النشر');
      expect(item.localizedTitle(const Locale('ja')), 'Deploy');
    },
  );

  test('structured result normalizes fields, items and safe URLs', () {
    final result = PluginActionResult.fromJson({
      'title': 'Deployment complete',
      'message': 'Two services updated.',
      'fields': {'Environment': 'production', 'Revision': 'abc123'},
      'items': [
        {'title': 'api', 'status': 'healthy'},
        {'title': 'worker', 'status': 'healthy'},
      ],
      'url': 'https://example.com/deployments/abc123',
    });

    expect(result.shouldPresent, isTrue);
    expect(result.usesRawFallback, isFalse);
    expect(result.title, 'Deployment complete');
    expect(result.fields.map((field) => field.label), [
      'Environment',
      'Revision',
    ]);
    expect(result.items, hasLength(2));
    expect(result.url?.scheme, 'https');
  });

  test(
    'result falls back to JSON and suppresses acknowledgement-only data',
    () {
      final fallback = PluginActionResult.fromJson({
        'custom_payload': {'answer': 42},
      });
      expect(fallback.shouldPresent, isTrue);
      expect(fallback.usesRawFallback, isTrue);

      final acknowledgement = PluginActionResult.fromJson({'ok': true});
      expect(acknowledgement.shouldPresent, isFalse);

      final unsafeUrl = PluginActionResult.fromJson({
        'url': 'file:///etc/passwd',
      });
      expect(unsafeUrl.url, isNull);
      expect(unsafeUrl.usesRawFallback, isTrue);
    },
  );

  test('automatic badges execute only read-only actions', () async {
    final connection = _RecordingConnection();
    final store = PluginContributionStore(connection);
    addTearDown(store.dispose);
    store.adaptPluginInventory([
      {
        'id': 'demo',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'safe',
            'title': 'Safe',
            'action': {'kind': 'gateway', 'method': 'config.show'},
            'badge_action': {'kind': 'gateway', 'method': 'config.show'},
          },
          {
            'id': 'unsafe',
            'title': 'Unsafe',
            'action': {'kind': 'gateway', 'method': 'config.set'},
            'badge_action': {
              'kind': 'gateway',
              'method': 'config.set',
              'params': {'action': 'list'},
            },
          },
        ],
      },
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(connection.calls, hasLength(1));
    expect(connection.calls.single.$1, 'config.show');
    expect(connection.calls.single.$2, isEmpty);
    expect(store.badges, {'demo:safe': '4'});

    await store.invoke(
      store.contributions.singleWhere((item) => item.id == 'unsafe'),
    );
    expect(connection.calls.last.$1, 'config.set');
  });

  test('inventory refresh removes stale result and badge state', () async {
    final connection = _RecordingConnection();
    final store = PluginContributionStore(connection);
    addTearDown(store.dispose);
    store.adaptPluginInventory([
      {
        'id': 'demo',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'old',
            'title': 'Old',
            'action': {'kind': 'gateway', 'method': 'config.show'},
            'badge_action': {'kind': 'gateway', 'method': 'config.show'},
          },
        ],
      },
    ]);
    await Future<void>.delayed(Duration.zero);
    await store.invoke(store.contributions.single);
    expect(store.results, isNotEmpty);
    expect(store.badges, isNotEmpty);

    store.adaptPluginInventory(const []);

    expect(store.results, isEmpty);
    expect(store.badges, isEmpty);
  });

  testWidgets('invoke() with kind clipboard writes the clipboard', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text']?.toString();
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = PluginContributionStore(ConnectionStore());
    store.adaptPluginInventory([
      {
        'id': 'demo',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'copy',
            'area': 'detail',
            'title': 'Copy',
            'action': {'kind': 'clipboard', 'text': 'hello from plugin'},
          },
        ],
      },
    ]);
    final result = await store.invoke(store.contributions.single);
    expect(result, {'ok': true});
    expect(clipboardText, 'hello from plugin');
    expect(store.results[store.contributions.single.namespacedId], {
      'ok': true,
    });
  });

  testWidgets(
    'invoke() with kind open-external rejects an invalid url before reaching the platform channel',
    (tester) async {
      final store = PluginContributionStore(ConnectionStore());
      store.adaptPluginInventory([
        {
          'id': 'demo',
          'enabled': true,
          'mobile_contributions': [
            {
              'id': 'open',
              'area': 'detail',
              'title': 'Open',
              'action': {'kind': 'open-external', 'url': ''},
            },
          ],
        },
      ]);
      await expectLater(
        store.invoke(store.contributions.single),
        throwsA(isA<StateError>()),
      );
    },
  );

  testWidgets('open-external rejects schemes outside the mobile allowlist', (
    tester,
  ) async {
    final store = PluginContributionStore(ConnectionStore());
    addTearDown(store.dispose);
    store.adaptPluginInventory([
      {
        'id': 'demo',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'open',
            'area': 'detail',
            'title': 'Open',
            'action': {'kind': 'open-external', 'url': 'file:///etc/passwd'},
          },
        ],
      },
    ]);

    await expectLater(
      store.invoke(store.contributions.single),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('scheme'),
        ),
      ),
    );
  });

  test(
    'REST action stays namespaced and forwards method, query and body',
    () async {
      late http.Request captured;
      final api = ApiClient(
        baseUrl: 'http://mobile.invalid',
        apiKey: 'test-key',
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"message":"updated"}', 200);
        }),
      );
      final gateway = GatewayClient(
        serverBaseUrl: 'http://mobile.invalid',
        apiKey: 'test-key',
      );
      final connection = ConnectionStore();
      connection.registry.add(
        ConnectionRuntime(
          id: const ConnectionId('work'),
          settings: ConnectionSettings(
            serverUrl: 'http://mobile.invalid',
            apiKey: 'test-key',
          ),
          api: api,
          gateway: gateway,
        ),
        makeActive: true,
      );
      final store = PluginContributionStore(connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      store.adaptPluginInventory(
        [
          {
            'id': 'demo/plugin',
            'enabled': true,
            'mobile_contributions': [
              {
                'id': 'update',
                'title': 'Update',
                'action': {
                  'kind': 'rest',
                  'method': 'PATCH',
                  'path': 'tasks/a?b',
                  'query': {'profile': 'work', 'limit': 5},
                  'body': {'status': 'done'},
                },
              },
            ],
          },
        ],
        owner: const OwnerRoute(
          connectionId: ConnectionId('work'),
          profile: 'work',
        ),
      );

      expect(await store.invoke(store.contributions.single), {
        'message': 'updated',
      });
      expect(captured.method, 'PATCH');
      expect(captured.url.path, '/api/v1/plugins/demo%2Fplugin/tasks/a%3Fb');
      expect(captured.url.queryParameters, {'profile': 'work', 'limit': '5'});
      expect(jsonDecode(captured.body), {'status': 'done'});
    },
  );

  test('plugin install sends profile and install policy', () async {
    late http.Request captured;
    final api = ApiClient(
      baseUrl: 'http://mobile.invalid',
      apiKey: 'test-key',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      }),
    );
    addTearDown(api.close);

    expect(
      await api.installPlugin(
        'owner/repo',
        profile: 'work',
        force: true,
        enable: false,
      ),
      {'ok': true},
    );
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/plugins/install');
    expect(captured.url.queryParameters, {'profile': 'work'});
    expect(jsonDecode(captured.body), {
      'identifier': 'owner/repo',
      'force': true,
      'enable': false,
    });
  });

  test('unsupported action kinds throw a clear error', () async {
    final store = PluginContributionStore(ConnectionStore());
    store.adaptPluginInventory([
      {
        'id': 'demo',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'x',
            'area': 'detail',
            'title': 'X',
            'action': {'kind': 'native-code-exec'},
          },
        ],
      },
    ]);
    await expectLater(
      store.invoke(store.contributions.single),
      throwsA(isA<StateError>()),
    );
  });

  test('adapter namespaces, sorts and replaces contributions per plugin', () {
    final store = PluginContributionStore(ConnectionStore());
    store.adaptPluginInventory([
      {
        'id': 'kanban',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'open',
            'area': 'navigation',
            'title': 'Board old',
            'order': 20,
          },
          {'id': 'open', 'area': 'navigation', 'title': 'Board', 'order': 10},
          {'id': 'sync', 'area': 'command', 'title': 'Sync', 'order': 5},
        ],
      },
      {
        'id': 'off',
        'enabled': false,
        'mobile_contributions': [
          {'id': 'hidden', 'title': 'Hidden'},
        ],
      },
    ]);

    expect(store.contributions.map((e) => e.namespacedId), [
      'kanban:sync',
      'kanban:open',
    ]);
    expect(store.contributions.last.title, 'Board');
    expect(store.forArea(MobileContributionArea.navigation).length, 1);
  });

  test('unknown area degrades to detail and malformed rows are ignored', () {
    final store = PluginContributionStore(ConnectionStore());
    store.adaptPluginInventory([
      {
        'name': 'demo',
        'enabled': true,
        'contributions': [
          {'id': 'one', 'area': 'desktop-only', 'title': 'Fallback'},
          {'id': '', 'title': 'invalid'},
        ],
      },
    ]);
    expect(store.contributions.single.area, MobileContributionArea.detail);
  });

  testWidgets('surface presents structured action results in a shared sheet', (
    tester,
  ) async {
    final connection = _RecordingConnection(
      response: {
        'title': 'Sync complete',
        'message': 'All records are current.',
        'fields': {'Updated': 12},
        'items': [
          {'title': 'Contacts', 'status': 'ready'},
        ],
        'url': 'https://example.com/sync',
      },
    );
    final store = PluginContributionStore(connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    store.adaptPluginInventory([
      {
        'id': 'demo',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'sync',
            'area': 'detail',
            'title': 'Sync',
            'action': {'kind': 'gateway', 'method': 'demo.sync'},
          },
        ],
      },
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<PluginContributionStore>.value(
        value: store,
        child: const MaterialApp(
          home: Scaffold(
            body: PluginContributionSurface(
              area: MobileContributionArea.detail,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sync'));
    await tester.pumpAndSettle();

    expect(find.text('Sync complete'), findsOneWidget);
    expect(find.text('All records are current.'), findsOneWidget);
    expect(find.text('Updated'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets(
    'surface does not open a sheet for acknowledgement-only results',
    (tester) async {
      final connection = _RecordingConnection(response: {'ok': true});
      final store = PluginContributionStore(connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      store.adaptPluginInventory([
        {
          'id': 'demo',
          'enabled': true,
          'mobile_contributions': [
            {
              'id': 'run',
              'title': 'Run',
              'action': {'kind': 'gateway', 'method': 'demo.run'},
            },
          ],
        },
      ]);

      await tester.pumpWidget(
        ChangeNotifierProvider<PluginContributionStore>.value(
          value: store,
          child: const MaterialApp(
            home: Scaffold(
              body: PluginContributionSurface(
                area: MobileContributionArea.detail,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(connection.calls, hasLength(1));
    },
  );

  testWidgets('form view validates and injects inputs into a gateway action', (
    tester,
  ) async {
    final connection = _RecordingConnection(response: {'ok': true});
    final store = PluginContributionStore(connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    store.adaptPluginInventory([
      {
        'id': 'deploy',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'configure',
            'title': 'Configure deploy',
            'action': {'kind': 'gateway', 'method': 'deploy.run'},
            'view': {
              'type': 'form',
              'persist_inputs': true,
              'fields': [
                {'id': 'name', 'label': 'Name', 'required': true},
                {
                  'id': 'replicas',
                  'label': 'Replicas',
                  'type': 'number',
                  'min': 1,
                  'max': 10,
                },
                {
                  'id': 'region',
                  'label': 'Region',
                  'type': 'select',
                  'required': true,
                  'options': ['eu', 'us'],
                },
                {
                  'id': 'notify',
                  'label': 'Notify',
                  'type': 'boolean',
                  'default': true,
                },
              ],
              'submit_action': {
                'kind': 'gateway',
                'method': 'deploy.configure',
                'params': {'source': 'mobile'},
              },
            },
          },
        ],
      },
    ]);

    await tester.pumpWidget(localizedApp(store));
    await tester.tap(find.text('Configure deploy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.text('This field is required'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'api');
    await tester.enterText(find.widgetWithText(TextFormField, 'Replicas'), '3');
    await tester.tap(find.text('Region'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('eu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(connection.calls.last.$1, 'deploy.configure');
    expect(connection.calls.last.$2, {
      'source': 'mobile',
      'inputs': {'name': 'api', 'replicas': 3, 'region': 'eu', 'notify': true},
    });
    await store.flushStorage();
    expect(await store.readStorage(store.contributions.single, 'form-inputs'), {
      'name': 'api',
      'replicas': 3,
      'region': 'eu',
      'notify': true,
    });
  });

  testWidgets('list view renders detail and confirms an item action', (
    tester,
  ) async {
    final connection = _RecordingConnection(
      responder: (method, params) => method == 'tasks.list'
          ? {
              'items': [
                {'id': 'T-1', 'name': 'Release', 'state': 'ready'},
              ],
            }
          : {'ok': true},
    );
    final store = PluginContributionStore(connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    store.adaptPluginInventory([
      {
        'id': 'tasks',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'list',
            'title': 'Tasks',
            'action': {'kind': 'gateway', 'method': 'tasks.list'},
            'view': {
              'type': 'list',
              'load_action': {'kind': 'gateway', 'method': 'tasks.list'},
              'item_title_key': 'name',
              'item_subtitle_key': 'state',
              'actions': [
                {
                  'id': 'delete',
                  'title': 'Delete',
                  'tone': 'danger',
                  'confirm_message': 'Delete this task?',
                  'action': {'kind': 'gateway', 'method': 'tasks.delete'},
                },
              ],
            },
          },
        ],
      },
    ]);

    await tester.pumpWidget(localizedApp(store));
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Release'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);

    await tester.tap(find.text('Release'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this task?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final delete = connection.calls.singleWhere(
      (call) => call.$1 == 'tasks.delete',
    );
    expect(delete.$2, {
      'item': {'id': 'T-1', 'name': 'Release', 'state': 'ready'},
    });
  });

  testWidgets('localized contribution title follows the active locale', (
    tester,
  ) async {
    final store = PluginContributionStore(ConnectionStore());
    addTearDown(store.dispose);
    store.adaptPluginInventory([
      {
        'id': 'demo',
        'enabled': true,
        'mobile_locales': {
          'ar': {'action.title': 'مزامنة'},
        },
        'mobile_contributions': [
          {
            'id': 'sync',
            'title': 'Sync',
            'title_key': 'action.title',
            'action': {'kind': 'gateway', 'method': 'demo.sync'},
          },
        ],
      },
    ]);

    await tester.pumpWidget(localizedApp(store, locale: const Locale('ar')));
    expect(find.text('مزامنة'), findsOneWidget);
    expect(find.text('Sync'), findsNothing);
  });

  test(
    'notify action is attributed into the host notification center',
    () async {
      final connection = _RecordingConnection();
      final notifications = NotificationStore(connection: connection);
      await notifications.initialized;
      final store = PluginContributionStore(
        connection,
        notifications: notifications,
      );
      addTearDown(store.dispose);
      addTearDown(notifications.dispose);
      addTearDown(connection.dispose);
      store.adaptPluginInventory([
        {
          'id': 'builds',
          'enabled': true,
          'mobile_contributions': [
            {
              'id': 'notify',
              'title': 'Notify',
              'action': {
                'kind': 'notify',
                'key': 'complete',
                'level': 'success',
                'title': 'Build complete',
                'message': 'Revision abc is ready.',
              },
            },
          ],
        },
      ]);

      await store.invoke(store.contributions.single);
      expect(notifications.items.single.id, 'plugin:builds:complete');
      expect(notifications.items.single.kind, NotificationKind.success);
      expect(notifications.items.single.title, 'Build complete');
    },
  );

  test(
    'plugin socket is namespace-scoped and updates live view data',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requested = Completer<Uri>();
      final accepted = Completer<WebSocket>();
      server.listen((request) async {
        if (!requested.isCompleted) requested.complete(request.uri);
        final socket = await WebSocketTransformer.upgrade(request);
        if (!accepted.isCompleted) accepted.complete(socket);
      });
      addTearDown(() => server.close(force: true));

      final baseUrl = 'http://127.0.0.1:${server.port}';
      final api = ApiClient(baseUrl: baseUrl, apiKey: 'mobile-key');
      final gateway = GatewayClient(
        serverBaseUrl: baseUrl,
        apiKey: 'mobile-key',
      );
      final connection = ConnectionStore();
      connection.registry.add(
        ConnectionRuntime(
          id: const ConnectionId('work'),
          settings: ConnectionSettings(
            serverUrl: baseUrl,
            apiKey: 'mobile-key',
          ),
          api: api,
          gateway: gateway,
        ),
        makeActive: true,
      );
      final store = PluginContributionStore(connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      store.adaptPluginInventory([
        {
          'id': 'tasks',
          'enabled': true,
          'mobile_contributions': [
            {
              'id': 'list',
              'title': 'Tasks',
              'action': {'kind': 'gateway', 'method': 'tasks.list'},
              'view': {
                'type': 'list',
                'socket_path': '/events/live',
                'load_action': {'kind': 'gateway', 'method': 'tasks.list'},
              },
            },
          ],
        },
      ]);

      final socket = await accepted.future.timeout(const Duration(seconds: 3));
      final uri = await requested.future;
      expect(uri.path, '/api/v1/plugins/tasks/events/live');
      expect(uri.queryParameters['token'], 'mobile-key');

      final changed = Completer<void>();
      store.addListener(() {
        if (store.viewData['tasks:list']?['items'] is List &&
            !changed.isCompleted) {
          changed.complete();
        }
      });
      socket.add(
        jsonEncode({
          'data': {
            'items': [
              {'id': 'T-9', 'title': 'Live'},
            ],
          },
        }),
      );
      await changed.future.timeout(const Duration(seconds: 3));
      expect(store.viewData['tasks:list']?['items'], [
        {'id': 'T-9', 'title': 'Live'},
      ]);
      await socket.close();
    },
  );
}
