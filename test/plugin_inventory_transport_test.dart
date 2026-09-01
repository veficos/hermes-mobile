import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/plugin_contribution_store.dart';

class _PluginApi extends ApiClient {
  final List<String?> profiles = [];
  final bool fail;

  _PluginApi({this.fail = false})
    : super(baseUrl: 'http://plugins.invalid', apiKey: 'key');

  @override
  Future<List<Map<String, dynamic>>> plugins({String? profile}) async {
    profiles.add(profile);
    if (fail) throw ApiException(404, 'missing');
    return [
      {
        'key': 'demo',
        'status': 'enabled',
        'mobile_contributions': [
          {
            'id': 'form',
            'title_key': 'demo.form',
            'view': {'type': 'form'},
          },
        ],
      },
    ];
  }
}

class _PluginConnection extends ConnectionStore {
  final List<(String, Map<String, dynamic>)> gatewayCalls = [];

  @override
  Future<Map<String, dynamic>> requestForOwner(
    OwnerRoute route,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    gatewayCalls.add((method, params));
    return {
      'plugins': [
        {
          'key': 'gateway',
          'status': 'enabled',
          'mobile_locales': {
            'zh-hant': {'gateway.dashboard': '儀表板'},
          },
          'mobile_contributions': [
            {
              'id': 'dashboard',
              'area': 'pane',
              'title_key': 'gateway.dashboard',
              'view': {
                'type': 'list',
                'load_action': {
                  'kind': 'gateway',
                  'method': 'gateway.list',
                  'params': <String, dynamic>{},
                },
                'socket_path': 'dashboard/events',
              },
            },
          ],
        },
      ],
    };
  }
}

void main() {
  test('plugin socket route follows companion and direct namespaces', () {
    final companion = ApiClient(
      baseUrl: 'https://agent.example',
      apiKey: 'secret',
    );
    final direct = ApiClient(
      baseUrl: 'https://agent.example',
      apiKey: 'secret',
      directGateway: true,
      gatewayRequest: (_, _) async => const {},
    );
    addTearDown(companion.close);
    addTearDown(direct.close);

    expect(
      pluginContributionSocketUri(
        companion,
        pluginId: 'tasks',
        socketPath: 'events/live',
      ).path,
      '/api/v1/plugins/tasks/events/live',
    );
    expect(
      pluginContributionSocketUri(
        direct,
        pluginId: 'tasks',
        socketPath: 'events/live',
      ).path,
      '/api/plugins/tasks/events/live',
    );
  });

  test('companion inventory prefers enriched REST manifest payload', () async {
    final api = _PluginApi();
    final connection = _PluginConnection()
      ..settings = const ConnectionSettings(
        serverUrl: 'http://plugins.invalid',
        apiKey: 'key',
        transport: ConnectionTransport.companion,
      )
      ..api = api;
    addTearDown(connection.dispose);

    final rows = await connection.listPlugins(profile: 'work');

    expect(api.profiles, ['work']);
    expect(connection.gatewayCalls, isEmpty);
    expect(rows.single['id'], 'demo');
    expect(rows.single['enabled'], isTrue);
    expect(
      (rows.single['mobile_contributions'] as List).single['title_key'],
      'demo.form',
    );
  });

  test('direct gateway inventory stays on plugins.manage', () async {
    final api = _PluginApi();
    final connection = _PluginConnection()
      ..settings = const ConnectionSettings(
        serverUrl: 'http://plugins.invalid',
        apiKey: 'key',
        transport: ConnectionTransport.directGateway,
      )
      ..api = api;
    addTearDown(connection.dispose);

    final rows = await connection.listPlugins();

    expect(api.profiles, isEmpty);
    expect(connection.gatewayCalls.single.$1, 'plugins.manage');
    expect(rows.single['id'], 'gateway');
    final contribution =
        (rows.single['mobile_contributions'] as List).single as Map;
    expect(contribution['area'], 'pane');
    expect((contribution['view'] as Map)['type'], 'list');
    expect((contribution['view'] as Map)['socket_path'], 'dashboard/events');
    expect(
      ((rows.single['mobile_locales'] as Map)['zh-hant']
          as Map)['gateway.dashboard'],
      '儀表板',
    );
  });

  test('old companion falls back to gateway inventory', () async {
    final api = _PluginApi(fail: true);
    final connection = _PluginConnection()
      ..settings = const ConnectionSettings(
        serverUrl: 'http://plugins.invalid',
        apiKey: 'key',
        transport: ConnectionTransport.companion,
      )
      ..api = api;
    addTearDown(connection.dispose);

    final rows = await connection.listPlugins(profile: 'legacy');

    expect(api.profiles, ['legacy']);
    expect(connection.gatewayCalls.single.$2['profile'], 'legacy');
    expect(rows.single['id'], 'gateway');
  });
}
