import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../kanban/api.dart';
import '../kanban/models.dart';
import '../kanban/store.dart';
import '../core/clipboard.dart';
import '../core/local_file_io.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import '../widgets/mobile/hermes_adaptive_menu.dart';

/// Full-screen task detail — previously a `showModalBottomSheet` that
/// squeezed this much content (description, diagnostics, comments, runs,
/// dependencies, attachments, event timeline, home channels) into a
/// default-height, partial-screen popup. That read as a glorified dropdown
/// rather than a real place to work with a task, so it now gets its own
/// page like every other detail view in the app.
class KanbanTaskDetailScreen extends StatefulWidget {
  final KanbanTaskDetail initial;
  final KanbanStore store;
  const KanbanTaskDetailScreen({
    super.key,
    required this.initial,
    required this.store,
  });
  @override
  State<KanbanTaskDetailScreen> createState() => _KanbanTaskDetailScreenState();
}

class _KanbanTaskDetailScreenState extends State<KanbanTaskDetailScreen> {
  late KanbanTaskDetail detail;
  late final KanbanApi _api;
  late final String _boardSlug;
  bool busy = false;
  final comment = TextEditingController();
  List<Map<String, dynamic>> homes = const [];
  bool homesLoading = true;
  String? homesError;
  @override
  void initState() {
    super.initState();
    _api = widget.store.api;
    _boardSlug = _api.boardSlug;
    detail = widget.initial;
    widget.store.addListener(_onStoreChanged);
    _loadHomes();
  }

  KanbanApi _requireTarget() {
    final api = widget.store.requireApi(_api);
    if (api.boardSlug != _boardSlug) {
      throw StateError(context.l10n.backendDisconnected);
    }
    return api;
  }

  void _onStoreChanged() {
    if (!mounted) return;
    try {
      _requireTarget();
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  Future<void> _loadHomes() async {
    if (mounted) {
      setState(() {
        homesLoading = true;
        homesError = null;
      });
    }
    try {
      final raw = await _requireTarget().homeChannels(taskId: detail.task.id);
      final list = (raw['home_channels'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (mounted) {
        setState(() {
          homes = list;
          homesLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          homes = const [];
          homesError = '$error';
          homesLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    comment.dispose();
    super.dispose();
  }

  Future<void> deleteAttachment(KanbanAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.kanbanDeleteAttachment(attachment.filename)),
        content: Text(context.l10n.kanbanCannotUndo),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await run(() => _requireTarget().deleteAttachment(attachment.id));
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      final d = await widget.store.loadDetail(
        detail.task.id,
        force: true,
        expectedApi: _api,
        expectedBoardSlug: _boardSlug,
      );
      if (mounted && d != null) setState(() => detail = d);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.kanbanOperationFailed('$e'))),
        );
      }
    }
    await _loadHomes();
  }

  Future<void> run(Future<dynamic> Function() action) async {
    if (busy || !mounted) return;
    setState(() => busy = true);
    try {
      await action();
      final d = await widget.store.loadDetail(
        detail.task.id,
        force: true,
        expectedApi: _api,
        expectedBoardSlug: _boardSlug,
      );
      if (mounted && d != null) setState(() => detail = d);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.kanbanOperationFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> inspect(Object id) async {
    try {
      final value = await _requireTarget().inspectRun(id);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(value.toString()),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.kanbanOperationFailed('$e'))),
        );
      }
    }
  }

  Future<void> showLog() async {
    try {
      final value = await _requireTarget().log(detail.task.id);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            value['content']?.toString() ?? context.l10n.kanbanNoLog,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.kanbanOperationFailed('$e'))),
        );
      }
    }
  }

  Future<void> estimate() async {
    try {
      final value = await _requireTarget().estimate(detail.task.id);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(value.toString()),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.kanbanOperationFailed('$e'))),
        );
      }
    }
  }

  Future<void> addChild() async {
    final ctl = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.kanbanAddChildTask),
        content: TextField(
          controller: ctl,
          decoration: InputDecoration(labelText: context.l10n.kanbanTaskId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text.trim()),
            child: Text(context.l10n.commonAdd),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.dispose());
    if (id != null && id.isNotEmpty) {
      await run(() => _requireTarget().addLink(detail.task.id, id));
    }
  }

  String _statusLabel(BuildContext context, String value) => switch (value) {
    'triage' => context.l10n.taskStatusTriage,
    'todo' => context.l10n.taskStatusTodo,
    'scheduled' => context.l10n.taskStatusScheduled,
    'ready' => context.l10n.taskStatusReady,
    'running' => context.l10n.taskStatusRunning,
    'blocked' => context.l10n.taskStatusBlocked,
    'review' => context.l10n.taskStatusReview,
    'done' => context.l10n.taskStatusDone,
    'archived' => context.l10n.taskStatusArchived,
    'queued' => context.l10n.kanbanRunQueued,
    'completed' => context.l10n.kanbanRunCompleted,
    'failed' => context.l10n.kanbanRunFailed,
    'cancelled' || 'canceled' => context.l10n.kanbanRunCancelled,
    _ => value,
  };

  String _eventKindLabel(BuildContext context, String value) => switch (value) {
    'task.created' || 'task_created' => context.l10n.kanbanEventTaskCreated,
    'task.updated' || 'task_updated' => context.l10n.kanbanEventTaskUpdated,
    'task.deleted' || 'task_deleted' => context.l10n.kanbanEventTaskDeleted,
    'run.started' || 'run_started' => context.l10n.kanbanEventRunStarted,
    'run.completed' || 'run_completed' => context.l10n.kanbanEventRunCompleted,
    'run.failed' || 'run_failed' => context.l10n.kanbanEventRunFailed,
    'run.cancelled' ||
    'run.canceled' ||
    'run_cancelled' ||
    'run_canceled' => context.l10n.kanbanEventRunCancelled,
    'comment.created' ||
    'comment_created' => context.l10n.kanbanEventCommentCreated,
    'attachment.added' ||
    'attachment_added' => context.l10n.kanbanEventAttachmentAdded,
    'attachment.deleted' ||
    'attachment_deleted' => context.l10n.kanbanEventAttachmentDeleted,
    _ => value,
  };

  String _effortLabel(BuildContext context, String value) => switch (value) {
    'low' => context.l10n.kanbanEffortLow,
    'medium' => context.l10n.kanbanEffortMedium,
    'high' => context.l10n.kanbanEffortHigh,
    _ => context.l10n.commonDefault,
  };

  Future<void> changeStatus() async {
    final columns = widget.store.boardData?.columns ?? const [];
    if (columns.isEmpty || busy) return;
    final next = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in columns)
              ListTile(
                title: Text(_statusLabel(sheet, c.name)),
                trailing: c.name == detail.task.status
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheet, c.name),
              ),
          ],
        ),
      ),
    );
    if (next == null || next == detail.task.status) return;
    await run(
      () => widget.store.moveTask(
        detail.task.id,
        next,
        expectedApi: _api,
        expectedBoardSlug: _boardSlug,
      ),
    );
  }

  Future<void> editTask() async {
    final title = TextEditingController(text: detail.task.title);
    final body = TextEditingController(text: detail.task.body ?? '');
    final tenant = TextEditingController(text: detail.task.tenant ?? '');
    final model = TextEditingController(
      text: detail.task.raw['model_override']?.toString() ?? '',
    );
    final provider = TextEditingController(
      text: detail.task.raw['provider_override']?.toString() ?? '',
    );
    var status = detail.task.status;
    var priority = detail.task.priority;
    var assignee = detail.task.assignee ?? '';
    var effort = detail.task.raw['reasoning_effort']?.toString() ?? '';
    final columns = widget.store.boardData?.columns ?? const [];
    final assignees = widget.store.boardData?.assignees ?? const [];
    final value =
        await showModalBottomSheet<
          ({
            String title,
            String body,
            String status,
            int priority,
            String assignee,
            String tenant,
            String model,
            String provider,
            String effort,
          })
        >(
          context: context,
          isScrollControlled: true,
          builder: (sheet) => StatefulBuilder(
            builder: (sheet, setSheetState) => Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.viewInsetsOf(sheet).bottom + 16,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.commonTitle,
                    ),
                  ),
                  TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.kanbanDescription,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: columns.any((c) => c.name == status)
                        ? status
                        : null,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.kanbanTaskStatus,
                    ),
                    items: [
                      for (final c in columns)
                        DropdownMenuItem(
                          value: c.name,
                          child: Text(_statusLabel(sheet, c.name)),
                        ),
                    ],
                    onChanged: (v) => setSheetState(() => status = v ?? status),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: priority,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.kanbanPriority,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(sheet.l10n.taskPriorityNormal),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(sheet.l10n.taskPriorityHigh),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(sheet.l10n.taskPriorityUrgent),
                      ),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => priority = v ?? priority),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: assignee,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.kanbanAssignee,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(sheet.l10n.taskUnassigned),
                      ),
                      for (final a in assignees)
                        DropdownMenuItem(value: a, child: Text(a)),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => assignee = v ?? assignee),
                  ),
                  TextField(
                    controller: tenant,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.kanbanTenant,
                    ),
                  ),
                  TextField(
                    controller: model,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.kanbanModelOverride,
                    ),
                  ),
                  TextField(
                    controller: provider,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.kanbanProviderOverride,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: effort,
                    decoration: InputDecoration(
                      labelText: sheet.l10n.kanbanEffort,
                    ),
                    items: [
                      for (final v in const ['', 'low', 'medium', 'high'])
                        DropdownMenuItem(
                          value: v,
                          child: Text(_effortLabel(sheet, v)),
                        ),
                    ],
                    onChanged: (v) => setSheetState(() => effort = v ?? effort),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheet, (
                      title: title.text.trim(),
                      body: body.text,
                      status: status,
                      priority: priority,
                      assignee: assignee,
                      tenant: tenant.text.trim(),
                      model: model.text.trim(),
                      provider: provider.text.trim(),
                      effort: effort,
                    )),
                    child: Text(sheet.l10n.commonSave),
                  ),
                ],
              ),
            ),
          ),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      title.dispose();
      body.dispose();
      tenant.dispose();
      model.dispose();
      provider.dispose();
    });
    if (value == null || value.title.isEmpty) return;
    await run(
      () => _requireTarget().patchTask(detail.task.id, {
        'title': value.title,
        'body': value.body,
        'status': value.status,
        'priority': value.priority,
        'assignee': value.assignee,
        'tenant': value.tenant,
        'model_override': value.model,
        'provider_override': value.provider,
        'reasoning_effort': value.effort,
      }),
    );
  }

  Future<void> uploadFile() async {
    try {
      final file = await openFile();
      if (file == null) return;
      await run(() async {
        await _requireTarget().uploadAttachment(
          detail.task.id,
          file.name,
          await file.readAsBytes(),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.kanbanOperationFailed('$error'))),
        );
      }
    }
  }

  Future<void> download(KanbanAttachment attachment) async {
    try {
      final data = await _requireTarget().downloadAttachment(attachment.id);
      final path = await writeDownloadBytes(
        attachment.filename.isEmpty ? data.filename : attachment.filename,
        data.bytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.filesDownloadedPath(path))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.filesDownloadFailed('$e'))),
        );
      }
    }
  }

  Future<void> toggleHome(Map<String, dynamic> home) async {
    final platform = '${home['platform'] ?? ''}';
    if (platform.isEmpty) return;
    try {
      if (home['subscribed'] == true) {
        await _requireTarget().unsubscribeHome(detail.task.id, platform);
      } else {
        await _requireTarget().subscribeHome(detail.task.id, platform);
      }
      await _loadHomes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.kanbanOperationFailed('$e'))),
        );
      }
    }
  }

  Widget diagnosticAction(KanbanDiagnosticAction action) {
    if (action.kind == 'reclaim') {
      return TextButton(
        onPressed: busy
            ? null
            : () => run(() => _requireTarget().reclaim(detail.task.id)),
        child: Text(action.label),
      );
    }
    if (action.kind == 'reassign') {
      final profile = action.payload['profile']?.toString() ?? '';
      return TextButton(
        onPressed: busy || profile.isEmpty
            ? null
            : () =>
                  run(() => _requireTarget().reassign(detail.task.id, profile)),
        child: Text(action.label),
      );
    }
    if (action.kind == 'specify') {
      return TextButton(
        onPressed: busy
            ? null
            : () => run(() => _requireTarget().specify(detail.task.id)),
        child: Text(action.label),
      );
    }
    if (action.kind == 'cli_hint') {
      return TextButton(
        onPressed: () => copyTextOrNotify(
          context,
          action.payload['command']?.toString() ?? action.label,
          successMessage: context.l10n.kanbanCommandCopied,
        ),
        child: Text(action.label),
      );
    }
    return Tooltip(
      message: context.l10n.kanbanUnsupportedAction(action.kind),
      child: TextButton(onPressed: null, child: Text(action.label)),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      'running' ||
      'done' ||
      'completed' => dark ? HermesSemanticDark.green : HermesSemantic.green,
      'blocked' ||
      'failed' => dark ? HermesSemanticDark.red : HermesSemantic.red,
      'review' ||
      'scheduled' => dark ? HermesSemanticDark.orange : HermesSemantic.orange,
      _ => dark ? HermesSemanticDark.gray : HermesSemantic.gray,
    };
  }

  String _priorityLabel(BuildContext context, int priority) =>
      switch (priority) {
        2 => context.l10n.taskPriorityUrgent,
        1 => context.l10n.taskPriorityHigh,
        _ => context.l10n.taskPriorityNormal,
      };

  Color _priorityColor(BuildContext context, int priority) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (priority) {
      2 => dark ? HermesSemanticDark.red : HermesSemantic.red,
      1 => dark ? HermesSemanticDark.orange : HermesSemantic.orange,
      _ => dark ? HermesSemanticDark.blue : HermesSemantic.blue,
    };
  }

  String _fmtTime(int unixSeconds) => unixSeconds == 0
      ? ''
      : DateTime.fromMillisecondsSinceEpoch(
          unixSeconds * 1000,
        ).toLocal().toString().substring(0, 16);

  Widget _emptyHint(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      context.l10n.commonNoData,
      style: TextStyle(color: HermesPalette.of(context).text3, fontSize: 13),
    ),
  );

  Widget _sectionCard(BuildContext context, {required Widget child}) =>
      HermesGlassCard(
        radius: HermesRadius.card,
        padding: const EdgeInsets.all(14),
        child: child,
      );

  Widget _headerCard(BuildContext context) {
    final palette = HermesPalette.of(context);
    final hasBody = detail.task.body?.trim().isNotEmpty == true;
    return HermesGlassCard(
      radius: HermesRadius.largeCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasBody ? detail.task.body! : context.l10n.kanbanNoDescription,
            style: TextStyle(
              color: hasBody ? palette.text : palette.text3,
              fontStyle: hasBody ? FontStyle.normal : FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                onPressed: busy ? null : changeStatus,
                backgroundColor: _statusColor(
                  context,
                  detail.task.status,
                ).withValues(alpha: .16),
                side: BorderSide.none,
                avatar: Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: _statusColor(context, detail.task.status),
                ),
                label: Text(
                  _statusLabel(context, detail.task.status),
                  style: TextStyle(
                    color: _statusColor(context, detail.task.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              HermesMobileStatusChip(
                label: _priorityLabel(context, detail.task.priority),
                color: _priorityColor(context, detail.task.priority),
              ),
              if (detail.task.assignee?.isNotEmpty == true)
                HermesMobileStatusChip(
                  label: detail.task.assignee!,
                  color: palette.text3,
                  icon: Icons.person_outline,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (detail.task.createdAt case final createdAt?)
                Expanded(
                  child: Text(
                    context.l10n.kanbanCreatedAt(_fmtTime(createdAt)),
                    style: TextStyle(color: palette.text4, fontSize: 11.5),
                  ),
                ),
              GestureDetector(
                onTap: () => copyTextOrNotify(
                  context,
                  detail.task.id,
                  successMessage: context.l10n.kanbanTaskIdCopied,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${context.l10n.kanbanTaskId}: ${detail.task.id}',
                      style: TextStyle(color: palette.text4, fontSize: 11.5),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.copy, size: 12, color: palette.text4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diagnosticsSection(BuildContext context) {
    if (detail.diagnostics.isEmpty) return const SizedBox.shrink();
    final palette = HermesPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesSectionHeader(title: context.l10n.kanbanDiagnostics),
        for (final d in detail.diagnostics)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(
              builder: (context) {
                final severityColor = d.severity == 'critical'
                    ? hermesSemantic(
                        context,
                        HermesSemantic.red,
                        HermesSemanticDark.red,
                      )
                    : hermesSemantic(
                        context,
                        HermesSemantic.orange,
                        HermesSemanticDark.orange,
                      );
                return HermesGlassCard(
                  radius: HermesRadius.card,
                  padding: EdgeInsets.zero,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(width: 3, color: severityColor),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: severityColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  d.detail,
                                  style: TextStyle(
                                    color: palette.text3,
                                    fontSize: 12.5,
                                  ),
                                ),
                                if (d.actions.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 2,
                                    children: [
                                      for (final action in d.actions)
                                        diagnosticAction(action),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _commentsSection(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesSectionHeader(
          title: context.l10n.kanbanComments(detail.comments.length),
        ),
        _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.comments.isEmpty)
                _emptyHint(context)
              else
                for (final x in detail.comments) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HermesAvatar(label: x.author, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  x.author,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (x.createdAt != 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    _fmtTime(x.createdAt),
                                    style: TextStyle(
                                      color: palette.text4,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(x.body, style: TextStyle(color: palette.text)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (x != detail.comments.last)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: comment,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: context.l10n.kanbanAddComment,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: busy
                        ? null
                        : () {
                            final v = comment.text.trim();
                            if (v.isNotEmpty) {
                              comment.clear();
                              run(
                                () =>
                                    _requireTarget().comment(detail.task.id, v),
                              );
                            }
                          },
                    icon: const Icon(Icons.send),
                    tooltip: context.l10n.commonSend,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _runsSection(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesSectionHeader(title: context.l10n.kanbanRuns(detail.runs.length)),
        if (detail.runs.isEmpty)
          _sectionCard(context, child: _emptyHint(context))
        else
          for (final r in detail.runs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HermesGlassCard(
                radius: HermesRadius.card,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                onTap: () => inspect(r.id),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      HermesMobileStatusChip(
                        label: _statusLabel(context, r.status),
                        color: _statusColor(context, r.status),
                      ),
                      if (r.startedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _fmtTime(r.startedAt!),
                          style: TextStyle(color: palette.text4, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  subtitle: (r.summary ?? r.error)?.isNotEmpty == true
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            r.summary ?? r.error!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: r.summary == null && r.error != null
                                ? TextStyle(
                                    color: hermesSemantic(
                                      context,
                                      HermesSemantic.red,
                                      HermesSemanticDark.red,
                                    ),
                                  )
                                : null,
                          ),
                        )
                      : null,
                  trailing: r.status == 'running'
                      ? IconButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () => _requireTarget().terminateRun(r.id),
                                ),
                          icon: const Icon(Icons.stop_circle_outlined),
                          tooltip: context.l10n.commonStop,
                        )
                      : const Icon(Icons.chevron_right, size: 18),
                ),
              ),
            ),
      ],
    );
  }

  Widget _dependenciesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesSectionHeader(
          title: context.l10n.kanbanDependencies(
            detail.parents.length,
            detail.children.length,
          ),
          trailing: IconButton(
            onPressed: busy ? null : addChild,
            icon: const Icon(Icons.add_link, size: 20),
            tooltip: context.l10n.kanbanAddChildTask,
            visualDensity: VisualDensity.compact,
          ),
        ),
        _sectionCard(
          context,
          child: detail.children.isEmpty
              ? _emptyHint(context)
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in detail.children)
                      InputChip(
                        label: Text(context.l10n.kanbanChildTask(id)),
                        onDeleted: busy
                            ? null
                            : () => run(
                                () => _requireTarget().removeLink(
                                  detail.task.id,
                                  id,
                                ),
                              ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _attachmentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesSectionHeader(
          title: context.l10n.kanbanAttachments(detail.attachments.length),
          trailing: IconButton(
            onPressed: busy ? null : uploadFile,
            icon: const Icon(Icons.attach_file, size: 20),
            tooltip: context.l10n.kanbanUploadAttachment,
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (detail.attachments.isEmpty)
          _sectionCard(context, child: _emptyHint(context))
        else
          _sectionCard(
            context,
            child: Column(
              children: [
                for (final a in detail.attachments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(a.filename),
                    subtitle: a.size == null
                        ? null
                        : Text(context.l10n.kanbanAttachmentBytes(a.size!)),
                    onTap: () => download(a),
                    trailing: IconButton(
                      onPressed: busy ? null : () => deleteAttachment(a),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: context.l10n.commonDelete,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _eventsSection(BuildContext context) {
    if (detail.events.isEmpty) return const SizedBox.shrink();
    final palette = HermesPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesSectionHeader(
          title: context.l10n.kanbanEventTimeline(detail.events.length),
        ),
        _sectionCard(
          context,
          child: Column(
            children: [
              for (final event in detail.events.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.history, size: 16, color: palette.text4),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _eventKindLabel(context, event.kind),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (event.createdAt != 0)
                        Text(
                          _fmtTime(event.createdAt),
                          style: TextStyle(color: palette.text4, fontSize: 11),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _homeChannelsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesSectionHeader(title: context.l10n.kanbanHomeChannels),
        _sectionCard(
          context,
          child: homesLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : homesError != null
              ? ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.error_outline),
                  title: Text(context.l10n.kanbanHomeChannelsFailed),
                  subtitle: Text(homesError!),
                  trailing: IconButton(
                    tooltip: context.l10n.commonRetry,
                    onPressed: _loadHomes,
                    icon: const Icon(Icons.refresh),
                  ),
                )
              : homes.isEmpty
              ? _emptyHint(context)
              : Column(
                  children: [
                    for (final home in homes)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${home['platform'] ?? ''}'),
                        subtitle: Text('${home['chat_id'] ?? ''}'),
                        value: home['subscribed'] == true,
                        onChanged: busy ? null : (_) => toggleHome(home),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MobilePageScaffold(
    title: detail.task.title.isEmpty
        ? context.l10n.taskTitle
        : detail.task.title,
    actions: [
      IconButton(
        onPressed: busy ? null : editTask,
        tooltip: context.l10n.commonEdit,
        icon: const Icon(Icons.edit),
      ),
      IconButton(
        onPressed: busy ? null : showLog,
        tooltip: context.l10n.kanbanViewLog,
        icon: const Icon(Icons.article_outlined),
      ),
      HermesAdaptiveMenuButton<String>(
        onSelected: (v) => v == 'estimate'
            ? estimate()
            : run(() => _requireTarget().decompose(detail.task.id)),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'estimate',
            child: Text(context.l10n.kanbanEstimate),
          ),
          PopupMenuItem(
            value: 'decompose',
            child: Text(context.l10n.kanbanDecompose),
          ),
        ],
      ),
    ],
    body: Column(
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                _headerCard(context),
                _diagnosticsSection(context),
                const SizedBox(height: 4),
                _commentsSection(context),
                _runsSection(context),
                _dependenciesSection(context),
                _attachmentsSection(context),
                _eventsSection(context),
                _homeChannelsSection(context),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
