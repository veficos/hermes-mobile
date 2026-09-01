/// Plugins (spec §105–106): backend plugin list (`plugins.manage` RPC) with
/// search + enabled toggle, backed by `/api/v1/plugins`.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/connection_store.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../core/connections/connection_registry.dart';
import '../theme/hermes_tokens.dart';
import '../l10n/l10n.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/plugin_contribution_surface.dart' show pluginToneColor;
import '../widgets/profile_scope_selector.dart';

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({super.key});

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen>
    with ConnectionReloadMixin<PluginsScreen> {
  List<Map<String, dynamic>>? _plugins;
  String? _error;
  String _query = '';
  String _busyName = '';
  ProfileScopeStore? _scopeStore;
  int _loadGeneration = 0;

  String? get _profile => _scopeStore?.override;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
    final scope = context.read<ProfileScopeStore>();
    if (identical(scope, _scopeStore)) return;
    _scopeStore?.removeListener(_onScopeChanged);
    _scopeStore = scope..addListener(_onScopeChanged);
    scope.ensureLoaded();
  }

  void _reloadForConnection() {
    if (!mounted) return;
    setState(() {
      _plugins = null;
      _error = null;
      _busyName = '';
    });
    _load();
  }

  void _onScopeChanged() {
    if (!mounted) return;
    setState(() {
      _plugins = null;
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
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    try {
      final plugins = await connection.listPlugins(profile: _profile);
      if (mounted &&
          generation == _loadGeneration &&
          profile == _profile &&
          identical(api, connection.api)) {
        context.read<PluginContributionStore>().adaptPluginInventory(
          plugins,
          owner: OwnerRoute(
            connectionId: connection.activeConnectionId,
            profile: _profile,
          ),
        );
        setState(() {
          _plugins = plugins;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          profile == _profile &&
          identical(api, connection.api)) {
        setState(() => _error = '$e');
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    final plugins = _plugins ?? [];
    if (q.isEmpty) return plugins;
    return plugins.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final key = (p['key'] ?? '').toString().toLowerCase();
      return name.contains(q) || desc.contains(q) || key.contains(q);
    }).toList();
  }

  Future<void> _toggle(Map<String, dynamic> plugin, bool enabled) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final connectionId = connection.activeConnectionId;
    final profile = _profile;
    final l10n = context.l10n;
    final name = (plugin['name'] ?? '').toString();
    setState(() => _busyName = name);
    try {
      requireActiveApi(context, connection, api);
      if (connectionId != connection.activeConnectionId ||
          profile != _profile) {
        throw StateError(l10n.backendDisconnected);
      }
      await connection.setPluginEnabled(plugin, enabled, profile: profile);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      if (connectionId != connection.activeConnectionId ||
          profile != _profile) {
        return;
      }
      await _load();
    } catch (e) {
      if (mounted &&
          identical(api, connection.api) &&
          connectionId == connection.activeConnectionId &&
          profile == _profile) {
        showHermesToast(context, message: l10n.pluginsOperationFailed('$e'));
      }
    } finally {
      if (mounted &&
          identical(api, connection.api) &&
          connectionId == connection.activeConnectionId &&
          profile == _profile) {
        setState(() => _busyName = '');
      }
    }
  }

  Future<void> _install() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final connectionId = connection.activeConnectionId;
    final profile = _profile;
    final l10n = context.l10n;
    final identifier = TextEditingController();
    var force = false;
    var enable = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.pluginsInstallTitle),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: identifier,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.pluginsIdentifierHint,
                    prefixIcon: const Icon(Icons.link),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.pluginsEnableAfterInstall),
                  value: enable,
                  onChanged: (value) => setDialogState(() => enable = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.pluginsForceReinstall),
                  value: force,
                  onChanged: (value) => setDialogState(() => force = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.download, size: 18),
              label: Text(l10n.configCenterInstall),
            ),
          ],
        ),
      ),
    );
    final value = identifier.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => identifier.dispose());
    if (accepted != true || value.isEmpty || !mounted) return;
    setState(() => _busyName = '__install__');
    try {
      requireActiveApi(context, connection, api);
      if (connectionId != connection.activeConnectionId ||
          profile != _profile) {
        throw StateError(l10n.backendDisconnected);
      }
      final result = await connection.installPlugin(
        value,
        force: force,
        enable: enable,
        profile: profile,
      );
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      if (connectionId != connection.activeConnectionId ||
          profile != _profile) {
        return;
      }
      await _load();
      if (mounted) {
        showHermesToast(
          context,
          message: l10n.pluginsInstalled(
            (result['plugin_name'] ?? result['name'] ?? value).toString(),
          ),
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: l10n.pluginsInstallFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyName = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featurePlugins),
        actions: [
          IconButton(
            tooltip: l10n.configCenterInstallPlugin,
            onPressed: _busyName.isEmpty ? _install : null,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _busyName.isNotEmpty ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_plugins == null && _error == null) {
      return HermesLoadingState(label: context.l10n.pluginsLoading);
    }
    if (_error != null && _plugins == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    if (_plugins == null) {
      return HermesEmptyState(
        icon: Icons.extension_off_outlined,
        title: context.l10n.pluginsNoData,
      );
    }
    final list = _filtered;
    return Column(
      children: [
        const ProfileScopeDropdown(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HermesSpacing.md,
            HermesSpacing.md,
            HermesSpacing.md,
            0,
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: context.l10n.pluginsSearchHint(_plugins!.length),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HermesRadius.card),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: list.isEmpty
                ? HermesEmptyState(
                    icon: Icons.search_off,
                    title: context.l10n.pluginsNoMatches,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                    children: [
                      HermesMobileGroup(
                        children: [
                          for (final plugin in list)
                            _pluginRow(context, plugin),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _pluginRow(BuildContext context, Map<String, dynamic> plugin) {
    final name = (plugin['name'] ?? '').toString();
    final desc = (plugin['description'] ?? '').toString();
    final version = (plugin['version'] ?? '').toString();
    final enabled = plugin['enabled'] == true;
    final kind = (plugin['key'] ?? '').toString().startsWith('platforms/')
        ? 'platform'
        : (plugin['key'] ?? '').toString().startsWith('providers/')
        ? 'provider'
        : 'tool';
    final color = switch (kind) {
      'platform' => HermesSemantic.blue,
      'provider' => HermesSemantic.purple,
      _ => HermesSemantic.green,
    };
    final kindLabel = switch (kind) {
      'platform' => context.l10n.pluginsKindPlatform,
      'provider' => context.l10n.pluginsKindProvider,
      _ => context.l10n.pluginsKindTool,
    };
    final pluginId = (plugin['id'] ?? plugin['name'] ?? plugin['key'] ?? '')
        .toString();
    final contributions = context
        .watch<PluginContributionStore>()
        .contributions
        .where((item) => item.pluginId == pluginId)
        .toList();
    return Column(
      children: [
        HermesMobileRow(
          icon: kind == 'platform'
              ? Icons.connected_tv_outlined
              : kind == 'provider'
              ? Icons.cloud_outlined
              : Icons.build_outlined,
          tone: color,
          title: name,
          subtitle: [
            if (version.isNotEmpty) 'v$version',
            kindLabel,
          ].join(' · '),
          trailing: _busyName != name
              ? Switch(
                  value: enabled,
                  onChanged: _busyName.isEmpty
                      ? (v) => _toggle(plugin, v)
                      : null,
                )
              : const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          onTap: desc.isEmpty
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(name),
                    content: SingleChildScrollView(child: Text(desc)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(context.l10n.commonClose),
                      ),
                    ],
                  ),
                ),
        ),
        if (contributions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in contributions)
                  ActionChip(
                    avatar: Icon(
                      Icons.extension_outlined,
                      size: 16,
                      color: pluginToneColor(item.color),
                    ),
                    label: Text(item.title),
                    tooltip: context.l10n.pluginsContributionTooltip(
                      _contributionAreaLabel(context, item.area),
                      item.description,
                    ),
                    onPressed: () async {
                      try {
                        final result = await context
                            .read<PluginContributionStore>()
                            .invoke(item);
                        if (context.mounted) {
                          final message =
                              (result['message'] ??
                                      context.l10n.pluginsActionExecuted(
                                        item.title,
                                      ))
                                  .toString();
                          showHermesToast(context, message: message);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showHermesToast(
                            context,
                            message: context.l10n.pluginActionFailed(
                              item.title,
                              '$e',
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _contributionAreaLabel(
    BuildContext context,
    MobileContributionArea area,
  ) => switch (area) {
    MobileContributionArea.navigation => context.l10n.pluginsAreaNavigation,
    MobileContributionArea.command => context.l10n.pluginsAreaCommand,
    MobileContributionArea.settings => context.l10n.pluginsAreaSettings,
    MobileContributionArea.composer => context.l10n.pluginsAreaComposer,
    MobileContributionArea.detail => context.l10n.pluginsAreaDetail,
    MobileContributionArea.transcript => context.l10n.pluginsAreaTranscript,
    MobileContributionArea.pane => context.l10n.pluginsAreaPane,
  };
}
