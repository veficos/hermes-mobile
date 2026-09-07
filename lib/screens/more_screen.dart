import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/connection_store.dart';
import '../core/stores/pane_workspace_store.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_logo.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/plugin_contribution_surface.dart';
import 'feature_registry.dart';
import 'pane_workspace_screen.dart';

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
    final groups = [
      for (final group in HermesFeatureGroup.values)
        (
          group.label(l10n),
          switch (group) {
            HermesFeatureGroup.workspace => tones[0],
            HermesFeatureGroup.intelligence => tones[1],
            HermesFeatureGroup.configuration => tones[2],
            HermesFeatureGroup.system => tones[4],
          },
          [
            for (final entry in hermesMoreEntries(group))
              _MenuEntry(
                entry.icon,
                entry.title(l10n),
                entry.subtitle(l10n),
                () => entry.open(context),
              ),
          ],
        ),
    ];
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
                const HermesAgentAvatar(size: 40),
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
                HermesStatusChip(
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
            HermesSectionHeader(
              title: name,
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            ),
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
                  await openWorkspaceScreen(Navigator.of(context));
                } catch (error) {
                  if (context.mounted) {
                    showHermesErrorSnackBar(
                      context,
                      error,
                      fallback: context.l10n.workspaceOpenPluginFailed('$error'),
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

class _MenuEntry {
  const _MenuEntry(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
