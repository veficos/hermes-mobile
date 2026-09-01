/// File browser (spec §58–62, Phase 6 style): directory tree with search +
/// tap-to-preview and tap-to-edit. Write path: `/api/v1/files/write`
/// (spot editor; parent dir must exist).
///
/// Tablet (spec §177): file list + inline preview/editor side-by-side.
/// Tree / list state lives in [FileTreeStore] (shared with the chat sidebar).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clipboard.dart';
import '../core/fs_download.dart';
import '../core/connection_reload_mixin.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/file_tree_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import 'file_editor_screen.dart';
import 'git_screen.dart';
import 'new_session_screen.dart';

class FilesScreen extends StatefulWidget {
  /// Jump straight to this directory (e.g. the active session's workspace)
  /// instead of the server's default cwd. Falls back to the usual
  /// [FileTreeStore.init] default when omitted or empty.
  final String? initialPath;

  /// When true, this screen is a directory picker: browsing behaves
  /// normally, but the title and a persistent bottom bar let the caller
  /// confirm the currently-browsed directory, which is returned via
  /// `Navigator.pop(path)` — used by the chat workspace picker so it can
  /// jump straight into the real file manager instead of the flat
  /// candidate-list sheet.
  final bool pickMode;

  const FilesScreen({super.key, this.initialPath, this.pickMode = false});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

/// Last path segment, for a short human-readable label (`/a/b/c` → `c`).
String _dirBaseName(String path) {
  final parts = path
      .split(RegExp(r'[\\/]'))
      .where((s) => s.isNotEmpty)
      .toList();
  return parts.isEmpty ? path : parts.last;
}

class _FilesScreenState extends State<FilesScreen>
    with ConnectionReloadMixin<FilesScreen> {
  static const _largeDownloadBytes = 32 * 1024 * 1024;

  late final FileTreeStore _store;
  final TextEditingController _searchCtrl = TextEditingController();
  var _downloading = false;
  int _downloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final connection = context.read<ConnectionStore>();
    _store = FileTreeStore(() => connection.api);
    _init();
  }

  Future<void> _init() async {
    await _store.init();
    final path = widget.initialPath;
    if (path != null && path.isNotEmpty && mounted) {
      await _store.navigateTo(path, promoteRoot: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  Future<void> _reloadForConnection() async {
    if (!mounted) return;
    _downloadGeneration++;
    setState(() => _downloading = false);
    await _store.resetForConnection();
    final path = widget.initialPath;
    if (path != null && path.isNotEmpty && mounted) {
      await _store.navigateTo(path, promoteRoot: true);
    }
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _searchCtrl.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<bool> _confirmLargeEdit(FsEntry entry) async {
    final size = entry.size;
    if (size == null || size <= _largeDownloadBytes) return true;
    final mb = (size / (1024 * 1024)).toStringAsFixed(1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesLargeEditQuestion),
        content: Text(context.l10n.filesLargeEditDescription(entry.name, mb)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.filesContinueEdit),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _open(FsEntry entry) async {
    if (entry.isDirectory) {
      await _store.navigateTo(entry.path, promoteRoot: _store.cwd.isEmpty);
      return;
    }
    if (!await _confirmLargeEdit(entry) || !mounted) return;
    final isTablet = MediaQuery.sizeOf(context).width >= 840;
    if (isTablet) {
      _store.selectPreview(entry);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FileEditorScreen(
          key: ValueKey(entry.path),
          path: entry.path,
          name: entry.name,
        ),
      ),
    );
    if (mounted) await _store.refreshCurrent();
  }

  Future<void> _revealEntry(FsEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _store.revealInExplorer(entry);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.filesRevealFailed('$e'))),
        );
      }
    }
  }

  Future<bool> _confirmLargeDownload(FsEntry entry) async {
    final size = entry.size;
    if (size == null || size <= _largeDownloadBytes) return true;
    final mb = (size / (1024 * 1024)).toStringAsFixed(1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesLargeDownloadQuestion),
        content: Text(
          context.l10n.filesLargeDownloadDescription(entry.name, mb),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.filesContinueDownload),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _confirmFolderDownload(FsEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesFolderDownloadQuestion),
        content: Text(context.l10n.filesFolderDownloadDescription(entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.filesArchiveDownload),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _downloadFileName(FsEntry entry) =>
      entry.isDirectory ? '${entry.name}.zip' : entry.name;

  Future<void> _downloadEntry(FsEntry entry) async {
    if (_downloading) return;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (api == null) return;
    if (entry.isDirectory) {
      if (!await _confirmFolderDownload(entry)) return;
    } else if (!await _confirmLargeDownload(entry)) {
      return;
    }
    if (!mounted) return;
    if (!identical(connection.api, api)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backendDisconnected)));
      return;
    }
    final generation = _downloadGeneration;
    setState(() => _downloading = true);
    try {
      final savedPath = await downloadServerFileToDevice(
        api: api,
        remotePath: entry.path,
        fileName: _downloadFileName(entry),
      );
      if (!mounted ||
          generation != _downloadGeneration ||
          !identical(connection.api, api)) {
        return;
      }
      await copyTextOrNotify(
        context,
        savedPath,
        successMessage: l10n.filesDownloadedPath(savedPath),
      );
    } catch (e) {
      if (mounted &&
          generation == _downloadGeneration &&
          identical(connection.api, api)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.filesDownloadFailed('$e'))),
        );
      }
    } finally {
      if (mounted && generation == _downloadGeneration) {
        setState(() => _downloading = false);
      }
    }
  }

  Future<void> _downloadSelection() async {
    final paths = _store.selection.toList(growable: false);
    final entries = <FsEntry>[];
    for (final path in paths) {
      final entry = _store.entryForPath(path);
      if (entry != null) entries.add(entry);
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.filesSelectDownloadItem)),
      );
      return;
    }
    if (_downloading) return;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    final messenger = ScaffoldMessenger.of(context);
    if (api == null) return;
    final generation = _downloadGeneration;
    setState(() => _downloading = true);
    var okCount = 0;
    var failedCount = 0;
    var skippedCount = 0;
    try {
      for (final entry in entries) {
        if (generation != _downloadGeneration ||
            !identical(connection.api, api)) {
          return;
        }
        if (entry.isDirectory) {
          if (!await _confirmFolderDownload(entry)) {
            skippedCount += 1;
            continue;
          }
        } else if (!await _confirmLargeDownload(entry)) {
          skippedCount += 1;
          continue;
        }
        try {
          if (!identical(connection.api, api)) return;
          await downloadServerFileToDevice(
            api: api,
            remotePath: entry.path,
            fileName: _downloadFileName(entry),
          );
          okCount += 1;
        } catch (_) {
          failedCount += 1;
        }
      }
      if (!mounted ||
          generation != _downloadGeneration ||
          !identical(connection.api, api)) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.filesDownloadSummary(
              okCount,
              failedCount,
              skippedCount,
            ),
          ),
        ),
      );
    } finally {
      if (mounted && generation == _downloadGeneration) {
        setState(() => _downloading = false);
      }
    }
  }

  void _showEntryMenu(FsEntry entry) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HermesType.onSurface(
                    HermesType.headline,
                    Theme.of(context),
                  ),
                ),
              ),
            ),
            if (_store.canRevealEntries)
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(context.l10n.filesRevealOnServer),
                subtitle: Text(context.l10n.filesRevealOnServerDescription),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _revealEntry(entry);
                },
              ),
            if (_store.canRevealEntries) const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.l10n.filesDetails),
              onTap: () {
                Navigator.of(ctx).pop();
                _showEntryInfo(entry);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.download_outlined,
                color: _downloading ? Theme.of(context).disabledColor : null,
              ),
              title: Text(
                _downloading
                    ? context.l10n.filesDownloading
                    : entry.isDirectory
                    ? context.l10n.filesDownloadFolderZip
                    : context.l10n.filesDownloadToDevice,
              ),
              onTap: _downloading
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _downloadEntry(entry);
                    },
            ),
            if (_store.canCopyEntries)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(context.l10n.filesCopyToClipboard),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _store.setClipboard([entry.path], cut: false);
                  messenger.showSnackBar(
                    SnackBar(content: Text(context.l10n.filesCopiedPasteHint)),
                  );
                },
              ),
            if (_store.canMoveEntries)
              ListTile(
                leading: const Icon(Icons.content_cut_outlined),
                title: Text(context.l10n.filesCutToClipboard),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _store.setClipboard([entry.path], cut: true);
                  messenger.showSnackBar(
                    SnackBar(content: Text(context.l10n.filesCutPasteHint)),
                  );
                },
              ),
            if (_store.canMoveEntries)
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(context.l10n.filesRename),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _renameEntry(entry);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: HermesSemantic.red,
              ),
              title: Text(context.l10n.commonDelete),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteEntry(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(context.l10n.filesCopyPath),
              onTap: () {
                Navigator.of(ctx).pop();
                copyTextOrNotify(
                  context,
                  entry.path,
                  successMessage: context.l10n.filesPathCopied,
                );
              },
            ),
            if (_store.cwd.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.short_text),
                title: Text(context.l10n.filesCopyRelativePath),
                onTap: () {
                  Navigator.of(ctx).pop();
                  copyTextOrNotify(
                    context,
                    _store.relativePath(entry.path),
                    successMessage: context.l10n.filesRelativePathCopied,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEntryInfo(FsEntry entry) {
    final l10n = context.l10n;
    final rows = <String>[
      l10n.filesInfoPath(entry.path),
      l10n.filesInfoType(
        entry.isDirectory
            ? l10n.commonFolder
            : entry.isLink
            ? l10n.filesLink
            : l10n.commonFile,
      ),
      if (entry.size != null) l10n.filesInfoSize(entry.size!),
      if (entry.modifiedAt != null)
        l10n.filesInfoModified(entry.modifiedAt!.toLocal().toString()),
      if (entry.readable != null)
        l10n.filesInfoReadable(entry.readable! ? l10n.agentYes : l10n.agentNo),
      if (entry.writable != null)
        l10n.filesInfoWritable(entry.writable! ? l10n.agentYes : l10n.agentNo),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: SelectableText(row),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pasteClipboard() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_store.hasClipboard) return;
    final wasCut = _store.clipboardIsCut;
    final count = _store.clipboardPaths?.length ?? 0;
    try {
      await _store.pasteClipboard();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              wasCut
                  ? context.l10n.filesMovedCount(count)
                  : context.l10n.filesCopiedCount(count),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.filesPasteFailed('$e'))),
        );
      }
    }
  }

  Future<void> _deleteSelection() async {
    final messenger = ScaffoldMessenger.of(context);
    final count = _store.selection.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesConfirmDelete),
        content: Text(context.l10n.filesDeleteSelectedDescription(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HermesSemantic.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.deleteSelection();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.filesDeleteFailed('$e'))),
        );
      }
    }
  }

  Future<void> _newFile() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_store.cwd.isEmpty) return;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesNewFile),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.filesFileName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(context.l10n.commonCreate),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (name == null || name.isEmpty) return;
    try {
      await _store.createFile(name);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.filesCreateFileFailed('$e'))),
        );
      }
    }
  }

  void _sendSelectionToNewSession() {
    final paths = _store.selection.isEmpty
        ? <String>[_store.cwd]
        : _store.selection.toList(growable: false);
    if (paths.isEmpty || paths.every((path) => path.isEmpty)) return;
    final references = paths
        .where((path) => path.isNotEmpty)
        .map((path) => '@$path')
        .join('\n');
    final cwd = _store.cwd.isNotEmpty ? _store.cwd : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewSessionScreen(
          initialCwd: cwd,
          initialDraftText: context.l10n.filesNewSessionPrompt(references),
        ),
      ),
    );
  }

  void _openGitForCurrentDirectory() {
    if (_store.cwd.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GitScreen(initialPath: _store.cwd)),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(context.l10n.filesNewFile),
              onTap: () {
                Navigator.of(ctx).pop();
                _newFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(context.l10n.filesNewFolder),
              onTap: () {
                Navigator.of(ctx).pop();
                _newFolder();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameEntry(FsEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController(text: entry.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesRename),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.filesNewName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(context.l10n.filesRename),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (newName == null || newName.isEmpty || newName == entry.name) return;
    try {
      await _store.renameEntry(entry, newName);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.filesRenameFailed('$e'))),
        );
      }
    }
  }

  Future<void> _deleteEntry(FsEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesConfirmDelete),
        content: Text(
          entry.isDirectory
              ? context.l10n.filesDeleteFolderDescription(entry.name)
              : context.l10n.filesDeleteFileDescription(entry.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HermesSemantic.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.deleteEntry(entry);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.filesDeleteFailed('$e'))),
        );
      }
    }
  }

  Future<void> _newFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_store.cwd.isEmpty) return;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesNewFolder),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.filesFolderName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(context.l10n.commonCreate),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (name == null || name.isEmpty) return;
    try {
      await _store.createDirectory(name);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.filesCreateFolderFailed('$e'))),
        );
      }
    }
  }

  /// List-mode back should climb directories until the volume picker, then exit.
  bool _listModeCanClimb(FileTreeStore store) {
    return !store.treeMode && store.cwd.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 840;
    return ChangeNotifierProvider.value(
      value: _store,
      child: Consumer<FileTreeStore>(
        builder: (context, store, _) {
          final climb = _listModeCanClimb(store);
          return PopScope(
            canPop: !climb,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_listModeCanClimb(store)) store.goUp();
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  widget.pickMode
                      ? context.l10n.filesSelectWorkspaceDirectory
                      : store.selecting
                      ? context.l10n.filesSelectedCount(store.selection.length)
                      : context.l10n.featureFiles,
                ),
                actions: [
                  IconButton(
                    tooltip: store.treeMode
                        ? context.l10n.filesSwitchToDirectoryBrowser
                        : context.l10n.filesSwitchToProjectTree,
                    onPressed: store.toggleTreeMode,
                    icon: Icon(
                      store.treeMode
                          ? Icons.folder_outlined
                          : Icons.account_tree_outlined,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: context.l10n.commonMore,
                    onSelected: (action) {
                      switch (action) {
                        case 'newFile':
                          _showCreateMenu();
                        case 'refresh':
                          store.refreshCurrent();
                        case 'git':
                          _openGitForCurrentDirectory();
                        case 'newSession':
                          _sendSelectionToNewSession();
                        case 'download':
                          _downloadSelection();
                        case 'copy':
                          store.copySelectionToClipboard(cut: false);
                        case 'cut':
                          store.copySelectionToClipboard(cut: true);
                        case 'paste':
                          _pasteClipboard();
                        case 'delete':
                          _deleteSelection();
                        case 'clearSelection':
                          store.clearSelection();
                      }
                    },
                    itemBuilder: (_) => [
                      if (store.cwd.isNotEmpty)
                        PopupMenuItem(
                          value: 'newFile',
                          child: ListTile(
                            leading: const Icon(Icons.add_circle_outline),
                            title: Text(context.l10n.commonNew),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      PopupMenuItem(
                        value: 'refresh',
                        child: ListTile(
                          leading: const Icon(Icons.refresh),
                          title: Text(context.l10n.commonRefresh),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (store.cwd.isNotEmpty) ...[
                        PopupMenuItem(
                          value: 'git',
                          child: ListTile(
                            leading: const Icon(Icons.account_tree_outlined),
                            title: Text(context.l10n.filesOpenInGit),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'newSession',
                          child: ListTile(
                            leading: const Icon(Icons.add_comment_outlined),
                            title: Text(
                              store.selection.isEmpty
                                  ? context.l10n.filesNewSessionForDirectory
                                  : context.l10n.filesSendSelectionToNewSession,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      if (store.selecting) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'download',
                          enabled: !_downloading,
                          child: ListTile(
                            leading: const Icon(Icons.download_outlined),
                            title: Text(
                              _downloading
                                  ? context.l10n.filesDownloading
                                  : context.l10n.filesDownloadSelected,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (store.canCopyEntries)
                          PopupMenuItem(
                            value: 'copy',
                            child: ListTile(
                              leading: const Icon(Icons.copy_outlined),
                              title: Text(context.l10n.filesCopySelected),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (store.canMoveEntries)
                          PopupMenuItem(
                            value: 'cut',
                            child: ListTile(
                              leading: const Icon(Icons.content_cut_outlined),
                              title: Text(context.l10n.filesCutSelected),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: const Icon(Icons.delete_outline),
                            title: Text(context.l10n.filesDeleteSelected),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'clearSelection',
                          child: ListTile(
                            leading: const Icon(Icons.close),
                            title: Text(context.l10n.filesClearSelection),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      if (store.canPasteClipboard)
                        PopupMenuItem(
                          value: 'paste',
                          child: ListTile(
                            leading: Icon(
                              store.clipboardIsCut
                                  ? Icons.drive_file_move_outlined
                                  : Icons.content_paste_outlined,
                            ),
                            title: Text(
                              store.clipboardIsCut
                                  ? context.l10n.filesMoveHere
                                  : context.l10n.filesCopyHere,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              body: isTablet
                  ? _buildTablet(context, store)
                  : _buildPhone(context, store),
              bottomNavigationBar: store.selecting
                  ? _SelectionBar(
                      count: store.selection.length,
                      hasClipboard: store.hasClipboard,
                      clipboardIsCut: store.clipboardIsCut,
                      downloading: _downloading,
                      onDownload: _downloadSelection,
                      onCopy: store.canCopyEntries
                          ? () => store.copySelectionToClipboard(cut: false)
                          : null,
                      onCut: store.canMoveEntries
                          ? () => store.copySelectionToClipboard(cut: true)
                          : null,
                      onPaste: store.canPasteClipboard ? _pasteClipboard : null,
                      onDelete: _deleteSelection,
                      onClear: store.clearSelection,
                    )
                  : widget.pickMode
                  ? SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: FilledButton.icon(
                          onPressed: store.cwd.isEmpty
                              ? null
                              : () => Navigator.of(context).pop(store.cwd),
                          icon: const Icon(Icons.check),
                          label: Text(
                            store.cwd.isEmpty
                                ? context.l10n.filesSelectCurrentDirectory
                                : context.l10n.filesUseAsWorkspace(
                                    _dirBaseName(store.cwd),
                                  ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhone(BuildContext context, FileTreeStore store) {
    return Column(
      children: [
        _breadcrumb(store),
        _searchBar(store),
        Expanded(
          child: RefreshIndicator(
            onRefresh: store.refreshCurrent,
            child: _buildBody(context, store),
          ),
        ),
      ],
    );
  }

  Widget _buildTablet(BuildContext context, FileTreeStore store) {
    final selected = store.selectedEntry;
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: Column(
            children: [
              _breadcrumb(store),
              _searchBar(store),
              Expanded(child: _buildBody(context, store, selectMode: true)),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? HermesEmptyState(
                  icon: Icons.preview_outlined,
                  title: context.l10n.filesSelectPreview,
                  description: context.l10n.filesSelectPreviewDescription,
                )
              : FileEditorScreen(
                  key: ValueKey(selected.path),
                  path: selected.path,
                  name: selected.name,
                  embedded: true,
                ),
        ),
      ],
    );
  }

  Widget _breadcrumb(FileTreeStore store) {
    final segments = store.breadcrumbSegments();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: segments.length,
        separatorBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        itemBuilder: (context, index) {
          final seg = segments[index];
          final isLast = index == segments.length - 1;
          return TextButton(
            onPressed: isLast
                ? null
                : () {
                    if (seg.path.isEmpty) {
                      store.listDriveRoots();
                    } else {
                      store.navigateTo(seg.path);
                    }
                  },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              seg.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _searchBar(FileTreeStore store) => Padding(
    padding: const EdgeInsets.fromLTRB(
      HermesSpacing.md,
      HermesSpacing.xs,
      HermesSpacing.md,
      0,
    ),
    child: TextField(
      controller: _searchCtrl,
      onChanged: store.setQuery,
      decoration: InputDecoration(
        hintText: store.treeMode
            ? context.l10n.filesFilterProjectTree
            : context.l10n.filesSearchDirectory,
        prefixIcon: const Icon(Icons.search),
      ),
    ),
  );

  Widget _refreshableFill(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: child)],
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    FileTreeStore store, {
    bool selectMode = false,
  }) {
    if (store.error != null && store.currentEntries == null) {
      return _refreshableFill(
        HermesErrorState(description: store.error, onRetry: store.init),
      );
    }
    if (store.bootstrapping || store.currentEntries == null) {
      return _refreshableFill(
        HermesLoadingState(label: context.l10n.filesLoadingDirectory),
      );
    }
    if (store.treeMode && store.root.isNotEmpty) {
      return _buildTreeBody(context, store, selectMode: selectMode);
    }
    final filtered = store.visibleListRows();
    if (filtered.isEmpty) {
      return _refreshableFill(
        HermesEmptyState(
          icon: Icons.search_off,
          title: context.l10n.filesNoMatches,
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final e = filtered[i];
        final isSelected = selectMode && store.selectedPath == e.path;
        final first = i == 0;
        final last = i == filtered.length - 1;
        final palette = HermesPalette.of(context);
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(first ? 15 : 0),
              bottom: Radius.circular(last ? 15 : 0),
            ),
            border: Border(
              left: BorderSide(color: palette.border),
              right: BorderSide(color: palette.border),
              top: first ? BorderSide(color: palette.border) : BorderSide.none,
              bottom: BorderSide(color: palette.border),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              dense: true,
              selected: isSelected,
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              leading: store.selecting
                  ? Checkbox(
                      value: store.selection.contains(e.path),
                      onChanged: (_) => store.toggleSelect(e.path),
                    )
                  : Icon(
                      e.isDirectory
                          ? Icons.folder_outlined
                          : e.isLink
                          ? Icons.link
                          : Icons.insert_drive_file_outlined,
                      color: e.isDirectory
                          ? HermesSemantic.orange
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: () {
                final parts = <String>[
                  if (e.size != null && !e.isDirectory) _formatSize(e.size!),
                  if (e.modifiedAt != null) _formatMtime(e.modifiedAt!),
                ];
                if (parts.isEmpty) return null;
                return Text(
                  parts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                );
              }(),
              trailing: store.selecting
                  ? null
                  : IconButton(
                      tooltip: context.l10n.filesActions,
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showEntryMenu(e),
                    ),
              onTap: () {
                if (store.selecting) {
                  store.toggleSelect(e.path);
                } else {
                  _open(e);
                }
              },
              onLongPress: () => store.addToSelection(e.path),
            ),
          ),
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatMtime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi';
  }

  Widget _buildTreeBody(
    BuildContext context,
    FileTreeStore store, {
    required bool selectMode,
  }) {
    final rows = store.visibleTreeRows();
    if (rows.isEmpty) {
      return _refreshableFill(
        HermesEmptyState(
          icon: Icons.search_off,
          title: context.l10n.filesNoMatches,
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.loading) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24.0 + row.depth * 20,
              top: 8,
              bottom: 8,
            ),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(context.l10n.commonLoading),
              ],
            ),
          );
        }
        if (row.error case final error?) {
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(
              left: 24.0 + row.depth * 20,
              right: 12,
            ),
            leading: const Icon(Icons.warning_amber_rounded, size: 18),
            title: Text(context.l10n.filesUnableToRead),
            subtitle: Text(error, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: row.errorPath == null
                ? null
                : TextButton(
                    onPressed: () => store.retryDirectory(row.errorPath!),
                    child: Text(context.l10n.commonRetry),
                  ),
          );
        }
        final entry = row.entry!;
        final expanded = store.isExpanded(entry.path);
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.only(left: 8.0 + row.depth * 20, right: 4),
          selected: selectMode && store.selectedPath == entry.path,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          leading: store.selecting
              ? Checkbox(
                  value: store.selection.contains(entry.path),
                  onChanged: (_) => store.toggleSelect(entry.path),
                )
              : Icon(
                  entry.isDirectory
                      ? expanded
                            ? Icons.folder_open_outlined
                            : Icons.folder_outlined
                      : entry.isLink
                      ? Icons.link
                      : Icons.insert_drive_file_outlined,
                  color: entry.isDirectory
                      ? HermesSemantic.orange
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: store.selecting
              ? null
              : IconButton(
                  tooltip: context.l10n.filesActions,
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showEntryMenu(entry),
                ),
          onTap: () {
            if (store.selecting) {
              store.toggleSelect(entry.path);
            } else if (entry.isDirectory) {
              store.toggleDirectory(entry);
            } else {
              _open(entry);
            }
          },
          onLongPress: () => store.addToSelection(entry.path),
        );
      },
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final bool hasClipboard;
  final bool clipboardIsCut;
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback? onCopy;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const _SelectionBar({
    required this.count,
    required this.hasClipboard,
    required this.clipboardIsCut,
    required this.downloading,
    required this.onDownload,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: onClear,
                  child: Text(context.l10n.filesSelectedCount(count)),
                ),
                Semantics(
                  label: downloading
                      ? context.l10n.filesDownloading
                      : context.l10n.filesDownload,
                  button: true,
                  child: IconButton(
                    tooltip: downloading
                        ? context.l10n.filesDownloading
                        : context.l10n.filesDownload,
                    onPressed: downloading ? null : onDownload,
                    icon: downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.profilesCopy,
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: context.l10n.filesCut,
                  onPressed: onCut,
                  icon: const Icon(Icons.content_cut_outlined),
                ),
                IconButton(
                  tooltip: clipboardIsCut
                      ? context.l10n.filesMoveHere
                      : context.l10n.terminalPaste,
                  onPressed: onPaste,
                  icon: Icon(
                    clipboardIsCut
                        ? Icons.drive_file_move_outlined
                        : Icons.content_paste_outlined,
                    color: hasClipboard ? null : palette.text3,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.commonDelete,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: HermesSemantic.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
