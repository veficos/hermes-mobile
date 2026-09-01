/// ProjectTreeStore: 项目分组树状态管理
///
/// Desktop parity with `src/store/projects.ts`: the tree is authoritative
/// from the backend (`projects.tree` RPC); the client only renders it and
/// persists node open/closed state plus the drill-in scope locally.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../models.dart';
import '../../l10n/runtime_l10n.dart';

class ProjectTreeStore extends ChangeNotifier {
  final ApiClient? Function() _apiProvider;

  ProjectTreeStore(this._apiProvider);

  // ── 树数据 ──
  List<ProjectTreeNode> _projects = [];
  String? _activeProjectId;
  Set<String> _scopedSessionIds = const {};

  List<ProjectTreeNode> get projects => _projects;
  String? get activeProjectId => _activeProjectId;
  Set<String> get scopedSessionIds => _scopedSessionIds;

  // ── 加载状态 ──
  bool _loading = false;
  String? _error;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _projects.isNotEmpty;

  // ── 节点开合（持久化，desktop $sidebarWorkspaceNodeOpen parity） ──
  final Map<String, bool> _nodeOpen = {};
  bool _prefsLoaded = false;

  static const _kNodeOpenKey = 'hm_workspace_node_open_v1';
  static const _kScopeKey = 'hm_project_scope_v1';

  bool nodeOpen(String id, {bool defaultOpen = false}) {
    // Stored value wins; otherwise the desktop default flip applies
    // (explicit user choice is never overwritten by defaults).
    return _nodeOpen[id] ?? defaultOpen;
  }

  Future<void> setNodeOpen(String id, bool open) async {
    _nodeOpen[id] = open;
    notifyListeners();
    await _persistNodeOpen();
  }

  Future<void> toggleNode(String id, {bool defaultOpen = false}) =>
      setNodeOpen(id, !nodeOpen(id, defaultOpen: defaultOpen));

  // ── 钻取作用域（desktop $projectScope parity） ──
  /// null = overview (all projects); otherwise the drilled-in project id.
  String? _scope;
  String? get scope => _scope;

  // ── 钻取数据 ──
  ProjectTreeNode? _scopedProject;
  bool _scopeLoading = false;
  String? _scopeError;
  int _scopeGeneration = 0;
  ProjectTreeNode? get scopedProject => _scopedProject;
  bool get scopeLoading => _scopeLoading;
  String? get scopeError => _scopeError;

  // ── 初始化 ──
  Future<void> init() async {
    await _loadPrefs();
    await refresh();
    // Restore the persisted drill-in scope after the first tree resolves.
    if (_scope != null && _projects.any((p) => p.id == _scope)) {
      await enterProject(_scope!, persist: false);
    } else if (_scope != null) {
      _scope = null;
      await _persistScope();
    }
  }

  Future<void> _loadPrefs() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kNodeOpenKey) ?? const [];
    // Format: "id=1" (open) / "id=0" (closed)
    for (final entry in raw) {
      final sep = entry.lastIndexOf('=');
      if (sep <= 0) continue;
      _nodeOpen[entry.substring(0, sep)] = entry.substring(sep + 1) == '1';
    }
    final scope = prefs.getString(_kScopeKey);
    if (scope != null && scope.isNotEmpty) _scope = scope;
  }

  Future<void> _persistNodeOpen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kNodeOpenKey,
      _nodeOpen.entries.map((e) => '${e.key}=${e.value ? 1 : 0}').toList(),
    );
  }

  Future<void> _persistScope() async {
    final prefs = await SharedPreferences.getInstance();
    if (_scope == null) {
      await prefs.remove(_kScopeKey);
    } else {
      await prefs.setString(_kScopeKey, _scope!);
    }
  }

  // ── 刷新树 ──
  Future<void> refresh() async {
    final api = _apiProvider();
    if (api == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final payload = await api.projectTree();
      _projects = payload.projects;
      _activeProjectId = payload.activeId;
      _scopedSessionIds = payload.scopedSessionIds;
      _error = null;
    } catch (e) {
      _error = '$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── 钻取（desktop $projectScope + fetchProjectSessions parity） ──
  Future<void> enterProject(String projectId, {bool persist = true}) async {
    final generation = ++_scopeGeneration;
    _scope = projectId;
    _scopeLoading = true;
    _scopeError = null;
    _scopedProject = null;
    notifyListeners();
    if (persist) await _persistScope();
    final api = _apiProvider();
    if (api == null) {
      if (generation != _scopeGeneration) return;
      _scopeLoading = false;
      notifyListeners();
      return;
    }
    try {
      final scopedProject = await api.projectSessions(projectId);
      if (generation != _scopeGeneration) return;
      _scopedProject = scopedProject;
      _scopeError = _scopedProject == null ? runtimeL10n.projectMissing : null;
    } catch (e) {
      if (generation != _scopeGeneration) return;
      _scopeError = '$e';
    } finally {
      if (generation == _scopeGeneration) {
        _scopeLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> exitProject() async {
    _scopeGeneration++;
    _scope = null;
    _scopedProject = null;
    _scopeError = null;
    notifyListeners();
    await _persistScope();
  }

  // ── 概览排序（desktop sortProjectsForOverview parity） ──
  /// Home bucket first, then active projects (explicit before auto), then by
  /// lastActive desc, then label.
  List<ProjectTreeNode> get sortedProjects {
    final list = List<ProjectTreeNode>.of(_projects);
    list.sort((a, b) {
      if (a.isNoProject != b.isNoProject) return a.isNoProject ? -1 : 1;
      if (a.isAuto != b.isAuto) return a.isAuto ? 1 : -1;
      final la = a.lastActive ?? 0;
      final lb = b.lastActive ?? 0;
      if (la != lb) return lb.compareTo(la);
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return list;
  }

  /// Sessions in the flat recents list that belong to a project (desktop
  /// parity: recents exclude rows already claimed by the project tree).
  bool isScoped(String sessionId) => _scopedSessionIds.contains(sessionId);
}
