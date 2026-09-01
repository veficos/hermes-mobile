import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'gateway.dart';
import '../l10n/l10n.dart';
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

  void observeConnection(
    ConnectionStore connection,
    FutureOr<void> Function() reload,
  ) {
    _reloadForConnection = reload;
    if (identical(connection, _observedConnection)) return;
    _observedConnection?.removeListener(_handleConnectionChange);
    _observedConnection = connection..addListener(_handleConnectionChange);
    _observedApi = connection.api;
    _observedGateway = connection.gateway;
    _observedConnected = connection.isConnected;
  }

  void disposeConnectionObserver() {
    _observedConnection?.removeListener(_handleConnectionChange);
    _observedConnection = null;
    _observedApi = null;
    _observedGateway = null;
    _observedConnected = false;
    _reloadForConnection = null;
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
}
