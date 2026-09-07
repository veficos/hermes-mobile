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
  }

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
  }

  // ------------------------------------------------------------------ Plugins
  Widget _buildPluginsTab() {
    return _managementLauncher(
      icon: Icons.extension_outlined,
      title: context.l10n.featurePlugins,
      description: context.l10n.featurePluginsDesc,
      page: const PluginsScreen(),
    );
  }
}
