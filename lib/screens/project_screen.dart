/// Projects (spec §51, Phase 2 base): list from the gateway projects API.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import 'project_detail_screen.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen>
    with ConnectionReloadMixin<ProjectScreen> {
  List<dynamic>? _projects;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _load);
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final connection = context.read<ConnectionStore>();
    final gateway = connection.gateway;
    if (gateway == null) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _projects = null;
          _error = connectionOfflineErrorCode;
        });
      }
      return;
    }
    try {
      final result = await gateway.request('projects.list', {});
      if (mounted &&
          generation == _loadGeneration &&
          identical(gateway, connection.gateway)) {
        setState(() {
          _projects = result['projects'] as List? ?? [];
          _error = null;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(gateway, connection.gateway)) {
        setState(() => _error = '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.featureProjects),
        actions: [
          IconButton(
            tooltip: context.l10n.projectCreate,
            onPressed: () => _createProject(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
        alternativeLabel: context.l10n.projectCreate,
        onAlternative: () => _createProject(context),
      );
    }
    final projects = _projects;
    if (projects == null) {
      return HermesLoadingState(label: context.l10n.projectLoading);
    }
    if (projects.isEmpty) {
      return HermesEmptyState(
        icon: Icons.folder_outlined,
        title: context.l10n.projectEmpty,
        description: context.l10n.projectEmptyDescription,
        primaryLabel: context.l10n.projectCreate,
        onPrimary: () => _createProject(context),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          < 600 => 1,
          < 840 => 2,
          < 1200 => 3,
          _ => 3,
        };
        if (columns == 1) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              HermesMobileGroup(
                children: [
                  for (final raw in projects)
                    _projectRow(context, (raw as Map).cast<String, dynamic>()),
                ],
              ),
            ],
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(HermesSpacing.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: HermesSpacing.md,
            mainAxisSpacing: HermesSpacing.md,
            childAspectRatio: 2.4,
          ),
          itemCount: projects.length,
          itemBuilder: (context, i) => HermesMobileCard(
            padding: EdgeInsets.zero,
            child: _projectRow(
              context,
              (projects[i] as Map).cast<String, dynamic>(),
            ),
          ),
        );
      },
    );
  }

  Widget _projectRow(BuildContext context, Map<String, dynamic> project) {
    final name =
        (project['name'] ?? project['label'] ?? context.l10n.projectUntitled)
            .toString();
    final sessions = project['session_count'] ?? project['sessions_count'];
    final description = project['description']?.toString().trim() ?? '';
    final subtitle = [
      if (sessions != null)
        context.l10n.projectSessionCount((sessions as num).toInt()),
      if (description.isNotEmpty) description,
    ].join(' · ');
    return HermesMobileRow(
      icon: _projectIcon(project),
      tone: _projectTone(context, project, name),
      title: name,
      subtitle: subtitle.isEmpty ? context.l10n.projectWorkspace : subtitle,
      onTap: () => _openDetail(context, project),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (action) {
          switch (action) {
            case 'appearance':
              _editAppearance(project);
            case 'rename':
              _renameProject(project);
            case 'delete':
              _deleteProject(project);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'appearance',
            child: Text(context.l10n.projectEditAppearance),
          ),
          PopupMenuItem(
            value: 'rename',
            child: Text(context.l10n.projectRename),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  /// Curated Material equivalents of desktop's codicon picker
  /// (apps/desktop/src/app/chat/sidebar/projects/project-appearance.tsx's
  /// `PROJECT_ICONS`) — mobile has no codicon font, so each name maps to the
  /// closest Material icon instead. Order matches desktop's grid.
  static const Map<String, IconData> _iconChoices = {
    'folder-library': Icons.layers_outlined,
    'repo': Icons.account_tree_outlined,
    'rocket': Icons.rocket_launch_outlined,
    'beaker': Icons.science_outlined,
    'flame': Icons.local_fire_department_outlined,
    'star-full': Icons.star_outline,
    'heart': Icons.favorite_border,
    'zap': Icons.bolt_outlined,
    'target': Icons.gps_fixed,
    'lightbulb': Icons.lightbulb_outline,
    'tools': Icons.build_outlined,
    'device-desktop': Icons.computer_outlined,
    'device-mobile': Icons.smartphone_outlined,
    'terminal': Icons.terminal,
    'dashboard': Icons.dashboard_outlined,
    'globe': Icons.public,
    'broadcast': Icons.cell_tower_outlined,
    'cloud': Icons.cloud_outlined,
    'database': Icons.storage_outlined,
    'package': Icons.inventory_2_outlined,
    'book': Icons.menu_book_outlined,
    'organization': Icons.corporate_fare_outlined,
    'bug': Icons.bug_report_outlined,
    'shield': Icons.shield_outlined,
    'key': Icons.vpn_key_outlined,
    'gift': Icons.card_giftcard_outlined,
    'telescope': Icons.explore_outlined,
    'home': Icons.home_outlined,
  };

  IconData _projectIcon(Map<String, dynamic> project) =>
      _iconChoices[project['icon']?.toString()] ?? Icons.layers_outlined;

  /// Desktop parity swatch ramp (apps/desktop/src/lib/profile-color.ts's
  /// `PROFILE_SWATCHES`): 12 hues at 30° steps, 68% saturation, 58%
  /// lightness. Persisted as `#RRGGBB` — a plain hex string is valid CSS, so
  /// it renders identically wherever desktop reads the same `color` field.
  static List<Color> get _colorSwatches => [
    for (var hue = 0; hue < 360; hue += 30)
      HSLColor.fromAHSL(1, hue.toDouble(), 0.68, 0.58).toColor(),
  ];

  static String _colorToHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Color? _parseHexColor(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final hex = text.startsWith('#') ? text.substring(1) : text;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  /// Prototype parity (`pageProjects()`'s per-project `color`): falls back to
  /// a stable hash-derived tone when the project has no persisted `color` —
  /// same project always gets the same tone, and a scanning list stays
  /// distinguishable at a glance even before anyone picks a real color.
  Color _projectTone(
    BuildContext context,
    Map<String, dynamic> project,
    String name,
  ) {
    final persisted = _parseHexColor(project['color']);
    if (persisted != null) return persisted;
    final key = (project['id'] ?? name).toString();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = [
      dark ? HermesSemanticDark.blue : HermesSemantic.blue,
      dark ? HermesSemanticDark.green : HermesSemantic.green,
      dark ? HermesSemanticDark.purple : HermesSemantic.purple,
      dark ? HermesSemanticDark.orange : HermesSemantic.orange,
      dark ? HermesSemanticDark.red : HermesSemantic.red,
    ];
    return palette[key.hashCode.abs() % palette.length];
  }

  Future<void> _editAppearance(Map<String, dynamic> project) async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final gateway = connectedGatewayOrNotify(context, connection);
    if (gateway == null) return;
    String? color = project['color']?.toString();
    String? icon = project['icon']?.toString();
    final result = await showDialog<(String?, String?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.projectEditAppearance),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.projectColor,
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _swatchButton(
                      key: const ValueKey('project-appearance-swatch-clear'),
                      null,
                      selected: color == null,
                      onTap: () => setDialogState(() => color = null),
                    ),
                    for (final swatch in _colorSwatches)
                      _swatchButton(
                        key: ValueKey(
                          'project-appearance-swatch-${_colorToHex(swatch)}',
                        ),
                        swatch,
                        selected: color == _colorToHex(swatch),
                        onTap: () =>
                            setDialogState(() => color = _colorToHex(swatch)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.projectIcon,
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in _iconChoices.entries)
                      _iconButton(
                        entry.value,
                        selected: icon == entry.key,
                        tint: icon == entry.key ? _parseHexColor(color) : null,
                        onTap: () => setDialogState(
                          () => icon = icon == entry.key ? null : entry.key,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop((color, icon)),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await requireActiveGateway(context, connection, gateway).request(
        'projects.update',
        {'id': project['id'], 'color': result.$1, 'icon': result.$2},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.projectAppearanceSaveFailed('$e'))),
        );
      }
    }
  }

  Widget _swatchButton(
    Color? color, {
    Key? key,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: color == null
            ? const Icon(Icons.not_interested, size: 16)
            : (selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null),
      ),
    );
  }

  Widget _iconButton(
    IconData icon, {
    required bool selected,
    required Color? tint,
    required VoidCallback onTap,
  }) {
    final palette = HermesPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.16) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: tint ?? (selected ? palette.accent : null),
        ),
      ),
    );
  }

  Future<void> _renameProject(Map<String, dynamic> project) async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final gateway = connectedGatewayOrNotify(context, connection);
    if (gateway == null) return;
    final ctrl = TextEditingController(
      text: (project['name'] ?? '').toString(),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.projectRenameTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.projectName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (name == null || name.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await requireActiveGateway(
        context,
        connection,
        gateway,
      ).request('projects.update', {'id': project['id'], 'name': name});
      await _load();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.projectRenameFailed('$e'))),
        );
      }
    }
  }

  Future<void> _deleteProject(Map<String, dynamic> project) async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final gateway = connectedGatewayOrNotify(context, connection);
    if (gateway == null) return;
    final name = (project['name'] ?? l10n.projectUntitled).toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.projectDeleteQuestion(name)),
        content: Text(l10n.projectDeleteDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await requireActiveGateway(
        context,
        connection,
        gateway,
      ).request('projects.delete', {'id': project['id']});
      await _load();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.projectDeleteFailed('$e'))),
        );
      }
    }
  }

  void _openDetail(BuildContext context, Map<String, dynamic> project) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    final connection = context.read<ConnectionStore>();
    final gateway = connectedGatewayOrNotify(context, connection);
    if (gateway == null) return;
    // The primary folder uses a stable marker; its display label is localized.
    // Any additional rows are optional extra folders with their own label.
    final extraFolders =
        <(TextEditingController path, TextEditingController label)>[];
    final fields = await showDialog<(String, List<Map<String, String>>)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.projectCreate),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.projectName),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pathCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.projectPrimaryPath,
                  ),
                ),
                for (final folder in extraFolders) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: folder.$1,
                              decoration: InputDecoration(
                                labelText: l10n.projectFolderPath,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: folder.$2,
                              decoration: InputDecoration(
                                labelText: l10n.projectFolderLabelOptional,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.commonRemove,
                        onPressed: () => setDialogState(() {
                          extraFolders.remove(folder);
                        }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setDialogState(() {
                      extraFolders.add((
                        TextEditingController(),
                        TextEditingController(),
                      ));
                    }),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.projectAddFolder),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop((
                nameCtrl.text.trim(),
                [
                  for (final folder in extraFolders)
                    if (folder.$1.text.trim().isNotEmpty)
                      {
                        'path': folder.$1.text.trim(),
                        'label': folder.$2.text.trim(),
                      },
                ],
              )),
              child: Text(l10n.commonCreate),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      pathCtrl.dispose();
      for (final folder in extraFolders) {
        folder.$1.dispose();
        folder.$2.dispose();
      }
    });
    if (fields == null || !context.mounted) return;
    final (name, extras) = fields;
    final path = pathCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await requireActiveGateway(context, connection, gateway).request(
        'projects.create',
        {
          'name': name,
          'folders': [
            {'path': path, 'label': '', 'is_primary': true},
            for (final folder in extras)
              {
                'path': folder['path'],
                'label': (folder['label']?.isNotEmpty ?? false)
                    ? folder['label']
                    : folder['path'],
              },
          ],
          'primary_path': path,
        },
      );
      await _load();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.projectCreateFailed('$e'))),
        );
      }
    }
  }
}
