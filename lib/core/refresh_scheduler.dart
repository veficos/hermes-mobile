import 'dart:async';

import 'performance_metrics.dart';

/// Coalesces resource refreshes across stores. One key has at most one active
/// request and one trailing refresh, preventing reconnect/timer/event bursts
/// from multiplying identical work.
class RefreshScheduler {
  RefreshScheduler({this.onCoalesced});

  final void Function(String key)? onCoalesced;
  final Map<String, Future<void>> _running = {};
  final Set<String> _trailing = {};

  Future<void> run(String key, Future<void> Function() action) {
    final active = _running[key];
    if (active != null) {
      _trailing.add(key);
      onCoalesced?.call(key);
      return active;
    }
    final future = _drain(key, action);
    _running[key] = future;
    return future;
  }

  Future<void> _drain(String key, Future<void> Function() action) async {
    try {
      do {
        _trailing.remove(key);
        await action();
      } while (_trailing.remove(key));
    } finally {
      _running.remove(key);
    }
  }

  bool isRunning(String key) => _running.containsKey(key);
}

final clientRefreshScheduler = RefreshScheduler(
  onCoalesced: (_) =>
      ClientPerformanceMetrics.instance.listRefreshesSuppressed++,
);
