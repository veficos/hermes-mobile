import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../kanban/api.dart';
import '../kanban/models.dart';
import '../kanban/store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/kanban_board_sheet.dart';
import '../widgets/kanban_new_task_sheet.dart';
import '../widgets/kanban_task_detail_sheet.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

class KanbanCanonicalScreen extends StatefulWidget {
  final String? initialProjectId;

  const KanbanCanonicalScreen({super.key, this.initialProjectId});
  @override
  State<KanbanCanonicalScreen> createState() => _KanbanCanonicalScreenState();
}

class _KanbanCanonicalScreenState extends State<KanbanCanonicalScreen> {
  final _search = TextEditingController();
  bool _columns = false;
  bool _searching = false;
  bool _initialProjectScheduled = false;
  bool _initialProjectResolved = false;
  bool _projectBoardMissing = false;
  String? _projectBoardError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectId = widget.initialProjectId;
    final store = context.watch<KanbanStore>();
    if (_initialProjectScheduled ||
        projectId == null ||
        projectId.isEmpty ||
        !store.ready) {
      return;
    }
    _initialProjectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectProjectBoard(store, projectId);
    });
  }

  Future<void> _selectProjectBoard(KanbanStore store, String projectId) async {
    try {
      final api = store.api;
      await store.loadBoards(expectedApi: api);
      store.requireApi(api);
      if (store.error case final error?) {
        throw StateError(error);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialProjectResolved = true;
        _projectBoardMissing = false;
        _projectBoardError = context.l10n.kanbanOperationFailed('$error');
      });
      return;
    }
    if (!mounted) return;
    final matches = store.boardList
        .where((board) => board.projectId == projectId)
        .toList();
    if (matches.isEmpty) {
      setState(() {
        _initialProjectResolved = true;
        _projectBoardMissing = true;
        _projectBoardError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.projectNoKanbanBoard)),
      );
      return;
    }
    final selected = matches.firstWhere(
      (board) => board.current,
      orElse: () => matches.first,
    );
    try {
      final api = store.api;
      if (api.boardSlug != selected.slug) {
        await store.selectBoard(selected.slug, expectedApi: api);
      }
      store.requireApi(api);
      if (store.error case final error?) {
        throw StateError(error);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialProjectResolved = true;
        _projectBoardMissing = false;
        _projectBoardError = context.l10n.kanbanOperationFailed('$error');
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _initialProjectResolved = true;
      _projectBoardMissing = false;
      _projectBoardError = null;
    });
  }

  void _retryProjectBoard(KanbanStore store, String projectId) {
    setState(() {
      _initialProjectResolved = false;
      _projectBoardError = null;
    });
    _selectProjectBoard(store, projectId);
  }

  @override
  void dispose() {
    _search.dispose();
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
                padding: const EdgeInsets.all(24),
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
    return MobilePageScaffold(
      title: context.l10n.taskTitle,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _viewToggle()),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: _searching
                          ? context.l10n.taskCloseSearch
                          : context.l10n.taskSearch,
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) {
                          _search.clear();
                          store.setFilters(search: '');
                        }
                      }),
                      icon: Icon(_searching ? Icons.close : Icons.search),
                    ),
                    PopupMenuButton<String>(
                      tooltip: context.l10n.taskOptions,
                      icon: const Icon(Icons.tune, size: 20),
                      onSelected: (value) {
                        if (value == 'boards') _showBoards(context, store);
                        if (value == 'filters') _showFilters(context, store);
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
                ),
                if (_searching) ...[
                  const SizedBox(height: 8),
                  TextField(
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
                      children: [
                        SizedBox(
                          height:
                              MediaQuery.sizeOf(context).height * 0.5,
                          child: HermesEmptyState(
                            icon: Icons.checklist_outlined,
                            title: context.l10n.commonNoData,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: store.load,
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
    );
  }

  Widget _viewToggle() {
    final palette = HermesPalette.of(context);
    Widget option({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) => Expanded(
      child: Material(
        color: selected ? palette.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? palette.text : palette.text3,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.codeBg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            label: context.l10n.taskListView,
            selected: !_columns,
            onTap: () => setState(() => _columns = false),
          ),
          option(
            label: context.l10n.taskBoardView,
            selected: _columns,
            onTap: () => setState(() => _columns = true),
          ),
        ],
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
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(HermesRadius.capsule),
                ),
                child: Text(
                  '$done/$total',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
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

  Widget _listView(KanbanStore s, List<KanbanTask> tasks) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
    children: [for (final task in tasks) _card(task, s)],
  );
  Widget _columnView(KanbanStore s, List<KanbanTask> tasks) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in s.boardData?.columns ?? const <KanbanColumn>[])
              Container(
                width: 190,
                margin: const EdgeInsets.only(right: 9),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: HermesPalette.of(context).codeBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _statusLabel(c.name),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${tasks.where((t) => t.status == c.name).length}',
                          style: TextStyle(
                            color: HermesPalette.of(context).text4,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final task in tasks.where((t) => t.status == c.name))
                      _card(task, s),
                  ],
                ),
              ),
          ],
        ),
      );
  Widget _card(KanbanTask task, KanbanStore store) {
    final palette = HermesPalette.of(context);
    final selected = store.selectedIds.contains(task.id);
    final statusColor = _statusColor(task.status);
    final priorityColor = _priorityColor(task.priority);
    return HermesMobileCard(
      margin: const EdgeInsets.only(bottom: 10),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                HermesMobileStatusChip(
                  label: _statusLabel(task.status),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      context.l10n.taskPriorityMeta(
                        _priorityLabel(task.priority),
                      ),
                      task.assignee ?? context.l10n.taskUnassigned,
                      context.l10n.taskCommentCount(task.commentCount),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.text3, fontSize: 12),
                  ),
                ),
                HermesMobileStatusChip(
                  label: _priorityLabel(task.priority),
                  color: priorityColor,
                  icon: task.warnings != null ? Icons.warning_amber : null,
                ),
              ],
            ),
            if (_taskProgress(task) case final progress?) ...[
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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

  Widget _bulkBar(BuildContext c, KanbanStore s) => BottomAppBar(
    child: Row(
      children: [
        Text(context.l10n.taskSelectedCount(s.selectedIds.length)),
        const Spacer(),
        IconButton(
          tooltip: context.l10n.kanbanMoveSelected,
          onPressed: () => _moveSelected(c, s),
          icon: const Icon(Icons.drive_file_move),
        ),
        IconButton(
          tooltip: context.l10n.kanbanClearSelection,
          onPressed: s.clearSelection,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
  Future<void> _moveSelected(BuildContext c, KanbanStore s) async {
    final status = await showModalBottomSheet<String>(
      context: c,
      builder: (_) => ListView(
        children: [
          for (final col in s.boardData?.columns ?? const <KanbanColumn>[])
            ListTile(
              title: Text(col.name),
              onTap: () => Navigator.pop(c, col.name),
            ),
        ],
      ),
    );
    if (status == null) return;
    final failed = await s.bulkPatch(s.selectedIds, {'status': status});
    if (c.mounted && failed.isNotEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(
        SnackBar(content: Text(c.l10n.taskBulkFailed(failed.length))),
      );
    }
  }

  Future<void> _detail(BuildContext c, KanbanTask t, KanbanStore s) async {
    final d = await s.loadDetail(t.id);
    if (!c.mounted || d == null) return;
    showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      builder: (_) => KanbanTaskDetailSheet(initial: d, store: s),
    );
  }

  Future<void> _showBoards(BuildContext c, KanbanStore s) =>
      showKanbanBoardSheet(c, s);
  Future<void> _showFilters(BuildContext c, KanbanStore s) async {
    await showModalBottomSheet<void>(
      context: c,
      builder: (sheet) => StatefulBuilder(
        builder: (_, setSheet) => ListView(
          children: [
            ListTile(title: Text(context.l10n.taskFilter)),
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
                final a = await showModalBottomSheet<String>(
                  context: sheet,
                  builder: (_) => ListView(
                    children: [
                      ListTile(
                        title: Text(context.l10n.taskAll),
                        onTap: () => Navigator.pop(sheet, ''),
                      ),
                      for (final x
                          in s.boardData?.assignees ?? const <String>[])
                        ListTile(
                          title: Text(x),
                          onTap: () => Navigator.pop(sheet, x),
                        ),
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
                final a = await showModalBottomSheet<String>(
                  context: sheet,
                  builder: (_) => ListView(
                    children: [
                      ListTile(
                        title: Text(context.l10n.taskAll),
                        onTap: () => Navigator.pop(sheet, ''),
                      ),
                      for (final x in s.boardData?.tenants ?? const <String>[])
                        ListTile(
                          title: Text(x),
                          onTap: () => Navigator.pop(sheet, x),
                        ),
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
    final messenger = ScaffoldMessenger.of(c);
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
        messenger.showSnackBar(
          SnackBar(content: Text(c.l10n.kanbanOperationFailed('$error'))),
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
    await showModalBottomSheet<void>(
      context: c,
      builder: (sheet) => StatefulBuilder(
        builder: (_, setSheet) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.l10n.taskOrchestration,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
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
                  (p) => DropdownMenuItem(value: p.name, child: Text(p.name)),
                ),
              ],
              onChanged: (v) => setSheet(() => orchestrator = v ?? ''),
            ),
            DropdownButtonFormField<String>(
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
                  (p) => DropdownMenuItem(value: p.name, child: Text(p.name)),
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
                    ScaffoldMessenger.of(sheet).showSnackBar(
                      SnackBar(content: Text(sheet.l10n.commonOperationFailed)),
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
                  final value = await showModalBottomSheet<String>(
                    context: sheet,
                    isScrollControlled: true,
                    builder: (edit) => Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.viewInsetsOf(edit).bottom + 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: ctl,
                            minLines: 3,
                            maxLines: 8,
                            decoration: InputDecoration(
                              labelText: context.l10n.taskProfileDescription(
                                p.name,
                              ),
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
                    final idx = profiles.indexWhere((x) => x.name == p.name);
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
                      ScaffoldMessenger.of(sheet).showSnackBar(
                        SnackBar(
                          content: Text(sheet.l10n.commonOperationFailed),
                        ),
                      );
                    }
                  }
                },
                trailing: busyProfiles.contains(p.name)
                    ? const Padding(
                        padding: EdgeInsets.all(8),
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
                              ScaffoldMessenger.of(sheet).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    sheet.l10n.commonOperationFailed,
                                  ),
                                ),
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
      ),
    );
  }

  Future<void> _newTask(BuildContext c, KanbanStore s) =>
      showKanbanNewTaskSheet(c, s);
}
