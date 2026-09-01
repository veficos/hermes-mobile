/// FileTreePanel: 右侧栏文件树面板
///
/// 对应 Desktop 版 right-sidebar/files/ 的文件浏览器面板。
/// 适配窄面板（360px），提供树状文件浏览、搜索、基本文件操作。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/clipboard.dart';
import '../../core/connection_reload_mixin.dart';
import '../../core/fs_download.dart';
import '../../core/models.dart';
import '../../core/stores/connection_store.dart';
import '../../core/stores/file_tree_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_states.dart';

class FileTreePanel extends StatefulWidget {
  /// 附加文件到 composer 的回调（Shift+Click 或菜单选择）
  final void Function(FsEntry entry)? onAttachFile;

  /// 打开文件预览的回调（双击文件）
  final void Function(FsEntry entry)? onPreviewFile;

  const FileTreePanel({super.key, this.onAttachFile, this.onPreviewFile});

  @override
  State<FileTreePanel> createState() => _FileTreePanelState();
}

class _FileTreePanelState extends State<FileTreePanel>
    with ConnectionReloadMixin<FileTreePanel> {
  late final FileTreeStore _store;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Capture the ConnectionStore instance (not a frozen api) so reconnects
    // pick up the live ApiClient.
    final connection = context.read<ConnectionStore>();
    _store = FileTreeStore(() => connection.api);
    _store.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(
      context.read<ConnectionStore>(),
      _store.resetForConnection,
    );
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _store,
      child: Consumer<FileTreeStore>(
        builder: (context, store, _) {
          return Column(
            children: [
              _buildHeader(context, store),
              _buildSearchBar(context, store),
              Expanded(child: _buildBody(context, store)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FileTreeStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Text(
            context.l10n.workspacePaneFiles,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: store.treeMode
                ? context.l10n.fileTreeListView
                : context.l10n.fileTreeTreeView,
            icon: Icon(
              store.treeMode ? Icons.view_list : Icons.account_tree_outlined,
              size: 18,
            ),
            onPressed: store.toggleTreeMode,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: context.l10n.filesNewFolder,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            onPressed: () => _showNewFolderDialog(context, store),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: context.l10n.commonRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: store.refresh,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, FileTreeStore store) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            hintText: context.l10n.filesSearchDirectory,
            prefixIcon: const Icon(Icons.search, size: 16),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: store.setQuery,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FileTreeStore store) {
    if (store.error != null) {
      return HermesErrorState(
        title: context.l10n.chatLoadFailed,
        description: store.error!,
        onRetry: store.refresh,
      );
    }
    if (store.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 12),
            Text(
              context.l10n.filesLoadingDirectory,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (store.treeMode) {
      return _buildTreeView(context, store);
    }
    return _buildListView(context, store);
  }

  // ── 树视图 ──
  Widget _buildTreeView(BuildContext context, FileTreeStore store) {
    final rows = store.visibleTreeRows();
    if (rows.isEmpty && store.query.isNotEmpty) {
      return HermesEmptyState(
        icon: Icons.search_off,
        title: context.l10n.filesNoMatches,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.loading) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20.0 + row.depth * 18.0,
              top: 6,
              bottom: 6,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 6),
                Text(
                  context.l10n.commonLoading,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        }
        if (row.error case final error?) {
          return Padding(
            padding: EdgeInsets.only(left: 20.0 + row.depth * 18.0),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(right: 8),
              leading: const Icon(Icons.warning_amber_rounded, size: 16),
              title: Text(
                context.l10n.filesUnableToRead,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Text(
                error,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: row.errorPath == null
                  ? null
                  : TextButton(
                      onPressed: () => store.retryDirectory(row.errorPath!),
                      child: Text(
                        context.l10n.commonRetry,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
            ),
          );
        }
        final entry = row.entry!;
        final expanded = store.isExpanded(entry.path);
        final isSelected = store.selectedPath == entry.path;
        return Material(
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          child: InkWell(
            onTap: () => _onTapEntry(store, entry),
            onLongPress: () => _showEntryMenu(context, store, entry),
            child: Padding(
              padding: EdgeInsets.only(left: 4.0 + row.depth * 18.0, right: 4),
              child: Row(
                children: [
                  // 展开箭头 / 占位
                  SizedBox(
                    width: 18,
                    child: entry.isDirectory
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              expanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 16,
                            ),
                            onPressed: () => store.toggleDirectory(entry),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Icon(
                    entry.isDirectory
                        ? expanded
                              ? Icons.folder_open_outlined
                              : Icons.folder_outlined
                        : entry.isLink
                        ? Icons.link
                        : Icons.insert_drive_file_outlined,
                    size: 16,
                    color: entry.isDirectory
                        ? HermesSemantic.orange
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonMore,
                    icon: const Icon(Icons.more_vert, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showEntryMenu(context, store, entry),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 列表视图 ──
  Widget _buildListView(BuildContext context, FileTreeStore store) {
    final entries = store.visibleListRows();
    if (entries.isEmpty && store.query.isNotEmpty) {
      return HermesEmptyState(
        icon: Icons.search_off,
        title: context.l10n.filesNoMatches,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = store.selectedPath == entry.path;
        return Material(
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          child: InkWell(
            onTap: () => _onTapEntry(store, entry),
            onLongPress: () => _showEntryMenu(context, store, entry),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    entry.isDirectory
                        ? Icons.folder_outlined
                        : entry.isLink
                        ? Icons.link
                        : Icons.insert_drive_file_outlined,
                    size: 16,
                    color: entry.isDirectory
                        ? HermesSemantic.orange
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (entry.size != null && !entry.isDirectory)
                    Text(
                      _formatSize(entry.size!),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 交互 ──
  void _onTapEntry(FileTreeStore store, FsEntry entry) {
    if (entry.isDirectory) {
      store.toggleDirectory(entry);
    } else {
      store.openEntry(entry);
      widget.onPreviewFile?.call(entry);
    }
  }

  void _showEntryMenu(
    BuildContext context,
    FileTreeStore store,
    FsEntry entry,
  ) {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final expectedApi = connection.api;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HermesRadius.sheet),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(context.l10n.fileTreeAttachToChat),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onAttachFile?.call(entry);
              },
            ),
            if (!entry.isDirectory)
              ListTile(
                leading: const Icon(Icons.preview),
                title: Text(context.l10n.commonOpen),
                onTap: () {
                  Navigator.of(ctx).pop();
                  store.openEntry(entry);
                  widget.onPreviewFile?.call(entry);
                },
              ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(
                entry.isDirectory
                    ? context.l10n.filesDownloadFolderZip
                    : context.l10n.filesDownloadToDevice,
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _downloadEntry(context, entry);
              },
            ),
            if (store.canRevealEntries)
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(context.l10n.filesRevealOnServer),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    if (expectedApi == null) {
                      throw StateError(l10n.backendDisconnected);
                    }
                    requireActiveApi(context, connection, expectedApi);
                    await store.revealInExplorer(entry);
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.filesRevealFailed('$e'))),
                      );
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.content_copy),
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
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline, color: HermesSemantic.red),
              title: Text(
                context.l10n.commonDelete,
                style: TextStyle(color: HermesSemantic.red),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final messenger = ScaffoldMessenger.of(this.context);
                final confirmed = await _confirmDelete(this.context, entry);
                if (!mounted) return;
                if (confirmed == true) {
                  try {
                    if (expectedApi == null) {
                      throw StateError(l10n.backendDisconnected);
                    }
                    requireActiveApi(this.context, connection, expectedApi);
                    await store.deleteEntry(entry);
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.filesDeleteFailed('$e'))),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmFolderDownload(
    BuildContext context,
    FsEntry entry,
  ) async {
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

  Future<void> _downloadEntry(BuildContext context, FsEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final api = context.read<ConnectionStore>().api;
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatServerNotConnected)),
      );
      return;
    }
    if (entry.isDirectory && !await _confirmFolderDownload(context, entry)) {
      return;
    }
    if (!context.mounted) return;
    try {
      requireActiveApi(context, context.read<ConnectionStore>(), api);
      final savedPath = await downloadServerFileToDevice(
        api: api,
        remotePath: entry.path,
        fileName: entry.isDirectory ? '${entry.name}.zip' : entry.name,
      );
      if (!context.mounted) return;
      requireActiveApi(context, context.read<ConnectionStore>(), api);
      await copyTextOrNotify(
        context,
        savedPath,
        successMessage: l10n.filesDownloadedPath(savedPath),
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.filesDownloadFailed('$e'))),
        );
      }
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, FsEntry entry) {
    return showDialog<bool>(
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
  }

  Future<void> _showNewFolderDialog(
    BuildContext context,
    FileTreeStore store,
  ) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.filesNewFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.filesFolderName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (!mounted || !context.mounted) return;
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        requireActiveApi(context, connection, api);
        await store.createDirectory(controller.text.trim());
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.filesCreateFolderFailed('$e'))),
          );
        }
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
