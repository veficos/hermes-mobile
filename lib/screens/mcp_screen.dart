/// MCP (spec §101–104): server list + enabled toggle + test + catalog,
/// backed by `/api/v1/mcp/*`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/mcp_import.dart';
import '../core/connection_reload_mixin.dart';
import '../core/mcp_tool_filter.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../core/stores/session_store.dart';
import '../theme/hermes_tokens.dart';
import '../l10n/l10n.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/hermes_adaptive_menu.dart';
import '../widgets/profile_scope_selector.dart';
import 'mcp_config_editor_screen.dart';
import 'mcp_logs_screen.dart';

class McpScreen extends StatefulWidget {
  const McpScreen({super.key});

  @override
  State<McpScreen> createState() => _McpScreenState();
}

class _McpScreenState extends State<McpScreen>
    with ConnectionReloadMixin<McpScreen> {
  List<Map<String, dynamic>>? _servers;
  List<Map<String, dynamic>>? _catalog;
  String? _error;
  String _busyName = '';
  String? _oauthFlowId;
  ApiClient? _oauthApi;
  String? _oauthProfile;
  bool _oauthCancelled = false;
  final Map<String, Map<String, dynamic>> _probes = {};
  final Map<String, String> _probeFingerprints = {};
  Map<String, int>? _usage30d;

  ProfileScopeStore? _scopeStore;
  // Without this, a fast profile-scope switch (or the toolbar refresh
  // button tapped twice) races two `_load()` calls; if the older request's
  // response lands after the newer one, it silently overwrites fresh
  // server/catalog data with stale data and there is no way to tell the UI
  // is now wrong. Mirrors `provider_config_screen.dart`'s `_loadGeneration`.
  int _loadGeneration = 0;
  int _mutationGeneration = 0;

  @override
  void initState() {
    super.initState();
    final scopeStore = context.read<ProfileScopeStore>();
    _scopeStore = scopeStore;
    scopeStore.addListener(_onScopeChanged);
    scopeStore.ensureLoaded();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForTarget);
  }

  @override
  void dispose() {
    final flowId = _oauthFlowId;
    final oauthApi = _oauthApi;
    if (flowId != null && oauthApi != null) {
      unawaited(_abandonOAuth(oauthApi, flowId, _oauthProfile));
    }
    disposeConnectionObserver();
    _scopeStore?.removeListener(_onScopeChanged);
    super.dispose();
  }

  void _onScopeChanged() {
    if (!mounted) return;
    _reloadForTarget();
  }

  void _reloadForTarget() {
    if (!mounted) return;
    final flowId = _oauthFlowId;
    final oauthApi = _oauthApi;
    if (flowId != null && oauthApi != null) {
      unawaited(_abandonOAuth(oauthApi, flowId, _oauthProfile));
    }
    ++_loadGeneration;
    ++_mutationGeneration;
    setState(() {
      _servers = null;
      _catalog = null;
      _usage30d = const {};
      _probes.clear();
      _probeFingerprints.clear();
      _busyName = '';
      _oauthFlowId = null;
      _oauthApi = null;
      _oauthProfile = null;
      _oauthCancelled = false;
      _error = null;
    });
    _load();
  }

  String? get _profile {
    final scope = _scopeStore;
    return scope?.override ?? scope?.activeProfile;
  }

  bool _ownsTarget(ApiClient api, String? profile) {
    return mounted &&
        profile == _profile &&
        identical(api, context.read<ConnectionStore>().api);
  }

  void _requireTarget(ApiClient api, String? profile) {
    if (!_ownsTarget(api, profile)) {
      throw StateError(context.l10n.backendDisconnected);
    }
  }

  Future<Map<String, dynamic>?> _persistedServer(
    ApiClient api,
    String? profile,
    String name,
  ) async {
    final servers = await api.mcpServers(profile: profile);
    _requireTarget(api, profile);
    for (final server in servers) {
      if (server['name']?.toString() == name) return server;
    }
    return null;
  }

  Future<void> _verifyServerEnabled(
    ApiClient api,
    String? profile,
    String name,
    bool enabled,
  ) async {
    final persistenceFailed = context.l10n.mcpPersistenceFailed;
    final persisted = await _persistedServer(api, profile, name);
    if (persisted == null || (persisted['enabled'] == true) != enabled) {
      throw StateError(persistenceFailed);
    }
  }

  Future<void> _verifyServerExists(
    ApiClient api,
    String? profile,
    String name,
  ) async {
    final persistenceFailed = context.l10n.mcpPersistenceFailed;
    if (await _persistedServer(api, profile, name) == null) {
      throw StateError(persistenceFailed);
    }
  }

  Future<void> _verifyCreatedServer(
    ApiClient api,
    String? profile,
    String name,
    Map<String, dynamic> submitted,
  ) async {
    final persistenceFailed = context.l10n.mcpPersistenceFailed;
    final persisted = await _persistedServer(api, profile, name);
    if (persisted == null) throw StateError(persistenceFailed);
    final expectedUrl = submitted['url']?.toString();
    final expectedCommand = submitted['command']?.toString();
    final expectedArgs = submitted['args'] as List? ?? const [];
    final expectedAuth = submitted['auth']?.toString();
    final env = submitted['env'] as Map? ?? const {};
    final persistedEnv = persisted['env'] as Map? ?? const {};
    final matches =
        (expectedUrl == null || persisted['url']?.toString() == expectedUrl) &&
        (expectedCommand == null ||
            persisted['command']?.toString() == expectedCommand) &&
        _sameJson(persisted['args'] as List? ?? const [], expectedArgs) &&
        (expectedAuth == null ||
            expectedAuth == 'none' ||
            persisted['auth']?.toString() == expectedAuth) &&
        env.keys.every(persistedEnv.containsKey);
    if (!matches) throw StateError(persistenceFailed);
  }

  Future<void> _verifyServerDeleted(
    ApiClient api,
    String? profile,
    String name,
  ) async {
    final persistenceFailed = context.l10n.mcpPersistenceFailed;
    if (await _persistedServer(api, profile, name) != null) {
      throw StateError(persistenceFailed);
    }
  }

  bool _sameJson(dynamic left, dynamic right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) ||
            !_sameJson(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_sameJson(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
  }

  Future<void> _verifyRawServer(
    ApiClient api,
    String? profile,
    String name,
    Map<String, dynamic> expected,
  ) async {
    final persistenceFailed = context.l10n.mcpPersistenceFailed;
    final config = await api.getConfig(profile: profile);
    _requireTarget(api, profile);
    final servers =
        (config['mcp_servers'] as Map?)?.cast<String, dynamic>() ?? const {};
    final persisted = (servers[name] as Map?)?.cast<String, dynamic>();
    if (persisted == null || !_sameJson(persisted, expected)) {
      throw StateError(persistenceFailed);
    }
  }

  Future<void> _verifyRawServers(
    ApiClient api,
    String? profile,
    Map<String, Map<String, dynamic>> expected,
  ) async {
    final persistenceFailed = context.l10n.mcpPersistenceFailed;
    final config = await api.getConfig(profile: profile);
    _requireTarget(api, profile);
    final persisted =
        (config['mcp_servers'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (!_sameJson(persisted, expected)) {
      throw StateError(persistenceFailed);
    }
  }

  Future<void> _load() async {
    final api = context.read<ConnectionStore>().api;
    if (api == null) {
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    final profile = _profile;
    final generation = ++_loadGeneration;
    try {
      final servers = await api.mcpServers(profile: profile);
      List<Map<String, dynamic>>? catalog;
      try {
        catalog = await api.mcpCatalog(profile: profile);
      } catch (_) {
        catalog = null;
      }
      if (_ownsTarget(api, profile) && generation == _loadGeneration) {
        final names = servers
            .map((server) => server['name'].toString())
            .toSet();
        setState(() {
          _probes.removeWhere((name, _) => !names.contains(name));
          _probeFingerprints.removeWhere((name, _) => !names.contains(name));
          for (final server in servers) {
            final name = server['name'].toString();
            final fingerprint = _serverFingerprint(server);
            if (_probeFingerprints[name] != fingerprint) {
              _probes.remove(name);
              _probeFingerprints.remove(name);
            }
          }
          _servers = servers;
          _catalog = catalog;
          _error = null;
        });
        for (final server in servers) {
          final name = server['name'].toString();
          if (server['enabled'] == true && !_probes.containsKey(name)) {
            unawaited(_probeSilently(server, api, profile, generation));
          }
        }
      }
    } catch (e) {
      if (_ownsTarget(api, profile) && generation == _loadGeneration) {
        setState(() => _error = '$e');
      }
    }
    // Cosmetic 30-day usage overlay — best-effort, never blocks the list.
    try {
      final usage = await api.toolCallCounts30d(profile: profile);
      if (_ownsTarget(api, profile) && generation == _loadGeneration) {
        setState(() => _usage30d = usage);
      }
    } catch (_) {
      // Analytics unavailable — the overlay simply omits usage.
    }
  }

  String _serverFingerprint(Map<String, dynamic> server) => jsonEncode({
    'transport': server['transport'],
    'url': server['url'],
    'command': server['command'],
    'args': server['args'],
    'env': server['env'],
    'auth': server['auth'],
    'enabled': server['enabled'],
    'tools': server['tools'],
  });

  Future<void> _probeSilently(
    Map<String, dynamic> server,
    ApiClient api,
    String? profile,
    int loadGeneration,
  ) async {
    final name = server['name'].toString();
    final fingerprint = _serverFingerprint(server);
    try {
      final result = await api.mcpTest(name, profile: profile);
      if (!_ownsTarget(api, profile) || loadGeneration != _loadGeneration) {
        return;
      }
      setState(() {
        _probes[name] = result;
        _probeFingerprints[name] = fingerprint;
      });
    } catch (error) {
      if (!_ownsTarget(api, profile) || loadGeneration != _loadGeneration) {
        return;
      }
      setState(() {
        _probes[name] = {'ok': false, 'error': '$error', 'tools': const []};
        _probeFingerprints[name] = fingerprint;
      });
    }
  }

  Future<void> _toggle(Map<String, dynamic> server, bool enabled) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final generation = _mutationGeneration;
    final name = (server['name'] ?? '').toString();
    setState(() => _busyName = name);
    try {
      await api.mcpSetEnabled(name, enabled, profile: profile);
      await _verifyServerEnabled(api, profile, name, enabled);
      if (generation != _mutationGeneration || !_ownsTarget(api, profile)) {
        return;
      }
      _requireTarget(api, profile);
      await _reloadLive(api, profile);
      await _load();
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.mcpOperationFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busyName = '');
      }
    }
  }

  Future<void> _test(Map<String, dynamic> server) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final generation = _mutationGeneration;
    final name = (server['name'] ?? '').toString();
    setState(() => _busyName = name);
    try {
      final result = await api.mcpTest(name, profile: profile);
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, profile)) {
        return;
      }
      setState(() => _probes[name] = result);
      _probeFingerprints[name] = _serverFingerprint(server);
      final ok = result['ok'] == true || result['reachable'] == true;
      final tools = result['tools'] as List? ?? const [];
      final prompts = (result['prompts'] as num?)?.toInt() ?? 0;
      final resources = (result['resources'] as num?)?.toInt() ?? 0;
      final error = result['error']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? context.l10n.mcpTestSuccess(tools.length, prompts, resources)
                : context.l10n.mcpTestConnectionFailed(
                    error?.isNotEmpty == true
                        ? error!
                        : context.l10n.commonUnknownError,
                  ),
          ),
          backgroundColor: ok ? HermesSemantic.green : HermesSemantic.red,
        ),
      );
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.mcpTestFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busyName = '');
      }
    }
  }

  /// Apply a persisted config to the currently connected live session when
  /// possible. REST writes are authoritative even when the optional Gateway
  /// WebSocket is offline (for example while the backend is restarting), so a
  /// reload failure must not turn a successful disk write into a false error.
  Future<bool> _reloadLive(ApiClient expectedApi, String? profile) async {
    final connection = context.read<ConnectionStore>();
    _requireTarget(expectedApi, profile);
    final gateway = connection.gateway;
    if (gateway == null || !gateway.isConnected) {
      return false;
    }
    final runtimeId = context.read<SessionStore>().runtimeId;
    try {
      await gateway.request('reload.mcp', {
        'confirm': true,
        'session_id': ?runtimeId,
      });
      _requireTarget(expectedApi, profile);
      return true;
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpReloadFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
      return false;
    }
  }

  Future<void> _batchImport(List<McpImportEntry> entries) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.mcpImportDetected(entries.length)),
        content: Text(
          context.l10n.mcpImportAllQuestion(
            entries.map((entry) => entry.name).join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.mcpAddAll),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _requireTarget(api, profile);
    setState(() => _busyName = entries.first.name);
    try {
      final config = await api.getConfig(profile: profile);
      _requireTarget(api, profile);
      final raw =
          (config['mcp_servers'] as Map?)?.cast<String, dynamic>() ?? const {};
      final next = <String, Map<String, dynamic>>{
        for (final item in raw.entries)
          item.key: (item.value as Map).cast<String, dynamic>(),
      };
      final imported = <String, Map<String, dynamic>>{};
      for (final entry in entries) {
        var name = entry.name;
        for (var suffix = 2; next.containsKey(name); suffix++) {
          name = '${entry.name}-$suffix';
        }
        final value = Map<String, dynamic>.from(entry.config);
        next[name] = value;
        imported[name] = value;
      }
      await api.mcpReplaceServers(next, profile: profile);
      for (final entry in imported.entries) {
        await _verifyRawServer(api, profile, entry.key, entry.value);
      }
      await _reloadLive(api, profile);
      await _load();
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.mcpServersAdded(imported.length),
        kind: HermesToastKind.success,
      );
    } catch (error) {
      if (mounted && _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.mcpAddFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
    }
  }

  Future<void> _createServer() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final result = await Navigator.of(context).push<McpServerDraftResult>(
      MaterialPageRoute(builder: (_) => const McpServerEditorScreen()),
    );
    final batch = result?.imports;
    if (batch != null) {
      if (mounted) await _batchImport(batch);
      return;
    }
    final payload = result?.payload;
    if (payload == null || !mounted) return;
    final serverName = payload['name'].toString();
    _requireTarget(api, profile);
    setState(() => _busyName = serverName);
    try {
      await api.mcpCreate(payload, profile: profile);
      await _verifyCreatedServer(api, profile, serverName, payload);
      _requireTarget(api, profile);
      await _reloadLive(api, profile);
      await _load();
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpServerAdded,
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpAddFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
    }
  }

  Future<void> _deleteServer(Map<String, dynamic> server) async {
    final name = (server['name'] ?? '').toString();
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.mcpDeleteQuestion(name)),
        content: Text(context.l10n.mcpDeleteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _requireTarget(api, profile);
    setState(() => _busyName = name);
    try {
      await api.mcpDelete(name, profile: profile);
      await _verifyServerDeleted(api, profile, name);
      _requireTarget(api, profile);
      await _reloadLive(api, profile);
      await _load();
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpDeleteFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
    }
  }

  /// In-place raw-JSON edit of one server's config. Reads from `getConfig()`
  /// (the unredacted `/api/config`, same source desktop's mcp.json editor
  /// uses) rather than `mcpServers()` (whose `env` values are masked for
  /// display — round-tripping those back through `mcpReplaceServers` would
  /// permanently overwrite the real secret with the redacted placeholder).
  Future<void> _editServerJson(Map<String, dynamic> server) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final name = (server['name'] ?? '').toString();
    setState(() => _busyName = name);
    Map<String, dynamic> rawServers;
    Map<String, dynamic> current;
    try {
      final config = await api.getConfig(profile: profile);
      _requireTarget(api, profile);
      rawServers =
          (config['mcp_servers'] as Map?)?.cast<String, dynamic>() ?? {};
      current = (rawServers[name] as Map?)?.cast<String, dynamic>() ?? {};
    } catch (e) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpReadConfigFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
      if (mounted) setState(() => _busyName = '');
      return;
    }
    if (!mounted) return;
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => McpConfigEditorScreen(
          title: context.l10n.mcpEditServer(name),
          initialValue: const JsonEncoder.withIndent('  ').convert(current),
        ),
      ),
    );
    if (edited == null || !mounted) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(edited);
    } on FormatException {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpInvalidJsonSyntax,
          kind: HermesToastKind.error,
        );
      }
      if (mounted) setState(() => _busyName = '');
      return;
    }
    if (decoded is! Map) {
      showHermesToast(
        context,
        message: context.l10n.mcpJsonObjectRequired,
        kind: HermesToastKind.error,
      );
      setState(() => _busyName = '');
      return;
    }
    final parsed = decoded.cast<String, dynamic>();
    try {
      _requireTarget(api, profile);
      final next = {...rawServers, name: parsed};
      await api.mcpReplaceServers(
        next.map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>())),
        profile: profile,
      );
      await _verifyRawServer(api, profile, name, parsed);
      _requireTarget(api, profile);
      await _reloadLive(api, profile);
      await _load();
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpServerSaved(name),
          kind: HermesToastKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpSaveFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
    }
  }

  Future<void> _editMcpDocument() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    setState(() => _busyName = 'mcp.json');
    Map<String, dynamic> current;
    try {
      final config = await api.getConfig(profile: profile);
      _requireTarget(api, profile);
      current =
          (config['mcp_servers'] as Map?)?.cast<String, dynamic>() ?? const {};
    } catch (error) {
      if (mounted && _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.mcpReadConfigFailed('$error'),
          kind: HermesToastKind.error,
        );
        setState(() => _busyName = '');
      }
      return;
    }
    if (!mounted) return;
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => McpConfigEditorScreen(
          title: 'mcp.json',
          initialValue: const JsonEncoder.withIndent(
            '  ',
          ).convert({'mcpServers': current}),
          documentEditor: true,
        ),
      ),
    );
    if (edited == null || !mounted) {
      if (mounted) setState(() => _busyName = '');
      return;
    }
    try {
      final decoded = jsonDecode(edited);
      if (decoded is! Map) throw const FormatException();
      final document = decoded.cast<String, dynamic>();
      final raw = document['mcpServers'] ?? document['mcp_servers'] ?? document;
      if (raw is! Map) throw const FormatException();
      final next = <String, Map<String, dynamic>>{};
      for (final entry in raw.entries) {
        if (entry.value is! Map) throw const FormatException();
        next[entry.key.toString()] = (entry.value as Map)
            .cast<String, dynamic>();
      }
      _requireTarget(api, profile);
      await api.mcpReplaceServers(next, profile: profile);
      await _verifyRawServers(api, profile, next);
      await _reloadLive(api, profile);
      await _load();
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpServerSaved('mcp.json'),
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted && _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: error is FormatException
              ? context.l10n.mcpInvalidJsonSyntax
              : context.l10n.mcpSaveFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
    }
  }

  /// Toggle one discovered tool's include/exclude gate for a server, ported
  /// from desktop's `toggleToolInServer` (lib/mcp-tool-filter.ts). Reads the
  /// unredacted config the same way `_editServerJson` does, so a toggle can
  /// never clobber another field's real secret with a redacted placeholder.
  Future<void> _toggleTool(String serverName, String toolName) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    setState(() => _busyName = serverName);
    try {
      final config = await api.getConfig(profile: profile);
      _requireTarget(api, profile);
      final rawServers =
          (config['mcp_servers'] as Map?)?.cast<String, dynamic>() ?? {};
      final current =
          (rawServers[serverName] as Map?)?.cast<String, dynamic>() ?? {};
      final updated = toggleToolInServer(current, toolName);
      final next = {...rawServers, serverName: updated};
      await api.mcpReplaceServers(
        next.map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>())),
        profile: profile,
      );
      await _verifyRawServer(api, profile, serverName, updated);
      _requireTarget(api, profile);
      await _reloadLive(api, profile);
      await _load();
    } catch (e) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpToolToggleFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
    }
  }

  void _viewLogs({String? serverName}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => McpLogsScreen(serverName: serverName)),
    );
  }

  Future<void> _cancelAuthentication() async {
    final flowId = _oauthFlowId;
    final api = _oauthApi;
    if (flowId == null || api == null) return;
    setState(() => _oauthCancelled = true);
    try {
      await api.mcpCancelAuthFlow(flowId, profile: _oauthProfile);
    } catch (_) {
      // Best effort. The backend also expires abandoned flows automatically.
    }
  }

  Future<void> _abandonOAuth(
    ApiClient api,
    String flowId,
    String? profile,
  ) async {
    try {
      await api.mcpCancelAuthFlow(flowId, profile: profile);
    } catch (_) {
      // Best effort during navigation/profile teardown.
    }
  }

  Future<void> _authenticate(Map<String, dynamic> server) async {
    final name = (server['name'] ?? '').toString();
    final l10n = context.l10n;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final generation = _mutationGeneration;
    setState(() {
      _busyName = name;
      _oauthCancelled = false;
      _oauthApi = api;
      _oauthProfile = profile;
    });
    try {
      final started = await api.mcpStartAuth(name, profile: profile);
      _requireTarget(api, profile);
      if (started['status'] == 'error') {
        throw StateError(
          (started['error'] ?? l10n.mcpOAuthStartFailed).toString(),
        );
      }
      final flowId = (started['flow_id'] ?? '').toString();
      final authorizationUrl = (started['authorization_url'] ?? '').toString();
      if (flowId.isEmpty || authorizationUrl.isEmpty) {
        throw StateError(l10n.mcpOAuthMissingUrl);
      }
      setState(() => _oauthFlowId = flowId);
      final opened = await launchUrl(
        Uri.parse(authorizationUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError(l10n.mcpBrowserOpenFailed);
      _requireTarget(api, profile);
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpCompleteAuthorization(name),
        );
      }

      var failures = 0;
      Map<String, dynamic>? approved;
      while (mounted) {
        if (_oauthCancelled || generation != _mutationGeneration) return;
        Map<String, dynamic> current;
        try {
          current = await api.mcpAuthFlow(flowId, profile: profile);
          _requireTarget(api, profile);
          failures = 0;
        } catch (error) {
          if (_oauthCancelled ||
              generation != _mutationGeneration ||
              !_ownsTarget(api, profile)) {
            return;
          }
          failures++;
          if (failures >= 3) rethrow;
          await Future<void>.delayed(const Duration(seconds: 1));
          if (_oauthCancelled ||
              generation != _mutationGeneration ||
              !_ownsTarget(api, profile)) {
            return;
          }
          continue;
        }
        final status = current['status']?.toString();
        if (status == 'approved') {
          approved = current;
          break;
        }
        if (status == 'error') {
          throw StateError(
            (current['error'] ?? l10n.mcpOAuthAuthorizationFailed).toString(),
          );
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        if (_oauthCancelled ||
            generation != _mutationGeneration ||
            !_ownsTarget(api, profile)) {
          return;
        }
      }
      if (!_ownsTarget(api, profile) || approved == null) return;
      await _verifyCreatedServer(api, profile, name, const {'auth': 'oauth'});
      await _reloadLive(api, profile);
      await _load();
      final tools = approved['tools'] as List? ?? const [];
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpAuthorizationSucceeded(name, tools.length),
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted &&
          !_oauthCancelled &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.mcpOAuthFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() {
          _busyName = '';
          _oauthFlowId = null;
          _oauthApi = null;
          _oauthProfile = null;
          _oauthCancelled = false;
        });
      }
    }
  }

  Future<void> _installCatalog(Map<String, dynamic> entry) async {
    final name = (entry['name'] ?? '').toString();
    final specs = (entry['required_env'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .toList();
    final controllers = {
      for (final spec in specs)
        spec['name'].toString(): TextEditingController(),
    };
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      return;
    }
    final profile = _profile;
    final env = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.mcpInstallTitle(name)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((entry['description'] ?? '').toString()),
              const SizedBox(height: HermesSpacing.sm),
              Text(
                (entry['url'] ?? entry['command'] ?? '').toString(),
                style: HermesType.code,
              ),
              for (final spec in specs) ...[
                const SizedBox(height: HermesSpacing.sm),
                TextField(
                  controller: controllers[spec['name'].toString()],
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: (spec['prompt'] ?? spec['name']).toString(),
                    suffixText: spec['required'] == true
                        ? context.l10n.mcpRequired
                        : context.l10n.mcpOptional,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final values = {
                for (final item in controllers.entries)
                  item.key: item.value.text.trim(),
              };
              final missing = specs.any(
                (spec) =>
                    spec['required'] == true &&
                    (values[spec['name'].toString()] ?? '').isEmpty,
              );
              if (missing) {
                showHermesToast(
                  ctx,
                  message: ctx.l10n.mcpRequiredCredentials,
                  kind: HermesToastKind.error,
                );
                return;
              }
              Navigator.of(ctx).pop(values);
            },
            child: Text(
              entry['installed'] == true
                  ? context.l10n.mcpReinstall
                  : context.l10n.mcpInstall,
            ),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    });
    if (env == null || !mounted) return;
    final l10n = context.l10n;
    _requireTarget(api, profile);
    setState(() => _busyName = name);
    try {
      final result = await api.mcpInstallCatalog(
        name,
        env: env,
        profile: profile,
      );
      final action = result['action']?.toString();
      if (result['background'] == true && action?.isNotEmpty == true) {
        while (mounted) {
          final status = await api.actionStatus(
            action!,
            lines: 50,
            profile: profile,
          );
          _requireTarget(api, profile);
          if (status['running'] != true) {
            final exitCode = (status['exit_code'] as num?)?.toInt();
            if (exitCode != null && exitCode != 0) {
              throw StateError(l10n.mcpInstallExitCode(exitCode));
            }
            break;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      _requireTarget(api, profile);
      await _verifyServerExists(
        api,
        profile,
        result['name']?.toString().isNotEmpty == true
            ? result['name'].toString()
            : name,
      );
      await _reloadLive(api, profile);
      await _load();
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpInstallComplete(name),
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpInstallFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mcpTitle),
        actions: [
          if (_oauthFlowId != null)
            IconButton(
              tooltip: context.l10n.commonCancel,
              onPressed: _oauthCancelled ? null : _cancelAuthentication,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          IconButton(
            tooltip: context.l10n.mcpEditConfiguration,
            onPressed: _busyName.isEmpty ? _editMcpDocument : null,
            icon: const Icon(Icons.data_object),
          ),
          IconButton(
            tooltip: context.l10n.mcpViewLogs,
            onPressed: () => _viewLogs(),
            icon: const Icon(Icons.article_outlined),
          ),
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _busyName.isNotEmpty ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: context.l10n.mcpAddServer,
            onPressed: _busyName.isEmpty ? _createServer : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          const ProfileScopeDropdown(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_servers == null && _error == null) {
      return HermesLoadingState(label: context.l10n.mcpLoading);
    }
    if (_error != null && _servers == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    if (_servers == null) {
      return HermesEmptyState(
        icon: Icons.extension_off_outlined,
        title: context.l10n.agentNoData,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(HermesSpacing.md),
        children: [
          HermesSectionHeader(title: context.l10n.mcpConfiguredServers),
          if (_servers!.isEmpty)
            HermesEmptyState(
              icon: Icons.hub_outlined,
              title: context.l10n.mcpNoConfiguredServers,
              description: context.l10n.mcpDescription,
            )
          else
            for (final s in _servers!) _serverRow(context, s),
          if (_catalog != null && _catalog!.isNotEmpty) ...[
            const SizedBox(height: HermesSpacing.lg),
            HermesSectionHeader(
              title: context.l10n.mcpAvailableCatalog(_catalog!.length),
            ),
            HermesMobileGroup(
              children: [for (final c in _catalog!) _catalogRow(context, c)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _serverRow(BuildContext context, Map<String, dynamic> server) {
    final name = (server['name'] ?? '').toString();
    final enabled = server['enabled'] == true;
    final desc = (server['description'] ?? '').toString();
    final transport = (server['transport'] ?? '').toString();
    final canAuthenticate =
        transport == 'http' && server['auth']?.toString() != 'header';
    final probe = _probes[name];
    final probeOk = probe?['ok'] == true || probe?['reachable'] == true;
    final needsAuth = RegExp(
      r'auth|oauth|unauthorized|401|403|token',
      caseSensitive: false,
    ).hasMatch(probe?['error']?.toString() ?? '');
    final statusColor = !enabled
        ? HermesSemantic.gray
        : probe == null
        ? HermesSemantic.gray
        : probeOk
        ? HermesSemantic.green
        : needsAuth
        ? HermesSemantic.orange
        : HermesSemantic.red;
    final probedTools = probe != null && probe['ok'] == true
        ? ((probe['tools'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
        : const <Map<String, dynamic>>[];
    final subtitleParts = <String>[
      if (transport.isNotEmpty) transport,
      if (probedTools.isNotEmpty)
        context.l10n.mcpToolCount(
          countEnabledTools(
            server,
            probedTools.map((tool) => tool['name'].toString()).toList(),
          ),
        ),
    ];
    final tokenEstimate = probedTools.isEmpty
        ? null
        : estimateServerTokens(server, probedTools);
    if (tokenEstimate != null && tokenEstimate > 0) {
      subtitleParts.add('~${_compactNumber(tokenEstimate)} tok');
    }
    final usage = _usage30d;
    if (usage != null) {
      subtitleParts.add(
        context.l10n.mcpUsage30Days(serverUsageCount(name, usage)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: HermesGlassCard(
        radius: HermesRadius.card,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.hub_outlined, color: statusColor),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                subtitleParts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busyName != name)
                    IconButton(
                      tooltip: context.l10n.mcpTestConnection,
                      icon: const Icon(Icons.wifi_tethering, size: 20),
                      onPressed: () => _test(server),
                    ),
                  HermesAdaptiveMenuButton<String>(
                    enabled: _busyName.isEmpty,
                    onSelected: (value) {
                      if (value == 'delete') _deleteServer(server);
                      if (value == 'auth') _authenticate(server);
                      if (value == 'edit') _editServerJson(server);
                      if (value == 'logs') _viewLogs(serverName: name);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(context.l10n.mcpEditConfiguration),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logs',
                        child: ListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: Text(context.l10n.mcpViewLogs),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (canAuthenticate)
                        PopupMenuItem(
                          value: 'auth',
                          child: ListTile(
                            leading: const Icon(Icons.key_outlined),
                            title: Text(context.l10n.mcpOAuthAuthorization),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(context.l10n.commonDelete),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: enabled,
                    onChanged: _busyName.isEmpty
                        ? (v) => _toggle(server, v)
                        : null,
                  ),
                ],
              ),
              onTap: desc.isEmpty
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(name),
                        content: Text(desc),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(context.l10n.commonClose),
                          ),
                        ],
                      ),
                    ),
            ),
            if (probedTools.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tool in probedTools)
                      _toolChip(context, name, server, tool['name'].toString()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolChip(
    BuildContext context,
    String serverName,
    Map<String, dynamic> server,
    String toolName,
  ) {
    final on = isToolEnabled(server, toolName);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: _busyName.isEmpty ? () => _toggleTool(serverName, toolName) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: HermesPalette.of(context).codeBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          toolName,
          style: HermesType.code.copyWith(
            fontSize: 11,
            color: on
                ? HermesPalette.of(context).text2
                : HermesPalette.of(context).text4,
            decoration: on ? null : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }

  static String _compactNumber(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  Widget _catalogRow(BuildContext context, Map<String, dynamic> entry) {
    final name = (entry['name'] ?? '').toString();
    final desc = (entry['description'] ?? '').toString();
    final transport = (entry['transport'] ?? '').toString();
    final installed = entry['installed'] == true;
    final enabled = entry['enabled'] == true;
    final busy = _busyName == name;
    return HermesMobileRow(
      icon: transport == 'stdio' ? Icons.terminal_outlined : Icons.dns_outlined,
      title: name,
      subtitle: [
        desc,
        if (installed)
          enabled
              ? context.l10n.mcpInstalledEnabled
              : context.l10n.mcpInstalledDisabled,
      ].where((value) => value.isNotEmpty).join(' · '),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonal(
              onPressed: _busyName.isEmpty
                  ? () => _installCatalog(entry)
                  : null,
              child: Text(
                installed ? context.l10n.mcpReinstall : context.l10n.mcpInstall,
              ),
            ),
    );
  }
}
