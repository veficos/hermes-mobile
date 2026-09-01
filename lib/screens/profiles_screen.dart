/// ProfilesScreen: 配置文件 CRUD 屏幕（真实后端数据）
///
/// - 数据：GET /api/v1/profiles（服务端按 upstream /api/profiles →
///   /api/config profiles 字段 → 本地 profiles.json 的顺序解析真实来源）
/// - 模型/提供者选项：GET /api/v1/model；工具选项：GET /api/v1/tools
/// - 操作：新建/编辑（POST/PUT /profiles）、删除、切换激活
///   （POST /profiles/{name}/activate）
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api_client.dart';
import '../core/clipboard.dart';
import '../core/connection_reload_mixin.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';

class ProfilesScreen extends StatefulWidget {
  final bool embedded;

  const ProfilesScreen({super.key, this.embedded = false});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen>
    with ConnectionReloadMixin<ProfilesScreen> {
  List<ProfileInfo> _profiles = const [];
  List<ModelInfo> _modelOptions = const [];
  List<String> _allTools = const [];
  bool _loading = true;
  bool _transferring = false;
  String? _error;
  String? _optionsError;
  int _loadGeneration = 0;
  ApiClient? _loadedApi;

  ApiClient? get _api => context.read<ConnectionStore>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    setState(() {
      _profiles = const [];
      _modelOptions = const [];
      _allTools = const [];
      _loadedApi = null;
      _transferring = false;
      _loading = true;
      _error = null;
      _optionsError = null;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final api = _api;
    if (api == null) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = connectionOfflineErrorCode;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await api.listProfiles();
      final active = payload.active;
      // Provider/model options and the tool list are independent surfaces;
      // failure there must not blank the profile list itself.
      List<ModelInfo> models = _modelOptions;
      List<String> tools = _allTools;
      final optionErrors = <String>[];
      try {
        models = await api.modelOptions();
      } catch (error) {
        optionErrors.add('models: $error');
      }
      try {
        tools = (await api.toolsets()).map((t) => t.name).toList();
      } catch (error) {
        optionErrors.add('tools: $error');
      }
      if (!mounted || generation != _loadGeneration || !identical(api, _api)) {
        return;
      }
      setState(() {
        _profiles = [
          for (final p in payload.profiles)
            active != null ? p.copyWith(isActive: p.name == active) : p,
        ];
        _modelOptions = models;
        _allTools = tools;
        _loadedApi = api;
        _optionsError = optionErrors.isEmpty ? null : optionErrors.join('; ');
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration || !identical(api, _api)) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _openEditor([ProfileInfo? existing]) async {
    final connection = context.read<ConnectionStore>();
    final api = _entityApiOrNotify();
    if (api == null) return;
    final saved = await showModalBottomSheet<ProfileInfo>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HermesRadius.sheet),
        ),
      ),
      builder: (_) => _ProfileEditorSheet(
        existing: existing,
        modelOptions: _modelOptions,
        allTools: _allTools,
      ),
    );
    if (saved == null) return;
    if (!mounted) return;
    try {
      requireActiveApi(context, connection, api);
      if (existing == null) {
        await api.saveProfile(saved.toJson());
      } else {
        await api.updateProfile(existing.name, saved.toJson());
      }
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      if (saved.isActive && existing?.isActive != true) {
        if (!mounted) return;
        await context.read<SessionStore>().switchActiveProfile(saved.name);
        if (!mounted) return;
        requireActiveApi(context, connection, api);
      }
    } catch (e) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.profilesSaveFailed('$e'),
        kind: HermesToastKind.error,
      );
      return;
    }
    await _load();
    if (!mounted) return;
    showHermesToast(
      context,
      message: existing == null
          ? context.l10n.profilesCreated
          : context.l10n.profilesSaved,
      kind: HermesToastKind.success,
    );
  }

  Future<void> _duplicate(ProfileInfo p) async {
    final connection = context.read<ConnectionStore>();
    final api = _entityApiOrNotify();
    if (api == null) return;
    try {
      await api.saveProfile(
        p
            .copyWith(
              name: context.l10n.profilesCopyName(p.name),
              isActive: false,
            )
            .toJson(),
      );
      if (!mounted) return;
      requireActiveApi(context, connection, api);
    } catch (e) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.profilesDuplicateFailed('$e'),
        kind: HermesToastKind.error,
      );
      return;
    }
    await _load();
    if (!mounted) return;
    showHermesToast(
      context,
      message: context.l10n.profilesDuplicated,
      kind: HermesToastKind.success,
    );
  }

  Future<void> _delete(ProfileInfo p) async {
    final connection = context.read<ConnectionStore>();
    final api = _entityApiOrNotify();
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.profilesDeleteQuestion(p.name)),
        content: Text(
          p.isActive
              ? context.l10n.profilesDeleteActiveWarning
              : context.l10n.profilesDeleteWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      requireActiveApi(context, connection, api);
      await api.deleteProfile(p.name);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
    } catch (e) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.profilesDeleteFailed('$e'),
        kind: HermesToastKind.error,
      );
      return;
    }
    await _load();
    if (!mounted) return;
    showHermesToast(
      context,
      message: context.l10n.profilesDeleted,
      kind: HermesToastKind.success,
    );
  }

  Future<void> _setActive(ProfileInfo p) async {
    final connection = context.read<ConnectionStore>();
    final api = _entityApiOrNotify();
    if (api == null || p.isActive) return;
    try {
      requireActiveApi(context, connection, api);
      await context.read<SessionStore>().switchActiveProfile(p.name);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
    } catch (e) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.profilesSwitchFailed('$e'),
        kind: HermesToastKind.error,
      );
      return;
    }
    await _load();
    if (!mounted) return;
    showHermesToast(
      context,
      message: context.l10n.profilesSwitchedTo(p.name),
      kind: HermesToastKind.success,
    );
  }

  Future<void> _editSoul(ProfileInfo profile) async {
    final connection = context.read<ConnectionStore>();
    final api = _entityApiOrNotify();
    if (api == null) return;
    try {
      final soul = await api.getProfileSoul(profile.name);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      final controller = TextEditingController(text: soul.content);
      final content = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${profile.name} · SOUL.md'),
          content: SizedBox(
            width: 640,
            height: 420,
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'HermesJetBrainsMono'),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: context.l10n.profilesSoulHint,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, controller.text),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(context.l10n.commonSave),
            ),
          ],
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
      if (content == null || !mounted) return;
      requireActiveApi(context, connection, api);
      await api.updateProfileSoul(profile.name, content);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.profilesSoulSaved,
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.profilesSoulFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _showSetupCommand(ProfileInfo profile) async {
    final connection = context.read<ConnectionStore>();
    final api = _entityApiOrNotify();
    if (api == null) return;
    try {
      final command = await api.getProfileSetupCommand(profile.name);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.profilesSetupCommand),
          content: SelectableText(
            command,
            style: const TextStyle(fontFamily: 'HermesJetBrainsMono'),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                if (await copyTextOrNotify(context, command) &&
                    context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(context.l10n.profilesCopy),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonDone),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.profilesSetupCommandFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _exportProfile(ProfileInfo profile) async {
    final connection = context.read<ConnectionStore>();
    final api = _entityApiOrNotify();
    if (api == null || _transferring) return;
    setState(() => _transferring = true);
    try {
      final archive = await api.exportProfileArchive(profile.name);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              archive.bytes,
              name: archive.filename,
              mimeType: 'application/gzip',
            ),
          ],
        ),
      );
      if (mounted &&
          identical(connection.api, api) &&
          result.status == ShareResultStatus.success) {
        showHermesToast(
          context,
          message: context.l10n.profilesExported,
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.profilesExportFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _importProfile() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null || _transferring) return;
    setState(() => _transferring = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Hermes Profile', extensions: ['gz', 'tgz']),
        ],
      );
      if (file == null || !mounted) return;
      requireActiveApi(context, connection, api);
      final result = await api.importProfileArchive(
        await file.readAsBytes(),
        file.name,
      );
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      await _load();
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.profilesImported(
            '${result['name'] ?? 'Profile'}',
          ),
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.profilesImportFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  ApiClient? _entityApiOrNotify() {
    final api = _loadedApi;
    if (api != null && identical(api, context.read<ConnectionStore>().api)) {
      return api;
    }
    showHermesToast(
      context,
      message: context.l10n.backendDisconnected,
      kind: HermesToastKind.error,
    );
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(context.l10n.profilesTitle),
              actions: [
                IconButton(
                  tooltip: context.l10n.profilesImport,
                  onPressed: _transferring ? null : _importProfile,
                  icon: _transferring
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_upload_outlined),
                ),
                IconButton(
                  tooltip: context.l10n.profilesNew,
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: context.l10n.commonRefresh,
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      body: _loading
          ? HermesLoadingState(label: context.l10n.profilesLoading)
          : _error != null
          ? HermesErrorState(
              description: _error == connectionOfflineErrorCode
                  ? context.l10n.backendDisconnected
                  : _error,
              onRetry: _load,
            )
          : _profiles.isEmpty
          ? HermesEmptyState(
              icon: Icons.person_outline,
              title: context.l10n.profilesEmptyTitle,
              description: context.l10n.profilesEmptyDescription,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                    children: [
                      if (_optionsError != null) ...[
                        HermesNoticeBar(
                          message: context.l10n.profilesOptionsLoadFailed(
                            _optionsError!,
                          ),
                          icon: Icons.warning_amber_outlined,
                          color: HermesSemantic.orange,
                          onTap: _load,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (widget.embedded)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: context.l10n.profilesImport,
                            onPressed: _transferring ? null : _importProfile,
                            icon: const Icon(Icons.file_upload_outlined),
                          ),
                        ),
                      HermesMobileGroup(
                        children: [for (final p in _profiles) _profileRow(p)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _profileRow(ProfileInfo p) {
    return HermesMobileRow(
      icon: Icons.person_outline,
      title: p.name,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p.provider ?? '?'} · ${p.model ?? '?'}',
            style: TextStyle(
              color: HermesPalette.of(context).text3,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          Text(
            context.l10n.profilesParameters(
              p.temperature.toStringAsFixed(1),
              p.maxTokens,
              p.isActive ? context.l10n.profilesCurrentSuffix : '',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HermesPalette.of(context).text3,
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
        ],
      ),
      onTap: () => _openEditor(p),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.isActive)
            HermesMobileStatusChip(
              label: context.l10n.profilesActive,
              color: HermesPalette.of(context).accent,
            )
          else
            // Prototype parity (pageProfiles()): activation is a single
            // always-visible tap, not buried in the overflow menu.
            TextButton(
              onPressed: () => _setActive(p),
              child: Text(context.l10n.profilesActivate),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'soul':
                  _editSoul(p);
                case 'setup':
                  _showSetupCommand(p);
                case 'export':
                  _exportProfile(p);
                case 'duplicate':
                  _duplicate(p);
                case 'delete':
                  _delete(p);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'soul',
                child: Row(
                  children: [
                    const Icon(Icons.edit_note),
                    const SizedBox(width: 8),
                    Text(context.l10n.profilesEditSoul),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'setup',
                child: Row(
                  children: [
                    const Icon(Icons.terminal),
                    const SizedBox(width: 8),
                    Text(context.l10n.profilesSetupCommand),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.file_download_outlined),
                    const SizedBox(width: 8),
                    Text(context.l10n.profilesExport),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    const Icon(Icons.content_copy_outlined),
                    const SizedBox(width: 8),
                    Text(context.l10n.profilesDuplicate),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: HermesSemantic.red),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.commonDelete,
                      style: const TextStyle(color: HermesSemantic.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileEditorSheet extends StatefulWidget {
  final ProfileInfo? existing;
  final List<ModelInfo> modelOptions;
  final List<String> allTools;

  const _ProfileEditorSheet({
    required this.existing,
    required this.modelOptions,
    required this.allTools,
  });

  @override
  State<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<_ProfileEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _systemPromptCtrl;
  late final TextEditingController _descriptionCtrl;
  late String _provider;
  late String _model;
  late double _temperature;
  late int _maxTokens;
  late double _topP;
  late Set<String> _tools;
  late bool _isActive;

  List<String> _modelsFor(String provider) {
    return widget.modelOptions
            .where((o) => o.slug == provider)
            .firstOrNull
            ?.models ??
        const [];
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _systemPromptCtrl = TextEditingController(text: e?.systemPrompt ?? '');
    _descriptionCtrl = TextEditingController(text: e?.description ?? '');
    _provider =
        e?.provider ??
        (widget.modelOptions.isNotEmpty ? widget.modelOptions.first.slug : '');
    _model = e?.model ?? (_modelsFor(_provider).firstOrNull ?? '');
    _temperature = e?.temperature ?? 0.7;
    _maxTokens = e?.maxTokens ?? 4096;
    _topP = e?.topP ?? 0.9;
    _tools = Set.from(e?.tools ?? widget.allTools.take(4));
    _isActive = e?.isActive ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _systemPromptCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showHermesToast(context, message: context.l10n.profilesNameRequired);
      return;
    }
    final result = ProfileInfo(
      name: name,
      model: _model.isEmpty ? null : _model,
      provider: _provider.isEmpty ? null : _provider,
      temperature: _temperature,
      maxTokens: _maxTokens,
      topP: _topP,
      systemPrompt: _systemPromptCtrl.text.trim(),
      tools: _tools.toList(),
      isActive: _isActive,
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = _modelsFor(_provider);
    final providerName = {for (final o in widget.modelOptions) o.slug: o.name};
    return Padding(
      padding: EdgeInsets.only(
        left: HermesSpacing.md,
        right: HermesSpacing.md,
        top: HermesSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + HermesSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null
                  ? context.l10n.profilesCreateTitle
                  : context.l10n.profilesEditTitle,
              style: HermesType.onSurface(HermesType.title, theme),
            ),
            const SizedBox(height: HermesSpacing.md),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.commonName,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
            if (widget.modelOptions.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final providerField = DropdownButtonFormField<String>(
                    initialValue:
                        widget.modelOptions.any((o) => o.slug == _provider)
                        ? _provider
                        : null,
                    decoration: InputDecoration(
                      labelText: context.l10n.profilesProvider,
                      prefixIcon: const Icon(Icons.cloud_outlined),
                    ),
                    items: [
                      for (final o in widget.modelOptions)
                        DropdownMenuItem(
                          value: o.slug,
                          child: Text(providerName[o.slug] ?? o.slug),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _provider = v;
                        _model = _modelsFor(v).firstOrNull ?? '';
                      });
                    },
                  );
                  final modelField = DropdownButtonFormField<String>(
                    initialValue: models.contains(_model) ? _model : null,
                    decoration: InputDecoration(
                      labelText: context.l10n.profilesModel,
                      prefixIcon: const Icon(Icons.psychology_alt_outlined),
                    ),
                    items: [
                      for (final m in models)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => setState(() => _model = v ?? _model),
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: [
                        providerField,
                        const SizedBox(height: HermesSpacing.sm),
                        modelField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: providerField),
                      const SizedBox(width: HermesSpacing.sm),
                      Expanded(child: modelField),
                    ],
                  );
                },
              ),
            const SizedBox(height: HermesSpacing.sm),
            _SliderRow(
              label: 'Temperature',
              value: _temperature,
              min: 0,
              max: 2,
              divisions: 20,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) => setState(() => _temperature = v),
            ),
            _SliderRow(
              label: 'Top P',
              value: _topP,
              min: 0,
              max: 1,
              divisions: 10,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) => setState(() => _topP = v),
            ),
            _SliderRow(
              label: 'Max Tokens',
              value: _maxTokens.toDouble(),
              min: 512,
              max: 32768,
              divisions: 63,
              format: (v) => '${v.round()}',
              onChanged: (v) => setState(() => _maxTokens = v.round()),
            ),
            const SizedBox(height: HermesSpacing.sm),
            TextField(
              controller: _systemPromptCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.profilesSystemPrompt,
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.speaker_notes_outlined),
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.l10n.profilesDescriptionOptional,
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.short_text_outlined),
              ),
            ),
            if (widget.allTools.isNotEmpty) ...[
              const SizedBox(height: HermesSpacing.md),
              Row(
                children: [
                  Text(
                    context.l10n.profilesTools,
                    style: HermesType.onSurface(HermesType.headline, theme),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_tools.length == widget.allTools.length) {
                          _tools.clear();
                        } else {
                          _tools = Set.from(widget.allTools);
                        }
                      });
                    },
                    icon: Icon(
                      _tools.length == widget.allTools.length
                          ? Icons.deselect
                          : Icons.select_all,
                    ),
                    label: Text(
                      _tools.length == widget.allTools.length
                          ? context.l10n.profilesDeselectAll
                          : context.l10n.profilesSelectAll,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HermesSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in widget.allTools)
                    FilterChip(
                      selected: _tools.contains(t),
                      onSelected: (_) {
                        setState(() {
                          if (_tools.contains(t)) {
                            _tools.remove(t);
                          } else {
                            _tools.add(t);
                          }
                        });
                      },
                      label: Text(t),
                    ),
                ],
              ),
            ],
            const SizedBox(height: HermesSpacing.md),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.l10n.profilesSetActive,
                style: HermesType.onSurface(HermesType.subheadline, theme),
              ),
              secondary: Icon(
                Icons.star,
                color: _isActive ? HermesPalette.of(context).accent : null,
              ),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: HermesSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(context.l10n.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: HermesType.onSurface(HermesType.subheadline, theme),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              format(value),
              textAlign: TextAlign.right,
              style: HermesType.onSurface(HermesType.headline, theme),
            ),
          ),
        ],
      ),
    );
  }
}
