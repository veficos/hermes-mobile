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
  int listRequests = 0;
  String? pinnedId;
  bool? pinnedValue;

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    listRequests++;
    return SessionPage(
      sessions: rows,
      total: rows.length,
      offset: offset,
      hasMore: false,
    );
  }

  @override
  Future<void> pinSession(String id, bool pinned, {String? profile}) async {
    pinnedId = id;
    pinnedValue = pinned;
  }
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

  test('pin keeps the loaded list and updates only the target row', () async {
    final api = _MutableSessionApi([
      SessionRow(id: 'pin-me', title: 'Pinned target'),
      SessionRow(id: 'keep-me', title: 'Visible sibling'),
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
    expect(api.listRequests, 1);

    // Simulate a backend projection that has not caught up yet. Pinning must
    // not fetch this transient empty snapshot over the visible list.
    api.rows = [];
    await store.setPinned('pin-me', true);

    expect(api.pinnedId, 'pin-me');
    expect(api.pinnedValue, isTrue);
    expect(api.listRequests, 1);
    expect(store.sessions, hasLength(2));
    expect(
      store.sessions!.firstWhere((row) => row.id == 'pin-me').pinned,
      isTrue,
    );
    expect(store.sessions!.any((row) => row.id == 'keep-me'), isTrue);
  });

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

  test(
    'session projection and title lookup stay stable until state changes',
    () async {
      final api = _MutableSessionApi([
        SessionRow(id: 's1', title: 'First'),
        SessionRow(id: 's2', title: 'Second'),
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
      final firstProjection = store.sessions;
      final firstUnchangedRow = firstProjection!.first;
      final firstChangedRow = firstProjection.last;
      final firstUnreadRevision = store.sessionUnreadRevision;
      expect(identical(firstProjection, store.sessions), isTrue);
      expect(store.sessionTitlesById, {'s1': 'First', 's2': 'Second'});

      connection.controller.add(
        GatewayEvent(
          type: 'message.start',
          payload: const {'active_stream_id': 'stream-2'},
          sessionId: 's2',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(identical(firstProjection, store.sessions), isFalse);
      expect(identical(firstUnchangedRow, store.sessions!.first), isTrue);
      expect(identical(firstChangedRow, store.sessions!.last), isFalse);
      expect(store.sessions!.last.isActivelyWorking, isTrue);
      expect(store.sessionUnreadRevision, firstUnreadRevision);
    },
  );
}
