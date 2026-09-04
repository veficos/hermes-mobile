import 'package:flutter/material.dart';

import '../kanban/api.dart';
import '../kanban/models.dart';
import '../kanban/store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import 'mobile/hermes_mobile_surfaces.dart';

/// Compatibility entry retained for existing callers. Task creation now opens
/// a full page instead of a modal sheet.
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
  final created = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => KanbanNewTaskScreen(store: store, api: api),
    ),
  );
  if (created != true) return;
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

class KanbanNewTaskScreen extends StatefulWidget {
  const KanbanNewTaskScreen({
    super.key,
    required this.store,
    required this.api,
  });

  final KanbanStore store;
  final KanbanApi api;

  @override
  State<KanbanNewTaskScreen> createState() => _KanbanNewTaskScreenState();
}

class _KanbanNewTaskScreenState extends State<KanbanNewTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final body = TextEditingController();
  final tenant = TextEditingController();
  final parent = TextEditingController();
  final workspace = TextEditingController();
  final model = TextEditingController();
  final provider = TextEditingController();
  late final KanbanApi _api;
  String status = 'triage';
  String assignee = '';
  String effort = '';
  int priority = 0;
  bool busy = false;
  bool advancedExpanded = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api;
    final columns = widget.store.boardData?.columns ?? const <KanbanColumn>[];
    if (columns.isNotEmpty && !columns.any((column) => column.name == status)) {
      status = columns.first.name;
    }
  }

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

  String _priorityLabel(BuildContext context, int value) => switch (value) {
    1 => context.l10n.taskPriorityHigh,
    2 => context.l10n.taskPriorityUrgent,
    _ => context.l10n.taskPriorityNormal,
  };

  Future<void> _submit() async {
    if (busy || !_formKey.currentState!.validate()) return;
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
          } catch (error) {
            if (!mounted) return;
            Navigator.of(context).pop(true);
            messenger.showSnackBar(
              SnackBar(
                content: Text(l10n.kanbanTaskCreatedLinkFailed('$error')),
              ),
            );
            return;
          }
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.kanbanOperationFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final columns = widget.store.boardData?.columns ?? const <KanbanColumn>[];
    final statuses = columns.isEmpty
        ? <String>[status]
        : columns.map((column) => column.name).toList(growable: false);
    final assignees = widget.store.boardData?.assignees ?? const <String>[];
    return Scaffold(
      key: const ValueKey('kanban-new-task-screen'),
      appBar: AppBar(title: Text(l10n.kanbanCreateTask)),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              const _IntroCard(),
              const SizedBox(height: 18),
              _SectionLabel(
                icon: Icons.edit_note_rounded,
                title: l10n.kanbanTaskContentSection,
              ),
              const SizedBox(height: 8),
              HermesMobileCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('kanban-new-task-title'),
                      controller: title,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.commonTitle,
                        hintText: l10n.kanbanTaskTitleHint,
                        prefixIcon: const Icon(Icons.title_rounded),
                      ),
                      validator: (value) => value?.trim().isEmpty == true
                          ? l10n.kanbanTaskTitleRequired
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: body,
                      minLines: 4,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.kanbanDescription,
                        hintText: l10n.kanbanTaskDescriptionHint,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionLabel(
                icon: Icons.tune_rounded,
                title: l10n.kanbanTaskArrangementSection,
              ),
              const SizedBox(height: 8),
              HermesMobileCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('kanban-new-task-status'),
                      initialValue: status,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.kanbanTaskStatus,
                        prefixIcon: const Icon(Icons.radio_button_checked),
                      ),
                      items: [
                        for (final value in statuses)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_statusLabel(context, value)),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => status = value ?? status),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: priority,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.kanbanPriority,
                        prefixIcon: const Icon(Icons.flag_outlined),
                      ),
                      items: [
                        for (final value in const [0, 1, 2])
                          DropdownMenuItem(
                            value: value,
                            child: Text(_priorityLabel(context, value)),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => priority = value ?? 0),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: assignee,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.kanbanAssignee,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l10n.taskUnassigned),
                        ),
                        for (final value in assignees)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => assignee = value ?? ''),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              HermesMobileCard(
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    key: const ValueKey('kanban-new-task-advanced'),
                    initiallyExpanded: advancedExpanded,
                    onExpansionChanged: (value) => advancedExpanded = value,
                    leading: const Icon(Icons.settings_suggest_outlined),
                    title: Text(l10n.kanbanTaskRuntimeSection),
                    subtitle: Text(l10n.kanbanTaskRuntimeDescription),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                    children: [
                      _field(tenant, l10n.kanbanTenant, Icons.domain_outlined),
                      _field(
                        parent,
                        l10n.kanbanParentTaskId,
                        Icons.account_tree_outlined,
                      ),
                      _field(
                        workspace,
                        l10n.kanbanWorkspacePath,
                        Icons.folder_outlined,
                      ),
                      _field(
                        model,
                        l10n.kanbanModelOverride,
                        Icons.psychology_outlined,
                      ),
                      _field(
                        provider,
                        l10n.kanbanProviderOverride,
                        Icons.cloud_outlined,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: effort,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.kanbanEffort,
                          prefixIcon: const Icon(Icons.speed_rounded),
                        ),
                        items: [
                          for (final value in const [
                            '',
                            'low',
                            'medium',
                            'high',
                          ])
                            DropdownMenuItem(
                              value: value,
                              child: Text(_effortLabel(context, value)),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(() => effort = value ?? ''),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: FilledButton.icon(
          key: const ValueKey('kanban-new-task-submit'),
          onPressed: busy ? null : _submit,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_task_rounded),
          label: Text(busy ? l10n.kanbanCreatingTask : l10n.kanbanCreateTask),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !busy,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.accentBg,
        borderRadius: BorderRadius.circular(HermesMobileMetrics.groupRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_task_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.kanbanCreateTaskDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.text2,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: palette.accent),
        const SizedBox(width: 7),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
