import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/diagnostics.dart';
import '../core/external_links.dart';
import '../core/stores/command_palette_store.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/pane_workspace_store.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../core/stores/session_store.dart';
import '../core/stores/update_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import '../widgets/pet_overlay.dart';
import '../widgets/plugin_contribution_surface.dart';
import 'agent_screen.dart';
import 'artifacts_screen.dart';
import 'billing_screen.dart';
import 'command_center_screen.dart';
import 'connect_screen.dart';
import 'credentials_screen.dart';
import 'cron_screen.dart';
import 'files_screen.dart';
import 'git_screen.dart';
import 'insights_screen.dart';
import 'mcp_screen.dart';
import 'memory_screen.dart';
import 'messaging_screen.dart';
import 'notification_screen.dart';
import 'plugins_screen.dart';
import 'profiles_screen.dart';
import 'project_screen.dart';
import 'settings_hub_screen.dart';
import 'pane_workspace_screen.dart';
import 'skills_screen.dart';
import 'starmap_screen.dart';
import 'subagents_screen.dart';
import 'terminal_screen.dart';
import 'tools_screen.dart';
import 'webhooks_screen.dart';

/// Low-frequency feature directory. Its grouping, compact identity card and
/// semantic icon colors mirror `docs/mobile-ui-prototype.html`.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _query = '';
  bool _searching = false;

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  bool _matches(_MenuEntry entry) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty ||
        entry.title.toLowerCase().contains(query) ||
        entry.subtitle.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = HermesPalette.of(context);
    final connection = context.watch<ConnectionStore>();
    final session = context.watch<SessionStore>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tones = [
      dark ? HermesSemanticDark.blue : HermesSemantic.blue,
      dark ? HermesSemanticDark.purple : HermesSemantic.purple,
      dark ? HermesSemanticDark.gray : HermesSemantic.gray,
      dark ? HermesSemanticDark.green : HermesSemantic.green,
      dark ? HermesSemanticDark.orange : HermesSemantic.orange,
    ];
    final groups = _groups(context, connection, tones);
    final visibleGroups = [
      for (final group in groups)
        (group.$1, group.$2, group.$3.where(_matches).toList()),
    ].where((group) => group.$3.isNotEmpty).toList();
    final connected = connection.isConnected;
    final running = session.info?.running == true;
    final statusColor = running
        ? (dark ? HermesSemanticDark.green : HermesSemantic.green)
        : (dark ? HermesSemanticDark.gray : HermesSemantic.gray);

    return MobilePageScaffold(
      title: l10n.navMore,
      actions: [
        IconButton(
          tooltip: _searching ? l10n.moreCloseSearch : l10n.moreSearchDirectory,
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _query = '';
          }),
          icon: Icon(_searching ? Icons.close : Icons.search),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HermesMobileMetrics.pagePadding,
          HermesMobileMetrics.pagePadding,
          HermesMobileMetrics.pagePadding,
          28,
        ),
        children: [
          const _PluginPaneLaunchers(),
          const PluginContributionSurface(
            area: MobileContributionArea.navigation,
          ),
          HermesMobileCard(
            child: Row(
              children: [
                Container(
                  width: 37,
                  height: 37,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [palette.accent, palette.accentHover],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    'H',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hermes Mobile',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.moreStatus(
                          connected
                              ? l10n.commonConnected
                              : l10n.commonDisconnected,
                          running ? l10n.commonRunning : l10n.commonIdle,
                        ),
                        style: TextStyle(color: palette.text3, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                HermesMobileStatusChip(
                  label: connected ? l10n.commonOnline : l10n.commonOffline,
                  color: connected
                      ? (dark ? HermesSemanticDark.green : HermesSemantic.green)
                      : statusColor,
                ),
              ],
            ),
          ),
          if (_searching) ...[
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: l10n.moreSearchHint,
                isDense: true,
              ),
            ),
          ],
          for (final (name, tone, entries) in visibleGroups) ...[
            HermesMobileSectionLabel(title: name),
            HermesMobileGroup(
              children: [
                for (final entry in entries)
                  HermesMobileRow(
                    icon: entry.icon,
                    title: entry.title,
                    subtitle: entry.subtitle,
                    tone: tone,
                    onTap: entry.onTap,
                  ),
              ],
            ),
          ],
          if (_query.trim().isNotEmpty && visibleGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  l10n.moreNoMatches,
                  style: TextStyle(color: palette.text3, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<(String, Color, List<_MenuEntry>)> _groups(
    BuildContext context,
    ConnectionStore connection,
    List<Color> tones,
  ) => [
    (
      context.l10n.groupWorkspace,
      tones[0],
      [
        _MenuEntry(
          Icons.view_quilt_outlined,
          context.l10n.workspaceTitle,
          context.l10n.workspaceDescription,
          () => _push(const PaneWorkspaceScreen()),
        ),
        _MenuEntry(
          Icons.folder_outlined,
          context.l10n.featureFiles,
          context.l10n.featureFilesDesc,
          () => _push(const FilesScreen()),
        ),
        _MenuEntry(
          Icons.terminal_outlined,
          context.l10n.featureTerminal,
          context.l10n.featureTerminalDesc,
          () => _push(const TerminalScreen()),
        ),
        _MenuEntry(
          Icons.account_tree_outlined,
          'Git',
          context.l10n.featureGitDesc,
          () => _push(const GitScreen()),
        ),
        _MenuEntry(
          Icons.inventory_2_outlined,
          context.l10n.featureArtifacts,
          context.l10n.featureArtifactsDesc,
          () => _push(const ArtifactsScreen()),
        ),
        _MenuEntry(
          Icons.layers_outlined,
          context.l10n.featureProjects,
          context.l10n.featureProjectsDesc,
          () => _push(const ProjectScreen()),
        ),
        _MenuEntry(
          Icons.bar_chart_outlined,
          context.l10n.featureInsights,
          context.l10n.featureInsightsDesc,
          () => _push(const InsightsScreen()),
        ),
        _MenuEntry(
          Icons.schedule_outlined,
          context.l10n.featureCron,
          context.l10n.featureCronDesc,
          () => _push(const CronScreen()),
        ),
      ],
    ),
    (
      context.l10n.groupIntelligence,
      tones[1],
      [
        _MenuEntry(
          Icons.auto_awesome_outlined,
          'Agent',
          context.l10n.featureAgentDesc,
          () => _push(const AgentScreen()),
        ),
        _MenuEntry(
          Icons.account_tree_outlined,
          context.l10n.featureSubagents,
          context.l10n.featureSubagentsDesc,
          () => _push(const SubagentsScreen()),
        ),
        _MenuEntry(
          Icons.bolt_outlined,
          context.l10n.featureSkills,
          context.l10n.featureSkillsDesc,
          () => _push(const SkillsScreen()),
        ),
        _MenuEntry(
          Icons.hub_outlined,
          context.l10n.featureStarmap,
          context.l10n.featureStarmapDesc,
          () => _push(const StarmapScreen()),
        ),
        _MenuEntry(
          Icons.memory_outlined,
          context.l10n.featureMemory,
          context.l10n.featureMemoryDesc,
          () => _push(const MemoryScreen()),
        ),
        _MenuEntry(
          Icons.pets_outlined,
          context.l10n.featurePet,
          context.l10n.featurePetDesc,
          () => _push(const PetCenterScreen()),
        ),
      ],
    ),
    (
      context.l10n.groupConfiguration,
      tones[2],
      [
        _MenuEntry(
          Icons.hub_outlined,
          'MCP',
          context.l10n.featureMcpDesc,
          () => _push(const McpScreen()),
        ),
        _MenuEntry(
          Icons.extension_outlined,
          context.l10n.featurePlugins,
          context.l10n.featurePluginsDesc,
          () => _push(const PluginsScreen()),
        ),
        _MenuEntry(
          Icons.build_outlined,
          context.l10n.featureTools,
          context.l10n.featureToolsDesc,
          () => _push(const ToolsScreen()),
        ),
        _MenuEntry(
          Icons.person_outline,
          context.l10n.featureProfiles,
          context.l10n.featureProfilesDesc,
          () => _push(const ProfilesScreen()),
        ),
      ],
    ),
    (
      context.l10n.groupIntegrations,
      tones[3],
      [
        _MenuEntry(
          Icons.chat_outlined,
          context.l10n.featureMessaging,
          context.l10n.featureMessagingDesc,
          () => _push(const MessagingScreen()),
        ),
        _MenuEntry(
          Icons.webhook_outlined,
          'Webhooks',
          context.l10n.featureWebhooksDesc,
          () => _push(const WebhooksScreen()),
        ),
        _MenuEntry(
          Icons.vpn_key_outlined,
          context.l10n.featureCredentials,
          context.l10n.featureCredentialsDesc,
          () => _push(const CredentialsScreen()),
        ),
        _MenuEntry(
          Icons.account_balance_wallet_outlined,
          context.l10n.featureBilling,
          context.l10n.featureBillingDesc,
          () => _push(const BillingScreen()),
        ),
      ],
    ),
    (
      context.l10n.groupSystem,
      tones[4],
      [
        _MenuEntry(
          Icons.notifications_outlined,
          context.l10n.commonNotifications,
          context.l10n.featureNotificationsDesc,
          () => _push(const NotificationScreen()),
        ),
        _MenuEntry(
          Icons.tune_outlined,
          context.l10n.featureSettings,
          context.l10n.featureSettingsDesc,
          () => _push(const SettingsHubScreen()),
        ),
        _MenuEntry(
          Icons.cloud_outlined,
          context.l10n.featureConnection,
          connection.isConfigured
              ? '${connection.isConnected ? context.l10n.commonConnected : context.l10n.commonDisconnected} · ${connection.settings.serverUrl}'
              : context.l10n.featureConnectionDesc,
          () => _push(const ConnectScreen()),
        ),
        _MenuEntry(
          Icons.monitor_heart_outlined,
          context.l10n.featureCommandCenter,
          context.l10n.featureCommandCenterDesc,
          () => _push(const CommandCenterScreen()),
        ),
        _MenuEntry(
          Icons.search,
          context.l10n.globalSearch,
          context.l10n.featureGlobalSearchDesc,
          () => context.read<CommandPaletteStore>().open(),
        ),
        _MenuEntry(
          Icons.info_outline,
          context.l10n.featureAbout,
          context.l10n.featureAboutDesc,
          () => _push(const _AboutScreen()),
        ),
      ],
    ),
  ];
}

class _PluginPaneLaunchers extends StatelessWidget {
  const _PluginPaneLaunchers();

  @override
  Widget build(BuildContext context) {
    PluginContributionStore store;
    try {
      store = context.watch<PluginContributionStore>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final items = store.forArea(MobileContributionArea.pane);
    if (items.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            ActionChip(
              avatar: const Icon(Icons.view_quilt_outlined, size: 16),
              label: Text(item.localizedTitle(locale)),
              tooltip: item.localizedDescription(locale),
              onPressed: () async {
                try {
                  await context.read<PaneWorkspaceStore>().openPlugin(item);
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PaneWorkspaceScreen(),
                    ),
                  );
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.workspaceOpenPluginFailed('$error'),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    final updates = Provider.of<UpdateStore?>(context);
    final l10n = context.l10n;
    final version = updates?.currentVersion ?? '1.0.0';
    final build = updates?.currentBuild ?? '1';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          HermesMobileCard(
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HermesPalette.of(context).accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'H',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hermes Mobile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  l10n.updateVersionBuild(version, build),
                  style: TextStyle(
                    color: HermesPalette.of(context).text3,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          HermesMobileSectionLabel(title: l10n.updateSectionTitle),
          HermesMobileGroup(
            children: [
              if (updates?.requiresUpdate == true)
                ListTile(
                  leading: const Icon(
                    Icons.warning_amber_outlined,
                    color: HermesSemantic.red,
                  ),
                  title: Text(l10n.updateUnsupportedTitle),
                  subtitle: Text(
                    l10n.updateMinimumVersion(
                      updates!.manifest!.minimumSupportedVersion,
                    ),
                  ),
                )
              else if (updates?.updateAvailable == true)
                ListTile(
                  leading: const Icon(
                    Icons.system_update_outlined,
                    color: HermesSemantic.green,
                  ),
                  title: Text(
                    l10n.updateAvailableTitle(updates!.manifest!.latestVersion),
                  ),
                  subtitle: Text(
                    updates.manifest?.message ?? l10n.updateNewVersionPublished,
                  ),
                )
              else
                ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(l10n.updateAppVersion),
                  subtitle: Text(l10n.updateVersionBuild(version, build)),
                ),
              ListTile(
                leading: updates?.checking == true
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                title: Text(l10n.updateCheck),
                subtitle: updates?.error == null
                    ? Text(l10n.updateCheckDescription)
                    : Text(l10n.updateCheckUnavailable(updates!.error!)),
                enabled: updates != null && !updates.checking,
                onTap: updates == null || updates.checking
                    ? null
                    : () async {
                        final ok = await updates.check(force: true);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? updates.updateAvailable
                                        ? l10n.updateFound(
                                            updates.manifest!.latestVersion,
                                          )
                                        : l10n.updateCurrent
                                  : l10n.updateCheckFailed,
                            ),
                          ),
                        );
                      },
              ),
              if (updates?.updateAvailable == true ||
                  updates?.requiresUpdate == true)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: Text(l10n.updateGoToUpdate),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () =>
                      launchExternalOrNotify(context, updates!.updateUri),
                ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(l10n.updateReleaseNotes),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => launchExternalOrNotify(
                  context,
                  updates?.releaseNotesUri ??
                      Uri.parse(
                        'https://github.com/NousResearch/hermes-agent/releases',
                      ),
                ),
              ),
            ],
          ),
          HermesMobileSectionLabel(title: l10n.helpAndFeedbackTitle),
          HermesMobileGroup(
            children: [
              HermesMobileRow(
                icon: Icons.bug_report_outlined,
                title: l10n.sendDiagnosticsTitle,
                subtitle: l10n.sendDiagnosticsSubtitle,
                onTap: () => showSendDiagnosticsDialog(context),
              ),
              HermesMobileRow(
                icon: Icons.forum_outlined,
                title: l10n.reportIssueTitle,
                onTap: () => launchExternalOrNotify(
                  context,
                  Uri.parse(
                    'https://github.com/NousResearch/hermes-agent/issues',
                  ),
                ),
              ),
              HermesMobileRow(
                icon: Icons.chat_bubble_outline,
                title: l10n.discordCommunityTitle,
                onTap: () => launchExternalOrNotify(
                  context,
                  Uri.parse('https://discord.gg/NousResearch'),
                ),
              ),
            ],
          ),
          HermesMobileSectionLabel(title: l10n.legalTitle),
          HermesMobileGroup(
            children: [
              HermesMobileRow(
                icon: Icons.code,
                title: l10n.aboutLicenses,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Hermes Mobile',
                  applicationVersion: version,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
