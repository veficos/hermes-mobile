/// FileTreeStore: 文件树状态管理
///
/// 从 FilesScreen 提取的状态逻辑，支持在右侧栏面板与主文件页复用。
/// 对应 Desktop 版 right-sidebar/files/use-project-tree.ts 的功能。
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/runtime_l10n.dart';

import '../api_client.dart';
import '../models.dart';
import '../server_path.dart';

class FileTreeStore extends ChangeNotifier {
  final ApiClient? Function() _apiProvider;

  FileTreeStore(this._apiProvider);

  ApiClient _requireApi() {
    final api = _apiProvider();
    if (api != null) return api;
    throw StateError(runtimeL10n.backendDisconnected);
  }

  bool _isCurrent(ApiClient api, int generation) =>
      generation == _generation && identical(api, _apiProvider());

  // ── 路径状态 ──
  String _cwd = '';
  String _root = '';
  String get cwd => _cwd;
  String get root => _root;

  // ── 数据缓存 ──
  final Map<String, List<FsEntry>> _treeChildren = {};
  final Set<String> _expandedDirs = {};
  final Set<String> _loadingDirs = {};
  final Map<String, String> _treeErrors = {};

  // ── UI 状态 ──
  String? _error;
  String _query = '';
  String? _selectedPath;
  bool _treeMode = false;
  bool _bootstrapping = true;
  int _generation = 0;
  final Set<String> _selection = <String>{};
  List<String>? _clipboardPaths;
  bool _clipboardIsCut = false;

  String? get error => _error;
  String get query => _query;
  String? get selectedPath => _selectedPath;
  bool get treeMode => _treeMode;
  bool get bootstrapping => _bootstrapping;
  bool get isEmpty => _treeChildren.isEmpty && _error == null;
  Set<String> get selection => Set.unmodifiable(_selection);
  bool get selecting => _selection.isNotEmpty;
  List<String>? get clipboardPaths => _clipboardPaths;
  bool get clipboardIsCut => _clipboardIsCut;
  bool get hasClipboard => _clipboardPaths?.isNotEmpty == true;
  bool get canMoveEntries => _apiProvider()?.capabilities.fileMove == true;
  bool get canCopyEntries => _apiProvider()?.capabilities.fileCopy == true;
  bool get canRevealEntries => _apiProvider()?.capabilities.fileReveal == true;
  bool get canPasteClipboard =>
      hasClipboard && (_clipboardIsCut ? canMoveEntries : canCopyEntries);

  /// List-mode / drive-picker entries for the current cwd (null while loading).
  List<FsEntry>? get currentEntries {
    if (_bootstrapping) return null;
    if (_error != null && !_treeChildren.containsKey(_cwd)) {
      return const [];
    }
    if (_loadingDirs.contains(_cwd) && !_treeChildren.containsKey(_cwd)) {
      return null;
    }
    return _treeChildren[_cwd];
  }

  FsEntry? get selectedEntry {
    final path = _selectedPath;
    if (path == null) return null;
    return entryForPath(path) ??
        FsEntry(
          name: ServerPath.basename(path),
          path: path,
          isDirectory: false,
        );
  }

  // ── 持久化 ──
  static const _kExpandedKey = 'hm_file_tree_expanded';
  static const _kTreeModeKey = 'hm_file_tree_mode';

  Future<void> loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final expanded = prefs.getStringList(_kExpandedKey);
    if (expanded != null) {
      _expandedDirs.addAll(expanded);
    }
    _treeMode = prefs.getBool(_kTreeModeKey) ?? false;
  }

  Future<void> _persistExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kExpandedKey, _expandedDirs.toList());
  }

  Future<void> _persistTreeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTreeModeKey, _treeMode);
  }

  // ── 初始化 ──
  Future<void> init() async {
    final generation = ++_generation;
    final api = _apiProvider();
    if (api == null) {
      _bootstrapping = false;
      _error = runtimeL10n.voiceServerDisconnected;
      notifyListeners();
      return;
    }
    await loadPersistedState();
    try {
      final cwd = await api.fsDefaultCwd();
      if (generation != _generation || !identical(api, _apiProvider())) return;
      _cwd = cwd;
      _root = cwd;
      await _loadDirectory(cwd, generation: generation);
    } catch (e) {
      if (generation != _generation || !identical(api, _apiProvider())) return;
      _error = '$e';
    } finally {
      if (generation == _generation && identical(api, _apiProvider())) {
        _bootstrapping = false;
        notifyListeners();
      }
    }
  }

  Future<void> resetForConnection() async {
    _generation++;
    _cwd = '';
    _root = '';
    _treeChildren.clear();
    _expandedDirs.clear();
    _loadingDirs.clear();
    _treeErrors.clear();
    _selectedPath = null;
    _selection.clear();
    _clipboardPaths = null;
    _clipboardIsCut = false;
    _error = null;
    _bootstrapping = true;
    notifyListeners();
    await init();
  }

  // ── 目录加载 ──
  Future<void> _loadDirectory(String path, {int? generation}) async {
    final requestGeneration = generation ?? _generation;
    final api = _apiProvider();
    if (api == null) return;
    _loadingDirs.add(path);
    _treeErrors.remove(path);
    notifyListeners();
    try {
      final result = await api.fsEntries(
        path,
        root: _root.isEmpty ? path : _root,
      );
      final entries = ((result['entries'] as List?) ?? const [])
          .map(
            (entry) => FsEntry.fromJson((entry as Map).cast<String, dynamic>()),
          )
          .toList();
      if (requestGeneration != _generation || !identical(api, _apiProvider())) {
        return;
      }
      _treeChildren[path] = entries;
      _treeErrors.remove(path);
      // Only clear the global error banner when this load was for the path
      // it's actually about — a background/other-directory load succeeding
      // (e.g. an already-expanded tree node) must not mask a real, still
      // current failure for `_cwd`/`_root`.
      if (path == _root || path == _cwd) _error = null;
    } catch (e) {
      if (requestGeneration != _generation || !identical(api, _apiProvider())) {
        return;
      }
      _treeErrors[path] = '$e';
      if (path == _root || path == _cwd) _error = '$e';
    } finally {
      if (requestGeneration == _generation && identical(api, _apiProvider())) {
        _loadingDirs.remove(path);
        notifyListeners();
      }
    }
  }

  Future<void> retryDirectory(String path) async {
    _treeChildren.remove(path);
    _treeErrors.remove(path);
    await _loadDirectory(path);
  }

  // ── 展开/折叠 ──
  Future<void> toggleDirectory(FsEntry entry) async {
    if (!entry.isDirectory) return;
    if (_expandedDirs.remove(entry.path)) {
      await _persistExpanded();
      notifyListeners();
      return;
    }
    _expandedDirs.add(entry.path);
    await _persistExpanded();
    notifyListeners();

    if (_treeChildren.containsKey(entry.path)) return;
    await _loadDirectory(entry.path);
  }

  bool isExpanded(String path) => _expandedDirs.contains(path);
  bool isLoading(String path) => _loadingDirs.contains(path);
  String? errorFor(String path) => _treeErrors[path];
  List<FsEntry>? childrenOf(String path) => _treeChildren[path];

  // ── 打开 / 导航 ──
  void openEntry(FsEntry entry) {
    if (entry.isDirectory) {
      navigateTo(entry.path, promoteRoot: _cwd.isEmpty);
      return;
    }
    _selectedPath = entry.path;
    notifyListeners();
  }

  void selectPreview(FsEntry entry) {
    if (entry.isDirectory) return;
    _selectedPath = entry.path;
    notifyListeners();
  }

  void clearPreview() {
    if (_selectedPath == null) return;
    _selectedPath = null;
    notifyListeners();
  }

  Future<void> navigateTo(String path, {bool promoteRoot = false}) async {
    if (promoteRoot || _cwd.isEmpty) _root = path;
    _cwd = path;
    _selectedPath = null;
    _selection.clear();
    _error = null;
    await _loadDirectory(path);
  }

  void goUp() {
    if (_cwd.isEmpty) return;
    if (ServerPath.isWindowsDriveRoot(_cwd) || ServerPath.isPosixRoot(_cwd)) {
      listDriveRoots();
      return;
    }
    final parent = ServerPath.parent(_cwd);
    if (parent.isEmpty) {
      listDriveRoots();
      return;
    }
    if (parent != _cwd) {
      navigateTo(parent);
    }
  }

  Future<void> listDriveRoots() async {
    final generation = _generation;
    final api = _apiProvider();
    if (api == null) return;
    _cwd = '';
    _root = '';
    _error = null;
    _selectedPath = null;
    _selection.clear();
    _loadingDirs.add('');
    notifyListeners();
    try {
      final drives = await api.fsDrives();
      final entries = drives
          .map(
            (drive) => FsEntry(
              name: (drive['label'] ?? drive['name'] ?? drive['path'])
                  .toString(),
              path: (drive['path'] ?? drive['root'] ?? '').toString(),
              isDirectory: true,
            ),
          )
          .where((drive) => drive.path.isNotEmpty)
          .toList();
      if (!_isCurrent(api, generation)) return;
      _treeChildren[''] = entries;
    } catch (e) {
      if (!_isCurrent(api, generation)) return;
      _error = '$e';
      _treeChildren[''] = const [];
    } finally {
      if (_isCurrent(api, generation)) {
        _loadingDirs.remove('');
        notifyListeners();
      }
    }
  }

  // ── 刷新 ──
  Future<void> refresh() async {
    final generation = _generation;
    final api = _apiProvider();
    if (api == null) return;
    if (_root.isEmpty) {
      await listDriveRoots();
      return;
    }
    final paths = <String>{_root, _cwd, ..._expandedDirs}
      ..removeWhere((p) => p.isEmpty);
    _loadingDirs.addAll(paths);
    _error = null;
    notifyListeners();

    await Future.wait(
      paths.map((path) async {
        try {
          final result = await api.fsEntries(path, root: _root);
          final children = ((result['entries'] as List?) ?? const [])
              .map(
                (item) =>
                    FsEntry.fromJson((item as Map).cast<String, dynamic>()),
              )
              .toList();
          if (!_isCurrent(api, generation)) return;
          _treeChildren[path] = children;
          _treeErrors.remove(path);
        } catch (e) {
          if (!_isCurrent(api, generation)) return;
          _treeErrors[path] = '$e';
          if (path == _root || path == _cwd) _error = '$e';
        } finally {
          if (_isCurrent(api, generation)) _loadingDirs.remove(path);
        }
      }),
    );
    if (_isCurrent(api, generation)) notifyListeners();
  }

  Future<void> refreshCurrent() async {
    if (_cwd.isEmpty && _root.isEmpty) {
      await listDriveRoots();
      return;
    }
    if (_treeMode) {
      await refresh();
      return;
    }
    await _loadDirectory(_cwd);
  }

  // ── 搜索过滤 ──
  void setQuery(String q) {
    _query = q.toLowerCase();
    notifyListeners();
  }

  // ── 视图模式 ──
  void toggleTreeMode() {
    _treeMode = !_treeMode;
    if (_treeMode && _root.isNotEmpty) {
      _cwd = _root;
    }
    _persistTreeMode();
    notifyListeners();
  }

  // ── 多选 / 剪贴板 ──
  void toggleSelect(String path) {
    if (!_selection.add(path)) _selection.remove(path);
    notifyListeners();
  }

  void addToSelection(String path) {
    if (_selection.add(path)) notifyListeners();
  }

  void clearSelection() {
    if (_selection.isEmpty) return;
    _selection.clear();
    notifyListeners();
  }

  void copySelectionToClipboard({required bool cut}) {
    final paths = _selection.isEmpty
        ? const <String>[]
        : _selection.toList(growable: false);
    if (paths.isEmpty) return;
    _clipboardPaths = paths;
    _clipboardIsCut = cut;
    notifyListeners();
  }

  void setClipboard(List<String> paths, {required bool cut}) {
    if (paths.isEmpty) return;
    _clipboardPaths = List<String>.from(paths);
    _clipboardIsCut = cut;
    _selection
      ..clear()
      ..addAll(paths);
    notifyListeners();
  }

  // ── 面包屑 ──
  List<({String label, String path})> breadcrumbSegments() {
    if (_cwd.isEmpty) {
      return [(label: runtimeL10n.filesThisComputer, path: '')];
    }
    final normalized = ServerPath.normalize(_cwd);
    final sep = ServerPath.separatorFor(normalized);
    final segments = <({String label, String path})>[];

    if (ServerPath.isWindowsStyle(normalized)) {
      final driveMatch = RegExp(r'^([a-zA-Z]:)[\\/]?').firstMatch(normalized);
      if (driveMatch != null) {
        final drive = driveMatch.group(1)!;
        final driveRoot = '$drive$sep';
        segments.add((label: drive, path: driveRoot));
        final rest = normalized.substring(driveMatch.end);
        var acc = driveRoot;
        for (final part in rest.split(RegExp(r'[\\/]+'))) {
          if (part.isEmpty) continue;
          acc = ServerPath.join(acc, part);
          segments.add((label: part, path: acc));
        }
        return segments;
      }
    }

    segments.add((label: '/', path: '/'));
    if (normalized == '/') return segments;
    var acc = '';
    for (final part in normalized.split('/')) {
      if (part.isEmpty) continue;
      acc = '$acc/$part';
      segments.add((label: part, path: acc));
    }
    return segments;
  }

  // ── 可见行计算（树模式） ──
  List<FileTreeRow> visibleTreeRows() {
    final rows = <FileTreeRow>[];
    void append(String parent, int depth) {
      final children = [...?_treeChildren[parent]]
        ..sort((a, b) {
          if (a.isDirectory != b.isDirectory) {
            return a.isDirectory ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      for (final entry in children) {
        if (_query.isEmpty || entry.name.toLowerCase().contains(_query)) {
          rows.add(FileTreeRow(entry: entry, depth: depth));
        }
        if (entry.isDirectory && _expandedDirs.contains(entry.path)) {
          if (_loadingDirs.contains(entry.path)) {
            rows.add(FileTreeRow(depth: depth + 1, loading: true));
          } else if (_treeErrors[entry.path] case final error?) {
            rows.add(
              FileTreeRow(
                depth: depth + 1,
                error: error,
                errorPath: entry.path,
              ),
            );
          } else {
            append(entry.path, depth + 1);
          }
        }
      }
    }

    append(_root, 0);
    return rows;
  }

  // ── 列表模式可见行 ──
  List<FsEntry> visibleListRows() {
    final entries = [...?_treeChildren[_cwd]]
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (_query.isEmpty) return entries;
    return entries.where((e) => e.name.toLowerCase().contains(_query)).toList();
  }

  // ── 路径工具 ──
  String relativePath(String path) {
    if (_cwd.isEmpty) return path;
    final normalizedBase = _cwd
        .replaceAll(r'\', '/')
        .replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.replaceAll(r'\', '/');
    final prefix = '$normalizedBase/';
    return normalizedPath.toLowerCase().startsWith(prefix.toLowerCase())
        ? normalizedPath.substring(prefix.length)
        : path;
  }

  FsEntry? entryForPath(String path) {
    for (final children in _treeChildren.values) {
      for (final entry in children) {
        if (entry.path == path) return entry;
      }
    }
    return null;
  }

  // ── 文件操作（调用后自动刷新） ──
  Future<void> createDirectory(String name) async {
    if (_cwd.isEmpty) return;
    final api = _requireApi();
    final generation = _generation;
    final fullPath = _joinPath(_cwd, name);
    await api.fsMkdir(fullPath);
    if (!_isCurrent(api, generation)) return;
    await refreshCurrent();
  }

  Future<void> createFile(String name) async {
    if (_cwd.isEmpty) return;
    final api = _requireApi();
    final generation = _generation;
    await api.fsWriteText(_joinPath(_cwd, name), '');
    if (!_isCurrent(api, generation)) return;
    await refreshCurrent();
  }

  Future<void> renameEntry(FsEntry entry, String newName) async {
    final api = _requireApi();
    final generation = _generation;
    final parent = ServerPath.parent(entry.path);
    await api.fsMove(entry.path, _joinPath(parent, newName));
    if (!_isCurrent(api, generation)) return;
    if (_selectedPath == entry.path) {
      _selectedPath = _joinPath(parent, newName);
    }
    await refreshCurrent();
  }

  Future<void> deleteEntry(FsEntry entry) async {
    final api = _requireApi();
    final generation = _generation;
    await api.fsDelete(entry.path, recursive: entry.isDirectory);
    if (!_isCurrent(api, generation)) return;
    _selection.remove(entry.path);
    if (_selectedPath == entry.path) _selectedPath = null;
    await refreshCurrent();
  }

  Future<void> deleteSelection() async {
    final paths = _selection.toList(growable: false);
    if (paths.isEmpty) return;
    final api = _requireApi();
    final generation = _generation;
    for (final path in paths) {
      final entry = entryForPath(path);
      await api.fsDelete(path, recursive: entry?.isDirectory ?? false);
      if (!_isCurrent(api, generation)) return;
    }
    _selection.clear();
    if (_selectedPath != null && paths.contains(_selectedPath)) {
      _selectedPath = null;
    }
    await refreshCurrent();
  }

  Future<void> pasteClipboard() async {
    final paths = _clipboardPaths;
    if (paths == null || paths.isEmpty || _cwd.isEmpty) return;
    final api = _requireApi();
    final generation = _generation;
    final wasCut = _clipboardIsCut;
    if (wasCut) {
      for (final path in paths) {
        await api.fsMove(path, _cwd);
        if (!_isCurrent(api, generation)) return;
      }
      _clipboardPaths = null;
      _clipboardIsCut = false;
    } else {
      await api.fsCopy(paths, _cwd);
      if (!_isCurrent(api, generation)) return;
    }
    _selection.clear();
    await refreshCurrent();
  }

  Future<void> revealInExplorer(FsEntry entry) async {
    final api = _requireApi();
    final generation = _generation;
    await api.fsReveal(entry.path);
    if (!_isCurrent(api, generation)) return;
  }

  String _joinPath(String dir, String name) => ServerPath.join(dir, name);
}

/// 树状列表行数据结构
class FileTreeRow {
  final FsEntry? entry;
  final int depth;
  final bool loading;
  final String? error;
  final String? errorPath;

  FileTreeRow({
    this.entry,
    required this.depth,
    this.loading = false,
    this.error,
    this.errorPath,
  });
}
