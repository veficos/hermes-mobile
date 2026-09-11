import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../kanban/api.dart';
import '../kanban/models.dart';
import '../kanban/store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../theme/hermes_glass_theme.dart';
import '../widgets/glass/glass_search_field.dart';
import '../widgets/glass/glass_selection_row.dart';
import '../widgets/glass/glass_surface.dart';
import '../widgets/h/hermes_segmented_control.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/kanban_board_sheet.dart';
import '../widgets/kanban_new_task_sheet.dart';
import 'kanban_task_detail_screen.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/hermes_adaptive_menu.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

/// 列表/看板切换控件的最大宽度（保持旧 190px 视觉）。
const double _kViewToggleMaxWidth = 190;

/// 看板列宽自适应：列宽 = clamp(可用宽 × [_kBoardColumnWidthFactor],
/// [_kBoardColumnMinWidth], [_kBoardColumnMaxWidth])，保证窄屏上至少露出
/// 下一列的边缘，提示可横向滚动。
const double _kBoardColumnMinWidth = 190;
const double _kBoardColumnMaxWidth = 260;
const double _kBoardColumnWidthFactor = 0.72;

class KanbanCanonicalScreen extends StatefulWidget {
  final String? initialProjectId;

  const KanbanCanonicalScreen({super.key, this.initialProjectId});
  @override
  State<KanbanCanonicalScreen> createState() => _KanbanCanonicalScreenState();
}

class _KanbanCanonicalScreenState extends State<KanbanCanonicalScreen> {
  final _search = TextEditingController();
  final _searchActionFocus = FocusNode(debugLabel: 'Task search action');
  final _searchFieldFocus = FocusNode(debugLabel: 'Task search field');

  void _toggleSearch(KanbanStore store) {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search.clear();
        store.setFilters(search: '');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_searching ? _searchFieldFocus : _searchActionFocus).requestFocus();
    });
  }

  bool _columns = false;
  bool _searching = false;
  bool _movingSelection = false;
  bool _submittingSelection = false;
  bool _initialProjectScheduled = false;
  bool _initialProjectResolved = false;
  bool _projectBoardMissing = false;
  String? _projectBoardError;
  KanbanApi? _initialProjectApi;
  int _initialProjectGeneration = 0;

  @override
  void didUpdateWidget(covariant KanbanCanonicalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialProjectId == widget.initialProjectId) return;
    ++_initialProjectGeneration;
    _initialProjectScheduled = false;
    _initialProjectResolved = false;
    _projectBoardMissing = false;
    _projectBoardError = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectId = widget.initialProjectId;
    final store = context.watch<KanbanStore>();
    final currentApi = store.ready ? store.api : null;
    if (!identical(currentApi, _initialProjectApi)) {
      _initialProjectApi = currentApi;
      ++_initialProjectGeneration;
      _initialProjectScheduled = false;
      _initialProjectResolved = false;
      _projectBoardMissing = false;
      _projectBoardError = null;
    }
    if (_initialProjectScheduled ||
        projectId == null ||
        projectId.isEmpty ||
        !store.ready) {
      return;
    }
    _initialProjectScheduled = true;
    final generation = _initialProjectGeneration;
    final api = currentApi!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectProjectBoard(store, projectId, generation, api);
    });
  }

  bool _ownsInitialProjectTarget(KanbanApi api, int generation) {
    return mounted &&
        generation == _initialProjectGeneration &&
        identical(api, _initialProjectApi);
  }

  Future<void> _selectProjectBoard(
    KanbanStore store,
    String projectId,
    int generation,
    KanbanApi api,
  ) async {
    final noBoardMessage = context.l10n.projectNoKanbanBoard;
    try {
      await store.loadBoards(expectedApi: api);
      store.requireApi(api);
      if (store.error case final error?) {
        throw StateError(error);
      }
    } catch (error) {
      if (!_ownsInitialProjectTarget(api, generation)) return;
      setState(() {
        _initialProjectResolved = true;
        _projectBoardMissing = false;
        _projectBoardError = context.l10n.kanbanOperationFailed('$error');
      });
      return;
    }
    if (!mounted || !_ownsInitialProjectTarget(api, generation)) return;
    final matches = store.boardList
        .where((board) => board.projectId == projectId)
        .toList();
    if (matches.isEmpty) {
      setState(() {
        _initialProjectResolved = true;
        _projectBoardMissing = true;
        _projectBoardError = null;
      });
      showHermesToast(context, message: noBoardMessage);
      return;
    }
    final selected = matches.firstWhere(
      (board) => board.current,
      orElse: () => matches.first,
    );
    try {
      if (api.boardSlug != selected.slug) {
        await store.selectBoard(selected.slug, expectedApi: api);
      }
      store.requireApi(api);
      if (store.error case final error?) {
        throw StateError(error);
      }
    } catch (error) {
      if (!_ownsInitialProjectTarget(api, generation)) return;
      setState(() {
        _initialProjectResolved = true;
        _projectBoardMissing = false;
        _projectBoardError = context.l10n.kanbanOperationFailed('$error');
      });
      return;
    }
    if (!_ownsInitialProjectTarget(api, generation)) return;
    setState(() {
      _initialProjectResolved = true;
      _projectBoardMissing = false;
      _projectBoardError = null;
    });
  }

  void _retryProjectBoard(KanbanStore store, String projectId) {
    final api = _initialProjectApi;
    if (api == null) return;
    setState(() {
      _initialProjectResolved = false;
      _projectBoardError = null;
    });
    _selectProjectBoard(store, projectId, _initialProjectGeneration, api);
  }

  @override
  void dispose() {
    _search.dispose();
    _searchActionFocus.dispose();
    _searchFieldFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<KanbanStore>();
    if (!store.ready) {
      return MobilePageScaffold(
        title: context.l10n.taskTitle,
        body: Center(child: Text(context.l10n.taskConnectBackend)),
      );
    }
    if (widget.initialProjectId case final projectId?
        when projectId.isNotEmpty &&
            _initialProjectScheduled &&
            !_initialProjectResolved) {
      return MobilePageScaffold(
        title: context.l10n.taskTitle,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_projectBoardMissing) {
      return MobilePageScaffold(
        title: context.l10n.taskTitle,
        body: Center(child: Text(context.l10n.projectNoKanbanBoard)),
      );
    }
    if (_projectBoardError case final error?) {
      return MobilePageScaffold(
        title: context.l10n.taskTitle,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(HermesSpacing.xl),
                child: Text(error, textAlign: TextAlign.center),
              ),
              FilledButton.icon(
                onPressed: () =>
                    _retryProjectBoard(store, widget.initialProjectId!),
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    final tasks = store.filteredTasks;
    final hasResultFilters =
        store.search.trim().isNotEmpty ||
        store.assigneeFilter.isNotEmpty ||
        store.tenantFilter.isNotEmpty;
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (_searching &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          final composing = _search.value.composing;
          if (composing.isValid && !composing.isCollapsed) {
            return KeyEventResult.ignored;
          }
          _toggleSearch(store);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: HermesPageScaffold(
        separateHeader: HermesGlassTheme.of(context).enabled,
        title: context.l10n.taskTitle,
        titleMode: HermesPageTitleMode.large,
        maxContentWidth: HermesLayout.workspace,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HermesMobileMetrics.pagePadding,
                HermesSpacing.sm,
                HermesMobileMetrics.pagePadding,
                HermesSpacing.sm,
              ),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked =
                          constraints.maxWidth < 360 ||
                          MediaQuery.textScalerOf(context).scale(14) > 21;
                      final actions = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 6),
                          IconButton(
                            focusNode: _searchActionFocus,
                            tooltip: _searching
                                ? context.l10n.taskCloseSearch
                                : context.l10n.taskSearch,
                            onPressed: () => _toggleSearch(store),
                            icon: Icon(_searching ? Icons.close : Icons.search),
                          ),
                          HermesAdaptiveMenuButton<String>(
                            tooltip: context.l10n.taskOptions,
                            icon: const Icon(Icons.tune, size: 20),
                            onSelected: (value) {
                              if (value == 'boards') {
                                _showBoards(context, store);
                              }
                              if (value == 'filters') {
                                _showFilters(context, store);
                              }
                              if (value == 'orchestration') {
                                _showOrchestration(context, store);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'boards',
                                child: Text(context.l10n.taskSwitchBoard),
                              ),
                              PopupMenuItem(
                                value: 'filters',
                                child: Text(context.l10n.taskFilter),
                              ),
                              PopupMenuItem(
                                value: 'orchestration',
                                child: Text(context.l10n.taskOrchestration),
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: context.l10n.taskNew,
                            onPressed: () => _newTask(context, store),
                            icon: const Icon(Icons.add, size: 21),
                          ),
                        ],
                      );
                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _viewToggle(),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: actions,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _viewToggle()),
                          actions,
                        ],
                      );
                    },
                  ),
                  if (_searching) ...[
                    const SizedBox(height: 8),
                    if (HermesGlassTheme.of(context).enabled)
                      GlassSearchField(
                        focusNode: _searchFieldFocus,
                        controller: _search,
                        autofocus: true,
                        hintText: context.l10n.taskSearch,
                        onChanged: (value) => store.setFilters(search: value),
                      )
                    else
                      TextField(
                        focusNode: _searchFieldFocus,
                        controller: _search,
                        autofocus: true,
                        onChanged: (value) => store.setFilters(search: value),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18),
                          hintText: context.l10n.taskSearch,
                          isDense: true,
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  if (store.assigneeFilter.isNotEmpty ||
                      store.tenantFilter.isNotEmpty ||
                      store.includeArchived)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (store.assigneeFilter.isNotEmpty)
                              Text(
                                context.l10n.taskAssigneeFilter(
                                  store.assigneeFilter,
                                ),
                              ),
                            if (store.tenantFilter.isNotEmpty)
                              Text(
                                context.l10n.taskTenantFilter(
                                  store.tenantFilter,
                                ),
                              ),
                            if (store.includeArchived)
                              Text(context.l10n.taskShowArchived),
                            TextButton(
                              key: const ValueKey('task-clear-visible-filters'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                              ),
                              onPressed: () => store.setFilters(
                                assignee: '',
                                tenant: '',
                                archived: false,
                              ),
                              child: Text(context.l10n.taskClearFilters),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _deliverySummary(tasks),
                ],
              ),
            ),
            Expanded(
              child: store.loading && store.boardData == null
                  ? const Center(child: CircularProgressIndicator())
                  : store.error != null && store.boardData == null
                  ? HermesErrorState(
                      description: context.l10n.kanbanOperationFailed(
                        store.error!,
                      ),
                      onRetry: store.load,
                    )
                  : tasks.isEmpty
                  ? RefreshIndicator(
                      onRefresh: store.load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: HermesEmptyState(
                              icon: hasResultFilters
                                  ? Icons.search_off
                                  : Icons.checklist_outlined,
                              title: hasResultFilters
                                  ? context.l10n.commonNoMatches
                                  : context.l10n.commonNoData,
                              primaryLabel: hasResultFilters
                                  ? context.l10n.taskClearFilters
                                  : context.l10n.taskNew,
                              onPrimary: hasResultFilters
                                  ? () {
                                      _search.clear();
                                      store.setFilters(
                                        search: '',
                                        assignee: '',
                                        tenant: '',
                                      );
                                    }
                                  : () => _newTask(context, store),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: store.load,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.vertical &&
                          notification.depth == (_columns ? 1 : 0),
                      child: _columns
                          ? _columnView(store, tasks)
                          : _listView(store, tasks),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: store.selectedIds.isEmpty
            ? null
            : _bulkBar(context, store),
      ),
    );
  }

  Widget _viewToggle() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kViewToggleMaxWidth),
      child: HermesSegmentedControl<bool>(
        options: [
          HermesSegment(value: false, label: context.l10n.taskListView),
          HermesSegment(value: true, label: context.l10n.taskBoardView),
        ],
        selected: _columns,
        onChanged: (v) => setState(() => _columns = v),
      ),
    );
  }

  Widget _deliverySummary(List<KanbanTask> tasks) {
    final palette = HermesPalette.of(context);
    final done = tasks.where((task) => task.status == 'done').length;
    final total = tasks.length;
    final progress = total == 0 ? 0.0 : done / total;
    return HermesMobileCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.taskWeeklyDelivery,
                  style: HermesType.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HermesSpacing.xs,
                  vertical: HermesSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(HermesRadius.capsule),
                ),
                child: Text(
                  '$done/$total',
                  style: HermesType.caption.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(HermesRadius.smallCard),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              color: palette.accent,
              backgroundColor: palette.codeBg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listView(KanbanStore s, List<KanbanTask> tasks) => ListView.builder(
    key: PageStorageKey((s.api.client, s.api.boardSlug, 'task-list')),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(
      HermesMobileMetrics.pagePadding,
      0,
      HermesMobileMetrics.pagePadding,
      HermesSpacing.xl,
    ),
    itemCount: tasks.length,
    itemBuilder: (_, index) => _card(tasks[index], s),
  );
  Widget _columnView(KanbanStore s, List<KanbanTask> tasks) => LayoutBuilder(
    key: PageStorageKey((s.api.client, s.api.boardSlug, 'task-board')),
    builder: (context, constraints) {
      final columnWidth = (constraints.maxWidth * _kBoardColumnWidthFactor)
          .clamp(_kBoardColumnMinWidth, _kBoardColumnMaxWidth)
          .toDouble();
      return _BoardScrollSurface(
        key: ValueKey((s.api.client, s.api.boardSlug)),
        columnWidth: columnWidth,
        labels: [
          for (final c in s.boardData?.columns ?? const <KanbanColumn>[])
            _statusLabel(c.name),
        ],
        child: SingleChildScrollView(
          key: const PageStorageKey('task-board-horizontal'),
          primary: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            HermesMobileMetrics.pagePadding,
            0,
            HermesMobileMetrics.pagePadding,
            HermesSpacing.xl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in s.boardData?.columns ?? const <KanbanColumn>[])
                Container(
                  width: columnWidth,
                  margin: const EdgeInsets.only(right: HermesSpacing.xs),
                  padding: const EdgeInsets.all(HermesSpacing.xs),
                  decoration: BoxDecoration(
                    color: HermesPalette.of(context).codeBg,
                    borderRadius: BorderRadius.circular(HermesRadius.card),
                  ),
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _statusLabel(c.name),
                                style: HermesType.subheadline.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${tasks.where((t) => t.status == c.name).length}',
                              style: HermesType.caption.copyWith(
                                color: HermesPalette.of(context).text4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: HermesSpacing.xs),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final columnTasks = tasks
                                .where((t) => t.status == c.name)
                                .toList();
                            return ListView.builder(
                              key: PageStorageKey('task-column-${c.name}'),
                              primary: false,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: columnTasks.length,
                              itemBuilder: (_, index) =>
                                  _card(columnTasks[index], s),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  Widget _card(KanbanTask task, KanbanStore store) {
    final palette = HermesPalette.of(context);
    final selected = store.selectedIds.contains(task.id);
    final statusColor = _statusColor(task.status);
    final priorityColor = _priorityColor(task.priority);
    final progress = _taskProgress(task);
    return Semantics(
      button: true,
      selected: selected,
      label: [
        task.title,
        _statusLabel(task.status),
        _priorityLabel(task.priority),
        task.assignee ?? context.l10n.taskUnassigned,
        context.l10n.taskCommentCount(task.commentCount),
      ].join(' · '),
      value: progress == null ? null : '${(progress * 100).round()}%',
      onTap: () => store.selectedIds.isNotEmpty
          ? store.toggleSelected(task.id)
          : _detail(context, task, store),
      onLongPress: () => store.toggleSelected(task.id),
      child: ExcludeSemantics(
        child: HermesMobileCard(
          margin: const EdgeInsets.only(bottom: HermesSpacing.sm),
          color: selected ? palette.accentBg : null,
          onTap: () => store.selectedIds.isNotEmpty
              ? store.toggleSelected(task.id)
              : _detail(context, task, store),
          child: GestureDetector(
            onLongPress: () => store.toggleSelected(task.id),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: HermesType.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    HermesStatusChip(
                      label: _statusLabel(task.status),
                      color: statusColor,
                    ),
                    HermesStatusChip(
                      label: _priorityLabel(task.priority),
                      color: priorityColor,
                      icon: task.warnings != null ? Icons.warning_amber : null,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  [
                    task.assignee ?? context.l10n.taskUnassigned,
                    context.l10n.taskCommentCount(task.commentCount),
                  ].join(' · '),
                  style: HermesType.footnote.copyWith(color: palette.text3),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(HermesRadius.smallCard),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: progress,
                      color: palette.accent,
                      backgroundColor: palette.codeBg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'triage' => context.l10n.taskStatusTriage,
    'todo' => context.l10n.taskStatusTodo,
    'scheduled' => context.l10n.taskStatusScheduled,
    'ready' => context.l10n.taskStatusReady,
    'running' => context.l10n.taskStatusRunning,
    'blocked' => context.l10n.taskStatusBlocked,
    'review' => context.l10n.taskStatusReview,
    'done' => context.l10n.taskStatusDone,
    'archived' => context.l10n.taskStatusArchived,
    _ => status,
  };

  Color _statusColor(String status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      'running' ||
      'done' => dark ? HermesSemanticDark.green : HermesSemantic.green,
      'blocked' => dark ? HermesSemanticDark.red : HermesSemantic.red,
      'review' ||
      'scheduled' => dark ? HermesSemanticDark.orange : HermesSemantic.orange,
      _ => dark ? HermesSemanticDark.gray : HermesSemantic.gray,
    };
  }

  String _priorityLabel(int priority) => switch (priority) {
    2 => context.l10n.taskPriorityUrgent,
    1 => context.l10n.taskPriorityHigh,
    _ => context.l10n.taskPriorityNormal,
  };

  Color _priorityColor(int priority) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (priority) {
      2 => dark ? HermesSemanticDark.red : HermesSemantic.red,
      1 => dark ? HermesSemanticDark.orange : HermesSemantic.orange,
      _ => dark ? HermesSemanticDark.blue : HermesSemantic.blue,
    };
  }

  double? _taskProgress(KanbanTask task) {
    final progress = task.progress;
    if (progress == null) return null;
    final percent = progress['percent'];
    if (percent is num) return (percent / 100).clamp(0, 1).toDouble();
    final current = progress['current'] ?? progress['completed'];
    final total = progress['total'];
    if (current is num && total is num && total > 0) {
      return (current / total).clamp(0, 1).toDouble();
    }
    return null;
  }

  Widget _bulkBar(BuildContext c, KanbanStore s) {
    final content = Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.taskSelectedCount(s.selectedIds.length)),
                if (_submittingSelection)
                  Text(
                    context.l10n.commonProcessing,
                    key: const ValueKey('task-bulk-processing'),
                    style: Theme.of(c).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        Semantics(
          button: true,
          label: context.l10n.kanbanMoveSelected,
          child: IconButton(
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              visualDensity: VisualDensity.standard,
            ),
            tooltip: context.l10n.kanbanMoveSelected,
            onPressed: _movingSelection ? null : () => _moveSelected(c, s),
            icon: const Icon(Icons.drive_file_move),
          ),
        ),
        Semantics(
          button: true,
          label: context.l10n.kanbanClearSelection,
          child: IconButton(
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              visualDensity: VisualDensity.standard,
            ),
            tooltip: context.l10n.kanbanClearSelection,
            onPressed: _submittingSelection ? null : s.clearSelection,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
    if (!HermesGlassTheme.of(c).enabled) {
      // BottomAppBar's fixed default height clips scaled selection/status text.
      return Material(
        color: Theme.of(c).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: content,
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: GlassSurface(
          key: const ValueKey('task-bulk-glass'),
          role: HermesGlassRole.control,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: content,
          ),
        ),
      ),
    );
  }

  Future<void> _moveSelected(BuildContext c, KanbanStore s) async {
    if (_movingSelection || s.selectedIds.isEmpty || !s.ready) return;
    final ids = Set<String>.of(s.selectedIds);
    final ownerApi = s.api;
    final board = ownerApi.boardSlug;
    final epoch = s.ownerEpoch;
    setState(() => _movingSelection = true);
    try {
      final status = await showMobileSheet<String>(
        c,
        isScrollControlled: false,
        (sheet) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Semantics(
              header: true,
              child: Text(
                c.l10n.kanbanMoveSelected,
                key: const ValueKey('task-move-title'),
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Text(c.l10n.taskSelectedCount(ids.length)),
            const SizedBox(height: 16),
            HermesMobileGroup(
              children: [
                for (final col
                    in s.boardData?.columns ?? const <KanbanColumn>[])
                  HermesMobileRow(
                    key: ValueKey('task-move-target-${col.name}'),
                    icon: Icons.drive_file_move_outlined,
                    title: _statusLabel(col.name),
                    onTap: () => Navigator.pop(sheet, col.name),
                  ),
              ],
            ),
          ],
        ),
      );
      if (!c.mounted ||
          status == null ||
          !s.ready ||
          s.ownerEpoch != epoch ||
          !identical(s.api, ownerApi) ||
          ownerApi.boardSlug != board) {
        return;
      }
      setState(() => _submittingSelection = true);
      final failed = await s.bulkPatch(ids, {'status': status});
      if (c.mounted && s.ownerEpoch == epoch && failed.isNotEmpty) {
        showHermesToast(
          c,
          message: c.l10n.taskBulkFailed(failed.length),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _movingSelection = false;
          _submittingSelection = false;
        });
      }
    }
  }

  Future<void> _detail(BuildContext c, KanbanTask t, KanbanStore s) async {
    final d = await s.loadDetail(t.id);
    if (!c.mounted || d == null) return;
    Navigator.of(c).push(
      MaterialPageRoute<void>(
        builder: (_) => KanbanTaskDetailScreen(initial: d, store: s),
      ),
    );
  }

  Future<void> _showBoards(BuildContext c, KanbanStore s) =>
      showKanbanBoardSheet(c, s);

  Widget _filterChoice(BuildContext context, String value, String selected) {
    final liquid = HermesGlassTheme.of(context).enabled;
    final active = value == selected;
    return GlassSelectionRow(
      selected: active,
      child: ListTile(
        selected: liquid && active,
        title: Text(value.isEmpty ? context.l10n.taskAll : value),
        trailing: liquid && active ? const Icon(Icons.check, size: 20) : null,
        onTap: () => Navigator.pop(context, value),
      ),
    );
  }

  Widget _filterHeading(BuildContext context, String title) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  );

  Future<void> _showFilters(BuildContext c, KanbanStore s) async {
    await showMobileSheet<void>(
      c,
      isScrollControlled: false,
      (sheet) => StatefulBuilder(
        builder: (_, setSheet) => ListView(
          children: [
            _filterHeading(sheet, context.l10n.taskFilter),
            SwitchListTile(
              title: Text(context.l10n.taskShowArchived),
              value: s.includeArchived,
              onChanged: (v) {
                s.setFilters(archived: v);
                setSheet(() {});
              },
            ),
            ListTile(
              title: Text(
                context.l10n.taskAssigneeFilter(
                  s.assigneeFilter.isEmpty
                      ? context.l10n.taskAll
                      : s.assigneeFilter,
                ),
              ),
              onTap: () async {
                final a = await showMobileSheet<String>(
                  sheet,
                  isScrollControlled: false,
                  (picker) => ListView(
                    children: [
                      _filterHeading(picker, context.l10n.kanbanAssignee),
                      _filterChoice(picker, '', s.assigneeFilter),
                      for (final x
                          in s.boardData?.assignees ?? const <String>[])
                        _filterChoice(picker, x, s.assigneeFilter),
                    ],
                  ),
                );
                if (a != null) {
                  s.setFilters(assignee: a);
                  setSheet(() {});
                }
              },
            ),
            ListTile(
              title: Text(
                context.l10n.taskTenantFilter(
                  s.tenantFilter.isEmpty
                      ? context.l10n.taskAll
                      : s.tenantFilter,
                ),
              ),
              onTap: () async {
                final a = await showMobileSheet<String>(
                  sheet,
                  isScrollControlled: false,
                  (picker) => ListView(
                    children: [
                      _filterHeading(picker, context.l10n.kanbanTenant),
                      _filterChoice(picker, '', s.tenantFilter),
                      for (final x in s.boardData?.tenants ?? const <String>[])
                        _filterChoice(picker, x, s.tenantFilter),
                    ],
                  ),
                );
                if (a != null) {
                  s.setFilters(tenant: a);
                  setSheet(() {});
                }
              },
            ),
            TextButton(
              onPressed: () {
                s.setFilters(assignee: '', tenant: '', archived: false);
                Navigator.pop(sheet);
              },
              child: Text(context.l10n.taskClearFilters),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOrchestration(BuildContext c, KanbanStore s) async {
    late final KanbanApi api;
    late final Map<String, dynamic> raw;
    late final Map<String, dynamic> profileRaw;
    try {
      api = s.api;
      raw = await api.orchestration();
      profileRaw = await api.profiles();
      s.requireApi(api);
    } catch (error) {
      if (c.mounted) {
        showHermesErrorSnackBar(
          c,
          error,
          fallback: c.l10n.kanbanOperationFailed('$error'),
        );
      }
      return;
    }
    if (!c.mounted) return;
    final settings = KanbanOrchestration.fromJson(raw);
    final profiles = (profileRaw['profiles'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => KanbanProfile.fromJson(e.cast<String, dynamic>()))
        .toList();
    var auto = settings.autoDecompose;
    var orchestrator = settings.orchestratorProfile;
    var assignee = settings.defaultAssignee;
    final busyProfiles = <String>{};
    await showMobileSheet<void>(
      c,
      isScrollControlled: false,
      (sheet) => AnimatedBuilder(
        animation: s,
        builder: (_, _) {
          try {
            s.requireApi(api);
          } catch (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (sheet.mounted) Navigator.pop(sheet);
            });
            return const SizedBox.shrink();
          }
          return StatefulBuilder(
            builder: (_, setSheet) => ListView(
              padding: const EdgeInsets.all(HermesSpacing.md),
              children: [
                Text(
                  context.l10n.taskOrchestration,
                  style: HermesType.title.copyWith(fontWeight: FontWeight.bold),
                ),
                DropdownButtonFormField<String>(
                  dropdownColor: hermesDropdownColor(context),
                  borderRadius: hermesDropdownBorderRadius,
                  initialValue: orchestrator,
                  decoration: InputDecoration(
                    labelText: context.l10n.taskOrchestratorProfile,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.l10n.taskDefault),
                    ),
                    ...profiles.map(
                      (p) =>
                          DropdownMenuItem(value: p.name, child: Text(p.name)),
                    ),
                  ],
                  onChanged: (v) => setSheet(() => orchestrator = v ?? ''),
                ),
                DropdownButtonFormField<String>(
                  dropdownColor: hermesDropdownColor(context),
                  borderRadius: hermesDropdownBorderRadius,
                  initialValue: assignee,
                  decoration: InputDecoration(
                    labelText: context.l10n.taskDefaultAssignee,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.l10n.taskDefault),
                    ),
                    ...profiles.map(
                      (p) =>
                          DropdownMenuItem(value: p.name, child: Text(p.name)),
                    ),
                  ],
                  onChanged: (v) => setSheet(() => assignee = v ?? ''),
                ),
                SwitchListTile(
                  title: Text(context.l10n.taskAutoDecompose),
                  value: auto,
                  onChanged: (v) => setSheet(() => auto = v),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await s.requireApi(api).saveOrchestration({
                        'orchestrator_profile': orchestrator,
                        'default_assignee': assignee,
                        'auto_decompose': auto,
                      });
                      if (sheet.mounted) Navigator.pop(sheet);
                    } catch (e) {
                      if (sheet.mounted) {
                        showHermesErrorSnackBar(
                          sheet,
                          e,
                          fallback: sheet.l10n.commonOperationFailed,
                        );
                      }
                    }
                  },
                  child: Text(context.l10n.commonSave),
                ),
                const Divider(),
                Text(
                  context.l10n.taskProfileDescriptions,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final p in profiles)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      p.description.isEmpty
                          ? context.l10n.taskNoDescription
                          : p.description,
                    ),
                    onTap: () async {
                      final ctl = TextEditingController(text: p.description);
                      final value = await showMobileSheet<String>(
                        sheet,
                        (edit) => Padding(
                          padding: const EdgeInsets.all(HermesSpacing.md),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: ctl,
                                minLines: 3,
                                maxLines: 8,
                                decoration: InputDecoration(
                                  labelText: context.l10n
                                      .taskProfileDescription(p.name),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(edit, ctl.text.trim()),
                                child: Text(context.l10n.commonSave),
                              ),
                            ],
                          ),
                        ),
                      );
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => ctl.dispose(),
                      );
                      if (value == null) return;
                      try {
                        await s
                            .requireApi(api)
                            .saveProfileDescription(p.name, value);
                        if (!sheet.mounted) return;
                        final idx = profiles.indexWhere(
                          (x) => x.name == p.name,
                        );
                        if (idx != -1) {
                          profiles[idx] = KanbanProfile(
                            name: p.name,
                            description: value,
                            isDefault: p.isDefault,
                            descriptionAuto: false,
                          );
                        }
                        setSheet(() {});
                      } catch (e) {
                        if (sheet.mounted) {
                          showHermesErrorSnackBar(
                            sheet,
                            e,
                            fallback: sheet.l10n.commonOperationFailed,
                          );
                        }
                      }
                    },
                    trailing: busyProfiles.contains(p.name)
                        ? const Padding(
                            padding: EdgeInsets.all(HermesSpacing.xs),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: context.l10n.taskAutoGenerate,
                            icon: const Icon(Icons.auto_awesome),
                            onPressed: () async {
                              setSheet(() => busyProfiles.add(p.name));
                              try {
                                final result = await s
                                    .requireApi(api)
                                    .autoDescribeProfile(p.name);
                                final description = result is Map
                                    ? (result['description']?.toString() ?? '')
                                    : '';
                                if (!sheet.mounted) return;
                                final idx = profiles.indexWhere(
                                  (x) => x.name == p.name,
                                );
                                if (idx != -1 && description.isNotEmpty) {
                                  profiles[idx] = KanbanProfile(
                                    name: p.name,
                                    description: description,
                                    isDefault: p.isDefault,
                                    descriptionAuto: true,
                                  );
                                }
                              } catch (e) {
                                if (sheet.mounted) {
                                  showHermesErrorSnackBar(
                                    sheet,
                                    e,
                                    fallback: sheet.l10n.commonOperationFailed,
                                  );
                                }
                              } finally {
                                if (sheet.mounted) {
                                  setSheet(() => busyProfiles.remove(p.name));
                                }
                              }
                            },
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _newTask(BuildContext c, KanbanStore s) =>
      showKanbanNewTaskSheet(c, s);
}

/// One horizontal controller per board. Vertical task lists explicitly opt
/// out of it, so the visible draggable thumb only navigates board columns.
class _BoardScrollSurface extends StatefulWidget {
  const _BoardScrollSurface({
    super.key,
    required this.child,
    required this.columnWidth,
    required this.labels,
  });
  final Widget child;
  final double columnWidth;
  final List<String> labels;

  @override
  State<_BoardScrollSurface> createState() => _BoardScrollSurfaceState();
}

class _BoardScrollSurfaceState extends State<_BoardScrollSurface> {
  final _controller = ScrollController();
  bool _canPrevious = false;
  bool _canNext = false;
  bool _syncScheduled = false;
  int _first = 0;
  int _last = 0;

  @override
  void didUpdateWidget(covariant _BoardScrollSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleBounds();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleBounds);
  }

  void _scheduleBounds() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted ||
          !_controller.hasClients ||
          !_controller.position.hasContentDimensions) {
        return;
      }
      final position = _controller.position;
      final previous = position.pixels > position.minScrollExtent + .5;
      final next = position.pixels < position.maxScrollExtent - .5;
      final stride = widget.columnWidth + HermesSpacing.xs;
      final limit = widget.labels.isEmpty ? 0 : widget.labels.length - 1;
      final start = position.pixels - HermesMobileMetrics.pagePadding;
      final first = ((start + HermesSpacing.xs) / stride).floor().clamp(
        0,
        limit,
      );
      final last = ((start + position.viewportDimension) / stride).ceil() - 1;
      final boundedLast = last.clamp(first, limit);
      if (previous != _canPrevious ||
          next != _canNext ||
          first != _first ||
          boundedLast != _last) {
        setState(() {
          _canPrevious = previous;
          _canNext = next;
          _first = first;
          _last = boundedLast;
        });
      }
    });
  }

  void _step(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final delta = widget.columnWidth + HermesSpacing.xs;
    _controller.jumpTo(
      (position.pixels + direction * delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: _controller,
    child: NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.horizontal) _scheduleBounds();
        return false;
      },
      child: Scrollbar(
        key: const ValueKey('task-board-scrollbar'),
        controller: _controller,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        notificationPredicate: (notification) =>
            notification.depth == 0 &&
            notification.metrics.axis == Axis.horizontal,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('task-board-previous'),
                  tooltip: context.l10n.taskPreviousColumn,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    visualDensity: VisualDensity.standard,
                  ),
                  onPressed: _canPrevious ? () => _step(-1) : null,
                  icon: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.labels.isEmpty
                        ? context.l10n.taskBoardView
                        : context.l10n.taskVisibleColumns(
                            _first.clamp(0, widget.labels.length - 1) + 1,
                            _last.clamp(0, widget.labels.length - 1) + 1,
                            widget.labels.length,
                          ),
                    key: const ValueKey('task-board-visible-columns'),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  key: const ValueKey('task-board-next'),
                  tooltip: context.l10n.taskNextColumn,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    visualDensity: VisualDensity.standard,
                  ),
                  onPressed: _canNext ? () => _step(1) : null,
                  icon: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                  ),
                ),
              ],
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    ),
  );
}
