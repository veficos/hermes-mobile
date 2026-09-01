library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../models.dart';

enum PullRequestBucket { open, draft, merged, closed, none }

class SessionPullRequest {
  final String branch;
  final bool draft;
  final int number;
  final String state;
  final String title;
  final String url;

  const SessionPullRequest({
    required this.branch,
    required this.draft,
    required this.number,
    required this.state,
    required this.title,
    required this.url,
  });

  factory SessionPullRequest.fromJson(Map<String, dynamic> json) {
    return SessionPullRequest(
      branch: json['branch']?.toString() ?? '',
      draft: json['draft'] == true || json['isDraft'] == true,
      number: (json['number'] as num?)?.toInt() ?? 0,
      state: json['state']?.toString().toLowerCase() ?? 'open',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  PullRequestBucket get bucket {
    if (state == 'merged') return PullRequestBucket.merged;
    if (state == 'closed') return PullRequestBucket.closed;
    return draft ? PullRequestBucket.draft : PullRequestBucket.open;
  }
}

class PullRequestStore extends ChangeNotifier {
  static const staleAfter = Duration(seconds: 60);
  static const _lookupStorageKey = 'hm_pr_session_lookup_v1';
  static const _scannedStorageKey = 'hm_pr_scanned_sessions_v1';
  static const _filterStorageKey = 'hm_pr_bucket_filters_v1';
  static const _trunkBranches = {'dev', 'develop', 'main', 'master', 'trunk'};

  factory PullRequestStore({
    ApiClient? api,
    String connectionId = 'primary',
    String? profile,
    DateTime Function()? now,
  }) => PullRequestStore._(api, connectionId, profile, now ?? DateTime.now);

  PullRequestStore._(this._api, this._connectionId, this._profile, this._now);

  ApiClient? _api;
  String _connectionId;
  String? _profile;
  final DateTime Function() _now;
  bool _loaded = false;
  Future<void>? _loadFuture;
  bool _scanUnavailable = false;
  int _generation = 0;

  final Map<String, String> _sessionLookups = {};
  final Set<String> _scannedSessions = {};
  final Map<String, Set<PullRequestBucket>> _filtersByScope = {};
  final Map<String, SessionPullRequest> _pullRequests = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<void>> _repoInflight = {};
  final Map<String, Future<void>> _scanInflight = {};

  String get _scope => _scopeKey(_connectionId, _profile);
  Set<PullRequestBucket> get filter =>
      Set.unmodifiable(_filtersByScope[_scope] ?? const {});
  bool get filtersActive => filter.isNotEmpty;

  static String branchKey(String repoRoot, String branch) =>
      '$repoRoot\n$branch';
  static String numberKey(String repoRoot, int number) => '$repoRoot\n#$number';

  static String _scopeKey(String connectionId, String? profile) =>
      '$connectionId\u0000${profile ?? ''}';
  static String _sessionKey(
    String connectionId,
    String? profile,
    String sessionId,
  ) => '${_scopeKey(connectionId, profile)}\u0000$sessionId';
  static String _scopedLookup(String scope, String lookup) =>
      '$scope\u0000$lookup';
  static String _repoKey(String scope, String repoRoot) =>
      '$scope\u0000$repoRoot';

  String _scopeFor(SessionRow row) =>
      _scopeKey(_connectionId, row.profile ?? _profile);

  String _scopeForBinding(
    SessionRow row,
    String connectionId,
    String? profile,
  ) => _scopeKey(connectionId, row.profile ?? profile);

  String _sessionKeyForBinding(
    SessionRow row,
    String connectionId,
    String? profile,
  ) => _sessionKey(connectionId, row.profile ?? profile, row.id);

  String? _sessionLookupForBinding(
    SessionRow row,
    String connectionId,
    String? profile,
  ) {
    final stamped =
        _sessionLookups[_sessionKeyForBinding(row, connectionId, profile)];
    if (stamped != null) return stamped;
    final root = row.gitRepoRoot?.trim() ?? '';
    final branch = row.gitBranch?.trim() ?? '';
    if (root.isEmpty ||
        branch.isEmpty ||
        _trunkBranches.contains(branch.toLowerCase())) {
      return null;
    }
    return branchKey(root, branch);
  }

  void bind({
    required ApiClient? api,
    required String connectionId,
    String? profile,
  }) {
    final scopeChanged =
        connectionId != _connectionId || profile != _profile || api != _api;
    if (!scopeChanged) return;
    _api = api;
    _connectionId = connectionId;
    _profile = profile;
    _generation++;
    _scanUnavailable = false;
    notifyListeners();
  }

  String? sessionLookupKey(SessionRow row) {
    return _sessionLookupForBinding(row, _connectionId, _profile);
  }

  SessionPullRequest? forSession(SessionRow row) {
    final lookup = sessionLookupKey(row);
    if (lookup == null) return null;
    return _pullRequests[_scopedLookup(_scopeFor(row), lookup)];
  }

  PullRequestBucket bucketFor(SessionRow row) =>
      forSession(row)?.bucket ?? PullRequestBucket.none;

  bool matchesFilter(SessionRow row) {
    final selected = _filtersByScope[_scopeFor(row)] ?? const {};
    return selected.isEmpty || selected.contains(bucketFor(row));
  }

  Future<void> setFilter(Set<PullRequestBucket> buckets) async {
    await _ensureLoaded();
    _filtersByScope[_scope] = Set.of(buckets);
    await _persistFilters();
    notifyListeners();
  }

  Future<void> stampSessionPrBranch({
    required String sessionId,
    required String repoRoot,
    required String branch,
    String? profile,
  }) async {
    if (sessionId.isEmpty || repoRoot.isEmpty || branch.isEmpty) return;
    await _ensureLoaded();
    final scope = _scopeKey(_connectionId, profile ?? _profile);
    _sessionLookups['$scope\u0000$sessionId'] = branchKey(repoRoot, branch);
    await _persistLookups();
    notifyListeners();
  }

  Future<void> refreshForSessions(
    List<SessionRow> sessions, {
    bool force = false,
  }) async {
    final api = _api;
    if (api == null || sessions.isEmpty) return;
    final generation = _generation;
    final connectionId = _connectionId;
    final profile = _profile;
    await _ensureLoaded();
    if (generation != _generation || !identical(api, _api)) return;
    await _recoverFromTranscripts(
      api,
      sessions,
      generation: generation,
      connectionId: connectionId,
      profile: profile,
    );
    if (generation != _generation || !identical(api, _api)) return;

    final lookupsByRepoAndScope = <String, _RepoRequest>{};
    for (final row in sessions) {
      final lookup = _sessionLookupForBinding(row, connectionId, profile);
      final root = row.gitRepoRoot?.trim() ?? '';
      if (lookup == null || root.isEmpty) continue;
      final scope = _scopeForBinding(row, connectionId, profile);
      final key = _repoKey(scope, root);
      final request = lookupsByRepoAndScope.putIfAbsent(
        key,
        () => _RepoRequest(scope: scope, repoRoot: root),
      );
      request.lookups.add(lookup.substring(root.length + 1));
    }

    await Future.wait(
      lookupsByRepoAndScope.values.map(
        (request) =>
            _refreshRepo(api, request, force: force, generation: generation),
      ),
    );
  }

  Future<void> _recoverFromTranscripts(
    ApiClient api,
    List<SessionRow> sessions, {
    required int generation,
    required String connectionId,
    required String? profile,
  }) async {
    if (_scanUnavailable) return;
    final candidates = <String, List<SessionRow>>{};
    for (final row in sessions) {
      final root = row.gitRepoRoot?.trim() ?? '';
      if (root.isEmpty ||
          _sessionLookupForBinding(row, connectionId, profile) != null) {
        continue;
      }
      if (_scannedSessions.contains(
        _sessionKeyForBinding(row, connectionId, profile),
      )) {
        continue;
      }
      candidates.putIfAbsent(row.id, () => []).add(row);
    }
    if (candidates.isEmpty) return;

    final scopes =
        candidates.values
            .expand((rows) => rows)
            .map((row) => _scopeForBinding(row, connectionId, profile))
            .toSet()
            .toList()
          ..sort();
    final inflightKey = '$generation\u0000${scopes.join('\n')}';
    final existing = _scanInflight[inflightKey];
    if (existing != null) return existing;
    final future = _runTranscriptScan(
      api,
      candidates,
      generation: generation,
      connectionId: connectionId,
      profile: profile,
    );
    _scanInflight[inflightKey] = future;
    try {
      await future;
    } finally {
      _scanInflight.remove(inflightKey);
    }
  }

  Future<void> _runTranscriptScan(
    ApiClient api,
    Map<String, List<SessionRow>> candidates, {
    required int generation,
    required String connectionId,
    required String? profile,
  }) async {
    try {
      final payload = await api.scanSessionPullRequests(
        candidates.keys.toList(),
      );
      if (generation != _generation || !identical(api, _api)) return;
      final found = payload['pull_requests'];
      if (found is Map) {
        for (final entry in found.entries) {
          final rows = candidates[entry.key.toString()] ?? const <SessionRow>[];
          final value = entry.value;
          final number = value is Map
              ? (value['number'] as num?)?.toInt()
              : null;
          if (number == null || number <= 0) continue;
          for (final row in rows) {
            final root = row.gitRepoRoot?.trim() ?? '';
            if (root.isNotEmpty) {
              _sessionLookups[_sessionKeyForBinding(
                row,
                connectionId,
                profile,
              )] = numberKey(
                root,
                number,
              );
            }
          }
        }
      }
      final scanned = payload['scanned'];
      if (scanned is List) {
        for (final id in scanned.map((value) => value.toString())) {
          for (final row in candidates[id] ?? const <SessionRow>[]) {
            _scannedSessions.add(
              _sessionKeyForBinding(row, connectionId, profile),
            );
          }
        }
      }
      await Future.wait([_persistLookups(), _persistScanned()]);
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 501) {
        if (generation == _generation && identical(api, _api)) {
          _scanUnavailable = true;
        }
      }
    } catch (_) {
      // A transient scan failure leaves the sessions eligible for a retry.
    }
  }

  Future<void> _refreshRepo(
    ApiClient api,
    _RepoRequest request, {
    required bool force,
    required int generation,
  }) async {
    final repoKey = _repoKey(request.scope, request.repoRoot);
    final inflightKey = '$generation\u0000$repoKey';
    final existing = _repoInflight[inflightKey];
    if (existing != null) return existing;
    final fetched = _fetchedAt[repoKey];
    if (!force && fetched != null && _now().difference(fetched) <= staleAfter) {
      return;
    }
    final future = _runRepoRefresh(api, request, repoKey, generation);
    _repoInflight[inflightKey] = future;
    try {
      await future;
    } finally {
      _repoInflight.remove(inflightKey);
    }
  }

  Future<void> _runRepoRefresh(
    ApiClient api,
    _RepoRequest request,
    String repoKey,
    int generation,
  ) async {
    final branches = request.lookups
        .where((lookup) => !lookup.startsWith('#'))
        .toList();
    final numbers = request.lookups
        .where((lookup) => lookup.startsWith('#'))
        .map((lookup) => int.tryParse(lookup.substring(1)))
        .whereType<int>()
        .toList();
    try {
      final rows = await api.gitPullRequests(
        request.repoRoot,
        branches: branches,
        numbers: numbers,
      );
      if (generation != _generation || !identical(api, _api)) return;
      final prefix = _scopedLookup(request.scope, '${request.repoRoot}\n');
      _pullRequests.removeWhere((key, _) => key.startsWith(prefix));
      for (final row in rows) {
        final pr = SessionPullRequest.fromJson(row);
        if (pr.branch.isNotEmpty) {
          _pullRequests[_scopedLookup(
                request.scope,
                branchKey(request.repoRoot, pr.branch),
              )] =
              pr;
        }
        if (numbers.contains(pr.number)) {
          _pullRequests[_scopedLookup(
                request.scope,
                numberKey(request.repoRoot, pr.number),
              )] =
              pr;
        }
      }
      notifyListeners();
    } catch (_) {
      // Keep the last known slice when gh is absent, offline or unauthenticated.
    } finally {
      if (generation == _generation && identical(api, _api)) {
        _fetchedAt[repoKey] = _now();
      }
    }
  }

  Future<void> _ensureLoaded() {
    if (_loaded) return Future.value();
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lookupJson = prefs.getString(_lookupStorageKey);
    final filterJson = prefs.getString(_filterStorageKey);
    if (lookupJson != null) {
      final decoded = jsonDecode(lookupJson);
      if (decoded is Map) {
        _sessionLookups.addAll(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    }
    _scannedSessions.addAll(
      prefs.getStringList(_scannedStorageKey) ?? const [],
    );
    if (filterJson != null) {
      final decoded = jsonDecode(filterJson);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final values = entry.value;
          if (values is! List) continue;
          _filtersByScope[entry.key.toString()] = values
              .map(
                (value) => PullRequestBucket.values
                    .where((bucket) => bucket.name == value.toString())
                    .firstOrNull,
              )
              .whereType<PullRequestBucket>()
              .toSet();
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistLookups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lookupStorageKey, jsonEncode(_sessionLookups));
  }

  Future<void> _persistScanned() async {
    final prefs = await SharedPreferences.getInstance();
    final values = _scannedSessions.toList()..sort();
    await prefs.setStringList(_scannedStorageKey, values);
  }

  Future<void> _persistFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _filterStorageKey,
      jsonEncode(
        _filtersByScope.map(
          (scope, buckets) => MapEntry(
            scope,
            buckets.map((bucket) => bucket.name).toList()..sort(),
          ),
        ),
      ),
    );
  }
}

class _RepoRequest {
  final String scope;
  final String repoRoot;
  final Set<String> lookups = {};

  _RepoRequest({required this.scope, required this.repoRoot});
}
