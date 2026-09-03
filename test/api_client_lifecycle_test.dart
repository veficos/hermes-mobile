import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:http/http.dart' as http;

class _HangingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _SequencedClient extends http.BaseClient {
  final List<Object> outcomes;
  int sends = 0;

  _SequencedClient(this.outcomes);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final outcome = outcomes[sends++];
    if (outcome is! int) throw outcome;
    final status = outcome;
    return http.StreamedResponse(
      Stream.value(const <int>[123, 125]),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _GatedClient extends http.BaseClient {
  final response = Completer<http.StreamedResponse>();
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sends++;
    return response.future;
  }
}

class _CapabilityApi extends ApiClient {
  _CapabilityApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'key');

  @override
  Future<Map<String, dynamic>> status() async => {'capability': 'full'};

  @override
  Future<Map<String, dynamic>> methods() async => {
    'rest': {
      'resources': ['/api/v1/sessions', '/api/v1/files/upload'],
    },
  };
}

class _GatedCapabilityApi extends _CapabilityApi {
  final statusGate = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> status() => statusGate.future;
}

void main() {
  test('REST requests use the configured timeout', () async {
    final transport = _HangingClient();
    final api = ApiClient(
      baseUrl: 'http://contract.invalid',
      apiKey: 'key',
      requestTimeout: const Duration(milliseconds: 5),
      client: transport,
    );

    await expectLater(api.status(), throwsA(isA<TimeoutException>()));
    api.close();
  });

  test('ApiClient.close releases its HTTP transport', () {
    final transport = _HangingClient();
    final api = ApiClient(
      baseUrl: 'http://contract.invalid',
      apiKey: 'key',
      client: transport,
    );

    api.close();
    expect(transport.closed, isTrue);
  });

  test('GET retries one transient weak-network failure', () async {
    final transport = _SequencedClient([
      http.ClientException('network changed'),
      200,
    ]);
    final delays = <Duration>[];
    final api = ApiClient(
      baseUrl: 'http://contract.invalid',
      apiKey: 'key',
      client: transport,
      retryDelay: (delay) async => delays.add(delay),
    );
    addTearDown(api.close);

    expect(await api.get('/status'), isA<Map>());
    expect(transport.sends, 2);
    expect(delays, [const Duration(milliseconds: 250)]);
  });

  test('concurrent identical GET requests share one network flight', () async {
    final transport = _GatedClient();
    final api = ApiClient(
      baseUrl: 'http://contract.invalid',
      apiKey: 'key',
      client: transport,
    );
    addTearDown(api.close);

    final first = api.get('/status', query: const {'profile': 'default'});
    final second = api.get('/status', query: const {'profile': 'default'});
    await Future<void>.delayed(Duration.zero);
    expect(transport.sends, 1);

    transport.response.complete(
      http.StreamedResponse(
        Stream.value(const <int>[123, 125]),
        200,
        headers: const {'content-type': 'application/json'},
      ),
    );
    expect(await first, isA<Map>());
    expect(await second, isA<Map>());
    expect(transport.sends, 1);
  });

  test(
    'POST is never automatically replayed after a network failure',
    () async {
      final transport = _SequencedClient([
        http.ClientException('network changed'),
        200,
      ]);
      final api = ApiClient(
        baseUrl: 'http://contract.invalid',
        apiKey: 'key',
        client: transport,
        retryDelay: (_) async {},
      );
      addTearDown(api.close);

      await expectLater(
        api.post('/mutate', body: const {'value': true}),
        throwsA(isA<http.ClientException>()),
      );
      expect(transport.sends, 1);
    },
  );

  test(
    'uploadFile retries one transient weak-network failure',
    () async {
      final transport = _SequencedClient([
        http.ClientException('network changed'),
        200,
      ]);
      final delays = <Duration>[];
      final api = ApiClient(
        baseUrl: 'http://contract.invalid',
        apiKey: 'key',
        client: transport,
        retryDelay: (delay) async => delays.add(delay),
      );
      addTearDown(api.close);

      final result = await api.uploadFile('draft/note.txt', 'data:,hi');

      expect(result, isA<Map>());
      expect(transport.sends, 2);
      expect(delays, [const Duration(milliseconds: 250)]);
    },
  );

  test(
    'uploadFile does not retry a definitive server response',
    () async {
      final transport = _SequencedClient([409, 200]);
      final api = ApiClient(
        baseUrl: 'http://contract.invalid',
        apiKey: 'key',
        client: transport,
        retryDelay: (_) async {},
      );
      addTearDown(api.close);

      // A received response — even an error one — means the server saw
      // the request, so it must not be resent blind.
      await expectLater(
        api.uploadFile('draft/note.txt', 'data:,hi'),
        throwsA(isA<ApiException>()),
      );
      expect(transport.sends, 1);
    },
  );

  test(
    'postMultipart retries one transient weak-network failure and honors a custom timeout',
    () async {
      final transport = _SequencedClient([
        http.ClientException('network changed'),
        200,
      ]);
      final delays = <Duration>[];
      final api = ApiClient(
        baseUrl: 'http://contract.invalid',
        apiKey: 'key',
        client: transport,
        retryDelay: (delay) async => delays.add(delay),
      );
      addTearDown(api.close);

      final result = await api.postMultipart(
        '/api/v1/kanban/tasks/t-1/attachments',
        fields: const {},
        field: 'file',
        filename: 'photo.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
        timeout: const Duration(minutes: 2),
      );

      expect(result, isA<Map>());
      expect(transport.sends, 2);
      expect(delays, [const Duration(milliseconds: 250)]);
    },
  );

  test('ConnectionStore negotiates runtime and REST capabilities', () async {
    final connection = ConnectionStore()..api = _CapabilityApi();
    addTearDown(connection.dispose);

    await connection.refreshCapabilities();

    expect(connection.capability, 'full');
    expect(connection.supportsRest('/api/v1/sessions'), isTrue);
    expect(connection.supportsRest('/api/v1/billing'), isFalse);
  });

  test(
    'stale capability response cannot overwrite a replacement API',
    () async {
      final stale = _GatedCapabilityApi();
      final connection = ConnectionStore()..api = stale;
      addTearDown(connection.dispose);

      final refresh = connection.refreshCapabilities();
      connection.api = _CapabilityApi();
      stale.statusGate.complete({'capability': 'legacy'});
      await refresh;

      expect(connection.capability, isNull);
      expect(connection.restCapabilities, isEmpty);
    },
  );
}
