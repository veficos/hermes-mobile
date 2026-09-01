import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/cloud_discovery.dart';

void main() {
  test('cloud discovery parses agents and authoritative org', () {
    final result = HermesCloudDiscoveryResult.fromBridgeMessage(
      jsonEncode({
        'status': 200,
        'body': jsonEncode({
          'agents': [
            {
              'id': 'a1',
              'name': 'Research Agent',
              'status': 'running',
              'dashboardUrl': 'https://a1.example',
              'dashboardGatewayState': 'active',
            },
          ],
          'org': {
            'id': 'o1',
            'slug': 'research',
            'name': 'Research',
            'role': 'OWNER',
          },
        }),
      }),
    );

    expect(result.statusCode, 200);
    expect(result.agents.single.dashboardUrl, 'https://a1.example');
    expect(result.org?.selector, 'research');
  });

  test('cloud discovery exposes multi-org selection and login state', () {
    final selection = HermesCloudDiscoveryResult.fromBridgeMessage(
      jsonEncode({
        'status': 409,
        'body': jsonEncode({
          'error': 'org_selection_required',
          'orgs': [
            {'id': 'o1', 'slug': null, 'name': 'Personal'},
          ],
        }),
      }),
    );
    expect(selection.needsOrgSelection, isTrue);
    expect(selection.orgs.single.selector, 'o1');

    final login = HermesCloudDiscoveryResult.fromBridgeMessage(
      jsonEncode({'status': 401, 'body': '{}'}),
    );
    expect(login.needsLogin, isTrue);
  });

  test('discovery script scopes org and uses credentialed fixed endpoint', () {
    final script = hermesCloudDiscoveryScript('research & labs');
    expect(script, contains("fetch('/api/agents?org=research+%26+labs'"));
    expect(script, contains("credentials:'include'"));
    expect(script, contains('CloudDiscovery.postMessage'));
  });
}
