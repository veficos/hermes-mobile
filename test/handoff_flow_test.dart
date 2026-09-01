import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';

void main() {
  test('MessagingPlatform parses the canonical Hermes handoff fields', () {
    final platform = MessagingPlatform.fromJson({
      'id': 'telegram',
      'name': 'Telegram',
      'enabled': true,
      'configured': true,
      'gateway_running': true,
      'state': 'connected',
      'home_channel': {'chat_id': '42', 'name': 'Home chat'},
    });

    expect(platform.name, 'telegram');
    expect(platform.displayName, 'Telegram');
    expect(platform.canHandoff, isTrue);
    expect(platform.gatewayRunning, isTrue);
    expect(platform.homeChannelName, 'Home chat');
  });

  test('handoff requests then polls until completed', () async {
    final calls = <String>[];
    var polls = 0;
    final progress = <String>[];

    final result = await runHandoffFlow(
      request: (method, params) async {
        calls.add(method);
        if (method == 'handoff.state') {
          polls++;
          return {'state': polls == 1 ? 'running' : 'completed'};
        }
        return {'queued': true};
      },
      sessionId: 'runtime-1',
      platform: 'Telegram',
      pollInterval: Duration.zero,
      onProgress: progress.add,
    );

    expect(result.ok, isTrue);
    expect(calls, ['handoff.request', 'handoff.state', 'handoff.state']);
    expect(progress, ['pending', 'running', 'completed']);
  });

  test('handoff surfaces the gateway failure message', () async {
    final result = await runHandoffFlow(
      request: (method, params) async => method == 'handoff.state'
          ? {'state': 'failed', 'error': 'home channel missing'}
          : {'queued': true},
      sessionId: 'runtime-1',
      platform: 'telegram',
      pollInterval: Duration.zero,
    );

    expect(result.ok, isFalse);
    expect(result.error, 'home channel missing');
  });

  test(
    'handoff marks an in-flight row failed after the desktop timeout',
    () async {
      final calls = <String>[];
      final result = await runHandoffFlow(
        request: (method, params) async {
          calls.add(method);
          if (method == 'handoff.fail') {
            return {'failed': true, 'state': 'failed'};
          }
          return {'queued': true};
        },
        sessionId: 'runtime-1',
        platform: 'telegram',
        timeout: Duration.zero,
        pollInterval: Duration.zero,
      );

      expect(result.ok, isFalse);
      expect(result.error, 'Handoff timed out. Try again.');
      expect(calls, ['handoff.request', 'handoff.fail']);
    },
  );
}
