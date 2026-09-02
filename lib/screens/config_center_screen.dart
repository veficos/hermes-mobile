/// ConfigCenterScreen — unified configuration for MCP / Knowledge / Skills / Plugins.
///
/// Desktop parity: mirrors the hermes-agent desktop settings panels for:
/// 1. MCP servers configuration (add/edit/remove MCP server entries)
/// 2. Knowledge base management (add sources, index, search)
/// 3. Skills management (list, enable/disable, configure)
/// 4. Plugins management (list, enable/disable, configure)

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/profile_scope_selector.dart';
import 'mcp_screen.dart';
import 'plugins_screen.dart';
import 'skills_screen.dart';

// ============================================================================
// Data models
// ============================================================================

class KnowledgeSource {
  final String id;
  final String name;
  final String type; // file | folder | url | database
  final int chunkCount;
  final bool indexed;

  const KnowledgeSource({
    required this.id,
    required this.name,
    required this.type,
    this.chunkCount = 0,
    this.indexed = false,
  });

  IconData get icon => switch (type) {
    'file' => Icons.insert_drive_file_outlined,
    'folder' => Icons.folder_outlined,
    'url' => Icons.link_outlined,
    'database' => Icons.storage_outlined,
    _ => Icons.help_outline,
  };
}

// ============================================================================
// Screen
// ============================================================================

class ConfigCenterScreen extends StatefulWidget {
  final bool embedded;

  const ConfigCenterScreen({super.key, this.embedded = false});

  @override
  State<ConfigCenterScreen> createState() => _ConfigCenterScreenState();
}

class _ConfigCenterScreenState extends State<ConfigCenterScreen>
    with
        SingleTickerProviderStateMixin,
        ConnectionReloadMixin<ConfigCenterScreen> {
  late final TabController _tabController;

  final List<KnowledgeSource> _knowledgeSources = [];
  bool _loading = true;
  bool _mutating = false;
  String? _error;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  bool _hasLoadedData = false;

  ProfileScopeStore? _scopeStore;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final scopeStore = context.read<ProfileScopeStore>();
    _scopeStore = scopeStore;
    scopeStore.addListener(_onScopeChanged);
    scopeStore.ensureLoaded();
    _loadData();
  }

  void _onScopeChanged() {
    if (!mounted) return;
    ++_mutationGeneration;
    if (_mutating) setState(() => _mutating = false);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _onConnectionChanged);
  }

  void _onConnectionChanged() {
    ++_mutationGeneration;
    if (mounted && _mutating) setState(() => _mutating = false);
    _loadData();
  }

  String? get _profile => _scopeStore?.override;

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    final api = context.read<ConnectionStore>().api;
    if (api == null) {
      setState(() {
        _error = _hasLoadedData ? null : connectionOfflineErrorCode;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final profile = _profile;
    try {
      final knowledgeGraph = await api.knowledgeGraph();

      if (!mounted ||
          generation != _loadGeneration ||
          profile != _profile ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }

      setState(() {
        _knowledgeSources
          ..clear()
          ..addAll(_parseKnowledgeGraph(knowledgeGraph));
        _loading = false;
        _hasLoadedData = true;
      });
    } catch (e) {
      if (!mounted ||
          generation != _loadGeneration ||
          profile != _profile ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _error = '$e';
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.configCenterLoadFailed('$e'))),
      );
    }
  }

  List<KnowledgeSource> _parseKnowledgeGraph(Map<String, dynamic> graph) {
    final sources = <KnowledgeSource>[];
    final nodes = graph['nodes'] as List? ?? [];
    for (final n in nodes) {
      final node = (n as Map).cast<String, dynamic>();
      final id = (node['id'] ?? '').toString();
      final name = (node['name'] ?? node['title'] ?? id).toString();
      final type = (node['type'] ?? 'file').toString();
      final chunkCount =
          (node['chunk_count'] ?? node['chunkCount'] ?? 0) as int;
      final indexed = node['indexed'] == true || chunkCount > 0;
      if (name.isNotEmpty) {
        sources.add(
          KnowledgeSource(
            id: id,
            name: name,
            type: type,
            chunkCount: chunkCount,
            indexed: indexed,
          ),
        );
      }
    }
    return sources;
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _scopeStore?.removeListener(_onScopeChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = TabBar(
      controller: _tabController,
      tabs: [
        Tab(text: l10n.featureMcp),
        Tab(text: l10n.configCenterKnowledgeTab),
        Tab(text: l10n.featureSkills),
        Tab(text: l10n.featurePlugins),
      ],
    );
    final body = _buildBody();

    if (widget.embedded) {
      return Column(
        children: [
          Material(color: Theme.of(context).colorScheme.surface, child: tabs),
          const ProfileScopeDropdown(),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.configCenterTitle), bottom: tabs),
      body: Column(
        children: [
          const ProfileScopeDropdown(),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return HermesErrorState(
        title: context.l10n.configCenterLoadErrorTitle,
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error!,
        onRetry: _loadData,
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _constrainContent(_buildMcpTab()),
        _constrainContent(_buildKnowledgeTab()),
        _constrainContent(_buildSkillsTab()),
        _constrainContent(_buildPluginsTab()),
      ],
    );
  }

  Widget _constrainContent(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: child,
      ),
    );
  }

  Widget _managementLauncher({
    required IconData icon,
    required String title,
    required String description,
    required Widget page,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(HermesSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: HermesPalette.of(context).accent),
                  const SizedBox(height: HermesSpacing.md),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: HermesSpacing.sm),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: HermesSpacing.lg),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => page)),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(context.l10n.commonOpen),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ MCP
  Widget _buildMcpTab() {
    return _managementLauncher(
      icon: Icons.hub_outlined,
      title: context.l10n.featureMcp,
      description: context.l10n.featureMcpDesc,
      page: const McpScreen(),
    );
    /* Legacy inline editor retained temporarily for migration safety.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.featureMcpDesc,
                  style: HermesType.onSurface(
                    HermesType.title,
                    Theme.of(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: _addMcpServer,
                tooltip: context.l10n.mcpAddServer,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: _mcpServers.isEmpty
              ? HermesEmptyState(
                  icon: Icons.dns_outlined,
                  title: context.l10n.mcpNoConfiguredServers,
                  description: context.l10n.configCenterMcpEmptyDescription,
                )
              : ListView.builder(
                  itemCount: _mcpServers.length,
                  itemBuilder: (ctx, i) => _mcpTile(context, _mcpServers[i]),
                ),
        ),
      ],
    ); */
  }

  /* Legacy MCP editor implementation. The canonical editor is McpScreen.
  Widget _mcpTile(BuildContext context, McpServer s) {
    final color = s.enabled ? HermesSemantic.green : HermesSemantic.gray;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: s.enabled,
                  onChanged: _mutating ? null : (v) => _toggleMcp(s, v),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${s.transport.toUpperCase()} · ${s.url}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editMcpServer(s),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(context.l10n.commonEdit),
                ),
                TextButton.icon(
                  onPressed: _mutating ? null : () => _removeMcpServer(s),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: HermesSemantic.red,
                  ),
                  label: Text(
                    context.l10n.commonDelete,
                    style: const TextStyle(color: HermesSemantic.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMcpServer() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    final result = await _showMcpDialog(null);
    if (result == null || !mounted) return;
    await _runMutation((api) async {
      if (profile != _profile) {
        throw StateError(context.l10n.backendDisconnected);
      }
      await api.mcpCreate(
        _mcpPayload(result.$1, result.$2, result.$3),
        profile: profile,
      );
    }, expectedApi: api);
  }

  Future<void> _editMcpServer(McpServer s) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    final result = await _showMcpDialog(s);
    if (result == null || !mounted) return;
    await _runMutation((api) async {
      if (profile != _profile) {
        throw StateError(context.l10n.backendDisconnected);
      }
      final updated = [
        for (final current in _mcpServers)
          if (current.id == s.id)
            current.copyWith(
              name: result.$1,
              url: result.$2,
              transport: result.$3,
            )
          else
            current,
      ];
      await api.mcpReplaceServers({
        for (final current in updated)
          current.name: {
            ...current.config,
            ..._mcpPayload(
              current.name,
              current.url,
              current.transport,
              includeName: false,
            ),
            'enabled': current.enabled,
          },
      }, profile: profile);
    }, expectedApi: api);
  }

  Future<(String, String, String)?> _showMcpDialog(McpServer? existing) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    String transport = existing?.transport ?? 'stdio';

    final result = await showDialog<(String, String, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(
            existing == null
                ? l10n.mcpAddServer
                : l10n.mcpEditServer(existing.name),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.commonName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: l10n.configCenterUrlOrCommand,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: transport,
                decoration: InputDecoration(
                  labelText: l10n.configCenterTransport,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'stdio',
                    child: Text(l10n.configCenterLocalStdio),
                  ),
                  const DropdownMenuItem(
                    value: 'sse',
                    child: Text('SSE (HTTP)'),
                  ),
                  const DropdownMenuItem(
                    value: 'streamable',
                    child: Text('Streamable HTTP'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDlg(() => transport = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final url = urlCtrl.text.trim();
                if (name.isEmpty || url.isEmpty) return;
                Navigator.of(ctx).pop((name, url, transport));
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      urlCtrl.dispose();
    });
    return result;
  }

  Future<void> _toggleMcp(McpServer server, bool enabled) async {
    await _runMutation((api) async {
      await api.mcpSetEnabled(server.name, enabled, profile: _profile);
    });
  }

  Future<void> _removeMcpServer(McpServer server) async {
    await _runMutation((api) async {
      await api.mcpDelete(server.name, profile: _profile);
    });
  }

  Map<String, dynamic> _mcpPayload(
    String name,
    String endpoint,
    String transport, {
    bool includeName = true,
  }) => {
    if (includeName) 'name': name,
    'transport': transport,
    if (transport == 'stdio') 'command': endpoint else 'url': endpoint,
  };

  */

  Future<void> _runMutation(
    Future<void> Function(ApiClient api) action, {
    ApiClient? expectedApi,
  }) async {
    if (_mutating) return;
    final generation = ++_mutationGeneration;
    final profile = _profile;
    setState(() => _mutating = true);
    late final ConnectionStore connection;
    ApiClient? api;
    try {
      connection = context.read<ConnectionStore>();
      api = expectedApi ?? connection.api;
      if (api == null) throw StateError(context.l10n.backendDisconnected);
      requireActiveApi(context, connection, api);
      await action(api);
      if (!mounted ||
          generation != _mutationGeneration ||
          profile != _profile) {
        return;
      }
      requireActiveApi(context, connection, api);
      await _loadData();
    } catch (error) {
      if (mounted &&
          generation == _mutationGeneration &&
          profile == _profile &&
          api != null &&
          identical(api, context.read<ConnectionStore>().api)) {
        showHermesToast(
          context,
          message: context.l10n.configCenterMutationFailed('$error'),
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _mutating = false);
      }
    }
  }

  // ------------------------------------------------------------------ Knowledge
  Widget _buildKnowledgeTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.configCenterKnowledgeTitle,
                  style: HermesType.onSurface(
                    HermesType.title,
                    Theme.of(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonRefresh,
                onPressed: _mutating ? null : _loadData,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _knowledgeSources.isEmpty
              ? HermesEmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: context.l10n.configCenterKnowledgeEmpty,
                  description:
                      context.l10n.configCenterKnowledgeEmptyDescription,
                )
              : ListView.builder(
                  itemCount: _knowledgeSources.length,
                  itemBuilder: (ctx, i) =>
                      _knowledgeTile(context, _knowledgeSources[i]),
                ),
        ),
      ],
    );
  }

  Widget _knowledgeTile(BuildContext context, KnowledgeSource s) {
    final l10n = context.l10n;
    final typeLabel = switch (s.type) {
      'file' => l10n.commonFile,
      'folder' => l10n.commonFolder,
      'url' => 'URL',
      'database' => l10n.configCenterDatabase,
      _ => s.type,
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(s.icon, size: 24, color: HermesSemantic.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    l10n.configCenterKnowledgeMeta(
                      typeLabel,
                      s.chunkCount,
                      s.indexed
                          ? l10n.configCenterIndexed
                          : l10n.configCenterNotIndexed,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _mutating ? null : () => _removeKnowledge(s.id),
              icon: const Icon(Icons.delete_outline, color: HermesSemantic.red),
              tooltip: l10n.commonDelete,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeKnowledge(String id) async {
    await _runMutation((api) async {
      await api.knowledgeNodeDelete(id);
    });
  }

  // ------------------------------------------------------------------ Skills
  Widget _buildSkillsTab() {
    return _managementLauncher(
      icon: Icons.auto_awesome_outlined,
      title: context.l10n.featureSkills,
      description: context.l10n.featureSkillsDesc,
      page: const SkillsScreen(),
    );
    /* Legacy inline editor retained temporarily for migration safety.
    if (_skills.isEmpty) {
      return HermesEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: context.l10n.configCenterSkillsEmpty,
        description: context.l10n.configCenterSkillsEmptyDescription,
      );
    }
    return ListView.builder(
      itemCount: _skills.length,
      itemBuilder: (ctx, i) => _skillTile(context, _skills[i]),
    ); */
  }

  /* Legacy Skills editor implementation. The canonical editor is SkillsScreen.
  Widget _skillTile(BuildContext context, SkillEntry s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HermesSemantic.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${s.toolCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: HermesSemantic.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        s.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: s.enabled,
                  onChanged: (v) => _toggleSkill(s.id, v),
                ),
              ],
            ),
            if (s.config != null) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                title: Text(context.l10n.configCenterConfiguration),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(s.config.toString(), style: HermesType.code),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSkill(String id, bool enabled) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final previous = _skills.indexWhere((x) => x.id == id);
    if (previous < 0) return;
    final old = _skills[previous];
    setState(() {
      final idx = _skills.indexWhere((x) => x.id == id);
      if (idx >= 0) {
        _skills[idx] = SkillEntry(
          id: _skills[idx].id,
          name: _skills[idx].name,
          description: _skills[idx].description,
          toolCount: _skills[idx].toolCount,
          enabled: enabled,
          config: _skills[idx].config,
        );
      }
    });
    try {
      await api.toggleSkill(id, enabled, profile: _profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final idx = _skills.indexWhere((x) => x.id == id);
        if (idx >= 0) _skills[idx] = old;
      });
      showHermesToast(
        context,
        message: context.l10n.skillsToggleFailed('$error'),
      );
    }
  }

  */

  // ------------------------------------------------------------------ Plugins
  Widget _buildPluginsTab() {
    return _managementLauncher(
      icon: Icons.extension_outlined,
      title: context.l10n.featurePlugins,
      description: context.l10n.featurePluginsDesc,
      page: const PluginsScreen(),
    );
    /* Legacy inline editor retained temporarily for migration safety.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.featurePluginsDesc,
                  style: HermesType.onSurface(
                    HermesType.title,
                    Theme.of(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: _installPlugin,
                tooltip: context.l10n.configCenterInstallPlugin,
                icon: const Icon(Icons.download),
              ),
            ],
          ),
        ),
        Expanded(
          child: _plugins.isEmpty
              ? HermesEmptyState(
                  icon: Icons.extension_outlined,
                  title: context.l10n.configCenterPluginsEmpty,
                  description: context.l10n.configCenterPluginsEmptyDescription,
                )
              : ListView.builder(
                  itemCount: _plugins.length,
                  itemBuilder: (ctx, i) => _pluginTile(context, _plugins[i]),
                ),
        ),
      ],
    ); */
  }

  /* Legacy Plugins editor implementation. The canonical editor is PluginsScreen.
  Widget _pluginTile(BuildContext context, PluginEntry p) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.extension, color: HermesSemantic.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HermesSemantic.gray.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.version,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        p.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (p.installed)
                  Switch(
                    value: p.enabled,
                    onChanged: _mutating ? null : (v) => _togglePlugin(p, v),
                  )
                else
                  FilledButton(
                    onPressed: () => _installPlugin(initialUrl: p.id),
                    child: Text(context.l10n.configCenterInstall),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlugin(PluginEntry plugin, bool enabled) async {
    await _runMutation((api) async {
      await api.setPluginEnabled(plugin.name, enabled, profile: _profile);
    });
  }

  Future<void> _installPlugin({String? initialUrl}) async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    final ctrl = TextEditingController(text: initialUrl ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.configCenterInstallPlugin),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.configCenterPluginUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(l10n.configCenterInstall),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (url == null || url.isEmpty) return;
    await _runMutation((_) async {
      if (profile != _profile) {
        throw StateError(context.l10n.backendDisconnected);
      }
      await connection.installPlugin(url, profile: profile);
    }, expectedApi: api);
  }
  */
}
