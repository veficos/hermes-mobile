/// ConnectionStore owns settings and projects the active runtime for legacy
/// consumers. ConnectionRuntime is the sole connect/reconnect/reclaim owner.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api_client.dart';
import '../connections/connection_registry.dart';
import '../gateway.dart';
import '../gateway_oauth.dart';
import '../../l10n/runtime_l10n.dart';
import '../settings_store.dart';
import '../ssh_gateway_tunnel.dart';

/// UI states for the reconnect banner (D10).
enum ConnectionPhase {
  disconnected, // not configured or initial
  connecting,
  connected,
  reconnecting, // socket dropped, auto-reconnect in progress
  exhausted,
}

typedef ConnectionClientsFactory =
    Future<({ApiClient api, GatewayClient gateway})> Function(
      ConnectionId id,
      ConnectionSettings settings,
    );

class ConnectionStore extends ChangeNotifier {
  static const primaryConnectionId = ConnectionId('primary');
  static ConnectionId savedConnectionId(String name) =>
      ConnectionId('saved:${name.trim()}');
  final SettingsStore store;
  final ConnectionClientsFactory? clientFactory;
  final ConnectionRegistry registry = ConnectionRegistry();
  final SessionOwnerIndex sessionOwners = SessionOwnerIndex();

  ConnectionSettings settings = const ConnectionSettings();
  ApiClient? api;
  GatewayClient? gateway;

  ConnectionPhase phase = ConnectionPhase.disconnected;
  String? error; // last connect/connection error
  String? capability; // full | legacy | missing
  Set<String> restCapabilities = const {};

  final StreamController<GatewayEvent> _events = StreamController.broadcast();
  final StreamController<void> _reconnected = StreamController.broadcast();
  StreamSubscription<RoutedGatewayEvent>? _registryEventSub;
  final List<Future<void> Function(ApiClient client)> _beforeDisconnectHooks =
      [];
  final Map<ConnectionId, int> _clientGenerations = {};
  final Map<(ConnectionId, int), GatewayOAuthTokens> _pendingOAuthTokens = {};

  ConnectionStore({SettingsStore? store, this.clientFactory})
    : store = store ?? SettingsStore() {
    _registryEventSub = registry.events.listen((routed) {
      if (routed.route.connectionId == activeConnectionId) {
        _events.add(routed.event);
      }
    });
  }

  /// Fan-out of gateway events; stores subscribe here once.
  Stream<GatewayEvent> get events => _events.stream;

  /// Broadcast after an automatic reconnect so stores can independently
  /// restore their authoritative snapshots.
  Stream<void> get reconnected => _reconnected.stream;
  Stream<RoutedGatewayEvent> get routedEvents => registry.events;
  ConnectionId get activeConnectionId =>
      registry.activeId ?? primaryConnectionId;

  bool get isConfigured => settings.isConfigured;
  bool get isConnected =>
      gateway?.isConnected == true && phase == ConnectionPhase.connected;

  /// User-given name of the saved profile matching the active connection's
  /// settings, when one exists — the chat transcript's "当前连接的备注".
  String? _activeProfileLabel;

  /// A short, human label for the connection currently in use: the saved
  /// profile's own name when the active settings match one, otherwise the
  /// server host (falling back to the raw URL, or null when unconfigured).
  /// Never blocks on a lookup — [_activeProfileLabel] is refreshed
  /// separately whenever the profile list or active settings change.
  String? get activeConnectionLabel {
    final label = _activeProfileLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (!settings.isConfigured) return null;
    final uri = Uri.tryParse(settings.baseUrl);
    final host = uri?.host;
    if (host != null && host.isNotEmpty) {
      final port = uri!.port;
      final showPort = uri.hasPort && port != 80 && port != 443;
      return showPort ? '$host:$port' : host;
    }
    return settings.serverUrl.trim().isEmpty ? null : settings.serverUrl;
  }

  Future<void> load() async {
    settings = await store.load();
    if (settings.isConfigured) {
      try {
        await _buildClients();
        unawaited(connect().catchError((_) {}));
      } catch (e) {
        error = '$e';
        phase = ConnectionPhase.exhausted;
      }
      unawaited(_loadSavedConnections());
    }
    notifyListeners();
  }

  /// Re-resolves [activeConnectionLabel] against the saved profile list.
  /// Side-effect-free beyond that (no connect/registry changes) — safe to
  /// call standalone whenever just the label needs refreshing.
  Future<void> refreshActiveConnectionLabel() async {
    _resolveActiveProfileLabel(await store.profiles());
  }

  Future<void> _loadSavedConnections() async {
    final saved = await store.profiles();
    final activeName = await store.activeProfileName();
    _resolveActiveProfileLabel(saved);
    for (final profile in saved) {
      final candidate = profile.settings;
      if (!candidate.isConfigured || candidate.hasSameIdentity(settings)) {
        continue;
      }
      final id = savedConnectionId(profile.name);
      try {
        await addConnection(
          id,
          candidate,
          makeActive: profile.name == activeName,
        );
      } catch (_) {
        // A saved backend may be offline. Keep the foreground usable; the
        // connection can be retried explicitly without retargeting sessions.
      }
    }
  }

  /// Matches the active [settings] against the saved profile list by
  /// connection identity (not the separately-tracked "active profile" flag,
  /// which can point at a different profile than what's actually connected)
  /// so [activeConnectionLabel] shows the right name.
  void _resolveActiveProfileLabel(List<ServerProfile> saved) {
    final match = saved
        .where((p) => p.settings.hasSameIdentity(settings))
        .firstOrNull;
    final next = match?.name;
    if (next == _activeProfileLabel) return;
    _activeProfileLabel = next;
    notifyListeners();
  }

  Future<void> _buildClients() async {
    // F9: tear down the old gateway/subscriptions before replacing them.
    // The old primary runtime is removed below; its dispose() closes the
    // gateway and its stream controllers.
    api?.close();
    final clients = await _clientsFor(primaryConnectionId, settings);
    api = clients.api;
    gateway = clients.gateway;
    final oldPrimary = registry.runtime(primaryConnectionId);
    if (oldPrimary != null) {
      await registry.remove(primaryConnectionId);
    }
    registry.add(
      _runtime(primaryConnectionId, settings, api!, gateway!),
      makeActive: true,
    );
  }

  Future<void> saveConnection(ConnectionSettings newSettings) async {
    final oldSettings = settings;
    final previousApi = api;
    final previousGeneration = _clientGenerations[primaryConnectionId];
    late ({ApiClient api, GatewayClient gateway}) clients;
    try {
      clients = await _clientsFor(primaryConnectionId, newSettings);
    } catch (_) {
      if (previousGeneration == null) {
        _clientGenerations.remove(primaryConnectionId);
      } else {
        _clientGenerations[primaryConnectionId] = previousGeneration;
      }
      rethrow;
    }
    final candidate = _runtime(
      primaryConnectionId,
      newSettings,
      clients.api,
      clients.gateway,
    );
    var persisted = false;
    try {
      // Prepare everything while the old primary remains fully usable.
      await candidate.connect();
      if (previousApi != null && !newSettings.hasSameIdentity(oldSettings)) {
        await _runBeforeDisconnectHooks(previousApi);
      }
      await store.save(newSettings);
      persisted = true;

      // Commit only after every fallible preparation step has succeeded.
      final oldPrimary = registry.runtime(primaryConnectionId);
      if (oldPrimary != null) await registry.remove(primaryConnectionId);
      registry.add(candidate, makeActive: true);
      settings = newSettings;
      api = clients.api;
      gateway = clients.gateway;
      _resetConnectionState();
      _syncActiveFacade();
    } catch (_) {
      if (persisted) {
        try {
          await store.save(oldSettings);
        } catch (_) {}
      }
      if (registry.runtime(primaryConnectionId) != candidate) {
        await candidate.dispose();
      }
      if (previousGeneration == null) {
        _clientGenerations.remove(primaryConnectionId);
      } else {
        _clientGenerations[primaryConnectionId] = previousGeneration;
      }
      rethrow;
    }
    _activeProfileLabel = null;
    notifyListeners();
    unawaited(refreshActiveConnectionLabel());
  }

  /// Verifies credentials without replacing or persisting the active runtime.
  Future<void> validateConnection(ConnectionSettings candidate) async {
    final clients = await _clientsFor(const ConnectionId('probe'), candidate);
    try {
      await clients.gateway.connect();
    } finally {
      await clients.gateway.dispose();
      clients.api.close();
    }
  }

  Future<void> clearConnection() async {
    final previousApi = api;
    if (previousApi != null) await _runBeforeDisconnectHooks(previousApi);
    await store.clear();
    _resetConnectionState();
    for (final runtime in registry.runtimes.toList()) {
      await registry.remove(runtime.id);
      sessionOwners.clearConnection(runtime.id);
    }
    settings = const ConnectionSettings();
    api = null;
    gateway = null;
    capability = null;
    restCapabilities = const {};
    sessionOwners.clearConnection(primaryConnectionId);
    notifyListeners();
  }

  void addBeforeDisconnectHook(Future<void> Function(ApiClient client) hook) {
    if (!_beforeDisconnectHooks.contains(hook)) {
      _beforeDisconnectHooks.add(hook);
    }
  }

  void removeBeforeDisconnectHook(
    Future<void> Function(ApiClient client) hook,
  ) {
    _beforeDisconnectHooks.remove(hook);
  }

  Future<void> _runBeforeDisconnectHooks(ApiClient client) async {
    for (final hook in List.of(_beforeDisconnectHooks)) {
      try {
        await hook(client);
      } catch (_) {
        // Connection teardown must not be held hostage by optional cleanup.
      }
    }
  }

  void _resetConnectionState() {
    phase = ConnectionPhase.disconnected;
    error = null;
  }

  /// Legacy single listener retained for compatibility. New stores should use
  /// [reconnected] so subscribers cannot overwrite one another.
  VoidCallback? onReconnected;

  /// Connect now; throws on failure (callers may catch and surface).
  Future<void> connect() async {
    if (!isConfigured || gateway == null) return;
    if (isConnected) return;
    final runtime = registry.active;
    if (runtime == null) return;
    try {
      await runtime.connect();
      _syncActiveFacade();
      unawaited(refreshCapabilities());
    } catch (e) {
      error = '$e';
      _syncActiveFacade();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Ensure a live connection; used by stores before socket-bound operations.
  Future<void> ensureConnected() async {
    if (isConnected) return;
    await connect();
  }

  /// Propagates application lifecycle state to every registered backend so
  /// iOS background suspension cannot strand inactive connection runtimes.
  void setForeground(bool foreground) {
    for (final runtime in registry.runtimes) {
      runtime.setForeground(foreground);
    }
  }

  /// Restarts an exhausted reconnect cycle when the app returns to the
  /// foreground. [refreshSocket] also replaces a socket that may look alive
  /// locally after the operating system suspended its network path. A forced
  /// refresh uses a two-phase reset: all registered sockets are closed before
  /// any of them is allowed to reconnect.
  Future<void> reconnectAfterResume({bool refreshSocket = false}) async {
    if (!isConfigured) return;
    final runtime = registry.active;
    if (runtime == null) return;
    try {
      if (refreshSocket) {
        await registry.reconnectAllAfterDisconnect();
      } else {
        await runtime.reconnectAfterResume();
      }
      _syncActiveFacade();
      unawaited(refreshCapabilities());
    } catch (e) {
      error = '$e';
      _syncActiveFacade();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Capability probe result (full | legacy | missing), fetched from status.
  Future<void> refreshStatus() async {
    await refreshCapabilities();
  }

  Future<void> refreshCapabilities() async {
    final client = api;
    if (client == null) return;
    final connectionId = activeConnectionId;
    try {
      final status = await client.status();
      if (!identical(client, api) || connectionId != activeConnectionId) return;
      capability = status['capability']?.toString() ?? 'missing';
    } catch (_) {
      // Keep the last known runtime capability while reconnecting.
    }
    try {
      final methods = await client.methods();
      if (!identical(client, api) || connectionId != activeConnectionId) return;
      final rest =
          ((methods['rest'] as Map?)?['resources'] as List? ?? const [])
              .map((item) => item.toString())
              .toSet();
      restCapabilities = Set.unmodifiable(rest);
    } catch (_) {
      // Older mobile servers may not expose /methods.
    }
    if (identical(client, api) && connectionId == activeConnectionId) {
      notifyListeners();
    }
  }

  bool supportsRest(String route) => restCapabilities.contains(route);

  /// Agent plugin management is a Gateway capability, so it works through
  /// local, URL, cloud and SSH topologies. Companion REST is preferred because
  /// the mobile server safely enriches the gateway inventory with manifest v2
  /// views/locales that older Hermes gateways intentionally omit.
  Future<List<Map<String, dynamic>>> listPlugins({String? profile}) async {
    List<Map<String, dynamic>> normalize(Iterable<Map> rows) => rows.map((raw) {
      final row = raw.cast<String, dynamic>();
      return <String, dynamic>{
        ...row,
        'id': row['id'] ?? row['key'] ?? row['name'],
        'enabled': row['enabled'] ?? row['status'] == 'enabled',
      };
    }).toList();

    if (settings.transport == ConnectionTransport.companion && api != null) {
      try {
        return normalize(await api!.plugins(profile: profile));
      } catch (_) {
        // Old companion servers may not expose /plugins. The gateway path
        // below preserves compatibility, albeit without v2 enrichment.
      }
    }
    try {
      final result = await requestForOwner(
        OwnerRoute(connectionId: activeConnectionId),
        'plugins.manage',
        {'action': 'list', 'profile': ?profile},
      );
      return normalize(
        (result['plugins'] as List? ?? const []).whereType<Map>(),
      );
    } catch (_) {
      if (settings.transport != ConnectionTransport.companion || api == null) {
        rethrow;
      }
      return normalize(await api!.plugins(profile: profile));
    }
  }

  Future<void> setPluginEnabled(
    Map<String, dynamic> plugin,
    bool enabled, {
    String? profile,
  }) async {
    final key = plugin['key']?.toString() ?? '';
    if (key.isNotEmpty) {
      final result = await requestForOwner(
        OwnerRoute(connectionId: activeConnectionId),
        'plugins.manage',
        {
          'action': 'toggle',
          'key': key,
          'enable': enabled,
          'profile': ?profile,
        },
      );
      if (result['ok'] != true) {
        throw StateError(runtimeL10n.errorPluginToggleRejected);
      }
      return;
    }
    if (settings.transport != ConnectionTransport.companion || api == null) {
      throw StateError(runtimeL10n.errorPluginCanonicalKeyRequired);
    }
    final name = plugin['name']?.toString() ?? '';
    await api!.setPluginEnabled(name, enabled, profile: profile);
  }

  Future<Map<String, dynamic>> installPlugin(
    String identifier, {
    bool force = false,
    bool enable = true,
    String? profile,
  }) async {
    final value = identifier.trim();
    if (value.isEmpty) throw ArgumentError('plugin identifier is required');
    try {
      return await requestForOwner(
        OwnerRoute(connectionId: activeConnectionId, profile: profile),
        'plugins.manage',
        {
          'action': 'install',
          'identifier': value,
          'force': force,
          'enable': enable,
          'profile': ?profile,
        },
      );
    } catch (_) {
      if (settings.transport != ConnectionTransport.companion || api == null) {
        rethrow;
      }
      return api!.installPlugin(
        value,
        force: force,
        enable: enable,
        profile: profile,
      );
    }
  }

  /// Register and connect another backend without tearing down the foreground
  /// backend. The legacy [api]/[gateway] getters remain an active-runtime
  /// facade while session-scoped work routes through [requestForOwner].
  Future<void> addConnection(
    ConnectionId id,
    ConnectionSettings settings, {
    bool makeActive = false,
  }) async {
    if (!settings.isConfigured) {
      throw StateError(runtimeL10n.errorConnectionNotConfigured);
    }
    final previousClientGeneration = _clientGenerations[id];
    late ({ApiClient api, GatewayClient gateway}) clients;
    try {
      clients = await _clientsFor(id, settings);
    } catch (_) {
      if (previousClientGeneration == null) {
        _clientGenerations.remove(id);
      } else {
        _clientGenerations[id] = previousClientGeneration;
      }
      rethrow;
    }
    final clientGeneration = _clientGenerations[id]!;
    final runtime = _runtime(id, settings, clients.api, clients.gateway);
    try {
      // A candidate is not observable as active until it has connected. This
      // keeps the existing REST facade and routed event filter on one backend.
      await runtime.connect();
      if (registry.runtime(id) != null) await registry.remove(id);
      registry.add(runtime, makeActive: makeActive);
      final pending = _pendingOAuthTokens.remove((id, clientGeneration));
      if (pending != null) {
        await _persistRefreshedTokens(id, clientGeneration, settings, pending);
      }
      if (makeActive) _syncActiveFacade();
      notifyListeners();
    } catch (_) {
      _pendingOAuthTokens.remove((id, clientGeneration));
      if (_clientGenerations[id] == clientGeneration) {
        if (previousClientGeneration == null) {
          _clientGenerations.remove(id);
        } else {
          _clientGenerations[id] = previousClientGeneration;
        }
      }
      await runtime.dispose();
      rethrow;
    }
  }

  Future<({ApiClient api, GatewayClient gateway})> _clientsFor(
    ConnectionId id,
    ConnectionSettings candidate,
  ) async {
    final clientGeneration = (_clientGenerations[id] ?? 0) + 1;
    _clientGenerations[id] = clientGeneration;
    final factory = clientFactory;
    if (factory != null) return factory(id, candidate);
    if (candidate.transport == ConnectionTransport.sshTunnel) {
      final tunnel = await openSshGatewayTunnel(
        candidate,
        secrets: store.secrets,
      );
      final gateway = GatewayClient(
        serverBaseUrl: tunnel.baseUrl,
        apiKey: tunnel.apiKey,
        extraHeaders: candidate.normalizedHeaders,
        directGateway: true,
      );
      return (
        api: ApiClient(
          baseUrl: tunnel.baseUrl,
          apiKey: tunnel.apiKey,
          extraHeaders: candidate.normalizedHeaders,
          directGateway: true,
          gatewayRequest: (method, params, {timeout}) => timeout == null
              ? gateway.request(method, params)
              : gateway.request(method, params, timeout: timeout),
          onClose: () => unawaited(tunnel.close()),
        ),
        gateway: gateway,
      );
    }
    final direct = candidate.transport == ConnectionTransport.directGateway;
    if (candidate.authMode != ConnectionAuthMode.oauth) {
      final gateway = GatewayClient(
        serverBaseUrl: candidate.baseUrl,
        apiKey: candidate.apiKey,
        extraHeaders: candidate.normalizedHeaders,
        directGateway: direct,
      );
      return (
        api: ApiClient(
          baseUrl: candidate.baseUrl,
          apiKey: candidate.apiKey,
          extraHeaders: candidate.normalizedHeaders,
          directGateway: direct,
          gatewayRequest: direct
              ? (method, params, {timeout}) => timeout == null
                    ? gateway.request(method, params)
                    : gateway.request(method, params, timeout: timeout)
              : null,
        ),
        gateway: gateway,
      );
    }

    final oauthClient = GatewayOAuthClient(
      baseUrl: candidate.baseUrl,
      extraHeaders: candidate.normalizedHeaders,
    );
    final oauth = GatewayOAuthSession(
      GatewayOAuthTokens(
        accessToken: candidate.apiKey,
        refreshToken: candidate.refreshToken,
        expiresAt: candidate.oauthExpiresAt,
        provider: candidate.oauthProvider,
        userId: candidate.oauthUserId,
      ),
      client: oauthClient,
      onTokensChanged: (tokens) =>
          _persistRefreshedTokens(id, clientGeneration, candidate, tokens),
    );
    final gateway = GatewayClient(
      serverBaseUrl: candidate.baseUrl,
      apiKey: candidate.apiKey,
      extraHeaders: candidate.normalizedHeaders,
      webSocketUriProvider: oauth.webSocketUri,
      directGateway: true,
    );
    return (
      api: ApiClient(
        baseUrl: candidate.baseUrl,
        apiKey: candidate.apiKey,
        extraHeaders: candidate.normalizedHeaders,
        accessTokenProvider: oauth.accessToken,
        directGateway: true,
        gatewayRequest: (method, params, {timeout}) => timeout == null
            ? gateway.request(method, params)
            : gateway.request(method, params, timeout: timeout),
        onClose: oauthClient.close,
      ),
      gateway: gateway,
    );
  }

  Future<void> _persistRefreshedTokens(
    ConnectionId id,
    int clientGeneration,
    ConnectionSettings previous,
    GatewayOAuthTokens tokens,
  ) async {
    if (_clientGenerations[id] != clientGeneration) return;
    final runtime = registry.runtime(id);
    if (runtime == null && id != primaryConnectionId) {
      _pendingOAuthTokens[(id, clientGeneration)] = tokens;
      return;
    }
    final base =
        runtime?.settings ?? (id == primaryConnectionId ? settings : previous);
    if (!base.hasSameIdentity(previous)) {
      _pendingOAuthTokens[(id, clientGeneration)] = tokens;
      return;
    }
    final next = tokens.applyTo(base);
    if (runtime != null) runtime.settings = next;
    if (id == primaryConnectionId) {
      if (_clientGenerations[id] != clientGeneration ||
          !settings.hasSameIdentity(previous)) {
        return;
      }
      settings = next;
      await store.save(next);
    }
  }

  ConnectionRuntime _runtime(
    ConnectionId id,
    ConnectionSettings settings,
    ApiClient api,
    GatewayClient gateway,
  ) => ConnectionRuntime(
    id: id,
    settings: settings,
    api: api,
    gateway: gateway,
    onDropped: (runtime, reason) {
      if (runtime.id != activeConnectionId) return;
      phase = ConnectionPhase.reconnecting;
      error = reason;
      notifyListeners();
    },
    onStateChanged: (runtime) {
      if (runtime.id != activeConnectionId) return;
      _syncActiveFacade();
      notifyListeners();
    },
    onReconnected: (runtime) {
      if (runtime.id != activeConnectionId) return;
      onReconnected?.call();
      _reconnected.add(null);
      unawaited(refreshCapabilities());
    },
  );

  void activateConnection(ConnectionId id) {
    if (id == activeConnectionId) return;
    registry.activate(id);
    _activeProfileLabel = null;
    capability = null;
    restCapabilities = const {};
    _syncActiveFacade();
    notifyListeners();
    unawaited(refreshActiveConnectionLabel());
    unawaited(refreshCapabilities());
  }

  void _syncActiveFacade() {
    final runtime = registry.active;
    if (runtime == null) return;
    settings = runtime.settings;
    api = runtime.api;
    gateway = runtime.gateway;
    phase = switch (runtime.phase) {
      RuntimePhase.connected => ConnectionPhase.connected,
      RuntimePhase.connecting => ConnectionPhase.connecting,
      RuntimePhase.reconnecting => ConnectionPhase.reconnecting,
      RuntimePhase.exhausted => ConnectionPhase.exhausted,
      RuntimePhase.disconnected => ConnectionPhase.disconnected,
    };
    error = runtime.error;
  }

  ConnectionRuntime runtimeFor(OwnerRoute route) {
    final runtime = registry.runtime(route.connectionId);
    if (runtime == null) {
      throw StateError(
        'session owner connection is unavailable: ${route.connectionId}',
      );
    }
    return runtime;
  }

  Future<Map<String, dynamic>> requestForOwner(
    OwnerRoute route,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final runtime = registry.runtime(route.connectionId);
    if (runtime == null &&
        route.connectionId == primaryConnectionId &&
        gateway != null) {
      if (!gateway!.isConnected) await ensureConnected();
      return gateway!.request(method, params, timeout: timeout);
    }
    if (runtime == null) {
      throw StateError(
        'session owner connection is unavailable: ${route.connectionId}',
      );
    }
    await runtime.connect();
    return runtime.gateway.request(method, params, timeout: timeout);
  }

  Future<Map<String, dynamic>> requestForSession(
    String durableId,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    final owner = sessionOwners.byDurable(durableId);
    if (owner == null) {
      throw StateError(runtimeL10n.errorSessionOwnerUnknown(durableId));
    }
    return requestForOwner(owner.route, method, params, timeout: timeout);
  }

  @override
  void dispose() {
    phase = ConnectionPhase.disconnected;
    notifyListeners();
    _registryEventSub?.cancel();
    unawaited(registry.dispose());
    _events.close();
    _reconnected.close();
    super.dispose();
  }
}
