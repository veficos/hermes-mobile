import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'gateway.dart';
import '../l10n/l10n.dart';
import 'connections/connection_registry.dart';
import 'stores/connection_store.dart';

const connectionOfflineErrorCode = 'hermes.connection.offline';

ApiClient? connectedApiOrNotify(
  BuildContext context,
  ConnectionStore connection,
) {
  final api = connection.api;
  if (api != null) return api;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(context.l10n.backendDisconnected)));
  return null;
}

ApiClient requireActiveApi(
  BuildContext context,
  ConnectionStore connection,
  ApiClient expected,
) {
  if (!identical(connection.api, expected)) {
    throw StateError(context.l10n.backendDisconnected);
  }
  return expected;
}

GatewayClient? connectedGatewayOrNotify(
  BuildContext context,
  ConnectionStore connection,
) {
  final gateway = connection.gateway;
  if (gateway != null) return gateway;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(context.l10n.backendDisconnected)));
  return null;
}

GatewayClient requireActiveGateway(
  BuildContext context,
  ConnectionStore connection,
  GatewayClient expected,
) {
  if (!identical(connection.gateway, expected)) {
    throw StateError(context.l10n.backendDisconnected);
  }
  return expected;
}

mixin ConnectionReloadMixin<T extends StatefulWidget> on State<T> {
  ConnectionStore? _observedConnection;
  ApiClient? _observedApi;
  GatewayClient? _observedGateway;
  bool _observedConnected = false;
  FutureOr<void> Function()? _reloadForConnection;

  // Optional target-connection tracking, used only when `observeConnection`
  // is called with a non-null `targetConnectionId` — e.g. a screen opened
  // for a specific bot's connection that may not be the active one (see
  // `ProfilesScreen.targetConnectionId`, `McpScreen.targetConnectionId`,
  // `McpLogsScreen.targetConnectionId`). The active-connection tracking
  // above is left untouched and keeps running alongside this.
  ConnectionId? _observedTargetId;
  ConnectionRegistry? _observedTargetRegistry;
  StreamSubscription<ConnectionId>? _targetStateSub;
  ApiClient? _observedTargetApi;
  GatewayClient? _observedTargetGateway;
  bool _observedTargetConnected = false;

  /// Starts (or updates) reload-on-reconnect observation.
  ///
  /// By default this only tracks [connection]'s *active* runtime. When
  /// [targetConnectionId] is given, it additionally tracks that specific
  /// runtime's identity/connectivity via [ConnectionRegistry.stateChanges]
  /// so [reload] also fires when that particular connection (re)connects
  /// with a new [ApiClient]/[GatewayClient], regardless of which connection
  /// happens to be active at the time.
  void observeConnection(
    ConnectionStore connection,
    FutureOr<void> Function() reload, {
    ConnectionId? targetConnectionId,
  }) {
    _reloadForConnection = reload;
    if (!identical(connection, _observedConnection)) {
      _observedConnection?.removeListener(_handleConnectionChange);
      _observedConnection = connection..addListener(_handleConnectionChange);
      _observedApi = connection.api;
      _observedGateway = connection.gateway;
      _observedConnected = connection.isConnected;
    }

    if (targetConnectionId == _observedTargetId &&
        identical(connection.registry, _observedTargetRegistry)) {
      return;
    }
    unawaited(_targetStateSub?.cancel());
    _targetStateSub = null;
    _observedTargetId = targetConnectionId;
    _observedTargetRegistry = connection.registry;
    if (targetConnectionId == null) {
      _observedTargetApi = null;
      _observedTargetGateway = null;
      _observedTargetConnected = false;
      return;
    }
    final runtime = connection.registry.runtime(targetConnectionId);
    _observedTargetApi = runtime?.api;
    _observedTargetGateway = runtime?.gateway;
    _observedTargetConnected = runtime?.phase == RuntimePhase.connected;
    _targetStateSub = connection.registry.stateChanges
        .where((id) => id == targetConnectionId)
        .listen((_) => _handleTargetConnectionChange());
  }

  void disposeConnectionObserver() {
    _observedConnection?.removeListener(_handleConnectionChange);
    _observedConnection = null;
    _observedApi = null;
    _observedGateway = null;
    _observedConnected = false;
    _reloadForConnection = null;

    unawaited(_targetStateSub?.cancel());
    _targetStateSub = null;
    _observedTargetId = null;
    _observedTargetRegistry = null;
    _observedTargetApi = null;
    _observedTargetGateway = null;
    _observedTargetConnected = false;
  }

  void _handleConnectionChange() {
    final api = _observedConnection?.api;
    final gateway = _observedConnection?.gateway;
    final connected = _observedConnection?.isConnected == true;
    final identityChanged =
        !identical(api, _observedApi) || !identical(gateway, _observedGateway);
    final recovered = connected && !_observedConnected;
    _observedConnected = connected;
    if (!identityChanged && !recovered) {
      return;
    }
    _observedApi = api;
    _observedGateway = gateway;
    _reloadForConnection?.call();
  }

  void _handleTargetConnectionChange() {
    final targetId = _observedTargetId;
    final registry = _observedTargetRegistry;
    if (targetId == null || registry == null) return;
    final runtime = registry.runtime(targetId);
    final api = runtime?.api;
    final gateway = runtime?.gateway;
    final connected = runtime?.phase == RuntimePhase.connected;
    final identityChanged =
        !identical(api, _observedTargetApi) ||
        !identical(gateway, _observedTargetGateway);
    final recovered = connected && !_observedTargetConnected;
    _observedTargetConnected = connected;
    if (!identityChanged && !recovered) {
      return;
    }
    _observedTargetApi = api;
    _observedTargetGateway = gateway;
    _reloadForConnection?.call();
  }
}
