/// Real-process integration smoke for the companion and Hermes backend.
///
/// Unlike the device E2E fake, this suite expects an actual
/// `hermes-mobile-server` process. It is opt-in because a full prompt may use
/// configured provider credits:
///
///   HM_REAL_SERVER_E2E=1 HM_API_KEY=... HM_BASE=http://127.0.0.1:8877 \
///     flutter test test/real_server_smoke_test.dart
///
/// Add HM_REAL_PROMPT_E2E=1 to include one model turn.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/terminal_gateway.dart';

void main() {
  final enabled = Platform.environment['HM_REAL_SERVER_E2E'] == '1';
  final apiKey = Platform.environment['HM_API_KEY'] ?? '';
  final base = Platform.environment['HM_BASE'] ?? 'http://127.0.0.1:8877';

  if (!enabled) {
    test('real server smoke skipped (set HM_REAL_SERVER_E2E=1)', () {});
    return;
  }

  setUpAll(() {
    if (apiKey.isEmpty) {
      throw StateError('HM_API_KEY is required for real server E2E');
    }
  });

  test(
    'real companion serves authenticated REST and rejects a bad key',
    () async {
      final api = ApiClient(baseUrl: base, apiKey: apiKey);
      final status = await api.status();
      final methods = await api.methods();
      expect(status['server'], isA<Map>());
      expect(status['backend'], isA<Map>());
      expect(methods['rest'], isA<Map>());

      final rejected = ApiClient(baseUrl: base, apiKey: 'invalid-e2e-key');
      await expectLater(rejected.status(), throwsA(isA<ApiException>()));
      api.close();
      rejected.close();
    },
  );

  test('real gateway creates and closes an isolated mobile session', () async {
    final gateway = GatewayClient(serverBaseUrl: base, apiKey: apiKey);
    final api = ApiClient(baseUrl: base, apiKey: apiKey);
    String? durableId;
    String? runtimeId;
    try {
      await gateway.connect();
      final created = await gateway.request('session.create', {
        'cols': 48,
        'source': 'mobile',
      });
      durableId = created['stored_session_id']?.toString();
      runtimeId = created['session_id']?.toString();
      expect(durableId, isNotEmpty);
      expect(runtimeId, isNotEmpty);

      if (Platform.environment['HM_REAL_PROMPT_E2E'] == '1') {
        final completed = Completer<void>();
        final subscription = gateway.events.listen((event) {
          if (event.sessionId == runtimeId &&
              event.type == 'message.complete' &&
              !completed.isCompleted) {
            completed.complete();
          }
        });
        await gateway.request('prompt.submit', {
          'session_id': runtimeId,
          'text': 'Reply with exactly: HM-REAL-E2E',
        }, timeout: const Duration(minutes: 3));
        await completed.future.timeout(const Duration(minutes: 3));
        await subscription.cancel();
      }
    } finally {
      if (runtimeId?.isNotEmpty == true && gateway.isConnected) {
        try {
          await gateway.request('session.close', {'session_id': runtimeId});
        } catch (_) {}
      }
      if (durableId?.isNotEmpty == true) {
        try {
          await api.deleteSession(durableId!);
        } catch (_) {}
      }
      await gateway.disconnect();
      api.close();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('real terminal websocket executes and disposes a PTY', () async {
    final terminal = TerminalGatewayClient(serverBaseUrl: base, apiKey: apiKey);
    String? terminalId;
    StreamSubscription<TerminalGatewayEvent>? subscription;
    try {
      await terminal.connect();
      final output = Completer<void>();
      subscription = terminal.events.listen((event) {
        if (event.type == 'data' &&
            event.data['id'] == terminalId &&
            event.data['data']?.toString().contains('HM-PTY-E2E') == true &&
            !output.isCompleted) {
          output.complete();
        }
      });
      final started = await terminal.request('start', {
        'cwd': Directory.systemTemp.path,
        'cols': 80,
        'rows': 24,
      });
      terminalId = started['id']?.toString();
      expect(terminalId, isNotEmpty);
      terminal.write(terminalId!, "printf 'HM-PTY-E2E\\n'\n");
      await output.future.timeout(const Duration(seconds: 20));
    } finally {
      if (terminalId?.isNotEmpty == true) {
        await terminal.disposeSession(terminalId!);
      }
      await subscription?.cancel();
      await terminal.close();
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
