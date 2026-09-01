import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('skillContent GETs /skills/content with the name query param', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode({'name': 'foo', 'content': '# Foo'}), 200);
      }),
    );
    final content = await api.skillContent('foo');
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/skills/content');
    expect(request.url.queryParameters['name'], 'foo');
    expect(content, '# Foo');
  });

  test('skillHubSources GETs /skills/hub/sources and parses the payload', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'sources': [
              {'id': 'github', 'label': 'GitHub'},
            ],
            'index_available': true,
            'featured': [],
            'installed': {},
          }),
          200,
        );
      }),
    );
    final result = await api.skillHubSources();
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/skills/hub/sources');
    expect(result.sources.single.id, 'github');
  });

  test('searchSkillsHub carries q/source/limit as query params', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'results': [],
            'source_counts': {},
            'timed_out': [],
            'installed': {},
          }),
          200,
        );
      }),
    );
    await api.searchSkillsHub('web research', source: 'github', limit: 20);
    expect(request.url.path, '/api/v1/skills/hub/search');
    expect(request.url.queryParameters['q'], 'web research');
    expect(request.url.queryParameters['source'], 'github');
    expect(request.url.queryParameters['limit'], '20');
  });

  test('previewSkillHub GETs /skills/hub/preview with identifier', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'name': 'A',
            'description': '',
            'source': 'github',
            'identifier': 'github:a/a',
            'trust_level': 'community',
            'repo': null,
            'tags': <String>[],
            'skill_md': '# A',
            'files': <String>[],
          }),
          200,
        );
      }),
    );
    final preview = await api.previewSkillHub('github:a/a');
    expect(request.url.path, '/api/v1/skills/hub/preview');
    expect(request.url.queryParameters['identifier'], 'github:a/a');
    expect(preview.skillMd, '# A');
  });

  test('scanSkillHub GETs /skills/hub/scan with identifier', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'name': 'A',
            'identifier': 'github:a/a',
            'source': 'github',
            'trust_level': 'community',
            'verdict': 'clean',
            'summary': 'no issues',
            'policy': 'allow',
            'policy_reason': null,
            'findings': <Map<String, dynamic>>[],
            'severity_counts': <String, int>{},
          }),
          200,
        );
      }),
    );
    final scan = await api.scanSkillHub('github:a/a');
    expect(request.url.path, '/api/v1/skills/hub/scan');
    expect(scan.policy, 'allow');
  });

  test('installSkillFromHub POSTs identifier body', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode({'ok': true, 'pid': 1, 'name': 'action-1'}), 200);
      }),
    );
    final result = await api.installSkillFromHub('github:a/a');
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/skills/hub/install');
    expect(jsonDecode(request.body), {'identifier': 'github:a/a'});
    expect(result['name'], 'action-1');
  });

  test('uninstallSkillFromHub POSTs name body', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode({'ok': true, 'pid': 1, 'name': 'action-2'}), 200);
      }),
    );
    await api.uninstallSkillFromHub('my-skill');
    expect(request.url.path, '/api/v1/skills/hub/uninstall');
    expect(jsonDecode(request.body), {'name': 'my-skill'});
  });

  test('updateSkillsFromHub POSTs an empty body (updates all)', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({'ok': true, 'pid': 1, 'name': 'skills-update'}),
          200,
        );
      }),
    );
    await api.updateSkillsFromHub();
    expect(request.url.path, '/api/v1/skills/hub/update');
    expect(jsonDecode(request.body), <String, dynamic>{});
  });
}
