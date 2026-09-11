/// CommandPalette: top search overlay for navigation, sessions and slash
/// commands (Batch 8 of the desktop migration).
///
/// Mirrors the desktop renderer's Cmd+K palette. On mobile it's triggered by
/// a search button in the app bar; on tablet by a keyboard shortcut.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_navigation.dart';
import '../core/models.dart';
import '../core/stores/command_palette_store.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../screens/artifacts_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/command_center_screen.dart';
import '../screens/files_screen.dart';
import '../screens/git_screen.dart';
import '../screens/kanban_canonical_screen.dart';
import '../screens/knowledge_screen.dart';
import '../screens/new_session_screen.dart';
import '../screens/project_screen.dart';
import '../screens/session_list_screen.dart';
import '../screens/settings_hub_screen.dart';
import '../screens/subagents_screen.dart';
import '../screens/terminal_screen.dart';
import '../theme/hermes_tokens.dart';
import '../theme/hermes_glass_theme.dart';
import 'glass/glass_surface.dart';
import 'glass/glass_selection_row.dart';
import 'h/hermes_glass.dart';
import 'h/hermes_kbd.dart';
import 'h/hermes_states.dart';
import 'pet_overlay.dart';

class _PaletteSurface extends StatelessWidget {
  const _PaletteSurface({required this.desktop, required this.child});
  final bool desktop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (HermesGlassTheme.of(context).enabled) {
      return GlassSurface(
        key: const ValueKey('command-palette-glass'),
        radius: 28,
        role: HermesGlassRole.overlay,
        child: Material(type: MaterialType.transparency, child: child),
      );
    }
    return HermesGlassCard(
      padding: EdgeInsets.zero,
      radius: desktop ? HermesRadius.largeCard : 0,
      tint: HermesPalette.of(context).elevated,
      shadow: HermesShadowTier.md,
      child: child,
    );
  }
}

class CommandPalette extends StatelessWidget {
  const CommandPalette({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<CommandPaletteStore>();
    palette.setLocalizations(context.l10n);
    if (!palette.isOpen) return const SizedBox.shrink();

    return CommandPaletteOverlay(palette: palette);
  }
}

class CommandPaletteOverlay extends StatefulWidget {
  final CommandPaletteStore palette;
  const CommandPaletteOverlay({super.key, required this.palette});

  @override
  State<CommandPaletteOverlay> createState() => _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends State<CommandPaletteOverlay> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _selectedResult = GlobalKey();
  final _resultsScroll = ScrollController();

  void _setQuery(String query) {
    widget.palette.setQuery(query);
    if (_resultsScroll.hasClients) _resultsScroll.jumpTo(0);
  }

  void _moveSelection(int delta) {
    widget.palette.moveSelection(delta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _selectedResult.currentContext;
      if (target != null) Scrollable.ensureVisible(target);
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.text = widget.palette.query;
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _resultsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = HermesPalette.of(context);
    final l10n = context.l10n;
    final palette = widget.palette;
    final results = palette.results;
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 840;
    final liquid = HermesGlassTheme.of(context).enabled;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // The palette is not a route: intercept the system back button so the
    // first press closes the palette instead of popping the route below.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) palette.close();
      },
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moveSelection(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moveSelection(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            _selectCurrent(context);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            palette.close();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => palette.close(),
          child: Container(
            color: Colors.black54,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {},
                child: Align(
                  alignment: isDesktop ? Alignment.topCenter : Alignment.center,
                  child: Padding(
                    padding: liquid
                        ? EdgeInsets.fromLTRB(
                            12,
                            isDesktop ? 24 : 12,
                            12,
                            keyboard + (isDesktop ? 24 : 12),
                          )
                        : isDesktop
                        ? const EdgeInsets.symmetric(vertical: 24)
                        : EdgeInsets.zero,
                    // §6.12 Popover：elevated 底 + shadow-md。
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 640 : double.infinity,
                        maxHeight: isDesktop
                            ? size.height * 0.7
                            : double.infinity,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: isDesktop || liquid ? null : double.infinity,
                        child: _PaletteSurface(
                          desktop: isDesktop,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Search field
                              Semantics(
                                textField: true,
                                label: l10n.featureGlobalSearchDesc,
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focus,
                                  onChanged: _setQuery,
                                  onSubmitted: (_) => _selectCurrent(context),
                                  textInputAction: TextInputAction.search,
                                  style: HermesType.onSurface(
                                    HermesType.body,
                                    theme,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.paletteHint,
                                    hintStyle: TextStyle(color: tokens.text3),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: tokens.accent,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: l10n.commonClose,
                                      icon: const Icon(Icons.close),
                                      onPressed: palette.close,
                                    ),
                                    border: InputBorder.none,
                                    filled: liquid ? false : null,
                                    enabledBorder: liquid
                                        ? InputBorder.none
                                        : null,
                                    focusedBorder: liquid
                                        ? UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: theme.colorScheme.primary,
                                              width: 2,
                                            ),
                                          )
                                        : null,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              Builder(
                                builder: (context) {
                                  PluginContributionStore plugin;
                                  try {
                                    plugin = context
                                        .watch<PluginContributionStore>();
                                  } on ProviderNotFoundException {
                                    return const SizedBox.shrink();
                                  }
                                  final items = plugin.forArea(
                                    MobileContributionArea.command,
                                  );
                                  if (items.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      4,
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        for (final item in items)
                                          ActionChip(
                                            avatar: const Icon(
                                              Icons.extension_outlined,
                                              size: 16,
                                            ),
                                            label: Text(item.title),
                                            onPressed: () async {
                                              await plugin.invoke(item);
                                              palette.close();
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Results
                              Flexible(
                                child: results.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          l10n.paletteNoResults,
                                          textAlign: TextAlign.center,
                                          style: HermesType.onSurfaceVariant(
                                            HermesType.callout,
                                            theme,
                                          ),
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        controller: _resultsScroll,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                            results.length,
                                            (i) {
                                              final r = results[i];
                                              final selected =
                                                  i == palette.selectedIndex;
                                              return KeyedSubtree(
                                                key: selected
                                                    ? _selectedResult
                                                    : null,
                                                child: _ResultTile(
                                                  result: r,
                                                  selected: selected,
                                                  onTap: () {
                                                    palette.selectedIndex = i;
                                                    _selectCurrent(context);
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                              ),
                              if (isDesktop) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      for (final hint in [
                                        ('↑↓', l10n.paletteHintNavigate),
                                        ('Enter', l10n.paletteHintOpen),
                                        ('Esc', l10n.paletteHintClose),
                                      ])
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            HermesKbd(hint.$1),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                hint.$2,
                                                style:
                                                    HermesType.onSurfaceVariant(
                                                      HermesType.caption,
                                                      theme,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectCurrent(BuildContext context) {
    final result = widget.palette.current;
    if (result == null) return;
    widget.palette.close();
    _handleResult(context, result);
  }

  void _handleResult(BuildContext context, PaletteResult result) {
    final nav = Navigator.of(context);
    switch (result.kind) {
      case PaletteResultKind.navigate:
        _navigateToRoute(nav, result.routeName);
        break;
      case PaletteResultKind.action:
        _handleAction(context, nav, result.routeName);
        break;
      case PaletteResultKind.session:
        if (result.sessionId != null) {
          _openSession(context, nav, result.sessionId!);
        }
        break;
      case PaletteResultKind.slashCommand:
        // No session is open yet — start a fresh one with the slash command
        // pre-filled into its durable composer draft.
        final name = result.command?.name;
        nav.push(
          MaterialPageRoute(
            builder: (_) => NewSessionScreen(
              initialDraftText: name == null ? null : '/$name ',
            ),
          ),
        );
        break;
    }
  }

  void _navigateToRoute(NavigatorState nav, String? route) {
    switch (route) {
      case 'home':
        nav.popUntil((r) => r.isFirst);
        break;
      case 'sessions':
        nav.push(MaterialPageRoute(builder: (_) => const SessionListScreen()));
        break;
      case 'projects':
        nav.push(MaterialPageRoute(builder: (_) => const ProjectScreen()));
        break;
      case 'tasks':
      case 'kanban':
        nav.push(
          MaterialPageRoute(builder: (_) => const KanbanCanonicalScreen()),
        );
        break;
      case 'terminal':
        nav.push(MaterialPageRoute(builder: (_) => const TerminalScreen()));
        break;
      case 'git':
        nav.push(MaterialPageRoute(builder: (_) => const GitScreen()));
        break;
      case 'files':
        nav.push(MaterialPageRoute(builder: (_) => const FilesScreen()));
        break;
      case 'knowledge':
        nav.push(MaterialPageRoute(builder: (_) => const KnowledgeScreen()));
        break;
      case 'settings':
        nav.push(MaterialPageRoute(builder: (_) => const SettingsHubScreen()));
        break;
      case 'command_center':
        nav.push(
          MaterialPageRoute(builder: (_) => const CommandCenterScreen()),
        );
        break;
      case 'pet_center':
        nav.push(MaterialPageRoute(builder: (_) => const PetCenterScreen()));
        break;
      case 'subagents':
        nav.push(MaterialPageRoute(builder: (_) => const SubagentsScreen()));
        break;
      case 'artifacts':
        nav.push(MaterialPageRoute(builder: (_) => const ArtifactsScreen()));
        break;
    }
  }

  void _handleAction(BuildContext context, NavigatorState nav, String? route) {
    switch (route) {
      case 'new_session':
        nav.push(MaterialPageRoute(builder: (_) => const NewSessionScreen()));
        break;
      case 'voice_input':
        // Triggered by the voice store elsewhere; just close.
        break;
      case 'reconnect':
        unawaited(
          context
              .read<ConnectionStore>()
              .reconnectAfterResume(refreshSocket: true)
              .catchError((_) {}),
        );
        break;
    }
  }

  Future<void> _openSession(
    BuildContext context,
    NavigatorState nav,
    String sessionId,
  ) async {
    final store = context.read<SessionStore>();
    final rows = store.sessions ?? const <SessionRow>[];
    final row = rows.cast<SessionRow?>().firstWhere(
      (r) => r?.id == sessionId,
      orElse: () => null,
    );
    try {
      if (row != null && (row.readOnly || row.isDelegatedChild)) {
        await store.openReadOnlySession(sessionId, profile: row.profile);
      } else {
        await store.resumeSession(sessionId, profile: row?.profile);
      }
    } catch (error) {
      // close() unmounts this overlay before the await above completes, so
      // the overlay's context is dead here — report through the app-level
      // navigator context instead of letting the failure vanish.
      final navContext = hermesNavigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        showHermesErrorSnackBar(navContext, error);
      } else if (context.mounted) {
        showHermesErrorSnackBar(context, error);
      }
      return;
    }
    // Same unmount reasoning: the captured root navigator outlives the
    // overlay, so gate on it rather than on the dead overlay context.
    if (!nav.mounted) return;
    nav.push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }
}

class _ResultTile extends StatelessWidget {
  final PaletteResult result;
  final bool selected;
  final VoidCallback onTap;

  const _ResultTile({
    required this.result,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = HermesPalette.of(context);
    final liquid = HermesGlassTheme.of(context).enabled;
    final tile = InkWell(
      onTap: onTap,
      borderRadius: liquid ? BorderRadius.circular(18) : null,
      child: Container(
        color: selected && !liquid ? tokens.accentBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              result.icon ?? Icons.circle,
              size: 20,
              color: liquid && selected
                  ? theme.colorScheme.onPrimaryContainer
                  : selected
                  ? tokens.accent
                  : tokens.text3,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: HermesType.onSurface(HermesType.callout, theme)
                        .copyWith(
                          color: liquid && selected
                              ? theme.colorScheme.onPrimaryContainer
                              : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.subtitle!,
                      style:
                          HermesType.onSurfaceVariant(
                            HermesType.footnote,
                            theme,
                          ).copyWith(
                            color: liquid && selected
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _kindBadge(context, result.kind),
          ],
        ),
      ),
    );
    return liquid ? GlassSelectionRow(selected: selected, child: tile) : tile;
  }

  Widget _kindBadge(BuildContext context, PaletteResultKind kind) {
    final (label, color) = switch (kind) {
      PaletteResultKind.navigate => (
        context.l10n.paletteKindPage,
        hermesSemantic(context, HermesSemantic.blue, HermesSemanticDark.blue),
      ),
      PaletteResultKind.session => (
        context.l10n.paletteKindSession,
        hermesSemantic(context, HermesSemantic.green, HermesSemanticDark.green),
      ),
      PaletteResultKind.slashCommand => (
        context.l10n.paletteKindCommand,
        hermesSemantic(
          context,
          HermesSemantic.purple,
          HermesSemanticDark.purple,
        ),
      ),
      PaletteResultKind.action => (
        context.l10n.paletteKindAction,
        hermesSemantic(
          context,
          HermesSemantic.orange,
          HermesSemanticDark.orange,
        ),
      ),
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // §3.6：语义色底 10%(light)/18%(dark)。
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(HermesRadius.smallCard),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
