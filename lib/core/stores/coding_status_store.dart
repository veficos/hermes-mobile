library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/runtime_l10n.dart';
import '../api_client.dart';

@immutable
class CodingStatusSnapshot {
  const CodingStatusSnapshot({
    required this.cwd,
    required this.branch,
    required this.added,
    required this.removed,
    required this.untracked,
    required this.ahead,
    required this.behind,
    required this.loading,
    this.error,
  });

  final String cwd;
  final String branch;
  final int added;
  final int removed;
  final int untracked;
  final int ahead;
  final int behind;
  final bool loading;
  final String? error;

  int get changed => added + removed + untracked;
}

class CodingStatusStore extends ChangeNotifier {
  CodingStatusStore({this.autoRefreshInterval = _ttl});

  ApiClient? _api;
  final Map<String, CodingStatusSnapshot> _byCwd = {};
  final Map<String, Future<void>> _inflight = {};
  final Map<String, DateTime> _refreshedAt = {};
  int _generation = 0;
  bool _disposed = false;
  bool _foreground = true;
  Timer? _timer;
  final Duration autoRefreshInterval;
  static const _ttl = Duration(seconds: 8);

  void startAutoRefresh() {
    if (!_foreground || _timer != null) return;
    _timer = Timer.periodic(autoRefreshInterval, (_) {
      if (_disposed) return;
      for (final cwd in _byCwd.keys.toList(growable: false)) {
        unawaited(refresh(cwd, force: true));
      }
    });
  }

  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    if (!value) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    startAutoRefresh();
    for (final cwd in _byCwd.keys.toList(growable: false)) {
      unawaited(refresh(cwd, force: true));
    }
  }

  void bindApi(ApiClient? api) {
    if (identical(_api, api)) return;
    _api = api;
    _generation++;
    _byCwd.clear();
    _inflight.clear();
    _refreshedAt.clear();
    notifyListeners();
  }

  CodingStatusSnapshot? forCwd(String? cwd) {
    final key = cwd?.trim() ?? '';
    return key.isEmpty ? null : _byCwd[key];
  }

  Future<void> refresh(String? cwd, {bool force = false}) {
    final key = cwd?.trim() ?? '';
    final api = _api;
    if (_disposed || key.isEmpty || api == null) return Future.value();
    final last = _refreshedAt[key];
    if (!force && last != null && DateTime.now().difference(last) < _ttl) {
      return Future.value();
    }
    final generation = _generation;
    return _inflight.putIfAbsent(key, () async {
      final previous = _byCwd[key];
      _byCwd[key] = CodingStatusSnapshot(
        cwd: key,
        branch: previous?.branch ?? '',
        added: previous?.added ?? 0,
        removed: previous?.removed ?? 0,
        untracked: previous?.untracked ?? 0,
        ahead: previous?.ahead ?? 0,
        behind: previous?.behind ?? 0,
        loading: true,
      );
      notifyListeners();
      try {
        final raw = await api.gitStatus(key);
        if (generation != _generation || !identical(api, _api)) return;
        _refreshedAt[key] = DateTime.now();
        _byCwd[key] = CodingStatusSnapshot(
          cwd: key,
          branch: (raw['current'] ?? raw['branch'] ?? '').toString(),
          added: _number(raw, const ['added', 'insertions']),
          removed: _number(raw, const ['removed', 'deletions']),
          untracked: _number(raw, const ['untracked', 'untracked_count']),
          ahead: _number(raw, const ['ahead']),
          behind: _number(raw, const ['behind']),
          loading: false,
        );
      } catch (error) {
        if (generation != _generation || !identical(api, _api)) return;
        _byCwd[key] = CodingStatusSnapshot(
          cwd: key,
          branch: previous?.branch ?? '',
          added: previous?.added ?? 0,
          removed: previous?.removed ?? 0,
          untracked: previous?.untracked ?? 0,
          ahead: previous?.ahead ?? 0,
          behind: previous?.behind ?? 0,
          loading: false,
          error: error.toString(),
        );
      } finally {
        if (generation == _generation && identical(api, _api)) {
          _inflight.remove(key);
          notifyListeners();
        }
      }
    });
  }

  Future<List<String>> branches(String? cwd) async {
    final key = cwd?.trim() ?? '';
    final api = _api;
    final generation = _generation;
    if (key.isEmpty || api == null) return const [];
    final rows = await api.gitBranches(key);
    if (generation != _generation || !identical(api, _api)) return const [];
    return rows
        .map((row) => (row['name'] ?? row['branch'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> switchBranch(String? cwd, String branch) async {
    final key = cwd?.trim() ?? '';
    final api = _api;
    if (key.isEmpty || branch.isEmpty) return;
    if (api == null) throw StateError(runtimeL10n.backendDisconnected);
    await api.gitBranchSwitch(key, branch);
    if (!identical(api, _api)) return;
    _refreshedAt.remove(key);
    await refresh(key);
  }

  Future<Map<String, dynamic>?> addWorktree(
    String? cwd, {
    required String name,
    String? base,
  }) async {
    final key = cwd?.trim() ?? '';
    final api = _api;
    if (key.isEmpty || name.trim().isEmpty) return null;
    if (api == null) throw StateError(runtimeL10n.backendDisconnected);
    final result = await api.gitWorktreeAdd(
      key,
      name: name.trim(),
      base: base?.trim(),
    );
    if (!identical(api, _api)) return null;
    _refreshedAt.remove(key);
    await refresh(key);
    return result;
  }

  static int _number(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _api = null;
    _timer?.cancel();
    super.dispose();
  }
}
