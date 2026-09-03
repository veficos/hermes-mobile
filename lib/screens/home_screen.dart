library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../core/session_tree.dart';
import '../core/stores/notification_store.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/session_appearance_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_badge.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_logo.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import '../widgets/session/session_card.dart';
import '../widgets/session/session_list_meta.dart';
import '../widgets/session/session_row_actions.dart';
import 'agent_screen.dart';
import 'artifacts_screen.dart';
import 'chat_screen.dart';
import 'cron_screen.dart';
import 'files_screen.dart';
import 'git_screen.dart';
import 'insights_screen.dart';
import 'kanban_canonical_screen.dart';
import 'knowledge_screen.dart';
import 'notification_screen.dart';
import 'project_screen.dart';
import 'session_list_screen.dart';
import 'settings_hub_screen.dart';
import 'subagents_screen.dart';
import 'terminal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _toolOrderKey = 'hm_home_quick_tool_order';
  static const _defaultToolOrder = [
    'files',
    'terminal',
    'git',
    'kanban',
    'agent',
    'settings',
    'projects',
    'subagents',
    'knowledge',
    'artifacts',
    'cron',
    'insights',
  ];
  static final Map<String, _HomeToolSpec> _toolSpecs = {
    'projects': _HomeToolSpec(
      id: 'projects',
      icon: Icons.folder_outlined,
      builder: (_) => const ProjectScreen(),
    ),
    'files': _HomeToolSpec(
      id: 'files',
      icon: Icons.description_outlined,
      builder: (_) => const FilesScreen(),
    ),
    'terminal': _HomeToolSpec(
      id: 'terminal',
      icon: Icons.terminal,
      builder: (_) => const TerminalScreen(),
    ),
    'git': _HomeToolSpec(
      id: 'git',
      icon: Icons.commit,
      builder: (_) => const GitScreen(),
    ),
    'kanban': _HomeToolSpec(
      id: 'kanban',
      icon: Icons.view_kanban_outlined,
      builder: (_) => const KanbanCanonicalScreen(),
    ),
    'agent': _HomeToolSpec(
      id: 'agent',
      icon: Icons.auto_awesome_outlined,
      builder: (_) => const AgentScreen(),
    ),
    'settings': _HomeToolSpec(
      id: 'settings',
      icon: Icons.tune_outlined,
      builder: (_) => const SettingsHubScreen(),
    ),
    'subagents': _HomeToolSpec(
      id: 'subagents',
      icon: Icons.account_tree_outlined,
      builder: (_) => const SubagentsScreen(),
    ),
    'knowledge': _HomeToolSpec(
      id: 'knowledge',
      icon: Icons.menu_book_outlined,
      builder: (_) => const KnowledgeScreen(),
    ),
    'artifacts': _HomeToolSpec(
      id: 'artifacts',
      icon: Icons.photo_library_outlined,
      builder: (_) => const ArtifactsScreen(),
    ),
    'cron': _HomeToolSpec(
      id: 'cron',
      icon: Icons.schedule_outlined,
      builder: (_) => const CronScreen(),
    ),
    'insights': _HomeToolSpec(
      id: 'insights',
      icon: Icons.query_stats_outlined,
      builder: (_) => const InsightsScreen(),
    ),
  };
  final Set<String> _expanded = {};
  List<String> _toolOrder = List.of(_defaultToolOrder);
  bool _loading = true;
  bool _opening = false;
  bool _reconnecting = false;
  int _generation = 0;

  SessionStore get _store => context.read<SessionStore>();

  @override
  void initState() {
    super.initState();
    _loadToolOrder();
    _load();
  }

  Future<void> _loadToolOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_toolOrderKey) ?? const [];
    final valid = saved.where(_defaultToolOrder.contains).toSet().toList();
    valid.addAll(_defaultToolOrder.where((id) => !valid.contains(id)));
    if (mounted) setState(() => _toolOrder = valid);
  }

  Future<void> _editToolOrder() async {
    var draft = List<String>.of(_toolOrder);
    final saved = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.homeEditQuickTools),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.homeQuickToolsDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: draft.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setDialogState(() {
                        final item = draft.removeAt(oldIndex);
                        draft.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final tool = _toolSpecs[draft[index]]!;
                      return ListTile(
                        key: ValueKey('quick-tool-editor-${tool.id}'),
                        leading: Icon(tool.icon),
                        title: Text(_toolLabel(tool.id)),
                        subtitle: index == 4
                            ? Text(context.l10n.homeLastVisibleTool)
                            : null,
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: Tooltip(
                            message: context.l10n.homeDragToReorder,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  setDialogState(() => draft = List.of(_defaultToolOrder)),
              child: Text(context.l10n.homeRestoreDefaults),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draft),
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _toolOrder = saved);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_toolOrderKey, saved);
  }

  Future<void> _load() async {
    if (_store.api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final generation = ++_generation;
    try {
      await _store.loadProfileContext(listLimit: 20);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reconnect() async {
    if (_reconnecting) return;
    final connection = _store.connection;
    setState(() => _reconnecting = true);
    try {
      await connection.reconnectAfterResume(refreshSocket: true);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.commonConnected)));
    } catch (error) {
      if (!mounted) return;
      showHermesErrorSnackBar(
        context,
        error,
        fallback: context.l10n.backendDisconnected,
        onRetry: _reconnect,
      );
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  Future<void> _switchProfile(String name) async {
    if (name == _store.activeProfile || _store.api == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _expanded.clear();
    });
    try {
      await _store.switchActiveProfile(name, listLimit: 20);
    } catch (error) {
      if (mounted) {
        showHermesErrorSnackBar(
          context,
          error,
          fallback: context.l10n.profilesSwitchFailed('$error'),
          onRetry: () => _switchProfile(name),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openChat({SessionRow? row}) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (row != null) {
        if (row.readOnly || row.isDelegatedChild) {
          await _store.openReadOnlySession(row.id, profile: row.profile);
        } else {
          await _store.resumeSession(row.id, profile: row.profile);
        }
      } else {
        await _store.openNewSession();
      }
    } catch (error) {
      if (mounted) {
        showHermesErrorSnackBar(
          context,
          error,
          fallback: row == null
              ? context.l10n.sessionCreateFailed('$error')
              : context.l10n.sessionResumeFailed('$error'),
          onRetry: () => _openChat(row: row),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  Future<void> _openRunningSession() async {
    final id = _store.durableId;
    final rows = _store.sessions ?? const <SessionRow>[];
    final active = id == null
        ? null
        : rows.cast<SessionRow?>().firstWhere(
            (row) => row?.id == id,
            orElse: () => null,
          );
    if (active != null) {
      await _openChat(row: active);
      return;
    }
    await _store.setStatusFilter({'working'});
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SessionListScreen()));
  }

  Future<void> _openAttentionSessions() async {
    await _store.setStatusFilter({'attention'});
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SessionListScreen()));
  }

  List<SessionRow> _recentRows(List<SessionRow> rows) {
    final roots = rows
        .where((row) => !row.isChildSession)
        .take(5)
        .map((e) => e.id)
        .toSet();
    final ids = <String>{...roots};
    var changed = true;
    while (changed) {
      changed = false;
      for (final row in rows) {
        if (!ids.contains(row.id) && ids.contains(row.parentSessionId)) {
          ids.add(row.id);
          changed = true;
        }
      }
    }
    return rows.where((row) => ids.contains(row.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SessionStore>();
    final rows = store.sessions ?? const <SessionRow>[];
    final recent = _recentRows(rows);
    final visible = buildVisibleSessionTree(recent, _expanded);
    final parents = recent
        .map((e) => e.parentSessionId)
        .whereType<String>()
        .toSet();
    final running = store.info?.running == true;
    final configuredModel = store.profileConfig['model']?.toString();
    final model = configuredModel?.isNotEmpty == true
        ? configuredModel!
        : (store.info?.model ?? '—');
    final attention = rows.where((row) => row.needsAttention).length;
    SessionRow? runningRow;
    for (final row in rows) {
      if (!row.isChildSession && row.isActivelyWorking) {
        runningRow = row;
        break;
      }
    }
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= HermesBreakpoints.desktop
        ? HermesLayout.workspace
        : (width >= HermesBreakpoints.phone ? HermesLayout.content : width);

    return MobilePageScaffold(
      title: 'Hermes',
      leading: IconButton(
        key: const ValueKey('home-settings-avatar'),
        tooltip: context.l10n.featureSettings,
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsHubScreen())),
        icon: const HermesAgentAvatar(size: 34),
      ),
      actions: [
        ListenableBuilder(
          listenable: store.connection,
          builder: (context, _) {
            final connection = store.connection;
            final phase = connection.phase;
            final busy =
                _reconnecting ||
                phase == ConnectionPhase.connecting ||
                phase == ConnectionPhase.reconnecting;
            final connected = phase == ConnectionPhase.connected;
            final status = switch (phase) {
              ConnectionPhase.connected => context.l10n.commonConnected,
              ConnectionPhase.connecting ||
              ConnectionPhase.reconnecting => context.l10n.connectConnecting,
              ConnectionPhase.disconnected ||
              ConnectionPhase.exhausted => context.l10n.backendDisconnected,
            };
            final tooltip = busy
                ? status
                : '$status · ${context.l10n.paletteReconnectDesc}';
            final colorScheme = Theme.of(context).colorScheme;
            return IconButton(
              key: const ValueKey('home-reconnect'),
              tooltip: tooltip,
              onPressed: connection.isConfigured && !busy ? _reconnect : null,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      connected ? Icons.cloud_done_outlined : Icons.cloud_off,
                      color: connected
                          ? colorScheme.primary
                          : colorScheme.error,
                    ),
            );
          },
        ),
        if (store.profiles.isNotEmpty) _profileMenu(store),
        Consumer<NotificationStore>(
          builder: (context, notifications, _) => IconButton(
            tooltip: context.l10n.notificationTitle,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                Positioned(
                  right: -6,
                  top: -4,
                  child: HermesBadge(count: notifications.unreadCount),
                ),
              ],
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
          ),
        ),
        const SizedBox(width: 6),
      ],
      body: Center(
        child: SizedBox(
          width: maxWidth,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                HermesMobileMetrics.pagePadding,
                HermesMobileMetrics.pagePadding,
                HermesMobileMetrics.pagePadding,
                32,
              ),
              children: [
                _continueHero(
                  running: running,
                  runningRow: runningRow,
                  model: model,
                  profile: store.activeProfile ?? 'default',
                ),
                HermesMobileSectionLabel(
                  title: context.l10n.homeQuickTools,
                  trailing: IconButton(
                    key: const ValueKey('edit-quick-tools'),
                    tooltip: context.l10n.homeEditQuickTools,
                    visualDensity: VisualDensity.compact,
                    onPressed: _editToolOrder,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                  ),
                ),
                _quickTools(),
                HermesMobileSectionLabel(title: context.l10n.homeCurrentWork),
                _statusCards(running, model, attention),
                HermesMobileSectionLabel(
                  title: context.l10n.homeRecentSessions,
                  trailing: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SessionListScreen(),
                      ),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(context.l10n.commonViewAll),
                  ),
                ),
                _recentWork(visible, parents),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _continueHero({
    required bool running,
    required SessionRow? runningRow,
    required String model,
    required String profile,
  }) {
    final palette = HermesPalette.of(context);
    final title = runningRow?.title?.trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accent, palette.accentHover],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: .28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.homeContinueWork,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.l10n.homeBackendSummary(model, profile),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xEBFFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 13),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .18),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () =>
                runningRow != null ? _openChat(row: runningRow) : _openChat(),
            child: Text(
              running && title?.isNotEmpty == true
                  ? context.l10n.homeContinueSession(title!)
                  : context.l10n.homeStartNewSession,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileMenu(SessionStore store) => PopupMenuButton<String>(
    key: const ValueKey('home-profile-menu'),
    tooltip: context.l10n.homeSwitchProfile,
    initialValue: store.activeProfile,
    onSelected: _switchProfile,
    itemBuilder: (_) => [
      for (final profile in store.profiles)
        PopupMenuItem(
          value: profile.name,
          child: Row(
            children: [
              Icon(
                profile.name == store.activeProfile
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(profile.name),
            ],
          ),
        ),
    ],
    child: SizedBox.square(
      dimension: 40,
      child: Tooltip(
        message: context.l10n.homeProfileTooltip(
          store.activeProfile ?? context.l10n.homeDefaultProfile,
        ),
        child: const Icon(Icons.person_outline, size: 20),
      ),
    ),
  );

  Widget _statusCards(bool running, String model, int attention) {
    final first = _StatusCard(
      icon: running ? Icons.bolt : Icons.psychology_outlined,
      color: running ? HermesSemantic.green : HermesSemantic.blue,
      title: running
          ? context.l10n.homeWorkingTitle
          : context.l10n.homeReadyTitle,
      detail: running ? context.l10n.homeWorkingDetail(model) : model,
      action: running
          ? context.l10n.homeViewSession
          : context.l10n.homeStartNewSession,
      busy: running,
      onTap: running ? _openRunningSession : () => _openChat(),
    );
    if (attention == 0) return first;
    final second = _StatusCard(
      icon: attention > 0
          ? Icons.notification_important_outlined
          : Icons.task_alt_outlined,
      color: attention > 0 ? HermesSemantic.orange : HermesSemantic.green,
      title: context.l10n.homeNeedsAttention(attention),
      detail: context.l10n.homeAttentionDetail,
      action: context.l10n.homeViewAttentionSessions,
      onTap: _openAttentionSessions,
    );
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < HermesBreakpoints.navigation) {
          return Column(children: [first, const SizedBox(height: 10), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _recentWork(List<SessionTreeItem> rows, Set<String> parents) {
    if (_loading) {
      return HermesLoadingState(label: context.l10n.homeLoadingRecent);
    }
    if ((_store.sessions ?? const []).isEmpty) {
      return HermesEmptyState(
        icon: Icons.chat_bubble_outline,
        title: context.l10n.homeNoWorkTitle,
        description: context.l10n.homeNoWorkDescription,
      );
    }
    return HermesGlassCard(
      radius: HermesMobileMetrics.groupRadius,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _recentTile(rows[i], parents.contains(rows[i].row.id)),
            if (i < rows.length - 1) const Divider(height: 1, indent: 60),
          ],
        ],
      ),
    );
  }

  Widget _recentTile(SessionTreeItem item, bool hasChildren) {
    final row = item.row;
    final sessionColor = context.watch<SessionAppearanceStore>().colorFor(
      row.id,
    );
    return Padding(
      padding: EdgeInsets.only(left: item.depth * 24, top: 2, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HermesRadius.card),
          onTap: () => _openChat(row: row),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: FutureBuilder<bool>(
              future: _store.hasUnreadForSession(row),
              builder: (_, snap) => SessionCard(
                session: row,
                attention: row.needsAttention,
                working: !row.needsAttention && row.isActivelyWorking,
                unread: snap.data == true,
                sessionColor: sessionColor,
                childrenCount: hasChildren ? 1 : 0,
                expanded: _expanded.contains(row.id),
                expandButtonKey: ValueKey('home-session-toggle-${row.id}'),
                onToggleExpand: () => setState(() {
                  if (!_expanded.add(row.id)) _expanded.remove(row.id);
                }),
                onMore: () => SessionRowActions.show(
                  context,
                  session: row,
                  isArchived: row.archived,
                  isStarred: row.pinned,
                  onRefreshed: _load,
                ),
                extraBadges: SessionMetaBadges(row: row),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tool(String id, IconData icon, Widget page) => _ToolTile(
    icon: icon,
    label: _toolLabel(id),
    subtitle: _toolSubtitle(id),
    onTap: () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
  );

  String _toolLabel(String id) => switch (id) {
    'files' => context.l10n.featureFiles,
    'terminal' => context.l10n.featureTerminal,
    'git' => context.l10n.featureGit,
    'kanban' => context.l10n.navTasks,
    'agent' => context.l10n.featureAgent,
    'settings' => context.l10n.featureSettings,
    'projects' => context.l10n.featureProjects,
    'subagents' => context.l10n.featureSubagents,
    'knowledge' => context.l10n.homeToolKnowledge,
    'artifacts' => context.l10n.featureArtifacts,
    'cron' => context.l10n.featureCron,
    'insights' => context.l10n.featureInsights,
    _ => id,
  };

  String _toolSubtitle(String id) => switch (id) {
    'files' => context.l10n.featureFilesDesc,
    'terminal' => context.l10n.featureTerminalDesc,
    'git' => context.l10n.featureGitDesc,
    'kanban' => context.l10n.featureCronDesc,
    'agent' => context.l10n.featureAgentDesc,
    'settings' => context.l10n.featureSettingsDesc,
    'projects' => context.l10n.featureProjectsDesc,
    'subagents' => context.l10n.featureSubagentsDesc,
    'knowledge' => context.l10n.featureStarmapDesc,
    'artifacts' => context.l10n.featureArtifactsDesc,
    'cron' => context.l10n.featureCronDesc,
    'insights' => context.l10n.featureInsightsDesc,
    _ => context.l10n.homeAllFeatures,
  };

  Widget _quickTools() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < HermesBreakpoints.navigation;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      return GridView.builder(
        key: const ValueKey('home-quick-tools'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: compact ? 3 : 6,
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          mainAxisExtent: 105 + ((scale - 1).clamp(0, 1) * 45),
        ),
        itemBuilder: (context, index) {
          if (index < 5) {
            final id = _toolOrder[index];
            return Builder(
              key: ValueKey('quick-tool-$id'),
              builder: (context) {
                final tool = _toolSpecs[id]!;
                return _tool(tool.id, tool.icon, tool.builder(context));
              },
            );
          }
          return _moreTools(_toolOrder.skip(5));
        },
      );
    },
  );

  Widget _moreTools(Iterable<String> ids) => PopupMenuButton<String>(
    tooltip: context.l10n.homeMoreTools,
    onSelected: (id) {
      final tool = _toolSpecs[id]!;
      Navigator.of(context).push(MaterialPageRoute(builder: tool.builder));
    },
    itemBuilder: (_) => [for (final id in ids) _moreItem(_toolSpecs[id]!)],
    child: _ToolContent(
      icon: Icons.more_horiz,
      label: context.l10n.navMore,
      subtitle: context.l10n.homeAllFeatures,
    ),
  );

  PopupMenuItem<String> _moreItem(_HomeToolSpec tool) => PopupMenuItem(
    value: tool.id,
    child: Row(
      children: [
        Icon(tool.icon, size: 20),
        const SizedBox(width: 10),
        Text(_toolLabel(tool.id)),
      ],
    ),
  );
}

class _HomeToolSpec {
  const _HomeToolSpec({
    required this.id,
    required this.icon,
    required this.builder,
  });

  final String id;
  final IconData icon;
  final WidgetBuilder builder;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.action,
    required this.onTap,
    this.busy = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return HermesMobileCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              HermesMobileStatusChip(
                label: busy
                    ? context.l10n.statusRunning
                    : context.l10n.statusReady,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.text3),
          ),
          if (busy) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 7,
                color: color,
                backgroundColor: palette.codeBg,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.only(top: 5, right: 8),
              ),
              onPressed: onTap,
              child: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => HermesMobileQuickTile(
    icon: icon,
    title: label,
    subtitle: subtitle,
    onTap: onTap,
  );
}

class _ToolContent extends StatelessWidget {
  const _ToolContent({
    required this.icon,
    required this.label,
    required this.subtitle,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(HermesMobileMetrics.tileRadius),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.accentBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: palette.accent),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.text3, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
