/// Single source of truth for Hermes feature entries (icons, titles,
/// subtitles, routes) shared by the Home quick-tools grid, the More
/// directory and the XL side navigation.
///
/// Lives next to the screens it routes to: every entry references a screen
/// widget, and nothing under `lib/core` may import `lib/screens`, so this
/// registry cannot sit in `lib/core` without inverting that layering.
///
/// Icons are canonical per feature: when Home/More/XL previously disagreed,
/// the value matching the feature's own screens and shared widgets wins
/// (e.g. `smart_toy_outlined` for Agent, `inventory_2_outlined` for
/// Artifacts, `account_tree_outlined` for Git).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/command_palette_store.dart';
import '../l10n/l10n.dart';
import '../widgets/pet_overlay.dart';
import 'about_screen.dart';
import 'agent_screen.dart';
import 'artifacts_screen.dart';
import 'command_center_screen.dart';
import 'cron_screen.dart';
import 'files_screen.dart';
import 'git_screen.dart';
import 'insights_screen.dart';
import 'kanban_canonical_screen.dart';
import 'knowledge_screen.dart';
import 'mcp_screen.dart';
import 'memory_screen.dart';
import 'notification_screen.dart';
import 'pane_workspace_screen.dart';
import 'plugins_screen.dart';
import 'project_screen.dart';
import 'settings_hub_screen.dart';
import 'skills_screen.dart';
import 'starmap_screen.dart';
import 'subagents_screen.dart';
import 'terminal_screen.dart';
import 'tools_screen.dart';

/// More-directory grouping. Also used to express deliberate per-surface
/// visibility differences without flattening them away.
enum HermesFeatureGroup { workspace, intelligence, configuration, system }

extension HermesFeatureGroupL10n on HermesFeatureGroup {
  /// Section label shown by the More directory (existing l10n keys).
  String label(AppLocalizations l10n) => switch (this) {
    HermesFeatureGroup.workspace => l10n.groupWorkspace,
    HermesFeatureGroup.intelligence => l10n.groupIntelligence,
    HermesFeatureGroup.configuration => l10n.groupConfiguration,
    HermesFeatureGroup.system => l10n.groupSystem,
  };
}

typedef HermesFeatureText = String Function(AppLocalizations l10n);

/// One navigable feature: stable [id], canonical [icon], localized
/// [title]/[subtitle], and either a [builder] route or a custom [onOpen]
/// action (workspace picker, command palette).
class HermesFeatureEntry {
  HermesFeatureEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.group,
    this.builder,
    this.onOpen,
    this.showInHome = false,
    this.showInMore = true,
    this.showInXlNav = false,
    this.searchAliases = const [],
  });

  /// Stable identifier, also used by the persisted Home quick-tool order
  /// (`hm_home_quick_tool_order`) and widget keys (`quick-tool-<id>`).
  final String id;

  /// Explicit alternate names, never used as labels or route identifiers.
  final List<String> searchAliases;

  bool matchesSearch(String query, AppLocalizations l10n) {
    final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
    final fields = [
      id,
      title(l10n),
      subtitle(l10n),
      ...searchAliases,
    ].map((value) => value.toLowerCase()).toList();
    return terms.every((term) => fields.any((field) => field.contains(term)));
  }

  /// Canonical icon shared by every surface.
  final IconData icon;

  /// Title/subtitle resolvers over the existing l10n keys.
  final HermesFeatureText title;
  final HermesFeatureText subtitle;

  /// More-directory group (meaningful only when [showInMore]).
  final HermesFeatureGroup group;

  /// Route builder, or a custom action (workspace picker, command palette).
  final WidgetBuilder? builder;
  final void Function(BuildContext context)? onOpen;

  /// Surface visibility flags. Most entries live in More; Home shows the
  /// quick-tool subset, XL side nav shows its own subset. Differences are
  /// deliberate (e.g. `kanban` is Home-only, `skills` skips Home).
  final bool showInHome;
  final bool showInMore;
  final bool showInXlNav;

  /// Default navigation: push the builder route, unless a custom action
  /// (workspace picker, command palette) replaces it.
  void open(BuildContext context) {
    final custom = onOpen;
    if (custom != null) {
      custom(context);
      return;
    }
    final route = builder;
    if (route == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: route));
  }
}

/// All feature entries, ordered by More-directory group and row order.
final List<HermesFeatureEntry> hermesFeatureEntries = [
  // Workspace
  HermesFeatureEntry(
    id: 'agent',
    searchAliases: ['bot', '机器人', '機器人'],
    icon: Icons.smart_toy_outlined,
    title: (l10n) => l10n.featureAgent,
    subtitle: (l10n) => l10n.featureAgentDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const AgentScreen(),
    showInHome: true,
    showInXlNav: true,
  ),
  HermesFeatureEntry(
    id: 'workspace',
    searchAliases: ['工作区', '工作區', '多窗格', 'panes'],
    icon: Icons.view_quilt_outlined,
    title: (l10n) => l10n.workspaceTitle,
    subtitle: (l10n) => l10n.workspaceDescription,
    group: HermesFeatureGroup.workspace,
    onOpen: (context) => openWorkspaceScreen(Navigator.of(context)),
  ),
  HermesFeatureEntry(
    id: 'files',
    searchAliases: ['file', '文件', '檔案'],
    icon: Icons.folder_outlined,
    title: (l10n) => l10n.featureFiles,
    subtitle: (l10n) => l10n.featureFilesDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const FilesScreen(),
    showInHome: true,
    showInXlNav: true,
  ),
  HermesFeatureEntry(
    id: 'terminal',
    searchAliases: ['shell', '终端', '終端機'],
    icon: Icons.terminal,
    title: (l10n) => l10n.featureTerminal,
    subtitle: (l10n) => l10n.featureTerminalDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const TerminalScreen(),
    showInHome: true,
    showInXlNav: true,
  ),
  HermesFeatureEntry(
    id: 'git',
    searchAliases: ['版本控制', 'version control'],
    icon: Icons.account_tree_outlined,
    title: (l10n) => l10n.featureGit,
    subtitle: (l10n) => l10n.featureGitDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const GitScreen(),
    showInHome: true,
    showInXlNav: true,
  ),
  HermesFeatureEntry(
    id: 'artifacts',
    icon: Icons.inventory_2_outlined,
    title: (l10n) => l10n.featureArtifacts,
    subtitle: (l10n) => l10n.featureArtifactsDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const ArtifactsScreen(),
    showInHome: true,
  ),
  HermesFeatureEntry(
    id: 'projects',
    searchAliases: ['项目', '專案'],
    icon: Icons.layers_outlined,
    title: (l10n) => l10n.featureProjects,
    subtitle: (l10n) => l10n.featureProjectsDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const ProjectScreen(),
    showInHome: true,
  ),
  HermesFeatureEntry(
    id: 'insights',
    icon: Icons.query_stats_outlined,
    title: (l10n) => l10n.featureInsights,
    subtitle: (l10n) => l10n.featureInsightsDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const InsightsScreen(),
    showInHome: true,
  ),
  HermesFeatureEntry(
    id: 'cron',
    searchAliases: ['schedule', '定时', '排程'],
    icon: Icons.schedule_outlined,
    title: (l10n) => l10n.featureCron,
    subtitle: (l10n) => l10n.featureCronDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const CronScreen(),
    showInHome: true,
  ),
  // Intelligence
  HermesFeatureEntry(
    id: 'subagents',
    icon: Icons.groups_outlined,
    title: (l10n) => l10n.featureSubagents,
    subtitle: (l10n) => l10n.featureSubagentsDesc,
    group: HermesFeatureGroup.intelligence,
    builder: (_) => const SubagentsScreen(),
    showInHome: true,
  ),
  HermesFeatureEntry(
    id: 'skills',
    icon: Icons.bolt_outlined,
    title: (l10n) => l10n.featureSkills,
    subtitle: (l10n) => l10n.featureSkillsDesc,
    group: HermesFeatureGroup.intelligence,
    builder: (_) => const SkillsScreen(),
    showInXlNav: true,
  ),
  HermesFeatureEntry(
    id: 'starmap',
    icon: Icons.hub_outlined,
    title: (l10n) => l10n.featureStarmap,
    subtitle: (l10n) => l10n.featureStarmapDesc,
    group: HermesFeatureGroup.intelligence,
    builder: (_) => const StarmapScreen(),
  ),
  HermesFeatureEntry(
    id: 'memory',
    icon: Icons.memory_outlined,
    title: (l10n) => l10n.featureMemory,
    subtitle: (l10n) => l10n.featureMemoryDesc,
    group: HermesFeatureGroup.intelligence,
    builder: (_) => const MemoryScreen(),
  ),
  HermesFeatureEntry(
    id: 'knowledge',
    icon: Icons.menu_book_outlined,
    title: (l10n) => l10n.homeToolKnowledge,
    subtitle: (l10n) => l10n.configCenterKnowledgeEmptyDescription,
    group: HermesFeatureGroup.intelligence,
    builder: (_) => const KnowledgeScreen(),
    showInHome: true,
  ),
  HermesFeatureEntry(
    id: 'pet',
    icon: Icons.pets_outlined,
    title: (l10n) => l10n.featurePet,
    subtitle: (l10n) => l10n.featurePetDesc,
    group: HermesFeatureGroup.intelligence,
    builder: (_) => const PetCenterScreen(),
  ),
  // Configuration
  HermesFeatureEntry(
    id: 'mcp',
    icon: Icons.hub_outlined,
    title: (l10n) => l10n.featureMcp,
    subtitle: (l10n) => l10n.featureMcpDesc,
    group: HermesFeatureGroup.configuration,
    builder: (_) => const McpScreen(),
  ),
  HermesFeatureEntry(
    id: 'plugins',
    icon: Icons.extension_outlined,
    title: (l10n) => l10n.featurePlugins,
    subtitle: (l10n) => l10n.featurePluginsDesc,
    group: HermesFeatureGroup.configuration,
    builder: (_) => const PluginsScreen(),
  ),
  HermesFeatureEntry(
    id: 'tools',
    icon: Icons.build_outlined,
    title: (l10n) => l10n.featureTools,
    subtitle: (l10n) => l10n.featureToolsDesc,
    group: HermesFeatureGroup.configuration,
    builder: (_) => const ToolsScreen(),
  ),
  // System
  HermesFeatureEntry(
    id: 'notifications',
    icon: Icons.notifications_outlined,
    title: (l10n) => l10n.commonNotifications,
    subtitle: (l10n) => l10n.featureNotificationsDesc,
    group: HermesFeatureGroup.system,
    builder: (_) => const NotificationScreen(),
  ),
  HermesFeatureEntry(
    id: 'settings',
    searchAliases: ['appearance', 'theme', '外观', '外觀', '设置', '設定'],
    icon: Icons.settings_outlined,
    title: (l10n) => l10n.featureSettings,
    subtitle: (l10n) => l10n.featureSettingsDesc,
    group: HermesFeatureGroup.system,
    builder: (_) => const SettingsHubScreen(),
    showInHome: true,
    showInXlNav: true,
  ),
  HermesFeatureEntry(
    id: 'commandCenter',
    icon: Icons.monitor_heart_outlined,
    title: (l10n) => l10n.featureCommandCenter,
    subtitle: (l10n) => l10n.featureCommandCenterDesc,
    group: HermesFeatureGroup.system,
    builder: (_) => const CommandCenterScreen(),
  ),
  HermesFeatureEntry(
    id: 'globalSearch',
    icon: Icons.search,
    title: (l10n) => l10n.globalSearch,
    subtitle: (l10n) => l10n.featureGlobalSearchDesc,
    group: HermesFeatureGroup.system,
    onOpen: (context) => context.read<CommandPaletteStore>().open(),
  ),
  HermesFeatureEntry(
    id: 'about',
    icon: Icons.info_outline,
    title: (l10n) => l10n.featureAbout,
    subtitle: (l10n) => l10n.featureAboutDesc,
    group: HermesFeatureGroup.system,
    builder: (_) => const AboutScreen(),
    showInXlNav: true,
  ),
  // Home quick-tools only (the Kanban board is a primary tab elsewhere, so
  // it is deliberately absent from More and the XL side nav).
  HermesFeatureEntry(
    id: 'kanban',
    icon: Icons.view_kanban_outlined,
    title: (l10n) => l10n.navTasks,
    // Pre-existing Home copy reused as-is; there is no dedicated kanban
    // description key and adding arb keys is out of scope here.
    subtitle: (l10n) => l10n.featureCronDesc,
    group: HermesFeatureGroup.workspace,
    builder: (_) => const KanbanCanonicalScreen(),
    showInHome: true,
    showInMore: false,
  ),
];

/// Lookup by stable [HermesFeatureEntry.id].
final Map<String, HermesFeatureEntry> hermesFeaturesById = {
  for (final entry in hermesFeatureEntries) entry.id: entry,
};

/// Default Home quick-tool order (persisted user order lives in
/// SharedPreferences under `hm_home_quick_tool_order`).
const List<String> hermesHomeDefaultToolOrder = [
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

/// Ids valid for the Home quick-tools grid (the reorderable subset).
final Set<String> hermesHomeToolIds = {
  for (final entry in hermesFeatureEntries)
    if (entry.showInHome) entry.id,
};

/// More-directory rows for [group], in display order.
List<HermesFeatureEntry> hermesMoreEntries(HermesFeatureGroup group) => [
  for (final entry in hermesFeatureEntries)
    if (entry.showInMore && entry.group == group) entry,
];
