library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../connections/connection_registry.dart';
import '../models.dart';
import '../../l10n/runtime_l10n.dart';
import 'connection_store.dart';

@immutable
class BillingGateSnapshot {
  const BillingGateSnapshot({this.blocked = false, this.reason});
  final bool blocked;
  final String? reason;
}

class BillingStore extends ChangeNotifier {
  ApiClient? _api;
  BillingState? _state;
  BillingGateSnapshot _gate = const BillingGateSnapshot();
  Future<void>? _inflight;
  DateTime? _refreshedAt;
  int _generation = 0;
  ConnectionStore? _connection;
  StreamSubscription<RoutedGatewayEvent>? _events;
  Timer? _timer;
  static const _ttl = Duration(seconds: 30);
  BillingState? get state => _state;
  BillingGateSnapshot get gate => _gate;

  void attachConnection(ConnectionStore connection) {
    if (identical(_connection, connection)) return;
    _events?.cancel();
    _timer?.cancel();
    _connection = connection;
    _events = connection.routedEvents.listen((routed) {
      if (routed.route.connectionId != connection.activeConnectionId ||
          routed.event.type != 'notification.show') {
        return;
      }
      final key = routed.event.payload['key']?.toString() ?? '';
      if (!key.startsWith('credits.')) return;
      _refreshedAt = null;
      unawaited(refresh());
    });
    _timer = Timer.periodic(_ttl, (_) => unawaited(refresh()));
  }

  void bindApi(ApiClient? api) {
    if (identical(_api, api)) return;
    _api = api;
    _generation++;
    _state = null;
    _gate = const BillingGateSnapshot();
    _inflight = null;
    _refreshedAt = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null) return;
    final last = _refreshedAt;
    if (last != null && DateTime.now().difference(last) < _ttl) return;
    final existing = _inflight;
    if (existing != null) return existing;
    final generation = _generation;
    final request = () async {
      try {
        final state = await api.billingState();
        if (generation != _generation || !identical(api, _api)) return;
        _state = state;
        _refreshedAt = DateTime.now();
        final blocked =
            state.balance <= 0 &&
            state.creditLimit != null &&
            state.creditLimit! <= 0;
        _gate = BillingGateSnapshot(
          blocked: blocked,
          reason: blocked ? runtimeL10n.billingCreditsExhausted : null,
        );
        notifyListeners();
      } catch (_) {
        // Keep the last known gate on transient billing endpoint failures.
      } finally {
        if (generation == _generation && identical(api, _api)) {
          _inflight = null;
        }
      }
    }();
    _inflight = request;
    return request;
  }

  @override
  void dispose() {
    _events?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
