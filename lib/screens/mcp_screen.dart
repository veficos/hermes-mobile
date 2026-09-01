/// MCP (spec §101–104): server list + enabled toggle + test + catalog,
/// backed by `/api/v1/mcp/*`.
library;

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
import '../widgets/profile_scope_selector.dart';
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
  final Map<String, Map<String, dynamic>> _probes = {};
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
    ++_loadGeneration;
    ++_mutationGeneration;
    setState(() {
      _servers = null;
      _catalog = null;
      _usage30d = const {};
      _probes.clear();
      _busyName = '';
      _error = null;
    });
    _load();
  }

  String? get _profile => _scopeStore?.override;

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
        setState(() {
          _servers = servers;
          _catalog = catalog;
          _error = null;
        });
      }
    } catch (e) {
      if (_ownsTarget(api, profile) && generation == _loadGeneration) {
        setState(() => _error = '$e');
      }
    }
    // Cosmetic 30-day usage overlay — best-effort, never blocks the list.
    try {
      final usage = await api.toolCallCounts30d();
      if (_ownsTarget(api, profile) && generation == _loadGeneration) {
        setState(() => _usage30d = usage);
      }
    } catch (_) {
      // Analytics unavailable — the overlay simply omits usage.
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

  Future<void> _reloadLive(ApiClient expectedApi, String? profile) async {
    final connection = context.read<ConnectionStore>();
    _requireTarget(expectedApi, profile);
    final gateway = connection.gateway;
    if (gateway == null || !gateway.isConnected) {
      throw StateError(context.l10n.backendDisconnected);
    }
    final runtimeId = context.read<SessionStore>().runtimeId;
    try {
      await gateway.request('reload.mcp', {
        'confirm': true,
        'session_id': ?runtimeId,
      });
      _requireTarget(expectedApi, profile);
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpReloadFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
      rethrow;
    }
  }

  /// Desktop parity: `lib/mcp-import.ts` — turn a pasted mcp.json snippet, a
  /// bare `npx`/`docker`/`uvx` command, a `claude mcp add` line, or a plain
  /// URL into filled-in fields, instead of making the user hand-transcribe
  /// every field from whatever a README told them to copy. A snippet
  /// describing several servers at once bypasses the single-server form
  /// entirely and is added directly (`_batchImport`).
  List<McpImportEntry>? _applyImport(
    String text,
    void Function(void Function()) setDialogState, {
    required TextEditingController name,
    required TextEditingController endpoint,
    required TextEditingController args,
    required TextEditingController env,
    required void Function(String) setTransport,
  }) {
    final entries = parseMcpImport(text);
    if (entries == null || entries.isEmpty) {
      showHermesToast(
        context,
        message: context.l10n.mcpImportUnrecognized,
        kind: HermesToastKind.error,
      );
      return null;
    }
    if (entries.length > 1) return entries;
    final entry = entries.single;
    setDialogState(() {
      name.text = entry.name;
      final url = entry.config['url'];
      if (url is String) {
        setTransport('url');
        endpoint.text = url;
      } else {
        setTransport('stdio');
        endpoint.text = entry.config['command']?.toString() ?? '';
        final rawArgs = entry.config['args'];
        args.text = rawArgs is List ? rawArgs.join('\n') : '';
        final rawEnv = entry.config['env'];
        env.text = rawEnv is Map
            ? const JsonEncoder.withIndent('  ').convert(rawEnv)
            : '{}';
      }
    });
    return null;
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
    var failures = 0;
    for (final entry in entries) {
      try {
        await api.mcpCreate({
          'name': entry.name,
          ...entry.config,
        }, profile: profile);
      } catch (_) {
        failures++;
      }
    }
    _requireTarget(api, profile);
    await _reloadLive(api, profile);
    await _load();
    if (!mounted) return;
    showHermesToast(
      context,
      message: failures == 0
          ? context.l10n.mcpServersAdded(entries.length)
          : context.l10n.mcpServersPartiallyAdded(
              entries.length - failures,
              failures,
            ),
    );
  }

  Future<void> _createServer() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final name = TextEditingController();
    final endpoint = TextEditingController();
    final args = TextEditingController();
    final env = TextEditingController(text: '{}');
    final bearer = TextEditingController();
    final importCtrl = TextEditingController();
    var transport = 'url';
    var auth = 'none';
    List<McpImportEntry>? batch;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.l10n.mcpAddServer),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: importCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.l10n.mcpPasteImport,
                    suffixIcon: IconButton(
                      tooltip: context.l10n.mcpParse,
                      icon: const Icon(Icons.auto_fix_high),
                      onPressed: () {
                        final result = _applyImport(
                          importCtrl.text,
                          setDialogState,
                          name: name,
                          endpoint: endpoint,
                          args: args,
                          env: env,
                          setTransport: (v) => transport = v,
                        );
                        if (result != null) {
                          batch = result;
                          Navigator.of(ctx).pop();
                        }
                      },
                    ),
                  ),
                ),
                const Divider(height: HermesSpacing.lg),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.commonName,
                  ),
                ),
                const SizedBox(height: HermesSpacing.sm),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'url',
                      label: Text(context.l10n.mcpRemoteUrl),
                    ),
                    ButtonSegment(
                      value: 'stdio',
                      label: Text(context.l10n.mcpLocalStdio),
                    ),
                  ],
                  selected: {transport},
                  onSelectionChanged: (value) =>
                      setDialogState(() => transport = value.first),
                ),
                const SizedBox(height: HermesSpacing.sm),
                TextField(
                  controller: endpoint,
                  decoration: InputDecoration(
                    labelText: transport == 'url'
                        ? context.l10n.mcpServerUrl
                        : context.l10n.mcpCommand,
                  ),
                ),
                if (transport == 'stdio') ...[
                  const SizedBox(height: HermesSpacing.sm),
                  TextField(
                    controller: args,
                    decoration: InputDecoration(
                      labelText: context.l10n.mcpArgumentsOnePerLine,
                    ),
                    minLines: 2,
                    maxLines: 5,
                  ),
                  const SizedBox(height: HermesSpacing.sm),
                  TextField(
                    controller: env,
                    decoration: InputDecoration(
                      labelText: context.l10n.mcpEnvironmentJson,
                      hintText: const JsonEncoder().convert({'API_KEY': '...'}),
                    ),
                    minLines: 2,
                    maxLines: 5,
                  ),
                ] else ...[
                  const SizedBox(height: HermesSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: auth,
                    decoration: InputDecoration(
                      labelText: context.l10n.mcpAuthentication,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(context.l10n.mcpNoAuthentication),
                      ),
                      DropdownMenuItem(
                        value: 'oauth',
                        child: Text(context.l10n.mcpAuthOauth),
                      ),
                      DropdownMenuItem(
                        value: 'header',
                        child: Text(context.l10n.mcpAuthBearerToken),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => auth = value ?? 'none'),
                  ),
                  if (auth == 'header') ...[
                    const SizedBox(height: HermesSpacing.sm),
                    TextField(
                      controller: bearer,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.mcpAuthBearerToken,
                      ),
                    ),
                  ],
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
                final serverName = name.text.trim();
                final target = endpoint.text.trim();
                if (serverName.isEmpty || target.isEmpty) return;
                Map<String, dynamic> envMap = const {};
                if (transport == 'stdio') {
                  try {
                    final decoded = jsonDecode(env.text) as Map;
                    envMap = {
                      for (final item in decoded.entries)
                        item.key.toString(): item.value.toString(),
                    };
                  } catch (_) {
                    showHermesToast(
                      ctx,
                      message: ctx.l10n.mcpEnvironmentMustBeJson,
                      kind: HermesToastKind.error,
                    );
                    return;
                  }
                }
                Navigator.of(ctx).pop({
                  'name': serverName,
                  if (transport == 'url') 'url': target else 'command': target,
                  if (transport == 'stdio')
                    'args': args.text
                        .split('\n')
                        .map((value) => value.trim())
                        .where((value) => value.isNotEmpty)
                        .toList(),
                  if (transport == 'stdio') 'env': envMap,
                  if (transport == 'url' && auth != 'none') 'auth': auth,
                  if (auth == 'header') 'bearer_token': bearer.text,
                });
              },
              child: Text(context.l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      endpoint.dispose();
      args.dispose();
      env.dispose();
      bearer.dispose();
      importCtrl.dispose();
    });
    if (batch != null) {
      if (mounted) await _batchImport(batch!);
      return;
    }
    if (payload == null || !mounted) return;
    final serverName = payload['name'].toString();
    _requireTarget(api, profile);
    setState(() => _busyName = serverName);
    try {
      await api.mcpCreate(payload, profile: profile);
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
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(current),
    );
    final edited = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.mcpEditServer(name)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 16,
            minLines: 8,
            style: HermesType.code,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
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

  Future<void> _authenticate(Map<String, dynamic> server) async {
    final name = (server['name'] ?? '').toString();
    final l10n = context.l10n;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    setState(() => _busyName = name);
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
        Map<String, dynamic> current;
        try {
          current = await api.mcpAuthFlow(flowId, profile: profile);
          _requireTarget(api, profile);
          failures = 0;
        } catch (error) {
          failures++;
          if (failures >= 3) rethrow;
          await Future<void>.delayed(const Duration(seconds: 1));
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
      }
      if (!_ownsTarget(api, profile) || approved == null) return;
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
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.mcpOAuthFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
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
          final status = await api.actionStatus(action!, lines: 50);
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
              leading: Icon(
                Icons.hub_outlined,
                color: enabled ? HermesSemantic.green : HermesSemantic.gray,
              ),
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
                  PopupMenuButton<String>(
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
