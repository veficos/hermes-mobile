import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/time_parsing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('task delete rejects an explicit ok false response', () async {
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((_) async => http.Response('{"ok":false}', 200)),
    );
    await expectLater(api.taskDelete('missing'), throwsA(isA<ApiException>()));
  });

  test('write requests reject an explicit failure envelope', () async {
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient(
        (_) async =>
            http.Response('{"ok":false,"error":{"message":"denied"}}', 200),
      ),
    );
    await expectLater(
      api.putConfig({'theme': 'dark'}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'denied',
        ),
      ),
    );
  });

  test('diagnostic requests can return an explicit negative result', () async {
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient(
        (_) async => http.Response('{"ok":false,"message":"unreachable"}', 200),
      ),
    );
    final result = await api.validateCustomEndpoint({
      'base_url': 'https://invalid.test',
    });
    expect(result['ok'], isFalse);
    expect(result['message'], 'unreachable');
  });

  test('provider environment methods use mobile server routes', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.url.path.endsWith('/reveal') ? '{"value":"secret"}' : '{}',
          200,
        );
      }),
    );
    await api.providerEnvVars(profile: 'work');
    await api.setProviderEnvVar('TOKEN', 'secret', profile: 'work');
    await api.deleteProviderEnvVar('TOKEN', profile: 'work');
    await api.revealProviderEnvVar('TOKEN', profile: 'work');

    expect(requests.map((request) => request.url.path), [
      '/api/v1/env',
      '/api/v1/env',
      '/api/v1/env',
      '/api/v1/env/reveal',
    ]);
    expect(requests.map((request) => request.method), [
      'GET',
      'PUT',
      'DELETE',
      'POST',
    ]);
  });

  test('ElevenLabs voices use the mobile server proxy route', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response('{"voices":[]}', 200);
      }),
    );
    await api.elevenLabsVoices(profile: 'work');
    expect(request.url.path, '/api/v1/audio/elevenlabs/voices');
    expect(request.url.queryParameters['profile'], 'work');
  });

  test('versioned provider routes map back for a direct Gateway', () async {
    final paths = <String>[];
    final api = ApiClient(
      baseUrl: 'http://gateway.test',
      apiKey: 'key',
      directGateway: true,
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          request.url.path.contains('voices') ? '{"voices":[]}' : '{}',
          200,
        );
      }),
    );
    await api.providerEnvVars();
    await api.elevenLabsVoices();
    expect(paths, ['/api/env', '/api/audio/elevenlabs/voices']);
  });

  test('empty knowledge delete response is accepted', () async {
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((_) async => http.Response('', 204)),
    );
    expect(await api.knowledgeNodeDelete('node'), isEmpty);
  });

  test('path segments are encoded and PATCH carries profile', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response('{"id":"task/id"}', 200);
      }),
    );
    await api.taskUpdate('task/id', title: 'x', profile: 'experts');
    expect(request.url.path, '/api/v1/tasks/task%2Fid');
    expect(request.url.queryParameters['profile'], 'experts');
  });

  test('validation detail arrays become readable text', () async {
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': [
              {
                'loc': ['query', 'path'],
                'msg': 'Field required',
              },
            ],
          }),
          422,
        ),
      ),
    );
    await expectLater(
      api.fsList('x'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'query.path: Field required',
        ),
      ),
    );
  });

  test('HTTP errors extract top-level and nested fallback messages', () async {
    final responses = <String>[
      '{"message":"top-level failure"}',
      '{"error":{"error":"nested failure"}}',
    ];
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient(
        (_) async => http.Response(responses.removeAt(0), 422),
      ),
    );
    await expectLater(
      api.status(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'top-level message',
          'top-level failure',
        ),
      ),
    );
    await expectLater(
      api.status(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'nested error fallback',
          'nested failure',
        ),
      ),
    );
  });

  test('timestamp parser handles seconds milliseconds and ISO', () {
    final expected = DateTime.utc(2026, 8, 25, 9);
    expect(parseHermesTime(expected.millisecondsSinceEpoch ~/ 1000), expected);
    expect(parseHermesTime(expected.millisecondsSinceEpoch), expected);
    expect(parseHermesTime(expected.toIso8601String()), expected);
  });

  test('gateway envelope fields override nested payload fields', () {
    final event = GatewayEvent.fromFrame({
      'method': 'event',
      'params': {
        'type': 'status.update',
        'status': 'outer',
        'session_id': 'outer-session',
        'payload': {'status': 'inner', 'session_id': 'inner-session'},
      },
    });
    expect(event.payload['status'], 'outer');
    expect(event.sessionId, 'outer-session');
  });

  test('workspace endpoint encodes the session id segment', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response('{}', 200);
      }),
    );
    await api.setSessionWorkspace('sess/with/slash', '/tmp');
    expect(request.url.path, '/api/v1/sessions/sess%2Fwith%2Fslash/workspace');
    expect(request.body, contains('"/tmp"'));
  });

  test(
    'non-object responses throw ApiException instead of CastError',
    () async {
      final api = ApiClient(
        baseUrl: 'http://contract.test',
        apiKey: 'key',
        client: MockClient((_) async => http.Response('[1,2,3]', 200)),
      );
      await expectLater(api.status(), throwsA(isA<ApiException>()));
    },
  );

  test('GatewayEvent tolerates malformed non-map params', () {
    final event = GatewayEvent.fromFrame({
      'method': 'event',
      'type': 'ignored-top-level',
      'params': 'not-a-map',
    });
    expect(event.type, 'ignored-top-level');
    expect(event.payload, isEmpty);
  });

  test('websocket close codes have actionable messages', () {
    expect(gatewayCloseMessage(4401, null), contains('API key'));
    expect(gatewayCloseMessage(1011, null), contains('Gateway'));
  });
}
