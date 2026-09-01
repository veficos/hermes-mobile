/// Integration test: exercise the app's real networking stack
/// (GatewayClient + ApiClient) against a live hermes-mobile-server.
///
/// Skipped unless HM_API_KEY is set. Run with:
///   HM_API_KEY=`<key>` flutter test test/gateway_integration_test.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';

void main() {
  final apiKey = Platform.environment['HM_API_KEY'];
  final base = Platform.environment['HM_BASE'] ?? 'http://127.0.0.1:8877';

  if (apiKey == null || apiKey.isEmpty) {
    test('integration tests skipped (set HM_API_KEY)', () {});
    return;
  }

  test('REST: status + sessions list (domain API)', () async {
    final api = ApiClient(baseUrl: base, apiKey: apiKey);
    final status = await api.status();
    expect(status['backend'], isNotNull);
    expect(status['capability'], isIn(['full', 'legacy', 'missing']));
    final rows = await api.listSessions(limit: 5);
    expect(rows, isA<List<dynamic>>());
    // Domain API exposes only durable ids.
    for (final row in rows) {
      expect(row.id, isNotEmpty);
    }
  }, timeout: const Timeout(Duration(minutes: 1)));

  test(
    'Gateway: connect, create session, stream a prompt to completion',
    () async {
      final gw = GatewayClient(serverBaseUrl: base, apiKey: apiKey);
      await gw.connect();
      expect(gw.isConnected, isTrue);

      final created = await gw.request('session.create', {
        'cols': 48,
        'source': 'mobile',
      });
      final sid = created['session_id'] as String;
      expect(sid, isNotEmpty);

      final done = Completer<String?>();
      final sub = gw.events.listen((e) {
        if (e.type == 'message.complete') {
          if (!done.isCompleted) done.complete(e.payload['status'] as String?);
        }
      });

      await gw.request('prompt.submit', {
        'session_id': sid,
        'text': 'Reply with exactly: E2E-OK',
      }, timeout: const Duration(minutes: 3));

      final status = await done.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => 'timeout',
      );
      expect(status, 'complete');
      await sub.cancel();
      await gw.disconnect();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test('Gateway: bad API key is rejected', () async {
    final gw = GatewayClient(serverBaseUrl: base, apiKey: 'wrong-key');
    try {
      await gw.connect();
      fail('expected connection rejection');
    } catch (_) {
      // expected
    }
  });

  test('resume flow loads the transcript (history bug regression)', () async {
    final gw = GatewayClient(serverBaseUrl: base, apiKey: apiKey);
    await gw.connect();
    final api = ApiClient(baseUrl: base, apiKey: apiKey);

    // Create a session with at least one exchange.
    final created = await gw.request('session.create', {
      'cols': 48,
      'source': 'mobile',
    });
    final runtimeId = created['session_id'] as String;
    final durableId = created['stored_session_id'] as String?;
    expect(durableId, isNotEmpty);
    await gw.request('prompt.submit', {
      'session_id': runtimeId,
      'text': 'Reply with exactly: HIST-OK',
    }, timeout: const Duration(minutes: 3));
    final done = Completer<String?>();
    final sub = gw.events.listen((e) {
      if (e.type == 'message.complete') {
        if (!done.isCompleted) done.complete(e.payload['status'] as String?);
      }
    });
    await done.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => 'timeout',
    );
    await sub.cancel();

    // Rebind via resume + refetch the raw transcript (the exact path the
    // History tab uses) and verify messages survive the conversion.
    final resumed = await gw.request('session.resume', {
      'session_id': durableId,
      'cols': 48,
      'source': 'mobile',
      'omit_messages': true,
    });
    expect(resumed['session_id'], isNotEmpty);
    final raw = await api.sessionMessagesRaw(durableId!);
    expect(raw.length, greaterThanOrEqualTo(2)); // user + assistant
    final built = ChatStore().fromSessionMessages(raw);
    expect(built.length, greaterThanOrEqualTo(2));
    expect(built.last.fullText, contains('HIST-OK'));
    await gw.disconnect();
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('message branch uses the desktop copyable-message count', () async {
    final api = ApiClient(baseUrl: base, apiKey: apiKey);
    final gateway = GatewayClient(serverBaseUrl: base, apiKey: apiKey);
    String? childId;
    String? childRuntimeId;
    try {
      final rows = await api.listSessions(limit: 50);
      String? parentId;
      List<ChatMessage> transcript = const [];
      for (final row in rows) {
        final raw = await api.sessionMessagesRaw(row.id, limit: 50);
        final built = ChatStore().fromSessionMessages(raw);
        if (branchMessageCount(built) >= 2) {
          parentId = row.id;
          transcript = built;
          break;
        }
      }
      expect(parentId, isNotNull, reason: '需要至少一个有文本往返的真实会话');

      await gateway.connect();
      final resumed = await gateway.request('session.resume', {
        'session_id': parentId,
        'cols': 48,
        'source': 'mobile',
        'omit_messages': true,
      });
      final runtimeId = resumed['session_id']?.toString();
      expect(runtimeId, isNotEmpty);

      final target = transcript.firstWhere(
        (message) =>
            message.role == 'assistant' && message.fullText.trim().isNotEmpty,
      );
      expect(target.historyOrdinal, isNotNull);
      final expectedCount = target.historyOrdinal! + 1;
      final branched = await gateway.request('session.branch', {
        'session_id': runtimeId,
        'count': expectedCount,
      });
      childId = branched['stored_session_id']?.toString();
      childRuntimeId = branched['session_id']?.toString();
      expect(childId, isNotEmpty);
      var observedCount = 0;
      for (var attempt = 0; attempt < 10; attempt++) {
        final childRaw = await api.sessionMessagesRaw(childId!, limit: 50);
        observedCount = childRaw.length;
        if (observedCount == expectedCount) break;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      expect(observedCount, expectedCount);
    } finally {
      if (childRuntimeId?.isNotEmpty == true && gateway.isConnected) {
        try {
          await gateway.request('session.close', {
            'session_id': childRuntimeId,
          });
        } catch (_) {}
      }
      if (childId?.isNotEmpty == true) {
        await api.deleteSession(childId!);
      }
      await gateway.disconnect();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
