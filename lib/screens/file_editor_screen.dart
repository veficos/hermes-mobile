/// File editor (spec §61, spot editor): loads a text file, edits with line
/// numbers, saves via `/api/v1/files/write`. Reload guard: re-reads before
/// save and surfaces the diff when the file changed on disk (spec §62).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/clipboard.dart';
import '../core/fs_download.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';

enum _ConflictChoice { cancel, reload, overwrite }

class FileEditorScreen extends StatefulWidget {
  final String path;
  final String name;

  /// When true, renders without its own Scaffold (embedded in a tablet split).
  final bool embedded;

  const FileEditorScreen({
    super.key,
    required this.path,
    required this.name,
    this.embedded = false,
  });

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen>
    with ConnectionReloadMixin<FileEditorScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _editorScroll = ScrollController();
  final ScrollController _gutterScroll = ScrollController();
  bool _loading = true;
  bool _saving = false;
  bool _isBinary = false;
  String? _error;
  String _original = '';
  int _lineCount = 1;
  bool _syncingScroll = false;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  ApiClient? _loadedApi;
  String? _loadedPath;

  bool get _dirty => _ctrl.text != _original;

  @override
  void initState() {
    super.initState();
    _editorScroll.addListener(_syncGutterFromEditor);
    _load();
  }

  @override
  void didUpdateWidget(covariant FileEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _mutationGeneration++;
      _loadedApi = null;
      _loadedPath = null;
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _loadedApi = null;
      _loadedPath = null;
      _saving = false;
      _loading = true;
      _error = null;
      _isBinary = false;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _editorScroll.removeListener(_syncGutterFromEditor);
    _ctrl.dispose();
    _editorScroll.dispose();
    _gutterScroll.dispose();
    super.dispose();
  }

  void _syncGutterFromEditor() {
    if (_syncingScroll ||
        !_gutterScroll.hasClients ||
        !_editorScroll.hasClients) {
      return;
    }
    final target = _editorScroll.offset.clamp(
      0.0,
      _gutterScroll.position.maxScrollExtent,
    );
    if ((target - _gutterScroll.offset).abs() < 0.5) return;
    _syncingScroll = true;
    _gutterScroll.jumpTo(target);
    _syncingScroll = false;
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final path = widget.path;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) {
        setState(() {
          _loadedApi = null;
          _loadedPath = null;
          _error = connectionOfflineErrorCode;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _isBinary = false;
    });
    try {
      final text = await api.fsReadText(path);
      if (!mounted ||
          generation != _loadGeneration ||
          path != widget.path ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() {
        _ctrl.text = text;
        _original = text;
        _lineCount = '\n'.allMatches(text).length + 1;
        _loadedApi = api;
        _loadedPath = path;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_editorScroll.hasClients) _editorScroll.jumpTo(0);
        if (_gutterScroll.hasClients) _gutterScroll.jumpTo(0);
      });
    } on BinaryFileException {
      if (!mounted ||
          generation != _loadGeneration ||
          path != widget.path ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() {
        _isBinary = true;
        _loadedApi = api;
        _loadedPath = path;
        _loading = false;
      });
    } catch (e) {
      if (!mounted ||
          generation != _loadGeneration ||
          path != widget.path ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fileEditorDiscardQuestion),
        content: Text(l10n.fileEditorDiscardDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.fileEditorKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.fileEditorDiscard),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<_ConflictChoice?> _showConflictDialog({
    required String onDisk,
    required String editorText,
  }) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final l10n = context.l10n;
    return showDialog<_ConflictChoice>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final panes = narrow
            ? Column(
                children: [
                  Expanded(
                    child: _DiffPane(
                      title: l10n.fileEditorDisk,
                      text: onDisk,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _DiffPane(
                      title: l10n.fileEditorEditor,
                      text: editorText,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _DiffPane(
                      title: l10n.fileEditorDisk,
                      text: onDisk,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DiffPane(
                      title: l10n.fileEditorEditor,
                      text: editorText,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              );

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.fileEditorConflictDescription),
            const SizedBox(height: 12),
            Expanded(child: panes),
          ],
        );

        if (narrow) {
          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text(l10n.fileEditorConflictTitle),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      Navigator.of(ctx).pop(_ConflictChoice.cancel),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: content,
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(_ConflictChoice.cancel),
                        child: Text(l10n.commonCancel),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(_ConflictChoice.reload),
                        child: Text(l10n.commonReload),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(_ConflictChoice.overwrite),
                        child: Text(l10n.fileEditorOverwriteSave),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: Text(l10n.fileEditorConflictTitle),
          content: SizedBox(width: 640, height: 360, child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_ConflictChoice.cancel),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_ConflictChoice.reload),
              child: Text(l10n.commonReload),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(_ConflictChoice.overwrite),
              child: Text(l10n.fileEditorOverwriteSave),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadToDevice() async {
    final l10n = context.l10n;
    final api = _loadedApi;
    final path = _loadedPath;
    final generation = _mutationGeneration;
    final messenger = ScaffoldMessenger.of(context);
    if (api == null || path == null || !_ownsTarget(api, path)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backendDisconnected)));
      return;
    }
    try {
      final savedPath = await downloadServerFileToDevice(
        api: api,
        remotePath: path,
        fileName: widget.name,
      );
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, path)) {
        return;
      }
      await copyTextOrNotify(
        context,
        savedPath,
        successMessage: l10n.filesDownloadedPath(savedPath),
      );
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, path)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.filesDownloadFailed('$e'))),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_isBinary) return;
    final api = _loadedApi;
    final path = _loadedPath;
    final generation = _mutationGeneration;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (api == null || path == null || !_ownsTarget(api, path)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backendDisconnected)));
      return;
    }
    setState(() => _saving = true);
    try {
      final onDisk = await api.fsReadText(path);
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, path)) {
        return;
      }
      final text = _ctrl.text;
      if (onDisk != _original) {
        if (!mounted) return;
        final choice = await _showConflictDialog(
          onDisk: onDisk,
          editorText: text,
        );
        if (!mounted ||
            generation != _mutationGeneration ||
            !_ownsTarget(api, path)) {
          return;
        }
        if (choice == null || choice == _ConflictChoice.cancel) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        if (choice == _ConflictChoice.reload) {
          if (!mounted) return;
          setState(() {
            _ctrl.text = onDisk;
            _original = onDisk;
            _lineCount = '\n'.allMatches(onDisk).length + 1;
            _saving = false;
          });
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.fileEditorReloaded)),
          );
          return;
        }
      }
      await api.fsWriteText(path, text);
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, path)) {
        return;
      }
      setState(() {
        _original = text;
        _lineCount = '\n'.allMatches(text).length + 1;
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.fileEditorSaved)));
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, path)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.fileEditorSaveFailed('$e'))),
        );
      }
    } finally {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, path)) {
        setState(() => _saving = false);
      }
    }
  }

  bool _ownsTarget(ApiClient api, String path) =>
      identical(context.read<ConnectionStore>().api, api) &&
      widget.path == path &&
      identical(_loadedApi, api) &&
      _loadedPath == path;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titleText = _dirty ? '● ${widget.name}' : widget.name;
    final actions = [
      IconButton(
        tooltip: l10n.filesDownloadToDevice,
        onPressed: _saving || _loading || _error != null
            ? null
            : () => _downloadToDevice(),
        icon: const Icon(Icons.download_outlined),
      ),
      IconButton(
        tooltip: l10n.commonReload,
        onPressed: _saving ? null : _load,
        icon: const Icon(Icons.refresh),
      ),
      if (!_isBinary)
        IconButton(
          onPressed: _saving ? null : _save,
          tooltip: _saving ? l10n.fileEditorSaving : l10n.commonSave,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
        ),
    ];

    final body = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saving
            ? () {}
            : _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _saving
            ? () {}
            : _save,
      },
      child: Focus(autofocus: widget.embedded, child: _buildBody(context)),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titleText,
                      semanticsLabel: _dirty
                          ? l10n.fileEditorUnsavedTitle(widget.name)
                          : widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HermesType.onSurface(
                        HermesType.headline,
                        Theme.of(context),
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (discard && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            titleText,
            semanticsLabel: _dirty
                ? l10n.fileEditorUnsavedTitle(widget.name)
                : widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: actions,
        ),
        body: body,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_isBinary) {
      final l10n = context.l10n;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HermesSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: HermesSpacing.md),
              Text(
                l10n.fileEditorBinaryTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HermesSpacing.sm),
              Text(
                l10n.fileEditorBinaryDescription,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HermesSpacing.md),
              FilledButton.icon(
                onPressed: _downloadToDevice,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.filesDownloadToDevice),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final codeStyle = HermesType.code.copyWith(
      color: isDark ? HermesText.darkPrimary : HermesText.lightPrimary,
      height: 1.45,
    );
    final gutterStyle = HermesType.code.copyWith(
      color: isDark ? HermesText.darkQuaternary : HermesText.lightQuaternary,
      height: 1.45,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 44,
          color: isDark
              ? HermesBackground.darkSecondary
              : HermesBackground.lightTertiary,
          child: SingleChildScrollView(
            controller: _gutterScroll,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              List.generate(_lineCount, (i) => '${i + 1}').join('\n'),
              textAlign: TextAlign.center,
              style: gutterStyle,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            scrollController: _editorScroll,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: codeStyle,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: (t) => setState(() {
              _lineCount = '\n'.allMatches(t).length + 1;
            }),
          ),
        ),
      ],
    );
  }
}

class _DiffPane extends StatelessWidget {
  final String title;
  final String text;
  final TextStyle? style;

  const _DiffPane({required this.title, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final preview = text.length > 4000 ? '${text.substring(0, 4000)}\n…' : text;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.codeBg,
        borderRadius: BorderRadius.circular(HermesRadius.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(title, style: Theme.of(context).textTheme.labelMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                preview.isEmpty ? context.l10n.fileEditorEmpty : preview,
                style: style ?? HermesType.code,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
