/// ProjectDialog: manage projects (working-directory collections) from the
/// SessionsScreen top dropdown. Supports create / edit / delete projects.
///
/// UI is styled strictly to the HermesTokens design system (solid cards,
/// 1px borders, sheet-radius dialog, sm/md shadows, text tiers).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/connection_reload_mixin.dart';
import '../../core/stores/connection_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_glass.dart';

typedef ProjectSelected = void Function(Map<String, dynamic>? project);

/// Desktop parity predicate for the "Move to project" submenu.
/// Home/no-project buckets, the current owner, folderless projects and a
/// project resolving to the current cwd are not valid destinations.
bool isSessionMoveTarget(
  Map<String, dynamic> project, {
  String? currentProjectId,
  String? currentCwd,
}) {
  final id = (project['project_id'] ?? project['id'])?.toString();
  if (id != null && id == currentProjectId) return false;
  if (project['is_no_project'] == true || project['isNoProject'] == true) {
    return false;
  }
  final path = (project['primary_path'] ?? project['path'])?.toString().trim();
  final repos = project['repos'] as List? ?? const [];
  final repoPath = repos
      .whereType<Map>()
      .map((repo) => repo['path']?.toString().trim() ?? '')
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final targetPath = path?.isNotEmpty == true ? path! : repoPath;
  if (targetPath.isEmpty) return false;
  final current = currentCwd?.trim().toLowerCase();
  return current == null ||
      current.isEmpty ||
      targetPath.toLowerCase() != current;
}

class ProjectDialog extends StatefulWidget {
  final Map<String, dynamic>? initialProject;
  final ProjectSelected? onSelected;
  final bool selectionOnly;
  final String? excludedProjectId;
  final String? excludedCwd;

  const ProjectDialog({
    super.key,
    this.initialProject,
    this.onSelected,
    this.selectionOnly = false,
    this.excludedProjectId,
    this.excludedCwd,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? initialProject,
  }) {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => ProjectDialog(initialProject: initialProject),
    );
  }

  static Future<Map<String, dynamic>?> showMoveTarget(
    BuildContext context, {
    String? currentProjectId,
    String? currentCwd,
  }) {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => ProjectDialog(
        selectionOnly: true,
        excludedProjectId: currentProjectId,
        excludedCwd: currentCwd,
      ),
    );
  }

  @override
  State<ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<ProjectDialog>
    with ConnectionReloadMixin<ProjectDialog> {
  List<Map<String, dynamic>> _projects = [];
  String? _error;
  bool _loading = true;
  int? _editingIndex;
  bool _saving = false;
  int _loadGeneration = 0;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _pathCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _handleConnectionChange);
  }

  void _handleConnectionChange() {
    if (!mounted) return;
    setState(() {
      _projects = [];
      _editingIndex = null;
      _saving = false;
      _loading = true;
      _error = null;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _nameCtrl.dispose();
    _pathCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _beginEditing(int index) {
    final existing = index < 0 ? null : _projects[index];
    _nameCtrl.text = existing?['name']?.toString() ?? '';
    _pathCtrl.text =
        existing?['primary_path']?.toString() ??
        existing?['path']?.toString() ??
        '';
    _descCtrl.text = existing?['description']?.toString() ?? '';
    setState(() {
      _editingIndex = index;
      _saving = false;
    });
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final connection = context.read<ConnectionStore>();
    final gateway = connection.gateway;
    if (gateway == null) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(gateway, connection.gateway)) {
        setState(() {
          _error = connectionOfflineErrorCode;
          _loading = false;
        });
      }
      return;
    }
    try {
      final result = await gateway.request('projects.list', {});
      final list = result['projects'] as List? ?? [];
      if (mounted &&
          generation == _loadGeneration &&
          identical(gateway, connection.gateway)) {
        final projects = list
            .map((e) => (e as Map).cast<String, dynamic>())
            .where(_isSelectableProject)
            .toList();
        setState(() {
          _projects = projects;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  bool _isSelectableProject(Map<String, dynamic> project) {
    if (!widget.selectionOnly) return true;
    return isSessionMoveTarget(
      project,
      currentProjectId: widget.excludedProjectId,
      currentCwd: widget.excludedCwd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark
        ? HermesBackground.darkBorder
        : HermesBackground.lightBorder;
    final surface = isDark
        ? HermesBackground.darkSecondary
        : HermesBackground.lightSecondary;

    return Dialog(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
        side: BorderSide(color: border, width: 1),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            const Divider(height: 1),
            Flexible(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.lg,
        HermesSpacing.md,
        HermesSpacing.xs,
        HermesSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.projectManagement,
              style: theme.textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(widget.initialProject),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(HermesSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: HermesSemantic.red),
            const SizedBox(height: HermesSpacing.md),
            Text(
              context.l10n.projectLoadFailed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              _error == connectionOfflineErrorCode
                  ? context.l10n.backendDisconnected
                  : _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: HermesSpacing.md),
            FilledButton(
              onPressed: _load,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_editingIndex != null || (_editingIndex == -1)) {
      return _editor(context);
    }
    return _list(context);
  }

  Widget _list(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quat = isDark
        ? HermesText.darkQuaternary
        : HermesText.lightQuaternary;

    if (_projects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 48, color: quat),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              widget.selectionOnly
                  ? context.l10n.projectNoMoveTargets
                  : context.l10n.projectEmpty,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              widget.selectionOnly
                  ? context.l10n.projectNoMoveTargetsDescription
                  : context.l10n.projectEmptyDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            if (!widget.selectionOnly) ...[
              const SizedBox(height: HermesSpacing.lg),
              FilledButton.icon(
                onPressed: () => _beginEditing(-1),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.projectNew),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: HermesSpacing.xs),
            itemCount: _projects.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
            itemBuilder: (context, i) => _projectTile(context, i),
          ),
        ),
        if (!widget.selectionOnly) const Divider(height: 1),
        if (!widget.selectionOnly)
          Padding(
            padding: const EdgeInsets.all(HermesSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _beginEditing(-1),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.projectNew),
              ),
            ),
          ),
      ],
    );
  }

  Widget _projectTile(BuildContext context, int i) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final p = _projects[i];
    final name = (p['name'] ?? p['label'] ?? context.l10n.projectUntitled)
        .toString();
    final path = (p['primary_path'] ?? p['path'] ?? '').toString();
    final sessions = (p['session_count'] as num?)?.toInt() ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final selected =
        widget.initialProject != null &&
        (p['id']?.toString() == widget.initialProject!['id']?.toString() ||
            p['name']?.toString() ==
                widget.initialProject!['name']?.toString());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onSelected?.call(p);
          Navigator.of(context).pop(p);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HermesSpacing.md,
            vertical: HermesSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HermesPalette.of(context).accentBg,
                  borderRadius: BorderRadius.circular(HermesRadius.card),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: HermesPalette.of(context).accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: HermesSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: HermesSpacing.xs,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (path.isNotEmpty)
                      Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? HermesText.darkTertiary
                              : HermesText.lightTertiary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.projectSessionCount(sessions),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HermesSpacing.xs),
              if (!widget.selectionOnly) ...[
                HermesIconButton(
                  icon: Icons.edit_outlined,
                  size: 32,
                  tooltip: context.l10n.commonEdit,
                  onTap: () => _beginEditing(i),
                ),
                const SizedBox(width: 4),
                HermesIconButton(
                  icon: Icons.delete_outline,
                  size: 32,
                  tooltip: context.l10n.commonDelete,
                  onTap: () => _confirmDelete(context, i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final isNew = _editingIndex == -1 || _editingIndex == null;
    final existing = isNew ? null : _projects[_editingIndex!];
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.commonBack,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _editingIndex = null),
              ),
              const SizedBox(width: HermesSpacing.xs),
              Text(
                isNew ? l10n.projectNew : l10n.projectEditTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.sm),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.projectName,
              prefixIcon: const Icon(Icons.folder_outlined),
            ),
          ),
          const SizedBox(height: HermesSpacing.sm),
          TextField(
            controller: _pathCtrl,
            decoration: InputDecoration(
              labelText: l10n.projectPrimaryPath,
              prefixIcon: const Icon(Icons.route_outlined),
              hintText: l10n.projectPrimaryPathHint,
            ),
          ),
          const SizedBox(height: HermesSpacing.sm),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.projectDescriptionOptional,
              prefixIcon: const Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: HermesSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editingIndex = null),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: HermesSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final name = _nameCtrl.text.trim();
                          final path = _pathCtrl.text.trim();
                          if (name.isEmpty || path.isEmpty) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(l10n.projectRequiredFields),
                              ),
                            );
                            return;
                          }
                          setState(() => _saving = true);
                          try {
                            final connection = context.read<ConnectionStore>();
                            final gateway = connectedGatewayOrNotify(
                              context,
                              connection,
                            );
                            if (gateway == null) {
                              setState(() => _saving = false);
                              return;
                            }
                            if (isNew) {
                              await gateway.request('projects.create', {
                                'name': name,
                                'description': _descCtrl.text.trim(),
                                'folders': [
                                  {
                                    'path': path,
                                    'label': '',
                                    'is_primary': true,
                                  },
                                ],
                                'primary_path': path,
                              });
                            } else {
                              final id =
                                  existing!['id']?.toString() ??
                                  existing['name']?.toString() ??
                                  '';
                              await gateway.request('projects.update', {
                                'id': id,
                                'name': name,
                                'description': _descCtrl.text.trim(),
                                'primary_path': path,
                              });
                            }
                            await _load();
                            if (!mounted) return;
                            setState(() {
                              _editingIndex = null;
                              _saving = false;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  isNew
                                      ? l10n.projectCreated
                                      : l10n.projectUpdated,
                                ),
                              ),
                            );
                          } catch (e) {
                            if (mounted) setState(() => _saving = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(l10n.projectSaveFailed('$e')),
                              ),
                            );
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isNew ? l10n.commonCreate : l10n.commonSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int i) async {
    final p = _projects[i];
    final l10n = context.l10n;
    final name = (p['name'] ?? l10n.projectUntitled).toString();
    final messenger = ScaffoldMessenger.of(context);
    final connection = context.read<ConnectionStore>();
    final gateway = connectedGatewayOrNotify(context, connection);
    if (gateway == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.projectDeleteTitle),
        content: Text(l10n.projectDeleteNamedDescription(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    try {
      final id = p['id']?.toString() ?? p['name']?.toString() ?? '';
      await requireActiveGateway(
        this.context,
        connection,
        gateway,
      ).request('projects.delete', {'id': id});
      if (!mounted) return;
      if (widget.initialProject != null &&
          (widget.initialProject!['id']?.toString() == id ||
              widget.initialProject!['name']?.toString() == id)) {
        widget.onSelected?.call(null);
      }
      await _load();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.projectDeleted)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.projectDeleteFailed('$e'))),
      );
    }
  }
}
