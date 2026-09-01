/// New Session wizard (spec §16–19, S006): pick workspace + model, then start.
///
/// Kept deliberately simple: workspace is chosen by browsing the server FS,
/// model is optional (deferred switch), and starting opens the session and
/// pushes the full-screen ChatScreen.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/models.dart';
import '../core/server_path.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart' show HermesSectionHeader;
import '../widgets/h/hermes_states.dart';
import '../widgets/session/project_dialog.dart';
import 'chat_screen.dart';

class NewSessionScreen extends StatefulWidget {
  /// File-browser handoff: preserve the selected workspace and pre-populate
  /// the new session's durable composer draft with the selected paths.
  final String? initialCwd;
  final String? initialDraftText;

  const NewSessionScreen({super.key, this.initialCwd, this.initialDraftText});

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen>
    with ConnectionReloadMixin<NewSessionScreen> {
  final TextEditingController _cwdCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  String? _selectedModel;
  Map<String, dynamic>? _selectedProject;
  List<ModelInfo> _providers = [];
  String? _error;
  bool _starting = false;
  int _loadGeneration = 0;

  ApiClient? get _api => context.read<SessionStore>().api;

  @override
  void initState() {
    super.initState();
    final initialCwd = widget.initialCwd?.trim();
    if (initialCwd != null && initialCwd.isNotEmpty) {
      _cwdCtrl.text = initialCwd;
    }
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<SessionStore>();
    observeConnection(session.connection, _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    final initialCwd = widget.initialCwd?.trim() ?? '';
    setState(() {
      _providers = const [];
      _selectedModel = null;
      _selectedProject = null;
      _starting = false;
      _error = null;
      _cwdCtrl.text = initialCwd;
    });
    _init();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _cwdCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final session = context.read<SessionStore>();
    final connection = session.connection;
    final api = _api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    final errors = <String>[];
    if (_cwdCtrl.text.trim().isEmpty) {
      try {
        final cwd = await api.fsDefaultCwd();
        if (mounted &&
            generation == _loadGeneration &&
            identical(api, connection.api)) {
          setState(() => _cwdCtrl.text = cwd);
        }
      } catch (e) {
        errors.add('$e');
      }
    }
    try {
      final catalog = await api.modelCatalog();
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, connection.api)) {
        setState(() {
          _providers = catalog.providers;
          _selectedModel =
              catalog.currentProvider != null && catalog.currentModel != null
              ? '${catalog.currentProvider}|${catalog.currentModel}'
              : _currentModelOf(catalog.providers);
        });
      }
    } catch (e) {
      errors.add('$e');
    }
    if (mounted &&
        generation == _loadGeneration &&
        identical(api, connection.api)) {
      setState(() {
        _error = errors.isEmpty
            ? null
            : context.l10n.newSessionInitFailed(errors.join('; '));
      });
    }
  }

  /// "providerSlug|modelName" of the backend's current model, if listed.
  String? _currentModelOf(List<ModelInfo> providers) {
    for (final p in providers) {
      if (p.isCurrent && p.models.isNotEmpty) {
        return '${p.slug}|${p.models.first}';
      }
    }
    return providers.isEmpty || providers.first.models.isEmpty
        ? null
        : '${providers.first.slug}|${providers.first.models.first}';
  }

  List<String> _modelChoices() {
    final out = <String>[];
    for (final p in _providers) {
      for (final m in p.models) {
        out.add('${p.slug}|$m');
      }
    }
    return out;
  }

  String _modelLabel(String choice) {
    final idx = choice.indexOf('|');
    if (idx < 0) return choice;
    return '${choice.substring(0, idx)} · ${choice.substring(idx + 1)}';
  }

  Future<void> _browse() async {
    final connection = context.read<SessionStore>().connection;
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    var path = _cwdCtrl.text.trim().isEmpty ? '' : _cwdCtrl.text.trim();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) => _DirectoryPicker(
            startPath: path,
            ownerApi: api,
            onPick: (picked) {
              if (!identical(connection.api, api)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.backendDisconnected)),
                );
                return;
              }
              Navigator.of(ctx).pop();
              if (mounted) {
                setState(() {
                  _cwdCtrl.text = picked;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final connection = session.connection;
    final ownerApi = connectedApiOrNotify(context, connection);
    if (ownerApi == null) return;
    final cwd = _cwdCtrl.text.trim();
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      requireActiveApi(context, connection, ownerApi);
      String? provider;
      String? model;
      if (_selectedModel != null) {
        final idx = _selectedModel!.indexOf('|');
        provider = idx < 0
            ? _selectedModel!
            : _selectedModel!.substring(0, idx);
        model = idx < 0 ? _selectedModel! : _selectedModel!.substring(idx + 1);
      }
      await session.openNewSession(
        cwd: cwd.isEmpty ? null : cwd,
        provider: provider,
        model: model,
        title: _titleCtrl.text,
        projectId: (_selectedProject?['project_id'] ?? _selectedProject?['id'])
            ?.toString(),
      );
      if (!mounted) return;
      requireActiveApi(context, connection, ownerApi);
      final sid = session.durableId;
      final handoff = widget.initialDraftText?.trim();
      String? draftSaveError;
      if (sid != null &&
          sid.isNotEmpty &&
          handoff != null &&
          handoff.isNotEmpty) {
        try {
          requireActiveApi(context, connection, ownerApi);
          await ownerApi.saveDraft(
            sid,
            text: handoff,
            files: const [],
            profile: session.profile,
          );
          if (!mounted) return;
          requireActiveApi(context, connection, ownerApi);
        } catch (error) {
          draftSaveError = '$error';
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            initialDraftText: handoff,
            initialDraftSaveError: draftSaveError,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = l10n.newSessionStartFailed('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette = HermesPalette.of(context);
    final panelWidth = width >= 1200
        ? 640.0
        : width >= 840
        ? 560.0
        : width >= 600
        ? 720.0
        : double.infinity;
    final desktop = width >= 840;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sessionNew)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: panelWidth),
          child: Container(
            margin: EdgeInsets.all(desktop ? 24 : 0),
            decoration: desktop
                ? BoxDecoration(
                    color: palette.surface,
                    border: Border.all(color: palette.border),
                    borderRadius: BorderRadius.circular(HermesRadius.largeCard),
                    boxShadow: hermesShadow(context, HermesShadowTier.md),
                  )
                : null,
            child: _form(context),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final choices = _modelChoices();
    return ListView(
      padding: const EdgeInsets.all(HermesSpacing.md),
      children: [
        HermesSectionHeader(title: l10n.newSessionTitleSection),
        TextField(
          controller: _titleCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: l10n.newSessionTitleHint,
            prefixIcon: const Icon(Icons.title),
          ),
        ),
        const SizedBox(height: HermesSpacing.lg),
        HermesSectionHeader(title: l10n.newSessionWorkspace),
        TextField(
          controller: _cwdCtrl,
          decoration: InputDecoration(
            hintText: l10n.newSessionWorkspaceHint,
            prefixIcon: const Icon(Icons.folder_outlined),
          ),
        ),
        const SizedBox(height: HermesSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _browse,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(l10n.newSessionBrowseDirectory),
          ),
        ),
        const SizedBox(height: HermesSpacing.lg),
        HermesSectionHeader(title: l10n.kanbanProject),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_copy_outlined),
          title: Text(
            (_selectedProject?['name'] ?? l10n.newSessionNoProject).toString(),
          ),
          subtitle: _selectedProject == null
              ? Text(l10n.newSessionMoveLater)
              : Text(
                  (_selectedProject?['primary_path'] ??
                          _selectedProject?['path'] ??
                          '')
                      .toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final picked = await ProjectDialog.show(
              context,
              initialProject: _selectedProject,
            );
            if (mounted) setState(() => _selectedProject = picked);
          },
        ),
        const SizedBox(height: HermesSpacing.lg),
        HermesSectionHeader(title: l10n.configVoiceModel),
        DropdownButtonFormField<String>(
          initialValue: _selectedModel,
          hint: Text(l10n.newSessionUseCurrentModel),
          items: [
            for (final c in choices)
              DropdownMenuItem(value: c, child: Text(_modelLabel(c))),
          ],
          onChanged: (v) => setState(() => _selectedModel = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.smart_toy_outlined),
          ),
        ),
        const SizedBox(height: HermesSpacing.lg),
        HermesSectionHeader(title: l10n.newSessionAgent),
        _agentSummary(context),
        if (_error != null) ...[
          const SizedBox(height: HermesSpacing.md),
          Text(
            _error == connectionOfflineErrorCode
                ? l10n.backendDisconnected
                : _error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: HermesSemantic.red),
          ),
        ],
        const SizedBox(height: HermesSpacing.lg),
        FilledButton.icon(
          key: const ValueKey('new-session-submit'),
          onPressed: _starting ? null : _start,
          icon: _starting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(
            _starting ? l10n.newSessionStarting : l10n.newSessionStart,
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _agentSummary(BuildContext context) {
    final session = context.watch<SessionStore>();
    final info = session.info;
    final palette = HermesPalette.of(context);
    return Row(
      children: [
        Icon(Icons.bolt, color: palette.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.newSessionAgentSummary(
              info?.model ?? context.l10n.newSessionCurrentModel,
              info?.cwd ?? context.l10n.newSessionWorkspaceAbove,
            ),
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Simple server-side directory browser used by the workspace picker.
class _DirectoryPicker extends StatefulWidget {
  final String startPath;
  final ApiClient ownerApi;
  final ValueChanged<String> onPick;

  const _DirectoryPicker({
    required this.startPath,
    required this.ownerApi,
    required this.onPick,
  });

  @override
  State<_DirectoryPicker> createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends State<_DirectoryPicker> {
  String _path = '';
  List<FsEntry> _entries = [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _path = widget.startPath;
    _load(_path);
  }

  Future<void> _load(String path) async {
    final connection = context.read<SessionStore>().connection;
    final generation = ++_loadGeneration;
    setState(() {
      _path = path;
      _loading = true;
      _error = null;
    });
    if (!identical(connection.api, widget.ownerApi)) {
      setState(() {
        _error = connectionOfflineErrorCode;
        _loading = false;
      });
      return;
    }
    try {
      final entries = await widget.ownerApi.fsList(path);
      if (mounted &&
          generation == _loadGeneration &&
          path == _path &&
          identical(connection.api, widget.ownerApi)) {
        setState(() {
          _entries = entries.where((entry) => entry.isDirectory).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration && path == _path) {
        setState(() {
          _error = identical(connection.api, widget.ownerApi)
              ? '$e'
              : connectionOfflineErrorCode;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _path.isEmpty ? '/' : _path,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: context.l10n.newSessionParentDirectory,
                icon: const Icon(Icons.arrow_upward),
                onPressed: _path.isEmpty || ServerPath.isPosixRoot(_path)
                    ? null
                    : () {
                        final up = ServerPath.parent(_path);
                        _load(up.isEmpty ? '/' : up);
                      },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? HermesLoadingState(label: context.l10n.filesLoadingDirectory)
              : _error != null
              ? HermesErrorState(
                  description: _error == connectionOfflineErrorCode
                      ? context.l10n.backendDisconnected
                      : _error,
                  onRetry: () => _load(_path),
                )
              : ListView.builder(
                  itemCount: _entries.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      return ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(context.l10n.filesSelectCurrentDirectory),
                        onTap: () => widget.onPick(_path),
                      );
                    }
                    final e = _entries[i - 1];
                    if (!e.isDirectory) return const SizedBox.shrink();
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(e.name),
                      subtitle: Text(
                        e.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _load(e.path),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
