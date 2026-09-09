library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/tools/tool_dismiss_store.dart';
import '../chat/content/compact_markdown.dart';
import '../core/connections/connection_registry.dart';
import '../core/clipboard.dart';
import '../core/pane_tree.dart';
import '../core/preview_document.dart';
import '../core/stores/chat_store.dart';
import '../core/stores/composer_handoff_store.dart';
import '../core/stores/composer_status_store.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/pane_workspace_store.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../core/stores/preview_store.dart';
import '../core/stores/request_store.dart';
import '../core/stores/session_store.dart';
import '../core/stores/terminal_store.dart';
import '../core/stores/mobile_surface_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/plugin_contribution_views.dart';
import '../widgets/mobile/hermes_adaptive_menu.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import '../widgets/h/hermes_confirm_dialog.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/right_sidebar/git_review_panel.dart';
import '../widgets/right_sidebar/terminal_panel.dart';
import '../widgets/web_preview.dart';
import 'chat_screen.dart';
import 'files_screen.dart';
import 'file_editor_screen.dart';
import 'mcp_logs_screen.dart';

/// Pushes a single [PaneWorkspaceScreen] instance onto [navigator], no-op if
/// one is already open on top of it.
///
/// `PaneWorkspaceScreen` can be reached from several independent entry
/// points (the agent-driven `pane.reveal`/`layout.apply` surfaces in
/// `app_shell.dart`, `FilesScreen`, `MoreScreen`, and
/// `session_row_actions.dart`). All of them must route through this helper
/// so the "already open" state is tracked in one place regardless of which
/// path triggered it — otherwise a second entry point can stack a duplicate
/// route on top of one already pushed by another.
Future<void> openWorkspaceScreen(NavigatorState navigator) async {
  if (PaneWorkspaceScreen._routeOpen) return;
  PaneWorkspaceScreen._routeOpen = true;
  try {
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const PaneWorkspaceScreen()),
    );
  } finally {
    PaneWorkspaceScreen._routeOpen = false;
  }
}

class PaneWorkspaceScreen extends StatelessWidget {
  const PaneWorkspaceScreen({super.key});

  /// Tracks whether a route built from this screen is currently pushed,
  /// shared by [openWorkspaceScreen] across every call site.
  static bool _routeOpen = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PaneWorkspaceStore>();
    final l10n = context.l10n;
    return MobilePageScaffold(
      title: l10n.workspaceTitle,
      actions: [
        HermesAdaptiveMenuButton<WorkspacePaneKind>(
          tooltip: l10n.workspaceAddPaneTooltip,
          icon: const Icon(Icons.add_box_outlined),
          onSelected: (kind) => _openCorePane(context, store, kind),
          itemBuilder: (context) => [
            _corePaneMenuItem(
              WorkspacePaneKind.terminal,
              Icons.terminal_outlined,
              l10n.workspacePaneTerminal,
            ),
            _corePaneMenuItem(
              WorkspacePaneKind.files,
              Icons.folder_outlined,
              l10n.workspacePaneFiles,
            ),
            _corePaneMenuItem(
              WorkspacePaneKind.review,
              Icons.rate_review_outlined,
              l10n.workspacePaneReview,
            ),
            _corePaneMenuItem(
              WorkspacePaneKind.logs,
              Icons.article_outlined,
              l10n.workspacePaneLogs,
            ),
            _corePaneMenuItem(
              WorkspacePaneKind.preview,
              Icons.preview_outlined,
              l10n.workspacePanePreview,
            ),
          ],
        ),
        if (!store.isEmpty)
          HermesAdaptiveMenuButton<WorkspaceLayoutPreset>(
            tooltip: l10n.workspaceApplyLayoutTooltip,
            icon: const Icon(Icons.dashboard_customize_outlined),
            onSelected: store.applyLayoutPreset,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: WorkspaceLayoutPreset.defaultLayout,
                child: Text(l10n.workspaceLayoutDefault),
              ),
              PopupMenuItem(
                value: WorkspaceLayoutPreset.focus,
                child: Text(l10n.workspaceLayoutFocus),
              ),
              PopupMenuItem(
                value: WorkspaceLayoutPreset.balanced,
                child: Text(l10n.workspaceLayoutBalanced),
              ),
              PopupMenuItem(
                value: WorkspaceLayoutPreset.mainWide,
                child: Text(l10n.workspaceLayoutMainWide),
              ),
              PopupMenuItem(
                value: WorkspaceLayoutPreset.toolsWide,
                child: Text(l10n.workspaceLayoutToolsWide),
              ),
              PopupMenuItem(
                value: WorkspaceLayoutPreset.terminalDeck,
                child: Text(l10n.workspaceLayoutTerminalDeck),
              ),
              PopupMenuItem(
                value: WorkspaceLayoutPreset.quad,
                child: Text(l10n.workspaceLayoutQuad),
              ),
            ],
          ),
        if (!store.isEmpty)
          IconButton(
            tooltip: l10n.workspaceCloseAllTooltip,
            onPressed: () => _confirmClear(context, store),
            icon: const Icon(Icons.close_fullscreen_outlined),
          ),
      ],
      body: !store.loaded
          ? const Center(child: CircularProgressIndicator())
          : store.tree == null
          ? const _EmptyWorkspace()
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return _CompactPaneWorkspace(store: store);
                }
                return _PaneNodeView(node: store.tree!, store: store);
              },
            ),
    );
  }

  PopupMenuItem<WorkspacePaneKind> _corePaneMenuItem(
    WorkspacePaneKind kind,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: kind,
    child: ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
    ),
  );

  Future<void> _openCorePane(
    BuildContext context,
    PaneWorkspaceStore store,
    WorkspacePaneKind kind,
  ) async {
    final connection = context.read<ConnectionStore>();
    SessionStore? session;
    try {
      session = context.read<SessionStore>();
    } on ProviderNotFoundException {
      // The workspace can be embedded without an active chat session.
    }
    var owner = OwnerRoute(
      connectionId: connection.activeConnectionId,
      profile: session?.profile ?? session?.activeProfile,
    );
    final path = session?.info?.cwd?.trim();
    final l10n = context.l10n;
    var title = switch (kind) {
      WorkspacePaneKind.terminal => l10n.workspacePaneTerminal,
      WorkspacePaneKind.files => l10n.workspacePaneFiles,
      WorkspacePaneKind.review => l10n.workspacePaneReview,
      WorkspacePaneKind.logs => l10n.workspacePaneLogs,
      WorkspacePaneKind.preview => l10n.workspacePanePreview,
      WorkspacePaneKind.session || WorkspacePaneKind.plugin => kind.name,
    };
    var referenceId =
        (kind == WorkspacePaneKind.files || kind == WorkspacePaneKind.review) &&
            path?.isNotEmpty == true
        ? path!
        : 'default';
    if (kind == WorkspacePaneKind.preview) {
      final tab = context.read<PreviewStore>().activeTab;
      if (tab != null) {
        referenceId = tab.id;
        title = tab.title;
        owner = tab.owner ?? owner;
      }
    }
    final position = switch (kind) {
      WorkspacePaneKind.terminal ||
      WorkspacePaneKind.logs => PaneDropPosition.bottom,
      _ => PaneDropPosition.right,
    };
    try {
      await store.openCorePane(
        kind: kind,
        title: title,
        owner: owner,
        referenceId: referenceId,
        position: position,
      );
    } catch (error) {
      if (context.mounted) {
        showHermesErrorSnackBar(
          context,
          error,
          fallback: l10n.workspaceOpenPluginFailed('$error'),
        );
      }
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    PaneWorkspaceStore store,
  ) async {
    final confirmed = await showHermesConfirmDialog(
      context: context,
      title: context.l10n.workspaceCloseAllQuestion,
      message: context.l10n.workspaceCloseAllDescription,
      confirmLabel: context.l10n.workspaceCloseAllAction,
      destructive: true,
    );
    if (confirmed) await store.clear();
  }
}

Future<void> _reloadPane(BuildContext context, WorkspacePane pane) async {
  try {
    switch (pane.kind) {
      case WorkspacePaneKind.preview:
        final preview = context.read<PreviewStore>();
        final tab = preview.tabs
            .where(
              (item) =>
                  item.id == pane.referenceId ||
                  item.document?.path == pane.referenceId,
            )
            .firstOrNull;
        if (tab != null) await preview.reloadTab(tab.id);
      case WorkspacePaneKind.session:
        await context.read<SessionStore>().refreshList();
      case WorkspacePaneKind.plugin:
        final plugins = context.read<PluginContributionStore>();
        final contribution = plugins.contributions
            .where((item) => item.namespacedId == pane.referenceId)
            .firstOrNull;
        if (contribution != null) await plugins.loadView(contribution);
      case WorkspacePaneKind.terminal ||
          WorkspacePaneKind.files ||
          WorkspacePaneKind.review ||
          WorkspacePaneKind.logs:
        // These panes own their connection-aware refresh lifecycle. Rebuilding
        // their keyed content safely recreates that lifecycle where needed.
        context.read<PaneWorkspaceStore>().activate(pane.id);
    }
  } catch (error) {
    if (context.mounted) {
      showHermesErrorSnackBar(context, error);
    }
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace();

  @override
  Widget build(BuildContext context) => HermesEmptyState(
    icon: Icons.view_quilt_outlined,
    iconSize: 42,
    title: context.l10n.workspaceEmptyTitle,
    description: context.l10n.workspaceEmptyDescription,
  );
}

class _CompactPaneWorkspace extends StatelessWidget {
  const _CompactPaneWorkspace({required this.store});

  final PaneWorkspaceStore store;

  @override
  Widget build(BuildContext context) {
    final panes = store.orderedPanes;
    final focused = panes.indexWhere((pane) => pane.id == store.focusedPaneId);
    final index = focused < 0 ? 0 : focused;
    return Column(
      children: [
        KeyedSubtree(
          key: Provider.of<MobileSurfaceStore?>(
            context,
            listen: false,
          )?.targetKey('workspace.tabs'),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                itemCount: panes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, paneIndex) {
                  final pane = panes[paneIndex];
                  return _PaneTab(
                    pane: pane,
                    selected: paneIndex == index,
                    onTap: () => store.activate(pane.id),
                    onClose: () => store.close(pane.id),
                    onCloseOthers: () => store.closeOthers(pane.id),
                    onCloseToRight: () => store.closeToRight(pane.id),
                    onReload: () => _reloadPane(context, pane),
                    onRename: (title) => store.rename(pane.id, title),
                    onMove: (sourcePaneId, position) =>
                        store.move(sourcePaneId, pane.id, position),
                  );
                },
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: index,
            children: [
              for (final pane in panes)
                _PaneContent(key: ValueKey(pane.id), pane: pane),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaneNodeView extends StatelessWidget {
  const _PaneNodeView({required this.node, required this.store});

  final PaneNode node;
  final PaneWorkspaceStore store;

  @override
  Widget build(BuildContext context) => switch (node) {
    PaneGroup() => _PaneGroupView(group: node as PaneGroup, store: store),
    PaneSplit() => _PaneSplitView(split: node as PaneSplit, store: store),
  };
}

class _PaneGroupView extends StatelessWidget {
  const _PaneGroupView({required this.group, required this.store});

  final PaneGroup group;
  final PaneWorkspaceStore store;

  @override
  Widget build(BuildContext context) {
    final panes = [for (final id in group.panes) ?store.panes[id]];
    final activeIndex = math.max(
      0,
      panes.indexWhere((pane) => pane.id == group.active),
    );
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              itemCount: panes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 3),
              itemBuilder: (context, index) {
                final pane = panes[index];
                return _PaneTab(
                  pane: pane,
                  selected: index == activeIndex,
                  onTap: () => store.activate(pane.id),
                  onClose: () => store.close(pane.id),
                  onCloseOthers: () => store.closeOthers(pane.id),
                  onCloseToRight: () => store.closeToRight(pane.id),
                  onReload: () => _reloadPane(context, pane),
                  onRename: (title) => store.rename(pane.id, title),
                  onMove: (sourcePaneId, position) =>
                      store.move(sourcePaneId, pane.id, position),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: activeIndex,
            children: [
              for (final pane in panes)
                _PaneContent(key: ValueKey(pane.id), pane: pane),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaneTab extends StatelessWidget {
  const _PaneTab({
    required this.pane,
    required this.selected,
    required this.onTap,
    required this.onClose,
    required this.onCloseOthers,
    required this.onCloseToRight,
    required this.onReload,
    required this.onRename,
    required this.onMove,
  });

  final WorkspacePane pane;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onCloseOthers;
  final VoidCallback onCloseToRight;
  final VoidCallback onReload;
  final ValueChanged<String> onRename;
  final void Function(String sourcePaneId, PaneDropPosition position) onMove;

  @override
  Widget build(BuildContext context) {
    final targetKey = GlobalKey();
    final tab = Material(
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 96, maxWidth: 220),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 10),
              Icon(_paneIcon(pane.kind), size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  pane.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              HermesAdaptiveMenuButton<String>(
                tooltip: context.l10n.workspaceLayoutTooltip,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.grid_view_outlined, size: 14),
                onSelected: (action) {
                  switch (action) {
                    case 'rename':
                      _rename(context);
                    case 'closeOthers':
                      onCloseOthers();
                    case 'closeRight':
                      onCloseToRight();
                    case 'reload':
                      onReload();
                    case 'close':
                      onClose();
                    case 'center':
                      onMove(pane.id, PaneDropPosition.center);
                    case 'left':
                      onMove(pane.id, PaneDropPosition.left);
                    case 'right':
                      onMove(pane.id, PaneDropPosition.right);
                    case 'top':
                      onMove(pane.id, PaneDropPosition.top);
                    case 'bottom':
                      onMove(pane.id, PaneDropPosition.bottom);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.drive_file_rename_outline),
                      title: Text(context.l10n.workspaceRenameTab),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'center',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.tab_outlined),
                      title: Text(context.l10n.workspaceMergeTabs),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'left',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.align_horizontal_left),
                      title: Text(context.l10n.workspaceMoveLeft),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'right',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.align_horizontal_right),
                      title: Text(context.l10n.workspaceMoveRight),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'top',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.align_vertical_top),
                      title: Text(context.l10n.workspaceMoveTop),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'bottom',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.align_vertical_bottom),
                      title: Text(context.l10n.workspaceMoveBottom),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'reload',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.refresh_outlined),
                      title: Text(context.l10n.commonRefresh),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'closeOthers',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.filter_none_outlined),
                      title: Text(context.l10n.workspaceCloseOtherTabs),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'closeRight',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.last_page_outlined),
                      title: Text(context.l10n.workspaceCloseTabsToRight),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.close),
                      title: Text(context.l10n.commonClose),
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: context.l10n.commonClose,
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 15),
              ),
            ],
          ),
        ),
      ),
    );
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != pane.id,
      onAcceptWithDetails: (details) {
        final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        final horizontal = local.dx / box.size.width;
        final vertical = local.dy / box.size.height;
        final position = horizontal < .24
            ? PaneDropPosition.left
            : horizontal > .76
            ? PaneDropPosition.right
            : vertical < .28
            ? PaneDropPosition.top
            : vertical > .72
            ? PaneDropPosition.bottom
            : PaneDropPosition.center;
        onMove(details.data, position);
      },
      builder: (context, candidates, rejected) => AnimatedContainer(
        key: targetKey,
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: candidates.isEmpty
                ? Colors.transparent
                : Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        child: LongPressDraggable<String>(
          data: pane.id,
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_paneIcon(pane.kind), size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        pane.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: .35, child: tab),
          child: tab,
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: pane.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.workspaceRenameTab),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 240,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    // Deferred: the dialog's exit transition can still be rebuilding this
    // TextField for a frame or two after showDialog's Future resolves —
    // disposing synchronously here races that and throws "used after being
    // disposed".
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (title != null && title.trim().isNotEmpty) onRename(title);
  }

  IconData _paneIcon(WorkspacePaneKind kind) => switch (kind) {
    WorkspacePaneKind.session => Icons.chat_bubble_outline,
    WorkspacePaneKind.plugin => Icons.extension_outlined,
    WorkspacePaneKind.terminal => Icons.terminal_outlined,
    WorkspacePaneKind.files => Icons.folder_outlined,
    WorkspacePaneKind.review => Icons.rate_review_outlined,
    WorkspacePaneKind.logs => Icons.article_outlined,
    WorkspacePaneKind.preview => Icons.preview_outlined,
  };
}

class _PaneSplitView extends StatelessWidget {
  const _PaneSplitView({required this.split, required this.store});

  final PaneSplit split;
  final PaneWorkspaceStore store;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = split.axis == PaneSplitAxis.horizontal;
      final extent = horizontal ? constraints.maxWidth : constraints.maxHeight;
      final children = <Widget>[];
      for (var index = 0; index < split.children.length; index++) {
        final weight = split.weights[index];
        children.add(
          Expanded(
            flex: math.max(1, (weight * 1000).round()),
            child: _PaneNodeView(node: split.children[index], store: store),
          ),
        );
        if (index == split.children.length - 1) continue;
        children.add(
          _SplitDivider(
            horizontal: horizontal,
            onDelta: (delta) {
              if (!extent.isFinite || extent <= 0) return;
              final next = [...split.weights];
              final total = next[index] + next[index + 1];
              final scaled =
                  delta /
                  extent *
                  split.weights.fold<double>(0, (sum, item) => sum + item);
              // Guard against a degenerate total (e.g. a persisted layout with
              // skewed weights) where the normal .15 minimum on each side
              // would make the clamp's lower bound exceed its upper bound and
              // throw. Fall back to splitting evenly in that case.
              final lower = total > 0.30 ? .15 : total / 2;
              final upper = total > 0.30 ? total - .15 : total / 2;
              next[index] = (next[index] + scaled).clamp(lower, upper);
              next[index + 1] = total - next[index];
              store.resize(split.id, next);
            },
          ),
        );
      }
      return horizontal ? Row(children: children) : Column(children: children);
    },
  );
}

class _SplitDivider extends StatelessWidget {
  const _SplitDivider({required this.horizontal, required this.onDelta});

  final bool horizontal;
  final ValueChanged<double> onDelta;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: horizontal
        ? SystemMouseCursors.resizeColumn
        : SystemMouseCursors.resizeRow,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: horizontal
          ? (details) => onDelta(details.delta.dx)
          : null,
      onVerticalDragUpdate: horizontal
          ? null
          : (details) => onDelta(details.delta.dy),
      child: SizedBox(
        width: horizontal ? 7 : double.infinity,
        height: horizontal ? double.infinity : 7,
        child: Center(
          child: Container(
            width: horizontal ? 1 : 28,
            height: horizontal ? 28 : 1,
            color: HermesPalette.of(context).border,
          ),
        ),
      ),
    ),
  );
}

class _PaneContent extends StatelessWidget {
  const _PaneContent({super.key, required this.pane});

  final WorkspacePane pane;

  @override
  Widget build(BuildContext context) {
    final content = switch (pane.kind) {
      WorkspacePaneKind.session => _SessionPaneHost(pane: pane),
      WorkspacePaneKind.plugin => _PluginPaneHost(pane: pane),
      WorkspacePaneKind.terminal => _OwnedPaneScope(
        owner: pane.owner,
        child: ChangeNotifierProvider(
          create: (context) => TerminalStore(
            connection: context.read<ConnectionStore>(),
            storageScope: pane.owner.key,
          ),
          child: const TerminalPanel(),
        ),
      ),
      WorkspacePaneKind.files => _OwnedPaneScope(
        owner: pane.owner,
        child: FilesScreen(
          initialPath: pane.referenceId == 'default' ? null : pane.referenceId,
          workspaceMode: true,
          owner: pane.owner,
        ),
      ),
      WorkspacePaneKind.review => _OwnedPaneScope(
        owner: pane.owner,
        child: GitReviewPanel(
          initialPath: pane.referenceId == 'default' ? null : pane.referenceId,
        ),
      ),
      WorkspacePaneKind.logs => _OwnedPaneScope(
        owner: pane.owner,
        child: const McpLogsScreen(embedded: true),
      ),
      WorkspacePaneKind.preview => _PreviewPaneHost(pane: pane),
    };
    final selector = switch (pane.kind) {
      WorkspacePaneKind.files => 'workspace.files',
      WorkspacePaneKind.terminal => 'workspace.terminal',
      WorkspacePaneKind.review => 'workspace.review',
      WorkspacePaneKind.preview => 'workspace.preview',
      _ => null,
    };
    final surfaces = Provider.of<MobileSurfaceStore?>(context, listen: false);
    return KeyedSubtree(
      key: selector == null ? null : surfaces?.targetKey(selector),
      child: content,
    );
  }
}

class _OwnedPaneScope extends StatefulWidget {
  const _OwnedPaneScope({required this.owner, required this.child});

  final OwnerRoute owner;
  final Widget child;

  @override
  State<_OwnedPaneScope> createState() => _OwnedPaneScopeState();
}

class _OwnedPaneScopeState extends State<_OwnedPaneScope> {
  ConnectionStore? _facade;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = context.watch<ConnectionStore>();
    try {
      final runtime = parent.runtimeFor(widget.owner);
      final facade = _facade ?? ConnectionStore();
      facade
        ..settings = runtime.settings
        ..api = runtime.api
        ..gateway = runtime.gateway
        ..phase = switch (runtime.phase) {
          RuntimePhase.connected => ConnectionPhase.connected,
          RuntimePhase.connecting => ConnectionPhase.connecting,
          RuntimePhase.reconnecting => ConnectionPhase.reconnecting,
          RuntimePhase.exhausted => ConnectionPhase.exhausted,
          RuntimePhase.disconnected => ConnectionPhase.disconnected,
        }
        ..error = runtime.error;
      _facade = facade;
      _error = null;
    } catch (error) {
      _error = error;
    }
  }

  @override
  void dispose() {
    _facade?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return HermesErrorState(description: '$_error');
    }
    final facade = _facade;
    return facade == null
        ? widget.child
        : ChangeNotifierProvider<ConnectionStore>.value(
            value: facade,
            child: widget.child,
          );
  }
}

class _PreviewPaneHost extends StatefulWidget {
  const _PreviewPaneHost({required this.pane});

  final WorkspacePane pane;

  @override
  State<_PreviewPaneHost> createState() => _PreviewPaneHostState();
}

class _PreviewPaneHostState extends State<_PreviewPaneHost> {
  PreviewDocumentMode? _mode;
  bool _forcing = false;
  String? _hydratingPath;
  String? _hydrateErrorPath;
  Object? _hydrateError;

  @override
  Widget build(BuildContext context) {
    final preview = context.watch<PreviewStore>();
    final tab = widget.pane.referenceId == 'default'
        ? preview.activeTab
        : preview.tabs
              .where(
                (item) =>
                    item.id == widget.pane.referenceId ||
                    item.document?.path == widget.pane.referenceId,
              )
              .firstOrNull;
    if (tab == null &&
        widget.pane.referenceId != 'default' &&
        !_looksLikeEphemeralPreviewId(widget.pane.referenceId) &&
        _hydrateErrorPath != widget.pane.referenceId &&
        _hydratingPath != widget.pane.referenceId) {
      _hydratingPath = widget.pane.referenceId;
      unawaited(_hydrateFile(preview, widget.pane.referenceId));
    }
    final document = tab?.document;
    final modes = document?.modes.toList(growable: false) ?? const [];
    final effectiveMode = modes.contains(_mode)
        ? _mode!
        : modes.contains(PreviewDocumentMode.rendered)
        ? PreviewDocumentMode.rendered
        : modes.firstOrNull;
    final content = switch (effectiveMode) {
      PreviewDocumentMode.source => _PreviewText(
        document?.source ?? '',
        document: document,
        owner: tab?.owner ?? widget.pane.owner,
      ),
      PreviewDocumentMode.diff => _PreviewText(document?.diff ?? ''),
      PreviewDocumentMode.rendered => _renderDocument(tab, document!),
      null => _emptyDocument(preview, tab, document),
    };
    final editor = document?.editable == true && document?.path != null
        ? IconButton(
            tooltip: context.l10n.commonEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _OwnedPaneScope(
                  owner: tab?.owner ?? widget.pane.owner,
                  child: FileEditorScreen(
                    path: document!.path!,
                    name: document.title,
                    profile: (tab?.owner ?? widget.pane.owner).profile,
                  ),
                ),
              ),
            ),
          )
        : null;
    if (modes.length < 2 && editor == null) return content;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: modes.isEmpty
                    ? const SizedBox.shrink()
                    : SegmentedButton<PreviewDocumentMode>(
                        showSelectedIcon: false,
                        segments: [
                          for (final mode in modes)
                            ButtonSegment(
                              value: mode,
                              icon: Icon(switch (mode) {
                                PreviewDocumentMode.source =>
                                  Icons.code_rounded,
                                PreviewDocumentMode.rendered =>
                                  Icons.visibility_outlined,
                                PreviewDocumentMode.diff =>
                                  Icons.difference_outlined,
                              }),
                              label: Text(switch (mode) {
                                PreviewDocumentMode.source =>
                                  context.l10n.previewSource,
                                PreviewDocumentMode.rendered =>
                                  context.l10n.previewRendered,
                                PreviewDocumentMode.diff =>
                                  context.l10n.previewDiff,
                              }),
                            ),
                        ],
                        selected: {effectiveMode!},
                        onSelectionChanged: (selection) =>
                            setState(() => _mode = selection.first),
                      ),
              ),
            ),
            ?editor,
            const SizedBox(width: 4),
          ],
        ),
        Expanded(child: content),
      ],
    );
  }

  bool _looksLikeEphemeralPreviewId(String value) =>
      value.startsWith('url:') || value.startsWith('html:');

  Future<void> _hydrateFile(PreviewStore preview, String path) async {
    try {
      await preview.openFile(
        path,
        title: widget.pane.title,
        owner: widget.pane.owner,
        repositoryRoot: widget.pane.repositoryRoot,
        byteSize: widget.pane.byteSize,
        mimeType: widget.pane.mimeType,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _hydrateErrorPath = path;
          _hydrateError = error;
        });
      }
    } finally {
      if (mounted && _hydratingPath == path) {
        setState(() => _hydratingPath = null);
      }
    }
  }

  Widget _renderDocument(PreviewTab? tab, PreviewDocument document) {
    switch (document.kind) {
      case PreviewDocumentKind.markdown:
        final source = document.source ?? '';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CompactMarkdown(text: source, selectable: true),
        );
      case PreviewDocumentKind.image:
        final bytes = _dataUrlBytes(document.url);
        return bytes == null
            ? _PreviewText(document.source ?? '')
            : InteractiveViewer(
                minScale: 0.25,
                maxScale: 8,
                child: Center(child: Image.memory(bytes)),
              );
      case PreviewDocumentKind.svg:
        final svg = document.source ?? '';
        return WebPreviewPane(
          html:
              '<!doctype html><meta name="viewport" content="width=device-width">'
              '<style>html,body{margin:0;min-height:100%;display:grid;place-items:center}'
              'svg{max-width:100%;height:auto}</style>$svg',
          previewTabId: tab?.id,
          restartCwd: document.repositoryRoot ?? widget.pane.repositoryRoot,
          showHtmlTools: false,
        );
      case PreviewDocumentKind.html:
        return WebPreviewPane(
          html: document.source,
          previewTabId: tab?.id,
          restartCwd: document.repositoryRoot ?? widget.pane.repositoryRoot,
        );
      case PreviewDocumentKind.pdf || PreviewDocumentKind.web:
        return WebPreviewPane(
          url: document.url ?? tab?.url,
          previewTabId: tab?.id,
          restartCwd: document.repositoryRoot ?? widget.pane.repositoryRoot,
        );
      case PreviewDocumentKind.text:
        return _PreviewText(document.source ?? '');
      case PreviewDocumentKind.binary:
        return _emptyDocument(context.read<PreviewStore>(), tab, document);
    }
  }

  Widget _emptyDocument(
    PreviewStore preview,
    PreviewTab? tab,
    PreviewDocument? document,
  ) {
    if (document == null) {
      if (_hydrateErrorPath == widget.pane.referenceId) {
        return HermesErrorState(
          description: context.l10n.previewFailed('$_hydrateError'),
          onRetry: () {
            setState(() {
              _hydrateErrorPath = null;
              _hydrateError = null;
              _hydratingPath = widget.pane.referenceId;
            });
            unawaited(_hydrateFile(preview, widget.pane.referenceId));
          },
        );
      }
      if (_hydratingPath == widget.pane.referenceId) {
        return const HermesLoadingState();
      }
      return Center(child: Text(context.l10n.previewEmpty));
    }
    final canForce =
        document.path != null && (document.large || document.binary);
    return HermesEmptyState(
      icon: document.large
          ? Icons.data_usage_rounded
          : Icons.insert_drive_file_outlined,
      title: document.large
          ? context.l10n.previewLargeFileTitle
          : context.l10n.fileEditorBinaryTitle,
      description: document.large
          ? context.l10n.previewLargeFileDescription
          : context.l10n.fileEditorBinaryDescription,
      primaryLabel: canForce ? context.l10n.filesContinueEdit : null,
      onPrimary: canForce && !_forcing
          ? () async {
              setState(() => _forcing = true);
              try {
                await preview.openFile(
                  document.path!,
                  title: document.title,
                  sessionId: tab?.sessionId,
                  owner: tab?.owner ?? widget.pane.owner,
                  repositoryRoot: widget.pane.repositoryRoot,
                  byteSize: document.byteSize,
                  mimeType: document.mimeType,
                  force: true,
                );
              } finally {
                if (mounted) setState(() => _forcing = false);
              }
            }
          : null,
    );
  }

  Uint8List? _dataUrlBytes(String? value) {
    if (value == null) return null;
    final comma = value.indexOf(',');
    if (comma < 0 || !value.substring(0, comma).contains(';base64')) {
      return null;
    }
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

class _PreviewText extends StatefulWidget {
  const _PreviewText(this.text, {this.document, this.owner});
  final String text;
  final PreviewDocument? document;
  final OwnerRoute? owner;

  @override
  State<_PreviewText> createState() => _PreviewTextState();
}

class _PreviewTextState extends State<_PreviewText> {
  int? _anchor;
  int? _extent;

  List<String> get _lines => widget.text.split('\n');

  void _select(int index) {
    setState(() {
      if (_anchor == null) {
        _anchor = index;
        _extent = index;
      } else {
        _extent = index;
      }
    });
  }

  ({int start, int end, String text})? get _selection {
    final anchor = _anchor;
    final extent = _extent;
    if (anchor == null || extent == null) return null;
    final start = math.min(anchor, extent);
    final end = math.max(anchor, extent);
    return (
      start: start + 1,
      end: end + 1,
      text: _lines.sublist(start, end + 1).join('\n'),
    );
  }

  Future<void> _copy() async {
    final selection = _selection;
    if (selection == null) return;
    await copyTextOrNotify(context, selection.text);
  }

  void _attach() {
    final selection = _selection;
    final document = widget.document;
    final owner = widget.owner;
    if (selection == null || document?.path == null || owner == null) return;
    context.read<ComposerHandoffStore>().addSnippet(
      ComposerSnippetHandoff(
        owner: owner,
        path: document!.path!,
        repositoryRoot: document.repositoryRoot,
        startLine: selection.start,
        endLine: selection.end,
        revision: document.revision,
        text: selection.text,
      ),
    );
    showHermesToast(
      context,
      message: context.l10n.fileTreeAttachToChat,
      kind: HermesToastKind.success,
    );
    setState(() {
      _anchor = null;
      _extent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final selection = _selection;
    final canAttach =
        widget.document?.path != null &&
        widget.owner != null &&
        selection != null;
    final selectedColor = Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: .55);
    return Column(
      children: [
        if (selection != null)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('L${selection.start}–L${selection.end}'),
                    ),
                    TextButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: Text(context.l10n.commonCopy),
                    ),
                    if (canAttach)
                      FilledButton.tonalIcon(
                        onPressed: _attach,
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        label: Text(context.l10n.fileTreeAttachToChat),
                      ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: lines.length,
            itemExtent: 21,
            itemBuilder: (context, index) {
              final selected =
                  selection != null &&
                  index + 1 >= selection.start &&
                  index + 1 <= selection.end;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () => _select(index),
                onTap: _anchor == null ? null : () => _select(index),
                child: ColoredBox(
                  color: selected ? selectedColor : Colors.transparent,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${index + 1}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'HermesJetBrainsMono',
                            fontSize: 12,
                            color: HermesPalette.of(context).text3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lines[index].isEmpty ? ' ' : lines[index],
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontFamily: 'HermesJetBrainsMono',
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PluginPaneHost extends StatelessWidget {
  const _PluginPaneHost({required this.pane});

  final WorkspacePane pane;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PluginContributionStore>();
    final contribution = store.contributions.where((item) {
      return item.namespacedId == pane.referenceId &&
          item.owner.key == pane.owner.key;
    }).firstOrNull;
    if (contribution == null) {
      return Center(child: Text(context.l10n.workspacePluginUnavailable));
    }
    return PluginContributionPane(store: store, contribution: contribution);
  }
}

class _SessionPaneHost extends StatefulWidget {
  const _SessionPaneHost({required this.pane});

  final WorkspacePane pane;

  @override
  State<_SessionPaneHost> createState() => _SessionPaneHostState();
}

class _SessionPaneHostState extends State<_SessionPaneHost> {
  late final ChatStore _chat;
  late final RequestStore _requests;
  late final SessionStore _session;
  late final ToolDismissStore _dismiss;
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final connection = context.read<ConnectionStore>();
    _chat = ChatStore()..attachRoutedEvents(connection.routedEvents);
    _requests = RequestStore()..attachRoutedEvents(connection.routedEvents);
    _dismiss = ToolDismissStore();
    _session = SessionStore(
      connection: connection,
      chat: _chat,
      requests: _requests,
      composerStatus: context.read<ComposerStatusStore>(),
      persistLastSession: false,
    )..addListener(_onSessionChanged);
    unawaited(_resume());
  }

  void _onSessionChanged() {
    final title = _session.info?.title?.trim();
    if (title?.isNotEmpty == true && mounted) {
      context.read<PaneWorkspaceStore>().rename(widget.pane.id, title!);
    }
  }

  Future<void> _resume() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    try {
      if (widget.pane.readOnly) {
        await _session.openWatchOwnedSession(
          widget.pane.referenceId,
          widget.pane.owner,
        );
      } else {
        await _session.resumeOwnedSession(
          widget.pane.referenceId,
          widget.pane.owner,
        );
      }
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _chat.dispose();
    _requests.dispose();
    _dismiss.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.workspaceSessionResumeFailed('$_error'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _resume,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
              ),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatStore>.value(value: _chat),
        ChangeNotifierProvider<RequestStore>.value(value: _requests),
        ChangeNotifierProvider<SessionStore>.value(value: _session),
        ChangeNotifierProvider<ToolDismissStore>.value(value: _dismiss),
      ],
      child: ChatScreen(embedded: true, surfaceId: widget.pane.id),
    );
  }
}
