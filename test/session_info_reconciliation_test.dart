import 'dart:async';

import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'http://session-info.invalid', apiKey: 'test');
}

class _Gateway extends GatewayClient {
  _Gateway() : super(serverBaseUrl: 'http://session-info.invalid', apiKey: 'x');

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async => method == 'session.create'
      ? {'session_id': 'runtime-a', 'stored_session_id': 'session-a'}
      : const {};
}

class _Connection extends ConnectionStore {
  _Connection() {
    api = _Api();
    gateway = _Gateway();
  }

  final controller = StreamController<GatewayEvent>.broadcast();

  @override
  Stream<GatewayEvent> get events => controller.stream;

  @override
  Future<void> ensureConnected() async {}

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('partial session.info merges without erasing authoritative fields', () {
    final current = SessionInfoView(
      title: '保留标题',
      model: 'model-a',
      provider: 'provider-a',
      cwd: '/workspace',
      running: true,
    );
    final merged = current.mergeJson(const {'branch': 'main'});
    expect(merged.title, '保留标题');
    expect(merged.model, 'model-a');
    expect(merged.provider, 'provider-a');
    expect(merged.cwd, '/workspace');
    expect(merged.branch, 'main');
    expect(merged.running, isTrue);
  });

  test('stale running true is rejected after a terminal edge', () {
    final current = SessionInfoView(title: 'A', running: false);
    final merged = current.mergeJson(const {
      'running': true,
      'provider': 'nous',
    }, allowRunningTrue: false);
    expect(merged.running, isFalse);
    expect(merged.provider, 'nous');
  });

  test('authoritative running false is accepted', () {
    final current = SessionInfoView(running: true);
    expect(current.mergeJson(const {'running': false}).running, isFalse);
  });

  test(
    'SessionStore session.info false settles an active partial stream',
    () async {
      SharedPreferences.setMockInitialValues({});
      final connection = _Connection();
      final chat = ChatStore()..attachEvents(connection.events);
      final requests = RequestStore();
      final sessions = SessionStore(
        connection: connection,
        chat: chat,
        requests: requests,
        persistLastSession: false,
      );
      addTearDown(() {
        sessions.dispose();
        requests.dispose();
        chat.dispose();
        connection.dispose();
      });
      await sessions.openNewSession();

      connection.controller.add(
        GatewayEvent(
          type: 'message.start',
          payload: const {},
          sessionId: 'runtime-a',
        ),
      );
      connection.controller.add(
        GatewayEvent(
          type: 'message.delta',
          payload: const {'text': 'kept partial'},
          sessionId: 'runtime-a',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(chat.busy, isTrue);

      connection.controller.add(
        GatewayEvent(
          type: 'session.info',
          payload: const {'running': false},
          sessionId: 'runtime-a',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(sessions.info?.running, isFalse);
      expect(chat.busy, isFalse);
      expect(chat.isStreaming, isFalse);
      expect(chat.messages.single.fullText, 'kept partial');
      expect(chat.messages.single.pending, isFalse);
    },
  );
}
