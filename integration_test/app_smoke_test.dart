import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/main.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:hermes_mobile/screens/connect_screen.dart';
import 'package:hermes_mobile/screens/new_session_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect, create a session, send, and resume', (tester) async {
    SharedPreferences.setMockInitialValues({'hm_display_locale_v1': 'en'});
    final backend = await _FakeHermesBackend.start();
    addTearDown(backend.close);

    await tester.pumpWidget(const HermesMobileApp());
    await _pumpUntil(tester, find.byKey(const ValueKey('connect-server-url')));

    await tester.enterText(
      find.byKey(const ValueKey('connect-server-url')),
      backend.baseUrl,
    );
    await tester.enterText(
      find.byKey(const ValueKey('connect-api-key')),
      _FakeHermesBackend.apiKey,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('connect-submit')));
    await tester.tap(find.byKey(const ValueKey('connect-submit')));
    await _pumpUntilAbsent(tester, find.byType(ConnectScreen));

    expect(backend.authorizedRequests, greaterThanOrEqualTo(2));
    expect(backend.webSocketConnections, greaterThanOrEqualTo(2));

    await tester.tap(find.text('Start new session').first);
    await _pumpUntil(tester, find.byType(NewSessionScreen));
    await tester.ensureVisible(
      find.byKey(const ValueKey('new-session-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('new-session-submit')));
    await _pumpUntil(tester, find.byType(ChatScreen));

    await tester.enterText(
      find.byKey(const ValueKey('composer-input')),
      'Device E2E prompt',
    );
    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await _waitFor(
      () => backend.gatewayMethods.contains('prompt.submit'),
      tester,
    );
    expect(find.text('Device E2E prompt'), findsOneWidget);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 100));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChatScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) => _waitFor(() => finder.evaluate().isNotEmpty, tester, timeout: timeout);

Future<void> _pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) => _waitFor(() => finder.evaluate().isEmpty, tester, timeout: timeout);

Future<void> _waitFor(
  bool Function() condition,
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Integration test condition was not met', timeout);
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _FakeHermesBackend {
  static const apiKey = 'hm_device_e2e_key';

  final HttpServer _server;
  final List<WebSocket> _sockets = [];
  final List<String> gatewayMethods = [];
  int authorizedRequests = 0;
  int webSocketConnections = 0;

  _FakeHermesBackend._(this._server);

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<_FakeHermesBackend> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final backend = _FakeHermesBackend._(server);
    server.listen(backend._handle);
    return backend;
  }

  Future<void> _handle(HttpRequest request) async {
    final bearer = request.headers.value(HttpHeaders.authorizationHeader);
    final token = request.uri.queryParameters['token'];
    if (bearer == 'Bearer $apiKey' || token == apiKey) {
      authorizedRequests++;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      if (token != apiKey) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      webSocketConnections++;
      socket.add(_event('gateway.ready'));
      socket.listen((raw) => _handleGateway(socket, raw));
      return;
    }

    if (bearer != 'Bearer $apiKey') {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(_restResponse(request.uri.path)));
    await request.response.close();
  }

  Map<String, dynamic> _restResponse(String path) {
    if (path == '/api/v1/status') {
      return {
        'server': {'name': 'device-e2e', 'version': '1.0.0'},
        'capability': 'full',
      };
    }
    if (path == '/api/v1/methods') {
      return {
        'rest': {'resources': <String>[]},
      };
    }
    if (path == '/api/v1/sessions') {
      return {'sessions': <Object>[], 'total': 0, 'has_more': false};
    }
    if (path == '/api/v1/profiles') {
      return {'profiles': <Object>[]};
    }
    if (path.contains('/messages')) {
      return {'messages': <Object>[], 'total': 0};
    }
    return <String, dynamic>{};
  }

  void _handleGateway(WebSocket socket, dynamic raw) {
    if (raw is! String) return;
    final frame = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final id = frame['id'];
    final method = frame['method']?.toString() ?? '';
    gatewayMethods.add(method);
    final result = switch (method) {
      'session.create' => {
        'stored_session_id': 'device-e2e-session',
        'session_id': 'device-e2e-runtime',
        'info': {
          'title': 'Device E2E session',
          'model': 'test-model',
          'cwd': '/tmp/device-e2e',
        },
      },
      _ => <String, dynamic>{'ok': true},
    };
    socket.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}));

    if (method == 'prompt.submit') {
      scheduleMicrotask(() {
        socket
          ..add(_event('message.start', sessionId: 'device-e2e-runtime'))
          ..add(
            _event(
              'message.delta',
              sessionId: 'device-e2e-runtime',
              payload: {'text': 'Device E2E response'},
            ),
          )
          ..add(
            _event(
              'message.complete',
              sessionId: 'device-e2e-runtime',
              payload: {'text': 'Device E2E response', 'status': 'complete'},
            ),
          );
      });
    }
  }

  String _event(
    String type, {
    String? sessionId,
    Map<String, dynamic> payload = const {},
  }) => jsonEncode({
    'jsonrpc': '2.0',
    'method': 'event',
    'params': {'type': type, 'session_id': ?sessionId, 'payload': payload},
  });

  Future<void> close() async {
    for (final socket in _sockets) {
      await socket.close();
    }
    await _server.close(force: true);
  }
}
