library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/tools/tool_dismiss_store.dart';
import '../core/connections/connection_registry.dart';
import '../core/pane_tree.dart';
import '../core/stores/chat_store.dart';
import '../core/stores/composer_status_store.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/pane_workspace_store.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../core/stores/preview_store.dart';
import '../core/stores/request_store.dart';
import '../core/stores/session_store.dart';
import '../core/stores/terminal_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/plugin_contribution_views.dart';
import '../widgets/mobile/hermes_adaptive_menu.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/right_sidebar/git_review_panel.dart';
import '../widgets/right_sidebar/terminal_panel.dart';
import '../widgets/web_preview.dart';
import 'chat_screen.dart';
import 'files_screen.dart';
import 'mcp_logs_screen.dart';

class PaneWorkspaceScreen extends StatelessWidget {
  const PaneWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PaneWorkspaceStore>();
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workspaceTitle),
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
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workspaceOpenPluginFailed('$error'))),
        );
      }
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    PaneWorkspaceStore store,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.workspaceCloseAllQuestion),
        content: Text(context.l10n.workspaceCloseAllDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.workspaceCloseAllAction),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.clear();
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_quilt_outlined, size: 42),
          const SizedBox(height: 12),
          Text(context.l10n.workspaceEmptyTitle),
          const SizedBox(height: 6),
          Text(context.l10n.workspaceEmptyDescription),
        ],
      ),
    ),
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
        Material(
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
    required this.onMove,
  });

  final WorkspacePane pane;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;
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
              HermesAdaptiveMenuButton<PaneDropPosition>(
                tooltip: context.l10n.workspaceLayoutTooltip,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.grid_view_outlined, size: 14),
                onSelected: (position) => onMove(pane.id, position),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: PaneDropPosition.center,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.tab_outlined),
                      title: Text(context.l10n.workspaceMergeTabs),
                    ),
                  ),
                  PopupMenuItem(
                    value: PaneDropPosition.left,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.align_horizontal_left),
                      title: Text(context.l10n.workspaceMoveLeft),
                    ),
                  ),
                  PopupMenuItem(
                    value: PaneDropPosition.right,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.align_horizontal_right),
                      title: Text(context.l10n.workspaceMoveRight),
                    ),
                  ),
                  PopupMenuItem(
                    value: PaneDropPosition.top,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.align_vertical_top),
                      title: Text(context.l10n.workspaceMoveTop),
                    ),
                  ),
                  PopupMenuItem(
                    value: PaneDropPosition.bottom,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.align_vertical_bottom),
                      title: Text(context.l10n.workspaceMoveBottom),
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
              next[index] = (next[index] + scaled).clamp(.15, total - .15);
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
  Widget build(BuildContext context) => switch (pane.kind) {
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

class _PreviewPaneHost extends StatelessWidget {
  const _PreviewPaneHost({required this.pane});

  final WorkspacePane pane;

  @override
  Widget build(BuildContext context) {
    final preview = context.watch<PreviewStore>();
    final tab = pane.referenceId == 'default'
        ? preview.activeTab
        : preview.tabs.where((item) => item.id == pane.referenceId).firstOrNull;
    return WebPreviewPane(
      url: tab?.url,
      html: tab?.html,
      previewTabId: tab?.id,
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
        await _session.openReadOnlyOwnedSession(
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
