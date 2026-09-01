import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MutableSessionApi extends ApiClient {
  _MutableSessionApi(this.rows)
    : super(baseUrl: 'http://session-state.invalid', apiKey: 'test');

  List<SessionRow> rows;

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async => SessionPage(
    sessions: rows,
    total: rows.length,
    offset: offset,
    hasMore: false,
  );
}

class _EventConnection extends ConnectionStore {
  _EventConnection(ApiClient client) {
    api = client;
  }

  final controller = StreamController<GatewayEvent>.broadcast();

  @override
  Stream<GatewayEvent> get events => controller.stream;

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'gateway activity and interactive requests project onto list rows',
    () async {
      final api = _MutableSessionApi([SessionRow(id: 's1')]);
      final connection = _EventConnection(api);
      final requests = RequestStore()..attachEvents(connection.events);
      final chat = ChatStore();
      final store = SessionStore(
        connection: connection,
        chat: chat,
        requests: requests,
        persistLastSession: false,
      );
      addTearDown(() {
        store.dispose();
        requests.dispose();
        chat.dispose();
        connection.dispose();
      });

      await store.refreshList();
      connection.controller.add(
        GatewayEvent(
          type: 'message.start',
          payload: const {'active_stream_id': 'stream-1'},
          sessionId: 's1',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.sessions!.single.isActivelyWorking, isTrue);
      expect(store.sessions!.single.activeStreamId, 'stream-1');

      connection.controller.add(
        GatewayEvent(
          type: 'session.info',
          payload: const {'running': true, 'cron_running': true},
          sessionId: 's1',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.sessions!.single.cronRunning, isTrue);

      connection.controller.add(
        GatewayEvent(
          type: 'approval.request',
          payload: const {'request_id': 'approval-1'},
          sessionId: 's1',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.sessions!.single.needsAttention, isTrue);

      connection.controller.add(
        GatewayEvent(
          type: 'interactive.expire',
          payload: const {'request_id': 'approval-1'},
          sessionId: 's1',
        ),
      );
    connection.controller.add(
      GatewayEvent(
        type: 'message.complete',
          payload: const {},
          sessionId: 's1',
      ),
    );
    connection.controller.add(
      GatewayEvent(type: 'cron.complete', payload: const {}, sessionId: 's1'),
    );
      await Future<void>.delayed(Duration.zero);
      expect(store.sessions!.single.needsAttention, isFalse);
      expect(store.sessions!.single.isActivelyWorking, isFalse);
      expect(store.sessions!.single.activeStreamId, isNull);
    },
  );

  test('refresh detects a streaming to idle completion edge', () async {
    final api = _MutableSessionApi([
      SessionRow(id: 'background', messageCount: 1, isStreaming: true),
    ]);
    final connection = _EventConnection(api);
    final requests = RequestStore();
    final chat = ChatStore();
    final store = SessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
      persistLastSession: false,
    );
    addTearDown(() {
      store.dispose();
      requests.dispose();
      chat.dispose();
      connection.dispose();
    });

    await store.refreshList();
    api.rows = [SessionRow(id: 'background', messageCount: 2)];
    await store.refreshList();

    expect(await store.hasUnreadForSession(store.sessions!.single), isTrue);
  });
}
