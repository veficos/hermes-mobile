import 'package:flutter/material.dart';
import '../kanban/api.dart';
import '../kanban/models.dart';
import '../kanban/store.dart';
import '../l10n/l10n.dart';

Future<void> showKanbanNewTaskSheet(
  BuildContext context,
  KanbanStore store,
) async {
  final messenger = ScaffoldMessenger.of(context);
  late final KanbanApi api;
  try {
    api = store.api;
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.kanbanOperationFailed('$error'))),
    );
    return;
  }
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NewTaskSheet(store: store, api: api),
  );
  if (created == true) {
    try {
      await store.load(expectedApi: api);
      store.requireApi(api);
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.kanbanOperationFailed('$error'))),
        );
      }
    }
  }
}

class _NewTaskSheet extends StatefulWidget {
  final KanbanStore store;
  final KanbanApi api;
  const _NewTaskSheet({required this.store, required this.api});
  @override
  State<_NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends State<_NewTaskSheet> {
  late final KanbanApi _api;
  final title = TextEditingController(),
      body = TextEditingController(),
      tenant = TextEditingController(),
      parent = TextEditingController(),
      workspace = TextEditingController(),
      model = TextEditingController(),
      provider = TextEditingController();
  String status = 'triage', assignee = '', effort = '';
  int priority = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api;
    final columns = widget.store.boardData?.columns ?? const <KanbanColumn>[];
    if (columns.isNotEmpty && !columns.any((column) => column.name == status)) {
      status = columns.first.name;
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
    _ => value,
  };

  String _effortLabel(BuildContext context, String value) => switch (value) {
    'low' => context.l10n.kanbanEffortLow,
    'medium' => context.l10n.kanbanEffortMedium,
    'high' => context.l10n.kanbanEffortHigh,
    _ => context.l10n.commonDefault,
  };
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    tenant.dispose();
    parent.dispose();
    workspace.dispose();
    model.dispose();
    provider.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy || title.text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => busy = true);
    try {
      final raw = await widget.store.requireApi(_api).createTask({
        'title': title.text.trim(),
        'body': body.text.trim(),
        'status': status,
        'priority': priority,
        if (assignee.isNotEmpty) 'assignee': assignee,
        if (tenant.text.trim().isNotEmpty) 'tenant': tenant.text.trim(),
        if (workspace.text.trim().isNotEmpty)
          'workspace_path': workspace.text.trim(),
        if (model.text.trim().isNotEmpty) 'model_override': model.text.trim(),
        if (provider.text.trim().isNotEmpty)
          'provider_override': provider.text.trim(),
        if (effort.isNotEmpty) 'reasoning_effort': effort,
      });
      if (parent.text.trim().isNotEmpty) {
        final id = raw is Map ? '${raw['id'] ?? raw['task']?['id'] ?? ''}' : '';
        if (id.isNotEmpty) {
          try {
            await widget.store.requireApi(_api).addLink(parent.text.trim(), id);
          } catch (e) {
            if (!mounted) return;
            Navigator.pop(context, true);
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.kanbanTaskCreatedLinkFailed('$e'))),
            );
            return;
          }
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.kanbanOperationFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        TextField(
          controller: title,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.commonTitle),
        ),
        TextField(
          controller: body,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: context.l10n.kanbanDescription,
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: InputDecoration(labelText: context.l10n.kanbanTaskStatus),
          items: [
            for (final c
                in widget.store.boardData?.columns ?? const <KanbanColumn>[])
              DropdownMenuItem(
                value: c.name,
                child: Text(_statusLabel(context, c.name)),
              ),
          ],
          onChanged: (v) => setState(() => status = v ?? 'triage'),
        ),
        DropdownButtonFormField<int>(
          initialValue: priority,
          decoration: InputDecoration(labelText: context.l10n.kanbanPriority),
          items: [
            DropdownMenuItem(
              value: 0,
              child: Text(context.l10n.taskPriorityNormal),
            ),
            DropdownMenuItem(
              value: 1,
              child: Text(context.l10n.taskPriorityHigh),
            ),
            DropdownMenuItem(
              value: 2,
              child: Text(context.l10n.taskPriorityUrgent),
            ),
          ],
          onChanged: (v) => setState(() => priority = v ?? 0),
        ),
        DropdownButtonFormField<String>(
          initialValue: assignee,
          decoration: InputDecoration(labelText: context.l10n.kanbanAssignee),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(context.l10n.taskUnassigned),
            ),
            for (final a
                in widget.store.boardData?.assignees ?? const <String>[])
              DropdownMenuItem(value: a, child: Text(a)),
          ],
          onChanged: (v) => setState(() => assignee = v ?? ''),
        ),
        TextField(
          controller: tenant,
          decoration: InputDecoration(labelText: context.l10n.kanbanTenant),
        ),
        TextField(
          controller: parent,
          decoration: InputDecoration(
            labelText: context.l10n.kanbanParentTaskId,
          ),
        ),
        TextField(
          controller: workspace,
          decoration: InputDecoration(
            labelText: context.l10n.kanbanWorkspacePath,
          ),
        ),
        TextField(
          controller: model,
          decoration: InputDecoration(
            labelText: context.l10n.kanbanModelOverride,
          ),
        ),
        TextField(
          controller: provider,
          decoration: InputDecoration(
            labelText: context.l10n.kanbanProviderOverride,
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: effort,
          decoration: InputDecoration(labelText: context.l10n.kanbanEffort),
          items: [
            for (final value in const ['', 'low', 'medium', 'high'])
              DropdownMenuItem(
                value: value,
                child: Text(_effortLabel(context, value)),
              ),
          ],
          onChanged: (v) => setState(() => effort = v ?? ''),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Text(
            busy
                ? context.l10n.kanbanCreatingTask
                : context.l10n.kanbanCreateTask,
          ),
        ),
      ],
    ),
  );
}
