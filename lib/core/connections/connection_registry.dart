library;

import 'dart:async';
import 'dart:math';

import '../api_client.dart';
import '../gateway.dart';
import '../settings_store.dart';
import '../../l10n/runtime_l10n.dart';

class ConnectionId {
  final String value;
  const ConnectionId(this.value);

  @override
  bool operator ==(Object other) =>
      other is ConnectionId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class OwnerRoute {
  final ConnectionId connectionId;
  final String? profile;

  const OwnerRoute({required this.connectionId, this.profile});

  String get key => '${connectionId.value}\u0000${profile ?? ''}';

  @override
  bool operator ==(Object other) =>
      other is OwnerRoute &&
      other.connectionId == connectionId &&
      other.profile == profile;

  @override
  int get hashCode => Object.hash(connectionId, profile);
}

class SessionOwner {
  final String durableId;
  final String? runtimeId;
  final String? lineageRootId;
  final OwnerRoute route;

  const SessionOwner({
    required this.durableId,
    required this.route,
    this.runtimeId,
    this.lineageRootId,
  });

  SessionOwner copyWith({String? runtimeId, String? lineageRootId}) =>
      SessionOwner(
        durableId: durableId,
        route: route,
        runtimeId: runtimeId ?? this.runtimeId,
        lineageRootId: lineageRootId ?? this.lineageRootId,
      );
}

class RoutedGatewayEvent {
  final OwnerRoute route;
  final int socketGeneration;
  final GatewayEvent event;

  const RoutedGatewayEvent({
    required this.route,
    required this.socketGeneration,
    required this.event,
  });
}

enum RuntimePhase {
  disconnected,
  connecting,
  connected,
  reconnecting,
  exhausted,
}

typedef ApiClientFactory = ApiClient Function(ConnectionSettings settings);
typedef GatewayClientFactory =
    GatewayClient Function(ConnectionSettings settings);

class ConnectionRuntime {
  final ConnectionId id;
  ConnectionSettings settings;
  final ApiClient api;
  final GatewayClient gateway;
  final void Function(ConnectionRuntime runtime, String reason)? onDropped;
  final void Function(ConnectionRuntime runtime)? onStateChanged;
  final void Function(ConnectionRuntime runtime)? onReconnected;

  RuntimePhase phase = RuntimePhase.disconnected;
  String? error;
  int socketGeneration = 0;
  StreamSubscription<GatewayEvent>? _eventSub;
  StreamSubscription<String>? _dropSub;
  final StreamController<RoutedGatewayEvent> _events =
      StreamController<RoutedGatewayEvent>.broadcast();
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  Future<void>? _connectFlight;

  ConnectionRuntime({
    required this.id,
    required this.settings,
    required this.api,
    required this.gateway,
    this.onDropped,
    this.onStateChanged,
    this.onReconnected,
  }) {
    _eventSub = gateway.events.listen((event) {
      _events.add(
        RoutedGatewayEvent(
          route: OwnerRoute(connectionId: id),
          socketGeneration: socketGeneration,
          event: event,
        ),
      );
    });
    _dropSub = gateway.onDisconnect.listen((reason) {
      if (reason == runtimeL10n.commonAuthenticationFailed) {
        phase = RuntimePhase.exhausted;
        error = reason;
        onDropped?.call(this, reason);
        onStateChanged?.call(this);
        return;
      }
      phase = RuntimePhase.reconnecting;
      error = reason;
      onDropped?.call(this, reason);
      onStateChanged?.call(this);
      _scheduleReconnect();
    });
  }

  Stream<RoutedGatewayEvent> get events => _events.stream;

  Future<void> connect() {
    final flight = _connectFlight;
    if (flight != null) return flight;
    final next = _connectOnce();
    _connectFlight = next;
    return next.whenComplete(() {
      if (identical(_connectFlight, next)) _connectFlight = null;
    });
  }

  Future<void> _connectOnce() async {
    if (gateway.isConnected) {
      phase = RuntimePhase.connected;
      onStateChanged?.call(this);
      return;
    }
    final reclaim = socketGeneration > 0 || phase == RuntimePhase.reconnecting;
    phase = phase == RuntimePhase.reconnecting
        ? RuntimePhase.reconnecting
        : RuntimePhase.connecting;
    try {
      await gateway.connect();
      socketGeneration++;
      _reconnectAttempt = 0;
      phase = RuntimePhase.connected;
      error = null;
      onStateChanged?.call(this);
      if (reclaim) onReconnected?.call(this);
    } catch (e) {
      phase = RuntimePhase.disconnected;
      error = '$e';
      onStateChanged?.call(this);
      rethrow;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) return;
    if (_reconnectAttempt >= 8) {
      phase = RuntimePhase.exhausted;
      onStateChanged?.call(this);
      return;
    }
    final delayMs = min(15000, 300 * pow(2, _reconnectAttempt).toInt());
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      _reconnectTimer = null;
      if (_disposed) return;
      try {
        await connect();
      } catch (_) {
        phase = RuntimePhase.reconnecting;
        onStateChanged?.call(this);
        _scheduleReconnect();
      }
    });
  }

  Future<void> reconnectNow() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    await connect();
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _eventSub?.cancel();
    await _dropSub?.cancel();
    await gateway.dispose();
    api.close();
    await _events.close();
  }
}

class ConnectionRegistry {
  final Map<ConnectionId, ConnectionRuntime> _runtimes = {};
  final StreamController<RoutedGatewayEvent> _events =
      StreamController<RoutedGatewayEvent>.broadcast();
  final Map<ConnectionId, StreamSubscription<RoutedGatewayEvent>> _subs = {};

  ConnectionId? activeId;

  Stream<RoutedGatewayEvent> get events => _events.stream;
  Iterable<ConnectionRuntime> get runtimes => _runtimes.values;
  ConnectionRuntime? get active =>
      activeId == null ? null : _runtimes[activeId!];

  ConnectionRuntime? runtime(ConnectionId id) => _runtimes[id];

  void add(ConnectionRuntime runtime, {bool makeActive = false}) {
    if (_runtimes.containsKey(runtime.id)) {
      throw StateError('connection already registered: ${runtime.id}');
    }
    _runtimes[runtime.id] = runtime;
    _subs[runtime.id] = runtime.events.listen(_events.add);
    if (makeActive || activeId == null) activeId = runtime.id;
  }

  void activate(ConnectionId id) {
    if (!_runtimes.containsKey(id)) {
      throw StateError('unknown connection: $id');
    }
    activeId = id;
  }

  Future<void> remove(ConnectionId id) async {
    final runtime = _runtimes.remove(id);
    await _subs.remove(id)?.cancel();
    if (runtime != null) await runtime.dispose();
    if (activeId == id) activeId = _runtimes.keys.firstOrNull;
  }

  Future<void> dispose() async {
    for (final id in _runtimes.keys.toList()) {
      await remove(id);
    }
    await _events.close();
  }
}

class SessionOwnerIndex {
  final Map<String, SessionOwner> _byDurable = {};
  final Map<String, SessionOwner> _byRuntime = {};

  SessionOwner? byDurable(String id) => _byDurable[id];
  SessionOwner? byRuntime(String id) => _byRuntime[id];

  void remember(SessionOwner owner) {
    final previous = _byDurable[owner.durableId];
    if (previous?.runtimeId != null) _byRuntime.remove(previous!.runtimeId);
    _byDurable[owner.durableId] = owner;
    if (owner.runtimeId case final runtimeId?) _byRuntime[runtimeId] = owner;
  }

  void forget(String durableId) {
    final owner = _byDurable.remove(durableId);
    if (owner?.runtimeId != null) _byRuntime.remove(owner!.runtimeId);
  }

  void clearConnection(ConnectionId id) {
    final ids = _byDurable.values
        .where((owner) => owner.route.connectionId == id)
        .map((owner) => owner.durableId)
        .toList();
    for (final durableId in ids) {
      forget(durableId);
    }
  }
}
