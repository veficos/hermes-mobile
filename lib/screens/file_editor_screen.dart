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
import '../core/json_document.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_confirm_dialog.dart';
import '../widgets/glass/glass_alert_dialog.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import '../widgets/mobile/hermes_adaptive_menu.dart';
import '../chat/content/code_highlighter.dart';

enum _ConflictChoice { cancel, reload, overwrite }

class FileEditorScreen extends StatefulWidget {
  final String path;
  final String name;
  final String? profile;

  /// When true, renders without its own Scaffold (embedded in a tablet split).
  final bool embedded;

  const FileEditorScreen({
    super.key,
    required this.path,
    required this.name,
    this.profile,
    this.embedded = false,
  });

  @override
  State<FileEditorScreen> createState() => FileEditorScreenState();
}

/// Public so the tablet split view (FilesScreen) can hold a
/// `GlobalKey<FileEditorScreenState>` and guard unsaved edits before swapping
/// the embedded editor.
class FileEditorScreenState extends State<FileEditorScreen>
    with ConnectionReloadMixin<FileEditorScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final GlobalKey _sourceFieldKey = GlobalKey();
  final ScrollController _editorScroll = ScrollController();
  final ScrollController _gutterScroll = ScrollController();
  bool _loading = true;
  bool _saving = false;
  bool _confirmingDiscard = false;
  bool _allowExit = false;
  bool _isBinary = false;
  String? _error;
  String _original = '';
  int _lineCount = 1;
  bool _syncingScroll = false;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  String _findQuery = '';
  bool _showDiff = false;
  ApiClient? _loadedApi;
  String? _loadedPath;

  bool get _dirty => _ctrl.text != _original;
  bool get _isJson => widget.name.toLowerCase().endsWith('.json');

  List<_DiffOp> get _diffOps =>
      _lineDiff(_original.split('\n'), _ctrl.text.split('\n'));

  ({int added, int removed}) get _changeStats {
    var added = 0;
    var removed = 0;
    for (final op in _diffOps) {
      switch (op.kind) {
        case _DiffOpKind.insert:
          added++;
        case _DiffOpKind.delete:
          removed++;
        case _DiffOpKind.equal:
          break;
      }
    }
    return (added: added, removed: removed);
  }

  Future<void> _findInFile() async {
    if (_saving || _loading || _isBinary || _confirmingDiscard) return;
    final source = _ctrl.text;
    final path = widget.path;
    final generation = _loadGeneration;
    final controller = TextEditingController(text: _findQuery);
    final replacement = TextEditingController();
    final result =
        await showDialog<({String query, String replacement, bool replaceAll})>(
          context: context,
          builder: (ctx) {
            return GlassAlertDialog(
              title: Text(context.l10n.fileEditorFindReplaceTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.fileEditorFindLabel,
                    ),
                  ),
                  TextField(
                    controller: replacement,
                    decoration: InputDecoration(
                      labelText: context.l10n.fileEditorReplaceWithLabel,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop((
                    query: controller.text,
                    replacement: replacement.text,
                    replaceAll: true,
                  )),
                  child: Text(context.l10n.fileEditorReplaceAll),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop((
                    query: controller.text,
                    replacement: replacement.text,
                    replaceAll: false,
                  )),
                  child: Text(context.l10n.fileEditorFindLabel),
                ),
              ],
            );
          },
        );
    // Deferred: the dialog's exit transition can still be rebuilding these
    // TextFields for a frame or two after showDialog's Future resolves —
    // disposing synchronously here races that and throws "used after being
    // disposed".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
      replacement.dispose();
    });
    if (!mounted ||
        result == null ||
        result.query.isEmpty ||
        _saving ||
        _loading ||
        widget.path != path ||
        _loadGeneration != generation ||
        _ctrl.text != source) {
      return;
    }
    final query = result.query;
    if (result.replaceAll) {
      final count = _ctrl.text.split(query).length - 1;
      if (count > 0) {
        final text = _ctrl.text.replaceAll(query, result.replacement);
        setState(() {
          _ctrl.text = text;
          _lineCount = '\n'.allMatches(text).length + 1;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? context.l10n.fileEditorNoMatches
                : context.l10n.fileEditorReplacedCount(count),
          ),
        ),
      );
      return;
    }
    final start = _ctrl.selection.isValid ? _ctrl.selection.end : 0;
    var index = _ctrl.text.indexOf(query, start);
    if (index < 0 && start > 0) index = _ctrl.text.indexOf(query);
    if (index < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.paletteNoResults)));
      return;
    }
    setState(() {
      _findQuery = query;
      _ctrl.selection = TextSelection(
        baseOffset: index,
        extentOffset: index + query.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_ctrl.selection.isValid ||
          _ctrl.selection.baseOffset != index) {
        return;
      }
      // EditableText owns wrapping, scaling and caret geometry. Do not
      // estimate pixel offsets from logical line numbers.
      void reveal(Element element) {
        if (element is StatefulElement && element.state is EditableTextState) {
          (element.state as EditableTextState).bringIntoView(
            TextPosition(offset: index),
          );
          return;
        }
        element.visitChildren(reveal);
      }

      final field = _sourceFieldKey.currentContext;
      if (field is Element) reveal(field);
    });
  }

  void _formatJson() {
    try {
      final formatted = JsonDocument.parse(_ctrl.text).formatted();
      setState(() {
        _ctrl.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        _lineCount = '\n'.allMatches(formatted).length + 1;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.configInvalidJson('$error'))),
      );
    }
  }

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
      final text = await api.fsReadText(path, profile: widget.profile);
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
    if (_saving || _confirmingDiscard) return false;
    if (!_dirty) return true;
    _confirmingDiscard = true;
    try {
      final l10n = context.l10n;
      final result = await showHermesConfirmDialog(
        context: context,
        title: l10n.fileEditorDiscardQuestion,
        message: l10n.fileEditorDiscardDescription,
        cancelLabel: l10n.fileEditorKeepEditing,
        confirmLabel: l10n.fileEditorDiscard,
        destructive: true,
      );
      return result == true;
    } finally {
      _confirmingDiscard = false;
    }
  }

  /// Embedded (tablet split) mode has no route of its own, so the PopScope
  /// below cannot guard it. The host split view calls this before swapping or
  /// unmounting the editor; resolves true when it is safe to proceed (not
  /// dirty, or the user chose to discard).
  Future<bool> confirmDiscardIfDirty() => _confirmDiscard();

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
            child: HermesPageScaffold(
              title: l10n.fileEditorConflictTitle,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(_ConflictChoice.cancel),
              ),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: content,
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(_ConflictChoice.cancel),
                        child: Text(l10n.commonCancel),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(_ConflictChoice.reload),
                        child: Text(l10n.commonReload),
                      ),
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

        return GlassAlertDialog(
          maxWidth: 688,
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
    if (_isBinary ||
        _saving ||
        _loading ||
        _error != null ||
        _confirmingDiscard) {
      return;
    }
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
      final onDisk = await api.fsReadText(path, profile: widget.profile);
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
      await api.fsWriteText(path, text, profile: widget.profile);
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
    final stats = _dirty ? _changeStats : (added: 0, removed: 0);
    final titleText = _dirty
        ? '● ${widget.name}  (+${stats.added} / -${stats.removed})'
        : widget.name;
    final actions = [
      if (_isJson && !_isBinary)
        IconButton(
          tooltip: l10n.configFullJson,
          onPressed: _saving || _loading || _error != null ? null : _formatJson,
          icon: const Icon(Icons.data_object),
        ),
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
          tooltip: _showDiff
              ? l10n.fileEditorEditFile
              : l10n.fileEditorShowChanges,
          onPressed: _loading || _error != null
              ? null
              : () => setState(() => _showDiff = !_showDiff),
          icon: Icon(
            _showDiff ? Icons.edit_outlined : Icons.difference_outlined,
          ),
        ),
      if (!_isBinary)
        IconButton(
          onPressed: _saving || _loading || _error != null ? null : _save,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            visualDensity: VisualDensity.standard,
          ),
          tooltip: _saving ? l10n.fileEditorSaving : l10n.commonSave,
          icon: _saving
              ? Semantics(
                  liveRegion: true,
                  label: l10n.fileEditorSaving,
                  child: const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _findInFile,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _findInFile,
      },
      child: Focus(autofocus: widget.embedded, child: _buildBody(context)),
    );
    final compactActions = <Widget>[
      HermesAdaptiveMenuButton<int>(
        key: const ValueKey('file-editor-actions'),
        tooltip: l10n.commonMore,
        icon: const Icon(Icons.more_horiz),
        itemBuilder: (_) => [
          for (var i = 0; i < actions.length - (_isBinary ? 0 : 1); i++)
            PopupMenuItem(
              value: i,
              enabled: actions[i].onPressed != null,
              child: Text(actions[i].tooltip!),
            ),
        ],
        onSelected: (index) => actions[index].onPressed?.call(),
      ),
      if (!_isBinary) actions.last,
    ];

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
      canPop: _allowExit || (!_saving && !_dirty),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (discard && mounted) {
          setState(() => _allowExit = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) navigator.pop();
          });
        }
      },
      child: HermesPageScaffold(
        title: titleText,
        titleSemanticsLabel: _dirty
            ? l10n.fileEditorUnsavedTitle(widget.name)
            : widget.name,
        actions: [
          IconButton(
            tooltip: context.l10n.commonSearch,
            onPressed: _loading || _isBinary ? null : _findInFile,
            icon: const Icon(Icons.search),
          ),
          if (MediaQuery.sizeOf(context).width < 600)
            ...compactActions
          else
            ...actions,
        ],
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
    if (_showDiff) return _buildDiff(context);
    final palette = HermesPalette.of(context);
    final codeStyle = HermesType.code.copyWith(
      color: palette.text,
      height: 1.45,
      inherit: false,
      fontFamily: HermesFonts.mono.first,
      textBaseline: TextBaseline.alphabetic,
      letterSpacing: 0,
    );
    final gutterStyle = codeStyle.copyWith(color: palette.text2, height: 1.45);
    final lineMetrics = TextPainter(
      text: TextSpan(text: '0', style: codeStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final lineHeight = lineMetrics.preferredLineHeight;
    lineMetrics.text = TextSpan(
      text: '0' * _lineCount.toString().length,
      style: gutterStyle,
    );
    lineMetrics.layout();
    final gutterWidth = (lineMetrics.width + 16).clamp(44.0, double.infinity);
    lineMetrics.dispose();
    return LayoutBuilder(
      builder: (context, constraints) {
        // EditableText reserves 2px caret width plus a 1px caret gap.
        final sourceWidth = (constraints.maxWidth - gutterWidth - 24 - 3).clamp(
          1.0,
          double.infinity,
        );
        final lines = _ctrl.text.split('\n');
        final extents = <int, double>{};
        final strut = StrutStyle.fromTextStyle(
          codeStyle,
          forceStrutHeight: true,
        );
        double extent(int index) => extents.putIfAbsent(index, () {
          final painter = TextPainter(
            text: TextSpan(text: '${lines[index]}\n', style: codeStyle),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
            strutStyle: strut,
          )..layout(maxWidth: sourceWidth);
          final height = painter.height - lineHeight;
          painter.dispose();
          return height < lineHeight ? lineHeight : height;
        });
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: gutterWidth,
              key: const ValueKey('file-editor-gutter'),
              color: palette.surface,
              child: ListView.builder(
                controller: _gutterScroll,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _lineCount,
                itemExtentBuilder: (index, _) => extent(index),
                itemBuilder: (_, index) => Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: gutterStyle,
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: palette.codeBg,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    key: _sourceFieldKey,
                    controller: _ctrl,
                    scrollController: _editorScroll,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: codeStyle,
                    strutStyle: strut,
                    textDirection: TextDirection.ltr,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: null,
                    onChanged: (t) => setState(() {
                      _lineCount = '\n'.allMatches(t).length + 1;
                    }),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiff(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final rows = <_EditorDiffRow>[];
    var oldLine = 0;
    var newLine = 0;
    for (final op in _diffOps) {
      switch (op.kind) {
        case _DiffOpKind.equal:
          oldLine++;
          newLine++;
          rows.add(_EditorDiffRow('  ', op.text, null, newLine));
        case _DiffOpKind.delete:
          oldLine++;
          rows.add(
            _EditorDiffRow(
              '- ',
              op.text,
              dark ? const Color(0xFF4A2028) : const Color(0xFFFFE8EA),
              oldLine,
            ),
          );
        case _DiffOpKind.insert:
          newLine++;
          rows.add(
            _EditorDiffRow(
              '+ ',
              op.text,
              dark ? const Color(0xFF1E422C) : const Color(0xFFE7F6EA),
              newLine,
            ),
          );
      }
    }
    if (rows.isEmpty) {
      return Center(
        child: Text(
          context.l10n.fileEditorNoChanges,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final row = rows[i];
          return _diffLine(context, row.prefix, row.text, row.color, row.line);
        },
      ),
    );
  }

  Widget _diffLine(
    BuildContext context,
    String prefix,
    String text,
    Color? color,
    int line,
  ) {
    final palette = HermesPalette.of(context);
    final ext = widget.name.contains('.') ? widget.name.split('.').last : '';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highlighted = ext.isEmpty
        ? null
        : CodeHighlighter.instance.highlight(text, ext, dark);
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '$line',
              textAlign: TextAlign.right,
              style: HermesType.code.copyWith(color: palette.text4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            prefix,
            style: HermesType.code.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: highlighted == null
                  ? Text(text, style: HermesType.code)
                  : Text.rich(
                      TextSpan(style: HermesType.code, children: [highlighted]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorDiffRow {
  final String prefix;
  final String text;
  final Color? color;
  final int line;
  const _EditorDiffRow(this.prefix, this.text, this.color, this.line);
}

enum _DiffOpKind { equal, insert, delete }

class _DiffOp {
  final _DiffOpKind kind;
  final String text;
  const _DiffOp(this.kind, this.text);
}

// Above this many (before-lines * after-lines) cells, the O(n*m) LCS table
// below gets too expensive in time/memory for a spot editor on a phone; fall
// back to a naive positional diff rather than hang or OOM on huge files.
const int _maxLineDiffCells = 4000000;

/// Line-based LCS (longest common subsequence) diff. Unlike a naive
/// index-by-index comparison, a single inserted/deleted line does not shift
/// every later line out of alignment and get misreported as changed.
List<_DiffOp> _lineDiff(List<String> before, List<String> after) {
  final n = before.length;
  final m = after.length;
  if (n * m > _maxLineDiffCells) {
    return _naiveLineDiff(before, after);
  }
  // dp[i][j] = length of the LCS of before[i:] and after[j:].
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = before[i] == after[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final ops = <_DiffOp>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (before[i] == after[j]) {
      ops.add(_DiffOp(_DiffOpKind.equal, before[i]));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      ops.add(_DiffOp(_DiffOpKind.delete, before[i]));
      i++;
    } else {
      ops.add(_DiffOp(_DiffOpKind.insert, after[j]));
      j++;
    }
  }
  while (i < n) {
    ops.add(_DiffOp(_DiffOpKind.delete, before[i]));
    i++;
  }
  while (j < m) {
    ops.add(_DiffOp(_DiffOpKind.insert, after[j]));
    j++;
  }
  return ops;
}

/// Fallback for files too large for the LCS table: the previous
/// positional comparison. Used only above [_maxLineDiffCells].
List<_DiffOp> _naiveLineDiff(List<String> before, List<String> after) {
  final max = before.length > after.length ? before.length : after.length;
  final ops = <_DiffOp>[];
  for (var i = 0; i < max; i++) {
    final a = i < before.length ? before[i] : null;
    final b = i < after.length ? after[i] : null;
    if (a == b) {
      ops.add(_DiffOp(_DiffOpKind.equal, a ?? ''));
    } else {
      if (a != null) ops.add(_DiffOp(_DiffOpKind.delete, a));
      if (b != null) ops.add(_DiffOp(_DiffOpKind.insert, b));
    }
  }
  return ops;
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
