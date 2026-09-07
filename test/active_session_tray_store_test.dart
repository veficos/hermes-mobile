import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/active_session_tray_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TraySessionStore extends SessionStore {
  _TraySessionStore({
    required super.connection,
    required super.chat,
    required super.requests,
    required this.rows,
  });

  List<SessionRow> rows;
  final Map<String, SessionQueueSummary> queueSummaries = {};

  @override
  List<SessionRow>? get sessions => rows;
  @override
  String? get durableId => null;
  @override
  SessionQueueSummary? queueSummaryFor(String durableId, {String? profile}) =>
      queueSummaries[durableId];

  void changed() => notifyListeners();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tray retains background completion until it is viewed', () async {
    final connection = ConnectionStore();
    final chat = ChatStore();
    final requests = RequestStore();
    final row = SessionRow(id: 'background', messageCount: 4);
    final sessions = _TraySessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
      rows: [row],
    );
    final tray = ActiveSessionTrayStore(sessions, requests);
    addTearDown(tray.dispose);
    addTearDown(sessions.dispose);
    addTearDown(requests.dispose);
    addTearDown(chat.dispose);
    addTearDown(connection.dispose);

    await sessions.unreadForSessions([row]);
    await sessions.markCompletionUnreadIfNeeded('background', 4);
    await pumpEventQueue();
    expect(tray.items.single.state, ActiveSessionState.completed);

    await sessions.setSessionViewedCount('background', 4);
    sessions.changed();
    await pumpEventQueue();
    expect(tray.items, isEmpty);
  });

  test('tray prioritizes waiting and running and bounds completions', () async {
    final connection = ConnectionStore();
    final chat = ChatStore();
    final requests = RequestStore();
    final rows = [
      SessionRow(id: 'run', isStreaming: true),
      SessionRow(id: 'wait', hasPendingUserMessage: true),
      for (var i = 0; i < 12; i++)
        SessionRow(id: 'done-$i', messageCount: i + 1),
    ];
    final sessions = _TraySessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
      rows: rows,
    );
    await sessions.unreadForSessions(rows);
    for (final row in rows.skip(2)) {
      await sessions.markCompletionUnreadIfNeeded(
        row.id,
        row.messageCount ?? 0,
      );
    }
    final tray = ActiveSessionTrayStore(sessions, requests);
    addTearDown(tray.dispose);
    addTearDown(sessions.dispose);
    addTearDown(requests.dispose);
    addTearDown(chat.dispose);
    addTearDown(connection.dispose);
    await pumpEventQueue();

    expect(tray.items.first.state, ActiveSessionState.waiting);
    expect(tray.items[1].state, ActiveSessionState.running);
    expect(
      tray.items.where((item) => item.state == ActiveSessionState.completed),
      hasLength(ActiveSessionTrayStore.maxCompletedItems),
    );
  });

  test('tray retains request scope for session navigation', () async {
    final connection = ConnectionStore();
    final chat = ChatStore();
    final requests = RequestStore();
    final sessions = _TraySessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
      rows: [SessionRow(id: 'durable')],
    );
    final tray = ActiveSessionTrayStore(sessions, requests);
    addTearDown(tray.dispose);
    addTearDown(sessions.dispose);
    addTearDown(requests.dispose);
    addTearDown(chat.dispose);
    addTearDown(connection.dispose);
    requests.enqueue(
      PendingRequest(
        kind: RequestKind.approval,
        requestId: 'approve-1',
        sessionId: 'runtime',
        durableSessionId: 'durable',
      ),
    );
    await pumpEventQueue();
    expect(tray.items.single.state, ActiveSessionState.waiting);
    expect(tray.items.single.request?.requestId, 'approve-1');
  });

  test('tray exposes a restored queue ahead of running sessions', () async {
    final connection = ConnectionStore();
    final chat = ChatStore();
    final requests = RequestStore();
    final sessions = _TraySessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
      rows: [
        SessionRow(id: 'running', isStreaming: true),
        SessionRow(id: 'queued'),
      ],
    );
    sessions.queueSummaries['queued'] = const SessionQueueSummary(
      count: 2,
      parked: true,
      deliveryUncertain: false,
    );
    final tray = ActiveSessionTrayStore(sessions, requests);
    addTearDown(tray.dispose);
    addTearDown(sessions.dispose);
    addTearDown(requests.dispose);
    addTearDown(chat.dispose);
    addTearDown(connection.dispose);
    await pumpEventQueue();

    expect(tray.items.first.row.id, 'queued');
    expect(tray.items.first.state, ActiveSessionState.queued);
    expect(tray.items.first.queue?.count, 2);
    expect(tray.items[1].state, ActiveSessionState.running);
  });
}
