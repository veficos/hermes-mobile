import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../kanban/api.dart';
import '../kanban/models.dart';
import '../kanban/store.dart';
import '../core/clipboard.dart';
import '../core/local_file_io.dart';
import '../l10n/l10n.dart';

class KanbanTaskDetailSheet extends StatefulWidget {
  final KanbanTaskDetail initial;
  final KanbanStore store;
  const KanbanTaskDetailSheet({
    super.key,
    required this.initial,
    required this.store,
  });
  @override
  State<KanbanTaskDetailSheet> createState() => _KanbanTaskDetailSheetState();
}

class _KanbanTaskDetailSheetState extends State<KanbanTaskDetailSheet> {
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

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                detail.task.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
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
            PopupMenuButton<String>(
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
        ),
        Text(detail.task.body ?? context.l10n.kanbanNoDescription),
        ActionChip(
          label: Text(_statusLabel(context, detail.task.status)),
          avatar: const Icon(Icons.arrow_drop_down, size: 18),
          onPressed: busy ? null : changeStatus,
        ),
        if (detail.diagnostics.isNotEmpty) ...[
          const Divider(),
          Text(
            context.l10n.kanbanDiagnostics,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final d in detail.diagnostics)
            ListTile(
              leading: Icon(
                Icons.warning,
                color: d.severity == 'critical' ? Colors.red : Colors.orange,
              ),
              title: Text(d.title),
              subtitle: Text(d.detail),
              trailing: d.actions.isEmpty
                  ? null
                  : Wrap(
                      spacing: 2,
                      children: [
                        for (final action in d.actions)
                          diagnosticAction(action),
                      ],
                    ),
            ),
        ],
        const Divider(),
        Text(context.l10n.kanbanComments(detail.comments.length)),
        for (final x in detail.comments)
          ListTile(title: Text(x.author), subtitle: Text(x.body)),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: comment,
                decoration: InputDecoration(
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
                        run(() => _requireTarget().comment(detail.task.id, v));
                      }
                    },
              icon: const Icon(Icons.send),
              tooltip: context.l10n.commonSend,
            ),
          ],
        ),
        const Divider(),
        Text(context.l10n.kanbanRuns(detail.runs.length)),
        for (final r in detail.runs)
          ListTile(
            title: Text(_statusLabel(context, r.status)),
            subtitle: Text(r.summary ?? r.error ?? ''),
            onTap: () => inspect(r.id),
            trailing: r.status == 'running'
                ? IconButton(
                    onPressed: busy
                        ? null
                        : () => run(() => _requireTarget().terminateRun(r.id)),
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: context.l10n.commonStop,
                  )
                : null,
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.kanbanDependencies(
                  detail.parents.length,
                  detail.children.length,
                ),
              ),
            ),
            IconButton(
              onPressed: busy ? null : addChild,
              icon: const Icon(Icons.add_link),
              tooltip: context.l10n.kanbanAddChildTask,
            ),
          ],
        ),
        for (final id in detail.children)
          ListTile(
            title: Text(context.l10n.kanbanChildTask(id)),
            trailing: IconButton(
              onPressed: busy
                  ? null
                  : () => run(
                      () => _requireTarget().removeLink(detail.task.id, id),
                    ),
              icon: const Icon(Icons.link_off),
              tooltip: context.l10n.commonRemove,
            ),
          ),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.kanbanAttachments(detail.attachments.length),
              ),
            ),
            IconButton(
              onPressed: busy ? null : uploadFile,
              icon: const Icon(Icons.attach_file),
              tooltip: context.l10n.kanbanUploadAttachment,
            ),
          ],
        ),
        for (final a in detail.attachments)
          ListTile(
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
        if (detail.events.isNotEmpty) ...[
          const Divider(),
          Text(context.l10n.kanbanEventTimeline(detail.events.length)),
          for (final event in detail.events.reversed)
            ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 18),
              title: Text(_eventKindLabel(context, event.kind)),
              subtitle: event.payload == null
                  ? null
                  : Text(
                      event.payload.toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: event.createdAt == 0
                  ? null
                  : Text(
                      DateTime.fromMillisecondsSinceEpoch(
                        event.createdAt * 1000,
                      ).toLocal().toString().substring(0, 16),
                    ),
            ),
        ],
        const Divider(),
        Text(context.l10n.kanbanHomeChannels),
        if (homesLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (homesError != null)
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(context.l10n.kanbanHomeChannelsFailed),
            subtitle: Text(homesError!),
            trailing: IconButton(
              tooltip: context.l10n.commonRetry,
              onPressed: _loadHomes,
              icon: const Icon(Icons.refresh),
            ),
          )
        else if (homes.isEmpty)
          ListTile(title: Text(context.l10n.kanbanHomeChannelsEmpty))
        else
          for (final home in homes)
            SwitchListTile(
              title: Text('${home['platform'] ?? ''}'),
              subtitle: Text('${home['chat_id'] ?? ''}'),
              value: home['subscribed'] == true,
              onChanged: busy ? null : (_) => toggleHome(home),
            ),
      ],
    ),
  );
}
