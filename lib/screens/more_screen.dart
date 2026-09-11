import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/stores/connection_store.dart';
import '../core/stores/pane_workspace_store.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../theme/hermes_glass_theme.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_search_field.dart';
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
  final _searchController = TextEditingController();
  final _searchActionFocus = FocusNode(debugLabel: 'More search action');
  final _searchFieldFocus = FocusNode(debugLabel: 'More search field');
  final _directoryScroll = ScrollController();
  final _searchScroll = ScrollController();
  double _directoryOffset = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _searchActionFocus.dispose();
    _searchFieldFocus.dispose();
    _directoryScroll.dispose();
    _searchScroll.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (!_searching && _directoryScroll.hasClients) {
      _directoryOffset = _directoryScroll.offset;
    }
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_searching ? _searchFieldFocus : _searchActionFocus).requestFocus();
      final controller = _searching ? _searchScroll : _directoryScroll;
      if (!controller.hasClients) return;
      controller.jumpTo(
        (_searching ? 0.0 : _directoryOffset).clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        ),
      );
    });
  }

  bool _matches(_MenuEntry entry) {
    return entry.feature.matchesSearch(_query, context.l10n);
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
                entry,
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

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (_searching &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          final composing = _searchController.value.composing;
          if (composing.isValid && !composing.isCollapsed) {
            // Let the platform IME cancel/finish its composition first.
            return KeyEventResult.ignored;
          }
          _toggleSearch();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: HermesPageScaffold(
        title: l10n.navMore,
        separateHeader: HermesGlassTheme.of(context).enabled,
        titleMode: HermesPageTitleMode.large,
        scrollBodyBehindHeader: true,
        maxContentWidth: HermesLayout.content,
        actions: [
          if (HermesGlassTheme.of(context).enabled)
            GlassButton(
              focusNode: _searchActionFocus,
              tooltip: _searching
                  ? l10n.moreCloseSearch
                  : l10n.moreSearchDirectory,
              selected: _searching,
              onPressed: _toggleSearch,
              child: Icon(_searching ? Icons.close : Icons.search),
            )
          else
            IconButton(
              focusNode: _searchActionFocus,
              tooltip: _searching
                  ? l10n.moreCloseSearch
                  : l10n.moreSearchDirectory,
              onPressed: _toggleSearch,
              icon: Icon(_searching ? Icons.close : Icons.search),
            ),
        ],
        body: ListView(
          // Search has its own reading position. Do not reuse a deep directory
          // offset when inserting the field, or lose it when returning.
          key: PageStorageKey(_searching ? 'more-search' : 'more-directory'),
          controller: _searching ? _searchScroll : _directoryScroll,
          padding: const EdgeInsets.fromLTRB(
            HermesMobileMetrics.pagePadding,
            HermesMobileMetrics.pagePadding,
            HermesMobileMetrics.pagePadding,
            28,
          ),
          children: [
            if (!_searching) ...[
              const _PluginPaneLaunchers(),
              const PluginContributionSurface(
                area: MobileContributionArea.navigation,
              ),
              HermesMobileCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HermesAgentAvatar(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hermes Mobile',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: palette.text),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              HermesStatusChip(
                                label: connected
                                    ? l10n.commonOnline
                                    : l10n.commonOffline,
                                color: connected
                                    ? (dark
                                          ? HermesSemanticDark.green
                                          : HermesSemantic.green)
                                    : statusColor,
                              ),
                              if (connected)
                                Text(
                                  running
                                      ? l10n.commonRunning
                                      : l10n.commonIdle,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: palette.text3),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_searching) ...[
              const SizedBox(height: 10),
              if (HermesGlassTheme.of(context).enabled)
                GlassSearchField(
                  focusNode: _searchFieldFocus,
                  controller: _searchController,
                  autofocus: true,
                  hintText: l10n.moreSearchHint,
                  onChanged: (value) => setState(() => _query = value),
                )
              else
                TextField(
                  focusNode: _searchFieldFocus,
                  controller: _searchController,
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
                      alignLeadingToTop: true,
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: palette.text2),
                  ),
                ),
              ),
          ],
        ),
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
                      fallback: context.l10n.workspaceOpenPluginFailed(
                        '$error',
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

class _MenuEntry {
  const _MenuEntry(
    this.feature,
    this.icon,
    this.title,
    this.subtitle,
    this.onTap,
  );

  final HermesFeatureEntry feature;

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
