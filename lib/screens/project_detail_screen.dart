/// Project detail (Q12 decision, spec §52): simplified — basic info,
/// project sessions (filtered by cwd prefix), and only data-backed panels
/// (Sessions / Files / Git / Tasks). Kanban / Memory / Agents / Settings are
/// marked V1.1.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/gateway.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/session/session_detail_panel.dart';
import '../widgets/session/session_rich_card.dart';
import 'chat_screen.dart';
import 'files_screen.dart';
import 'git_screen.dart';
import 'memory_screen.dart';
import 'starmap_screen.dart';
import 'subagents_screen.dart';
import 'kanban_canonical_screen.dart';
import 'webhooks_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with ConnectionReloadMixin<ProjectDetailScreen> {
  ProjectTreeNode? _tree;
  bool _loading = true;
  bool _foldersBusy = false;
  late List<Map<String, dynamic>> _folders;
  late final GatewayClient? _ownerGateway;
  late final ApiClient? _ownerApi;
  bool _connectionChanged = false;
  int _loadGeneration = 0;

  String get _name =>
      widget.project['name']?.toString() ?? context.l10n.projectUntitled;
  String get _path =>
      widget.project['primary_path']?.toString() ??
      widget.project['path']?.toString() ??
      '';
  String get _projectId =>
      widget.project['id']?.toString() ??
      widget.project['project_id']?.toString() ??
      '';

  String _folderLabel(Map<String, dynamic> folder) {
    final label = folder['label']?.toString().trim() ?? '';
    final path = folder['path']?.toString() ?? '';
    final primary = folder['is_primary'] == true || path == _path;
    if (primary && (label.isEmpty || label == 'Main')) {
      return context.l10n.projectPrimaryFolder;
    }
    return label;
  }

  @override
  void initState() {
    super.initState();
    _folders = ((widget.project['folders'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    _ownerGateway = context.read<ConnectionStore>().gateway;
    _ownerApi = context.read<SessionStore>().api;
    _loadSessions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _handleConnectionChange);
  }

  void _handleConnectionChange() {
    if (!mounted) return;
    _loadGeneration++;
    setState(() {
      _connectionChanged = true;
      _tree = null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _saveFolders(List<Map<String, dynamic>> next) async {
    if (_projectId.isEmpty || _foldersBusy) return;
    final connection = context.read<ConnectionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final previous = _folders;
    setState(() {
      _folders = next;
      _foldersBusy = true;
    });
    try {
      final gateway = _ownerGateway;
      if (gateway == null) throw StateError(l10n.backendDisconnected);
      await requireActiveGateway(
        context,
        connection,
        gateway,
      ).request('projects.update', {'id': _projectId, 'folders': next});
    } catch (e) {
      if (mounted) {
        setState(() => _folders = previous);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.projectSaveFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _foldersBusy = false);
    }
  }

  Future<void> _addFolder() async {
    final l10n = context.l10n;
    final pathCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.projectAddFolder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.projectFolderPath),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: l10n.projectFolderLabelOptional,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    );
    final path = pathCtrl.text.trim();
    final label = labelCtrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pathCtrl.dispose();
      labelCtrl.dispose();
    });
    if (result != true || path.isEmpty || !mounted) return;
    await _saveFolders([
      ..._folders,
      {'path': path, 'label': label.isNotEmpty ? label : path},
    ]);
  }

  Future<void> _removeFolder(Map<String, dynamic> folder) async {
    if (_folders.length <= 1) return;
    await _saveFolders(_folders.where((f) => !identical(f, folder)).toList());
  }

  Future<void> _loadSessions() async {
    final generation = ++_loadGeneration;
    final api = _ownerApi;
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final project = await api.projectSessions(_projectId);
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<SessionStore>().api)) {
        setState(() {
          _tree = project;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<SessionStore>().api)) {
        setState(() {
          _tree = null;
          _loading = false;
        });
      }
    }
  }

  bool get _hasAnySession =>
      (_tree?.repos ?? const []).any((repo) => repo.sessionCount > 0);

  Future<void> _openSession(SessionRow row) async {
    final session = context.read<SessionStore>();
    try {
      await session.resumeSession(row.id, profile: row.profile);
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.projectResumeFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connectionChanged) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.projectDetailTitle)),
        body: HermesErrorState(
          description: context.l10n.backendDisconnected,
          alternativeLabel: context.l10n.commonBack,
          onAlternative: () => Navigator.maybePop(context),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.projectDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(HermesSpacing.md),
        children: [
          // ── Basic info ──────────────────────────────────────────
          HermesGlassCard(
            radius: HermesRadius.largeCard,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: HermesType.onSurface(
                    HermesType.title,
                    Theme.of(context),
                  ),
                ),
                if ((widget.project['description']?.toString() ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(widget.project['description'].toString()),
                ],
                const SizedBox(height: 10),
                if (_path.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 15,
                        color: HermesSemantic.gray,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _path,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (_folders.isNotEmpty) ...[
                  Text(
                    context.l10n.projectFolderCount(_folders.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  for (final folder in _folders)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.folder_open_outlined,
                            size: 15,
                            color: HermesSemantic.gray,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _folderLabel(folder).isNotEmpty
                                  ? '${_folderLabel(folder)} — ${folder['path']}'
                                  : (folder['path'] ?? '').toString(),
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_projectId.isNotEmpty && _folders.length > 1)
                            IconButton(
                              tooltip: context.l10n.commonRemove,
                              iconSize: 16,
                              visualDensity: VisualDensity.compact,
                              onPressed: _foldersBusy
                                  ? null
                                  : () => _removeFolder(folder),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    ),
                ],
                if (_projectId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _foldersBusy ? null : _addFolder,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(context.l10n.projectAddFolder),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: HermesSpacing.lg),
          // ── Sessions, grouped by repo → branch/worktree lane (desktop's
          // workspace-group.tsx parity: flattening this into one list loses
          // which branch each session belongs to) ─────────────────────────
          HermesSectionHeader(title: context.l10n.projectSessionsTitle),
          if (_loading)
            HermesLoadingState(label: context.l10n.projectLoadingSessions)
          else if (_tree == null || !_hasAnySession)
            HermesEmptyState(
              icon: Icons.chat_bubble_outline,
              title: context.l10n.projectNoSessions,
              description: context.l10n.projectNoSessionsDescription,
            )
          else
            for (final repo in _tree!.repos)
              if (repo.sessionCount > 0) _buildRepoSection(context, repo),
          const SizedBox(height: HermesSpacing.md),
          // ── Data-backed panels ──────────────────────────────────
          HermesSectionHeader(title: context.l10n.projectModulesTitle),
          _panel(
            context,
            key: const ValueKey('project-files-panel'),
            icon: Icons.insert_drive_file_outlined,
            title: context.l10n.featureFiles,
            subtitle: context.l10n.projectBrowseFiles,
            onTap: _path.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FilesScreen(initialPath: _path),
                    ),
                  ),
          ),
          _panel(
            context,
            icon: Icons.commit,
            title: context.l10n.featureGit,
            subtitle: context.l10n.projectGitDescription,
            onTap: _path.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GitScreen(initialPath: _path),
                    ),
                  ),
          ),
          _panel(
            context,
            key: const ValueKey('project-tasks-panel'),
            icon: Icons.task_alt,
            title: context.l10n.projectTasksTitle,
            subtitle: context.l10n.projectTasksDescription,
            onTap: _projectId.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          KanbanCanonicalScreen(initialProjectId: _projectId),
                    ),
                  ),
          ),
          _panel(
            context,
            icon: Icons.memory_outlined,
            title: context.l10n.featureMemory,
            subtitle: context.l10n.projectGlobalMemoryDescription,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MemoryScreen())),
          ),
          _panel(
            context,
            icon: Icons.account_tree_outlined,
            title: context.l10n.featureSubagents,
            subtitle: context.l10n.projectGlobalSubagentsDescription,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SubagentsScreen())),
          ),
          _panel(
            context,
            icon: Icons.webhook_outlined,
            title: context.l10n.featureWebhooks,
            subtitle: context.l10n.projectGlobalWebhooksDescription,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const WebhooksScreen())),
          ),
          _panel(
            context,
            icon: Icons.auto_awesome_outlined,
            title: context.l10n.featureStarmap,
            subtitle: context.l10n.projectGlobalStarmapDescription,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const StarmapScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoSection(BuildContext context, WorkspaceTreeNode repo) {
    final multiRepo = _tree!.repos.where((r) => r.sessionCount > 0).length > 1;
    final theme = Theme.of(context);
    final lanes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in repo.groups)
          if (group.sessions.isNotEmpty) _buildGroupLane(context, group),
      ],
    );
    if (!multiRepo) {
      // A single repo (the common case) doesn't need its own collapsible
      // header on top of the branch lanes below it — just the lanes.
      return Padding(
        padding: const EdgeInsets.only(bottom: HermesSpacing.sm),
        child: lanes,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.sm),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.source_outlined, size: 18),
          title: Text(
            repo.label,
            style: HermesType.onSurface(HermesType.callout, theme),
          ),
          subtitle: Text(
            context.l10n.projectSessionCount(repo.sessionCount),
            style: theme.textTheme.bodySmall,
          ),
          childrenPadding: const EdgeInsets.only(left: 8),
          children: [lanes],
        ),
      ),
    );
  }

  Widget _buildGroupLane(BuildContext context, SessionGroupNode group) {
    final theme = Theme.of(context);
    final icon = group.isKanban
        ? Icons.view_kanban_outlined
        : group.isHome
        ? Icons.home_outlined
        : group.isMain
        ? Icons.merge_type
        : Icons.call_split;
    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  group.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${group.sessions.length})',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final s in group.sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SessionRichCard(
                row: s,
                onTap: () => _openSession(s),
                onLongPress: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FractionallySizedBox(
                    heightFactor: .85,
                    child: SessionDetailPanel(
                      row: s,
                      onOpen: () => _openSession(s),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: HermesGlassCard(
        key: key,
        radius: HermesRadius.card,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: onTap,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: onTap == null
              ? Text(
                  context.l10n.projectUnavailable,
                  style: Theme.of(context).textTheme.labelSmall,
                )
              : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
