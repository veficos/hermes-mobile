import 'package:flutter/material.dart';
import '../kanban/api.dart';
import '../kanban/models.dart';
import '../kanban/store.dart';
import '../l10n/l10n.dart';

Future<void> showKanbanBoardSheet(
  BuildContext context,
  KanbanStore store,
) async {
  final messenger = ScaffoldMessenger.of(context);
  late final KanbanApi api;
  try {
    api = store.api;
    await store.loadBoards(expectedApi: api);
    store.requireApi(api);
    if (store.error case final error?) throw StateError(error);
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.kanbanOperationFailed('$error'))),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _BoardSheet(store: store, api: api),
  );
}

class _BoardSheet extends StatefulWidget {
  final KanbanStore store;
  final KanbanApi api;
  const _BoardSheet({required this.store, required this.api});
  @override
  State<_BoardSheet> createState() => _BoardSheetState();
}

class _BoardSheetState extends State<_BoardSheet> {
  bool busy = false;
  late final KanbanApi _api;

  @override
  void initState() {
    super.initState();
    _api = widget.api;
  }

  KanbanApi get _currentApi => widget.store.requireApi(_api);

  Future<void> _runMutation(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.kanbanOperationFailed('$e'))),
        );
      }
    }
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.kanbanCreateBoard),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.commonName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text.trim()),
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.dispose());
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => busy = true);
    await _runMutation(() async {
      await _currentApi.createBoard(
        name.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
        name,
      );
      await widget.store.loadBoards(expectedApi: _api);
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> _edit(KanbanBoardMeta board) async {
    final l10n = context.l10n;
    Map<String, dynamic> projectRaw;
    try {
      projectRaw = await _currentApi.projects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.kanbanOperationFailed('$e'))),
        );
      }
      return;
    }
    if (!mounted) return;
    final projects = (projectRaw['projects'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => KanbanProject.fromJson(e.cast<String, dynamic>()))
        .toList();
    final ctl = TextEditingController(text: board.name ?? board.slug);
    var projectId = board.projectId ?? '';
    final result = await showDialog<({String name, String projectId})>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(l10n.kanbanBoardSettings),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                decoration: InputDecoration(labelText: l10n.commonName),
              ),
              DropdownButtonFormField<String>(
                initialValue: projectId,
                decoration: InputDecoration(labelText: l10n.kanbanProject),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.kanbanNoProject),
                  ),
                  ...projects.map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ),
                ],
                onChanged: (v) => setDialog(() => projectId = v ?? ''),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, (
                name: ctl.text.trim(),
                projectId: projectId,
              )),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.dispose());
    if (result == null || result.name.isEmpty) return;
    await _runMutation(() async {
      await _currentApi.updateBoard(board.slug, {
        'name': result.name,
        'project_id': result.projectId,
      });
      await widget.store.loadBoards(expectedApi: _api);
    });
  }

  Future<void> _delete(KanbanBoardMeta board) async {
    if (board.current) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.kanbanDeleteBoardQuestion),
        content: Text(l10n.kanbanDeleteBoardDescription(board.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _runMutation(() async {
      await _currentApi.deleteBoard(board.slug);
      await widget.store.loadBoards(expectedApi: _api);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(context.l10n.kanbanCreateBoard),
          onTap: busy ? null : _create,
        ),
        for (final board in widget.store.boardList)
          ListTile(
            title: Text(board.label),
            subtitle: Text(
              board.projectName == null
                  ? context.l10n.kanbanBoardTaskCount(board.total ?? 0)
                  : context.l10n.kanbanBoardTaskCountProject(
                      board.total ?? 0,
                      board.projectName!,
                    ),
            ),
            leading: board.current
                ? const Icon(Icons.check_circle)
                : const Icon(Icons.dashboard_outlined),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await widget.store.selectBoard(board.slug, expectedApi: _api);
              if (!context.mounted) return;
              if (widget.store.error != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.kanbanOperationFailed(widget.store.error!),
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(context);
            },
            trailing: PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? _edit(board) : _delete(board),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(context.l10n.kanbanRenameBoard),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !board.current,
                  child: Text(context.l10n.commonDelete),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
