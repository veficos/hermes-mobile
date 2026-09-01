/// RightSidebar: 右侧栏三标签面板
///
/// 对应 Desktop 版 right-sidebar/ 的三栏布局（文件树 + 终端 + Git 审查）。
/// 仅在平板/桌面宽度（>= 840px）下显示，宽度 360px。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/stores/preview_store.dart';
import '../../l10n/l10n.dart';
import '../../screens/mcp_logs_screen.dart';
import '../preview/artifact_preview.dart';
import '../web_preview.dart';
import 'file_tree_panel.dart';
import 'git_review_panel.dart';
import 'terminal_panel.dart';

enum RightSidebarTab { files, terminal, git, artifacts, preview, logs }

class RightSidebar extends StatefulWidget {
  /// 初始 Tab
  final RightSidebarTab initialTab;

  /// 面板宽度
  final double width;

  /// 文件附加到 composer 的回调
  final void Function(dynamic entry)? onAttachFile;

  const RightSidebar({
    super.key,
    this.initialTab = RightSidebarTab.files,
    this.width = 360,
    this.onAttachFile,
  });

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends State<RightSidebar>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _collapsed = false;
  Widget? _filesPanel;
  Widget? _terminalPanel;
  Widget? _gitPanel;
  Widget? _artifactsPanel;
  Widget? _logsPanel;
  PreviewStore? _previewStore;

  static const _kTabKey = 'hm_right_sidebar_tab';
  static const _kCollapsedKey = 'hm_right_sidebar_collapsed';

  static const List<_TabInfo> _tabs = [
    _TabInfo(
      tab: RightSidebarTab.files,
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
    ),
    _TabInfo(
      tab: RightSidebarTab.terminal,
      icon: Icons.terminal_outlined,
      activeIcon: Icons.terminal,
    ),
    _TabInfo(
      tab: RightSidebarTab.git,
      icon: Icons.merge_outlined,
      activeIcon: Icons.merge,
    ),
    _TabInfo(
      tab: RightSidebarTab.artifacts,
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
    ),
    _TabInfo(
      tab: RightSidebarTab.preview,
      icon: Icons.preview_outlined,
      activeIcon: Icons.preview,
    ),
    _TabInfo(
      tab: RightSidebarTab.logs,
      icon: Icons.article_outlined,
      activeIcon: Icons.article,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabs.indexWhere((t) => t.tab == widget.initialTab);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
    _ensurePanel(_tabController.index);
    _tabController.addListener(_handleTabChanged);
    _loadPersisted();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PreviewStore? next;
    try {
      next = context.read<PreviewStore>();
    } catch (_) {
      next = null;
    }
    if (!identical(next, _previewStore)) {
      _previewStore?.removeListener(_onPreview);
      _previewStore = next;
      _previewStore?.addListener(_onPreview);
    }
  }

  void _onPreview() {
    if (!mounted || _previewStore?.hasContent != true) return;
    final idx = _tabs.indexWhere((t) => t.tab == RightSidebarTab.preview);
    if (idx >= 0 && _tabController.index != idx) {
      _tabController.animateTo(idx);
    }
  }

  @override
  void dispose() {
    _previewStore?.removeListener(_onPreview);
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() => _ensurePanel(_tabController.index));
    _persistTab();
  }

  Future<void> _persistTab() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTabKey, _tabs[_tabController.index].tab.name);
  }

  void _ensurePanel(int index) {
    switch (index) {
      case 0:
        _filesPanel ??= FileTreePanel(
          onAttachFile: (entry) => widget.onAttachFile?.call(entry),
        );
      case 1:
        _terminalPanel ??= const TerminalPanel();
      case 2:
        _gitPanel ??= const GitReviewPanel();
      case 3:
        _artifactsPanel ??= const ArtifactListView();
      case 5:
        _logsPanel ??= const McpLogsScreen(
          embedded: true,
          initialSource: 'agent',
          title: 'Hermes',
        );
    }
  }

  Widget _panelAt(int index) {
    return switch (index) {
      0 => _filesPanel ?? const SizedBox.shrink(),
      1 => _terminalPanel ?? const SizedBox.shrink(),
      2 => _gitPanel ?? const SizedBox.shrink(),
      3 => _artifactsPanel ?? const SizedBox.shrink(),
      4 => const _RightPreviewPanel(),
      _ => _logsPanel ?? const SizedBox.shrink(),
    };
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final tabName = prefs.getString(_kTabKey);
    if (tabName != null) {
      final idx = _tabs.indexWhere((t) => t.tab.name == tabName);
      if (idx >= 0 && idx != _tabController.index) {
        _tabController.animateTo(idx);
      }
    }
    _collapsed = prefs.getBool(_kCollapsedKey) ?? false;
    if (mounted) setState(() {});
  }

  Future<void> _toggleCollapse() async {
    setState(() => _collapsed = !_collapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCollapsedKey, _collapsed);
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return _buildCollapsedRail(context);
    }
    return SizedBox(
      width: widget.width,
      child: Column(
        children: [
          _buildTabBar(context),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var index = 0; index < _tabs.length; index++)
                  _panelAt(index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2,
              tabs: _tabs
                  .map(
                    (t) => Tab(
                      icon: Icon(t.icon, size: 16),
                      text: _tabLabel(context, t.tab),
                      height: 40,
                    ),
                  )
                  .toList(),
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonCollapse,
            icon: const Icon(Icons.chevron_right, size: 18),
            onPressed: _toggleCollapse,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedRail(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._tabs.asMap().entries.map((e) {
            final idx = e.key;
            final tab = e.value;
            final isSelected = _tabController.index == idx;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: IconButton(
                tooltip: _tabLabel(context, tab.tab),
                icon: Icon(
                  isSelected ? tab.activeIcon : tab.icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                onPressed: () {
                  setState(() => _collapsed = false);
                  _tabController.animateTo(idx);
                },
              ),
            );
          }),
          const Spacer(),
          IconButton(
            tooltip: context.l10n.commonExpand,
            icon: const Icon(Icons.chevron_left, size: 22),
            onPressed: _toggleCollapse,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

String _tabLabel(BuildContext context, RightSidebarTab tab) => switch (tab) {
  RightSidebarTab.files => context.l10n.workspacePaneFiles,
  RightSidebarTab.terminal => context.l10n.workspacePaneTerminal,
  RightSidebarTab.git => 'Git',
  RightSidebarTab.artifacts => context.l10n.featureArtifacts,
  RightSidebarTab.preview => context.l10n.workspacePanePreview,
  RightSidebarTab.logs => context.l10n.workspacePaneLogs,
};

class _TabInfo {
  final RightSidebarTab tab;
  final IconData icon;
  final IconData activeIcon;

  const _TabInfo({
    required this.tab,
    required this.icon,
    required this.activeIcon,
  });
}

class _RightPreviewPanel extends StatelessWidget {
  const _RightPreviewPanel();

  @override
  Widget build(BuildContext context) {
    PreviewStore? preview;
    try {
      preview = context.watch<PreviewStore>();
    } catch (_) {
      preview = null;
    }
    final tabs = preview?.tabs ?? const <PreviewTab>[];
    final active = preview?.activeTab;
    if (tabs.isEmpty) {
      return WebPreviewPane(url: preview?.url, html: preview?.html);
    }
    return Column(
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (_, index) {
              final tab = tabs[index];
              final selected = tab.id == active?.id;
              return InputChip(
                selected: selected,
                label: Text(tab.title, overflow: TextOverflow.ellipsis),
                onPressed: () => preview?.activate(tab.id),
                onDeleted: () => preview?.closeTab(tab.id),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: WebPreviewPane(url: preview?.url, html: preview?.html),
        ),
      ],
    );
  }
}
