import 'dart:async';

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

  test('ConnectionStore negotiates runtime and REST capabilities', () async {
    final connection = ConnectionStore()..api = _CapabilityApi();
    addTearDown(connection.dispose);

    await connection.refreshCapabilities();

    expect(connection.capability, 'full');
    expect(connection.supportsRest('/api/v1/sessions'), isTrue);
    expect(connection.supportsRest('/api/v1/billing'), isFalse);
  });
}
