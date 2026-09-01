import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/stores/connection_store.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/profile_scope_store.dart';
import '../core/models.dart';
import '../l10n/l10n.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/profile_scope_selector.dart';

/// Toolsets, mirroring the desktop's Capabilities page (toolsets tab).
/// Skill management lives in its own dedicated `SkillsScreen` — this screen
/// used to duplicate it behind a second tab with a bare-bones, English-only
/// list; that tab is gone so "工具集" and "技能" stay two distinct, single
/// places to manage each concept (prototype `pageTools()` parity).
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with ConnectionReloadMixin<ToolsScreen> {
  List<ToolsetInfo>? _toolsets;
  Map<String, dynamic>? _computerUse;
  Map<String, dynamic>? _terminalBackends;
  bool _grantingComputerUse = false;
  String? _selectingTerminalBackend;
  String? _error;
  ProfileScopeStore? _scopeStore;
  ApiClient? _loadedApi;
  String? _loadedProfile;
  // Desktop parity with this codebase's own `provider_config_screen.dart`
  // `_loadGeneration` pattern: without it, a fast profile-scope switch or a
  // double refresh-button tap races two `_load()` calls, and an older
  // request finishing after a newer one silently overwrites fresh data
  // with stale toolset/backend info.
  int _loadGeneration = 0;
  int _mutationGeneration = 0;

  String? get _profile => _scopeStore?.override;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForTarget);
    final scope = context.read<ProfileScopeStore>();
    if (identical(scope, _scopeStore)) return;
    _scopeStore?.removeListener(_onScopeChanged);
    _scopeStore = scope..addListener(_onScopeChanged);
    scope.ensureLoaded();
  }

  void _onScopeChanged() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _toolsets = null;
      _computerUse = null;
      _terminalBackends = null;
      _loadedApi = null;
      _loadedProfile = null;
      _grantingComputerUse = false;
      _selectingTerminalBackend = null;
      _error = null;
    });
    _load();
  }

  void _reloadForTarget() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _toolsets = null;
      _computerUse = null;
      _terminalBackends = null;
      _loadedApi = null;
      _loadedProfile = null;
      _grantingComputerUse = false;
      _selectingTerminalBackend = null;
      _error = null;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _scopeStore?.removeListener(_onScopeChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final profile = _profile;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) {
        setState(() {
          _toolsets = null;
          _computerUse = null;
          _terminalBackends = null;
          _loadedApi = null;
          _loadedProfile = null;
          _error = connectionOfflineErrorCode;
        });
      }
      return;
    }
    try {
      final toolsets = await api.toolsets(profile: profile);
      Map<String, dynamic>? computerUse;
      if (toolsets.any(_isComputerUse)) {
        try {
          computerUse = await api.computerUseStatus(profile: profile);
        } catch (_) {
          // Older backends still expose the toolset but not its preflight API.
        }
      }
      // Not gated on a toolset row existing — the terminal tool itself is
      // always available; this just picks where it executes. Older
      // backends that never registered this endpoint fail silently and the
      // panel simply doesn't render.
      Map<String, dynamic>? terminalBackends;
      try {
        terminalBackends = await api.terminalBackends(profile: profile);
      } catch (_) {
        // No backend picker on this server — fine.
      }
      if (!mounted ||
          generation != _loadGeneration ||
          !_ownsTarget(api, profile)) {
        return;
      }
      setState(() {
        _toolsets = toolsets;
        _computerUse = computerUse;
        _terminalBackends = terminalBackends;
        _loadedApi = api;
        _loadedProfile = profile;
        _error = null;
      });
    } catch (e) {
      if (!mounted ||
          generation != _loadGeneration ||
          !_ownsTarget(api, profile)) {
        return;
      }
      setState(() => _error = '$e');
    }
  }

  bool _ownsTarget(ApiClient api, String? profile) =>
      identical(context.read<ConnectionStore>().api, api) &&
      profile == _profile;

  bool _ownsLoadedTarget() {
    final api = _loadedApi;
    return api != null &&
        identical(context.read<ConnectionStore>().api, api) &&
        _loadedProfile == _profile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.toolsTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const ProfileScopeDropdown(),
          Expanded(
            child: _error != null
                ? _errorView(context)
                : _toolsetsView(context),
          ),
        ],
      ),
    );
  }

  Widget _toolsetsView(BuildContext context) {
    final toolsets = _toolsets;
    if (toolsets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (toolsets.isEmpty) {
      return Center(child: Text(context.l10n.toolsEmpty));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        if (_terminalBackends != null) ...[
          _terminalBackendPanel(context, _terminalBackends!),
          const SizedBox(height: 14),
        ],
        HermesMobileGroup(
          children: [
            for (final t in toolsets)
              Column(
                children: [
                  HermesMobileRow(
                    icon: _isComputerUse(t)
                        ? Icons.desktop_windows_outlined
                        : Icons.build_outlined,
                    title: t.name,
                    subtitle: context.l10n.toolsToolsetSummary(
                      t.toolCount,
                      t.enabled
                          ? context.l10n.webhookEnabledLabel
                          : context.l10n.webhookDisabledLabel,
                    ),
                    trailing: Switch(
                      value: t.enabled,
                      onChanged: (v) => _toggleToolset(t, v),
                    ),
                  ),
                  if (_isComputerUse(t) && _computerUse != null)
                    _computerUsePanel(context, _computerUse!),
                ],
              ),
          ],
        ),
      ],
    );
  }

  bool _isComputerUse(ToolsetInfo toolset) =>
      toolset.name.toLowerCase().replaceAll('-', '_') == 'computer_use';

  /// Desktop parity: `terminal-backend-panel.tsx` — where the terminal tool
  /// actually runs (local shell, Docker, an SSH host, Modal/Daytona sandbox),
  /// each row showing a live readiness probe instead of a bare enum picker.
  Widget _terminalBackendPanel(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final active = data['active']?.toString();
    final backends = (data['backends'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    if (backends.isEmpty) return const SizedBox.shrink();
    return HermesMobileGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.toolsTerminalBackend,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonRefresh,
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
        ),
        RadioGroup<String>(
          groupValue: active,
          onChanged: (value) {
            if (_selectingTerminalBackend != null || value == null) return;
            _selectTerminalBackend(value);
          },
          child: Column(
            children: [
              for (final backend in backends)
                _terminalBackendRow(context, backend, active),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _terminalBackendRow(
    BuildContext context,
    Map<String, dynamic> backend,
    String? active,
  ) {
    final name = backend['name']?.toString() ?? '';
    final label = backend['label']?.toString() ?? name;
    final description = backend['description']?.toString() ?? '';
    final status = backend['status']?.toString() ?? '';
    final detail = backend['detail']?.toString() ?? '';
    final isActive = name == active;
    final ready = status == 'ready';
    final color = ready
        ? Colors.green
        : status == 'needs_setup'
        ? Colors.orange
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final statusLabel = ready
        ? context.l10n.toolsReady
        : status == 'needs_setup'
        ? context.l10n.toolsNeedsSetup
        : context.l10n.toolsUnavailable;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Radio<String>(value: name),
        title: Row(
          children: [
            Expanded(child: Text(label)),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle, size: 16, color: Colors.green),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty) Text(description),
            Row(
              children: [
                Icon(
                  ready ? Icons.check_circle_outline : Icons.warning_amber,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(statusLabel, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
            if (!ready && detail.isNotEmpty)
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: _selectingTerminalBackend == name
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: _selectingTerminalBackend != null
            ? null
            : () => _selectTerminalBackend(name),
      ),
    );
  }

  Future<void> _selectTerminalBackend(String backend) async {
    final api = _loadedApi;
    final profile = _loadedProfile;
    if (api == null || !_ownsLoadedTarget()) {
      showHermesToast(
        context,
        message: context.l10n.backendDisconnected,
        kind: HermesToastKind.error,
      );
      return;
    }
    final generation = _mutationGeneration;
    setState(() => _selectingTerminalBackend = backend);
    try {
      await api.selectTerminalBackend(backend, profile: profile);
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        await _load();
      }
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.toolsBackendSwitchFailed('$e'))),
        );
      }
    } finally {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile) &&
          _selectingTerminalBackend == backend) {
        setState(() => _selectingTerminalBackend = null);
      }
    }
  }

  Widget _computerUsePanel(BuildContext context, Map<String, dynamic> status) {
    final supported = status['platform_supported'] == true;
    final installed = status['installed'] == true;
    final ready = status['ready'] == true;
    final canGrant = status['can_grant'] == true;
    final checks = (status['checks'] as List? ?? const []).whereType<Map>();
    final color = ready
        ? Colors.green
        : installed
        ? Colors.orange
        : Theme.of(context).colorScheme.error;
    final label = !supported
        ? context.l10n.toolsComputerUseUnsupported
        : !installed
        ? context.l10n.toolsComputerUseNotInstalled
        : ready
        ? context.l10n.toolsComputerUseReady
        : context.l10n.toolsComputerUseNotReady;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle_outline : Icons.warning_amber,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(label)),
              IconButton(
                tooltip: context.l10n.toolsRecheck,
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if ((status['version'] ?? '').toString().isNotEmpty)
            Text(
              status['version'].toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          for (final check in checks.where((row) => row['status'] != 'ok'))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.l10n.toolsCheckResult(
                  (check['label'] ?? context.l10n.toolsCheck).toString(),
                  (check['message'] ?? check['status']).toString(),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (canGrant && !ready) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _grantingComputerUse ? null : _grantComputerUse,
              icon: _grantingComputerUse
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new, size: 16),
              label: Text(
                _grantingComputerUse
                    ? context.l10n.toolsWaitingForPermission
                    : context.l10n.toolsRequestPermission,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _grantComputerUse() async {
    final api = _loadedApi;
    final profile = _loadedProfile;
    if (api == null || !_ownsLoadedTarget()) {
      showHermesToast(
        context,
        message: context.l10n.backendDisconnected,
        kind: HermesToastKind.error,
      );
      return;
    }
    final generation = _mutationGeneration;
    setState(() => _grantingComputerUse = true);
    try {
      final started = await api.grantComputerUsePermissions(profile: profile);
      final action = started['name']?.toString() ?? 'computer-use-grant';
      var completed = false;
      for (var attempt = 0; attempt < 150 && mounted; attempt++) {
        if (generation != _mutationGeneration || !_ownsTarget(api, profile)) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (generation != _mutationGeneration || !_ownsTarget(api, profile)) {
          return;
        }
        final state = await api.actionStatus(action);
        if (state['running'] != true) {
          completed = true;
          break;
        }
      }
      if (!completed && mounted) throw TimeoutException('computer-use grant');
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        await _load();
      }
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is TimeoutException
                  ? context.l10n.toolsPermissionTimeout
                  : context.l10n.toolsPermissionFailed('$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        setState(() => _grantingComputerUse = false);
      }
    }
  }

  Widget _errorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _error == connectionOfflineErrorCode
                ? context.l10n.backendDisconnected
                : _error!,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }

  Future<void> _toggleToolset(ToolsetInfo t, bool enabled) async {
    final api = _loadedApi;
    final profile = _loadedProfile;
    if (api == null || !_ownsLoadedTarget()) {
      showHermesToast(
        context,
        message: context.l10n.backendDisconnected,
        kind: HermesToastKind.error,
      );
      return;
    }
    final generation = _mutationGeneration;
    try {
      await api.toggleToolset(t.name, enabled, profile: profile);
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        _load();
      }
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.toolsToggleFailed('$e'))),
        );
      }
    }
  }
}
