library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'request_store.dart';
import 'session_store.dart';

enum ActiveSessionState { queued, running, waiting, completed, failed }

@immutable
class ActiveSessionTrayItem {
  const ActiveSessionTrayItem({
    required this.row,
    required this.state,
    this.request,
    this.queue,
  });
  final SessionRow row;
  final ActiveSessionState state;
  final PendingRequest? request;
  final SessionQueueSummary? queue;
}

class ActiveSessionTrayStore extends ChangeNotifier {
  static const maxItems = 24;
  static const maxCompletedItems = 8;

  ActiveSessionTrayStore(this._sessions, this._requests) {
    _sessions.addListener(_rebuild);
    _requests.addListener(_rebuild);
    _rebuild();
  }

  SessionStore _sessions;
  RequestStore _requests;
  List<ActiveSessionTrayItem> _items = const [];
  List<ActiveSessionTrayItem> get items => _items;
  int _generation = 0;

  void bind(SessionStore sessions, RequestStore requests) {
    if (identical(_sessions, sessions) && identical(_requests, requests)) {
      return;
    }
    _sessions.removeListener(_rebuild);
    _requests.removeListener(_rebuild);
    _sessions = sessions;
    _requests = requests;
    _sessions.addListener(_rebuild);
    _requests.addListener(_rebuild);
    _rebuild();
  }

  void _rebuild() {
    final generation = ++_generation;
    unawaited(_rebuildAsync(generation));
  }

  Future<void> _rebuildAsync(int generation) async {
    final pendingBySession = <String, PendingRequest>{};
    for (final request in _requests.pendingRequests) {
      final durable = request.durableSessionId;
      final runtime = request.sessionId;
      if (durable?.isNotEmpty == true) pendingBySession[durable!] = request;
      if (runtime?.isNotEmpty == true) pendingBySession[runtime!] = request;
    }
    final rows = _sessions.sessions ?? const <SessionRow>[];
    final unread = await _sessions.unreadForSessions(rows);
    if (generation != _generation) return;
    final next = <ActiveSessionTrayItem>[];
    var completed = 0;
    for (final row in rows) {
      final request = pendingBySession[row.id];
      final queue = _sessions.queueSummaryFor(row.id, profile: row.profile);
      final state = queue != null
          ? ActiveSessionState.queued
          : (request != null ||
                row.pendingUserMessage ||
                row.hasPendingUserMessage)
          ? ActiveSessionState.waiting
          : row.isActivelyWorking
          ? ActiveSessionState.running
          : (row.handoffError?.isNotEmpty == true ||
                row.compressionFailureError?.isNotEmpty == true ||
                row.endReason == 'error')
          ? ActiveSessionState.failed
          : unread[row.id] == true
          ? ActiveSessionState.completed
          : null;
      if (state != null || row.id == _sessions.durableId || row.isActive) {
        final resolved = state ?? ActiveSessionState.completed;
        if (resolved == ActiveSessionState.completed &&
            row.id != _sessions.durableId) {
          if (completed >= maxCompletedItems) continue;
          completed++;
        }
        next.add(
          ActiveSessionTrayItem(
            row: row,
            state: resolved,
            request: request,
            queue: queue,
          ),
        );
      }
    }
    next.sort((a, b) {
      final rank = {
        ActiveSessionState.queued: 0,
        ActiveSessionState.waiting: 1,
        ActiveSessionState.running: 2,
        ActiveSessionState.failed: 3,
        ActiveSessionState.completed: 4,
      };
      final byState = rank[a.state]!.compareTo(rank[b.state]!);
      if (byState != 0) return byState;
      return (b.row.lastMessageAt ?? 0).compareTo(a.row.lastMessageAt ?? 0);
    });
    if (next.length > maxItems) next.removeRange(maxItems, next.length);
    final signature = next
        .map(
          (item) =>
              '${item.row.id}:${item.state.name}:${item.row.messageCount}:'
              '${item.row.lastMessageAt}:${item.row.lastActivityDescription}:'
              '${item.request?.requestId}:'
              '${item.queue?.count}:${item.queue?.parked}:'
              '${item.queue?.deliveryUncertain}',
        )
        .join('|');
    final old = _items
        .map(
          (item) =>
              '${item.row.id}:${item.state.name}:${item.row.messageCount}:'
              '${item.row.lastMessageAt}:${item.row.lastActivityDescription}:'
              '${item.request?.requestId}:'
              '${item.queue?.count}:${item.queue?.parked}:'
              '${item.queue?.deliveryUncertain}',
        )
        .join('|');
    if (signature == old) return;
    _items = List.unmodifiable(next);
    notifyListeners();
  }

  @override
  void dispose() {
    _sessions.removeListener(_rebuild);
    _requests.removeListener(_rebuild);
    super.dispose();
  }
}
