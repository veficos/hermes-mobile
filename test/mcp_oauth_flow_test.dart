import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/mcp_oauth_flow.dart';

class _OAuthApi extends ApiClient {
  _OAuthApi() : super(baseUrl: 'http://oauth.invalid', apiKey: 'test');

  int starts = 0;
  int polls = 0;
  Map<String, dynamic> startResult = const {
    'flow_id': 'flow-1',
    'authorization_url': 'https://auth.example/flow-1',
  };
  final List<Object> pollResults = [];

  @override
  Future<Map<String, dynamic>> mcpStartAuth(
    String name, {
    String? profile,
  }) async {
    starts++;
    return startResult;
  }

  @override
  Future<Map<String, dynamic>> mcpAuthFlow(
    String flowId, {
    String? profile,
  }) async {
    final result = pollResults[polls++];
    if (result is Map<String, dynamic>) return result;
    throw result;
  }
}

void main() {
  const flow = McpOAuthFlow(
    pollInterval: Duration.zero,
    timeout: Duration(seconds: 1),
  );

  test('starts a fresh OAuth flow and returns approval', () async {
    final api = _OAuthApi()
      ..pollResults.addAll([
        const {'status': 'pending'},
        const {
          'status': 'approved',
          'tools': ['issues'],
        },
      ]);
    String? started;
    String? finished;

    final result = await flow.authorize(
      api: api,
      server: 'github',
      profile: 'work',
      openAuthorization: (url) async =>
          url.toString() == 'https://auth.example/flow-1',
      cancelled: () => false,
      onStarted: (id, _) => started = id,
      onFinished: (id) => finished = id,
    );

    expect(result['status'], 'approved');
    expect(api.starts, 1);
    expect(api.polls, 2);
    expect(started, 'flow-1');
    expect(finished, 'flow-1');
  });

  test('resumes an existing flow without starting another one', () async {
    final api = _OAuthApi()..pollResults.add(const {'status': 'approved'});

    await flow.authorize(
      api: api,
      server: 'github',
      flowId: 'existing',
      authorizationUrl: 'https://auth.example/existing',
      openAuthorization: (_) async => true,
      cancelled: () => false,
    );

    expect(api.starts, 0);
    expect(api.polls, 1);
  });

  test('retries transient polling failures up to approval', () async {
    final api = _OAuthApi()
      ..pollResults.addAll([
        Exception('temporary-1'),
        Exception('temporary-2'),
        const {'status': 'approved'},
      ]);

    final result = await flow.authorize(
      api: api,
      server: 'github',
      openAuthorization: (_) async => true,
      cancelled: () => false,
    );

    expect(result['status'], 'approved');
    expect(api.polls, 3);
  });

  test('reports denial and always finishes the flow', () async {
    final api = _OAuthApi()
      ..pollResults.add(const {'status': 'denied', 'error': 'not allowed'});
    var finished = false;

    await expectLater(
      flow.authorize(
        api: api,
        server: 'github',
        openAuthorization: (_) async => true,
        cancelled: () => false,
        onFinished: (_) => finished = true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(finished, isTrue);
  });

  test('cancellation stops before the first poll', () async {
    final api = _OAuthApi();

    await expectLater(
      flow.authorize(
        api: api,
        server: 'github',
        openAuthorization: (_) async => true,
        cancelled: () => true,
      ),
      throwsA(isA<McpOAuthCancelled>()),
    );
    expect(api.polls, 0);
  });

  test('times out when approval never arrives', () async {
    final api = _OAuthApi();
    const immediate = McpOAuthFlow(
      pollInterval: Duration.zero,
      timeout: Duration.zero,
    );

    await expectLater(
      immediate.authorize(
        api: api,
        server: 'github',
        openAuthorization: (_) async => true,
        cancelled: () => false,
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(api.polls, 0);
  });
}
