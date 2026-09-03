/// Sessions (spec §16–19): grouped list with swipe actions, long-press menu
/// and full-screen chat navigation.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/connectivity_service.dart';
import '../core/models.dart';
import '../core/performance_metrics.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/project_tree_store.dart';
import '../core/stores/pull_request_store.dart';
import '../core/stores/session_store.dart';
import '../core/stores/session_appearance_store.dart';
import '../core/stores/subagent_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_badge.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/session/session_card.dart';
import '../widgets/session/session_row_actions.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import '../widgets/session/session_list_meta.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'new_session_screen.dart';
import 'sessions_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionVisibleRow {
  final SessionRow row;
  final _TimeGroup group;
  final int depth;

  const _SessionVisibleRow(
    this.row, {
    required this.group,
    required this.depth,
  });
}

enum _TimeGroup {
  pinned,
  running,
  today,
  yesterday,
  last7days,
  older,
  archived,
}

class _SessionListScreenState extends State<SessionListScreen>
    with ConnectionReloadMixin<SessionListScreen> {
  bool _loading = false;
  String? _error;
  String? _lastSessionId;
  // ── Refresh debounce (WebUI #4966 equivalent) ──
  DateTime? _lastTouchAt;
  DateTime? _lastListLoad;
  Timer? _pollTimer;
  int _idlePolls = 0;
  String? _lastPollSignature;
  static const _interactionQuietMs = 1500;
  static const _pollIntervalMs = HermesPolicy.sessionPollInterval;
  static const _minListRefreshMs = 3500;
  // Unread state cache (mirrors the in-memory sidebar cache in sessions.js).
  final Map<String, bool> _unreadCache = {};
  int _unreadCacheKey = 0;
  String? _unreadRowsSignature;
  String? _openingSessionId;

  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  final Set<String> _expandedSessionIds = {};
  final Map<String, List<SessionRow>> _childrenByParent = {};
  Map<String, int> _projectedActivity = const {};
  Map<String, bool> _projectedRunning = const {};
  Map<String, bool> _projectedUnread = const {};
  Map<String, int> _projectedDurableCount = const {};
  Map<String, int> _projectedRuntimeCount = const {};
  List<SessionRow>? _projectionRowsIdentity;
  String? _projectionQuery;
  int _projectionSessionRevision = -1;
  int _projectionSidebarRevision = -1;
  int _projectionPullRequestRevision = -1;
  int _projectionSubagentRevision = -1;
  int _projectionUnreadRevision = 0;
  int _unreadRevision = 0;
  List<SessionRow> _cachedDisplayRows = const [];
  Map<_TimeGroup, List<SessionRow>> _cachedTimeGroups = const {};
  bool _deleting = false;
  String _query = '';
  final _queryController = TextEditingController();
  // ── Project grouping tree (desktop $sidebarGrouping='project' parity) ──
  late final ProjectTreeStore _projectTree = ProjectTreeStore(
    () => context.read<SessionStore>().connection.api,
  );

  @override
  void initState() {
    super.initState();
    // Desktop parity: persistent sidebar filters / pinned order atoms.
    context.read<SessionStore>().loadSidebarPrefs();
    _projectTree.init();
    _load();
    // P5-3 state restoration: remember the last opened session id.
    context.read<SessionStore>().lastSessionId().then((id) {
      if (mounted) setState(() => _lastSessionId = id);
    });
    _schedulePolling();
  }

  void _schedulePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer(_adaptivePollInterval, () async {
      await _maybeBackgroundRefresh();
      if (mounted) _schedulePolling();
    });
  }

  Duration get _adaptivePollInterval {
    final rows = context.read<SessionStore>().sessions ?? const <SessionRow>[];
    if (rows.any((row) => row.effectivelyStreaming)) return _pollIntervalMs;
    if (_idlePolls >= 6) return const Duration(seconds: 30);
    if (_idlePolls >= 2) return const Duration(seconds: 15);
    return const Duration(seconds: 8);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), () {
      unawaited(_projectTree.refreshVisible());
    });
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _pollTimer?.cancel();
    _projectTree.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _recordInteraction() {
    _lastTouchAt = DateTime.now();
  }

  Future<void> _maybeBackgroundRefresh() async {
    if (!mounted) return;
    // Weak-network: skip this tick outright when the OS reports no network
    // at all — firing on schedule into a request that can only time out
    // just burns battery/data and delays the eventual timeout error.
    if (Provider.of<ConnectivityService?>(context, listen: false)?.hasNetwork ==
        false) {
      return;
    }
    final lastTouch = _lastTouchAt;
    if (lastTouch != null &&
        DateTime.now().difference(lastTouch).inMilliseconds <
            _interactionQuietMs) {
      return;
    }
    final lastLoad = _lastListLoad;
    if (lastLoad != null &&
        DateTime.now().difference(lastLoad).inMilliseconds <
            _minListRefreshMs) {
      return;
    }
    if (_loading) return;
    final session = context.read<SessionStore>();
    final pullRequests = context.read<PullRequestStore>();
    if (session.chat.busy) return; // turn in flight: avoid transient empty rows
    try {
      // Refresh the whole loaded window (page 0..loaded) so rows already
      // fetched via "load more" stay fresh — desktop mergeSessionPage parity.
      final loaded = session.sessions?.length ?? 0;
      final limit = loaded > SessionStore.sessionPageSize
          ? loaded
          : SessionStore.sessionPageSize;
      await session.refreshList(limit: limit);
      final rows = session.sessions ?? const <SessionRow>[];
      final signature = rows
          .take(SessionStore.sessionPageSize)
          .map(
            (row) =>
                '${row.id}:${row.lastMessageAt}:${row.effectivelyStreaming}',
          )
          .join('|');
      if (signature == _lastPollSignature) {
        _idlePolls++;
        ClientPerformanceMetrics.instance.adaptivePollBackoffs++;
      } else {
        _idlePolls = 0;
        _lastPollSignature = signature;
      }
      await _refreshSubagents(rows);
      unawaited(pullRequests.refreshForSessions(rows));
      if (session.groupingMode == 'project') {
        unawaited(_projectTree.refreshVisible());
      }
      _lastListLoad = DateTime.now();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _continueLastSession(SessionRow row) async {
    final session = context.read<SessionStore>();
    try {
      await session.resumeSession(row.id, profile: row.profile);
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.sessionResumeLastFailed('$e'))),
        );
      }
    }
  }

  Widget _restoreBanner(BuildContext context, SessionRow row) {
    final title = row.title?.trim().isNotEmpty == true
        ? row.title!.trim()
        : context.l10n.sessionUntitled;
    return HermesGlassCard(
      radius: HermesRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.restore, color: HermesSemantic.blue),
        title: Text(context.l10n.sessionContinueLast),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: title,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: ' · ${_fmtId(row.id)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _continueLastSession(row),
      ),
    );
  }

  String _fmtId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
  }

  Future<void> _load() async {
    final session = context.read<SessionStore>();
    final pullRequests = context.read<PullRequestStore>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Desktop parity: page-window listing — first page of 50 rows, with a
      // manual "load more" row driven by the server's has_more flag.
      await session.refreshList(limit: SessionStore.sessionPageSize);
      final rows = session.sessions ?? const <SessionRow>[];
      await _refreshSubagents(rows);
      unawaited(pullRequests.refreshForSessions(rows));
      _lastListLoad = DateTime.now();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshSubagents(List<SessionRow> sessions) async {
    await context.read<SubagentStore>().refreshProjection();
  }

  bool _rowMatchesFilters(SessionRow row) =>
      context.read<SessionStore>().rowMatchesFilters(row) &&
      context.read<PullRequestStore>().matchesFilter(row);

  Future<void> _openSubagent(SessionRow child) async {
    final sessionId = child.id;
    if (sessionId.isEmpty || _openingSessionId != null) return;
    final session = context.read<SessionStore>();
    setState(() => _openingSessionId = sessionId);
    try {
      await session.openReadOnlySession(sessionId, profile: child.profile);
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.sessionResumeSubagentFailed('$error')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingSessionId = null);
    }
  }

  Future<void> _open(SessionRow row) async {
    if (_openingSessionId != null) return;
    final session = context.read<SessionStore>();
    _recordInteraction();
    setState(() => _openingSessionId = row.id);
    try {
      await session.resumeSession(row.id, profile: row.profile);
      // Mark viewed: clears both the message-count unread dot and any
      // stale completion-unread entry (mirrors WebUI openSession).
      await session.setSessionViewedCount(row.id, row.messageCount ?? 0);
      _unreadCache
        ..remove(row.id)
        ..clear(); // simplest cache invalidation
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.sessionResumeFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingSessionId = null);
    }
  }

  // ─────────── WebUI parity: time grouping helpers ───────────

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static _TimeGroup _groupOf(SessionRow row) {
    if (row.archived) return _TimeGroup.archived;
    if (row.pinned) return _TimeGroup.pinned;
    if (row.source == 'running' || row.effectivelyStreaming) {
      return _TimeGroup.running;
    }
    DateTime? anchor;
    final lm = row.lastMessageAt;
    if (lm != null && lm > 0) {
      anchor = DateTime.fromMillisecondsSinceEpoch(lm);
    } else {
      anchor = row.startedAt;
    }
    if (anchor == null) return _TimeGroup.older;
    final local = anchor.toLocal();
    final now = DateTime.now();
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    final day = _dateOnly(local);
    if (day == today) return _TimeGroup.today;
    if (day == yesterday) return _TimeGroup.yesterday;
    if (!day.isBefore(sevenDaysAgo)) return _TimeGroup.last7days;
    return _TimeGroup.older;
  }

  String _groupTitle(BuildContext context, _TimeGroup g) => switch (g) {
    _TimeGroup.pinned => context.l10n.sessionGroupPinned,
    _TimeGroup.running => context.l10n.sessionGroupRunning,
    _TimeGroup.today => context.l10n.dateToday,
    _TimeGroup.yesterday => context.l10n.dateYesterday,
    _TimeGroup.last7days => context.l10n.sessionGroupLast7Days,
    _TimeGroup.older => context.l10n.sessionGroupOlder,
    _TimeGroup.archived => context.l10n.sessionGroupArchived,
  };

  void _prepareChildren(List<SessionRow> rows) {
    final filtered = rows.where(_rowMatchesFilters).toList();
    _childrenByParent.clear();
    final ids = {for (final row in filtered) row.id};
    final nestedIds = <String>{};
    for (final row in filtered) {
      // WebUI parity: nest every child session regardless of source
      // (subagent, desktop delegate, weixin, …), not only subagent rows.
      if (!row.isChildSession) continue;
      final parentId = row.parentSessionId;
      if (parentId != null && ids.contains(parentId) && nestedIds.add(row.id)) {
        (_childrenByParent[parentId] ??= <SessionRow>[]).add(row);
      }
    }
    for (final children in _childrenByParent.values) {
      children.sort(
        (a, b) => (b.lastMessageAt ?? b.startedAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(
              a.lastMessageAt ?? a.startedAt?.millisecondsSinceEpoch ?? 0,
            ),
      );
    }
  }

  bool _runtimeRunning(SubagentNode node) {
    if (node.status == 'running' || node.status == 'queued') return true;
    return node.children.any(_runtimeRunning);
  }

  bool _hasRunningDescendant(SessionRow row, SubagentStore store) {
    final seen = <String>{};
    bool visit(String parentId) {
      if (!seen.add(parentId)) return false;
      if (store.forSession(parentId).any(_runtimeRunning)) return true;
      for (final child in _childrenByParent[parentId] ?? const <SessionRow>[]) {
        if (child.effectivelyStreaming || visit(child.id)) return true;
      }
      return false;
    }

    return visit(row.id);
  }

  bool _hasUnreadDescendant(SessionRow row) {
    final seen = <String>{};
    bool visit(String parentId) {
      if (!seen.add(parentId)) return false;
      for (final child in _childrenByParent[parentId] ?? const <SessionRow>[]) {
        if (_unreadCache[child.id] == true || visit(child.id)) return true;
      }
      return false;
    }

    return visit(row.id);
  }

  int _durableDescendantCount(String parentId) {
    final seen = <String>{};
    void visit(String id) {
      for (final child in _childrenByParent[id] ?? const <SessionRow>[]) {
        if (seen.add(child.id)) visit(child.id);
      }
    }

    visit(parentId);
    return seen.length;
  }

  int _runtimeDescendantCount(String parentId, SubagentStore store) {
    final seenSessions = <String>{};
    var count = 0;
    void visit(String id) {
      if (!seenSessions.add(id)) return;
      count += store.runtimeDescendantCount(id);
      for (final child in _childrenByParent[id] ?? const <SessionRow>[]) {
        visit(child.id);
      }
    }

    visit(parentId);
    return count;
  }

  int _activityMillis(SessionRow row) {
    final projected = _projectedActivity[row.id];
    if (projected != null) return projected;
    var latest =
        row.lastMessageAt ?? row.startedAt?.millisecondsSinceEpoch ?? 0;
    final seen = <String>{};
    void visit(String parentId) {
      if (!seen.add(parentId)) return;
      for (final child in _childrenByParent[parentId] ?? const <SessionRow>[]) {
        final value =
            child.lastMessageAt ?? child.startedAt?.millisecondsSinceEpoch ?? 0;
        if (value > latest) latest = value;
        visit(child.id);
      }
    }

    visit(row.id);
    return latest;
  }

  Map<_TimeGroup, List<SessionRow>> _projectTimeGroups(List<SessionRow> rows) {
    final started = Stopwatch()..start();
    final metrics = ClientPerformanceMetrics.instance;
    metrics.sessionProjectionBuilds++;
    metrics.sessionProjectionRows += rows.length;
    final session = context.read<SessionStore>();
    final subagents = context.read<SubagentStore>();
    final filtered = rows.where(_rowMatchesFilters).toList(growable: false);
    final visibleIds = {for (final row in filtered) row.id};
    final byId = {for (final row in filtered) row.id: row};
    final activity = <String, int>{};
    final running = <String, bool>{};
    final unread = <String, bool>{};
    final durableCount = <String, int>{};
    final runtimeCount = <String, int>{};
    final visiting = <String>{};

    void derive(String id) {
      if (activity.containsKey(id) || !visiting.add(id)) return;
      final row = byId[id];
      if (row == null) return;
      var latest =
          row.lastMessageAt ?? row.startedAt?.millisecondsSinceEpoch ?? 0;
      var hasRunning = false;
      var hasUnread = false;
      var descendants = 0;
      var runtimeDescendants = subagents.runtimeDescendantCount(id);
      for (final child in _childrenByParent[id] ?? const <SessionRow>[]) {
        derive(child.id);
        descendants += 1 + (durableCount[child.id] ?? 0);
        runtimeDescendants += runtimeCount[child.id] ?? 0;
        final childActivity = activity[child.id] ?? 0;
        if (childActivity > latest) latest = childActivity;
        hasRunning =
            hasRunning ||
            child.effectivelyStreaming ||
            (running[child.id] ?? false);
        hasUnread =
            hasUnread ||
            _unreadCache[child.id] == true ||
            (unread[child.id] ?? false);
      }
      hasRunning = hasRunning || subagents.forSession(id).any(_runtimeRunning);
      activity[id] = latest;
      running[id] = hasRunning;
      unread[id] = hasUnread;
      durableCount[id] = descendants;
      runtimeCount[id] = runtimeDescendants;
      visiting.remove(id);
    }

    for (final row in filtered) {
      derive(row.id);
    }
    _projectedActivity = activity;
    _projectedRunning = running;
    _projectedUnread = unread;
    _projectedDurableCount = durableCount;
    _projectedRuntimeCount = runtimeCount;

    final result = <_TimeGroup, List<SessionRow>>{};
    for (final row in filtered) {
      if (row.isChildSession && visibleIds.contains(row.parentSessionId)) {
        continue;
      }
      final group = row.archived || row.pinned
          ? _groupOf(row)
          : row.effectivelyStreaming || (running[row.id] ?? false)
          ? _TimeGroup.running
          : _groupOf(
              SessionRow(
                id: row.id,
                lastMessageAt: activity[row.id],
                startedAt: row.startedAt,
              ),
            );
      (result[group] ??= <SessionRow>[]).add(row);
    }
    for (final entry in result.entries) {
      final group = entry.key;
      final list = entry.value;
      if (group == _TimeGroup.pinned) {
        result[group] = session.applyPinnedOrder(list);
      } else if (group != _TimeGroup.running) {
        switch (session.sortMode) {
          case 'created':
            list.sort(
              (a, b) => (b.startedAt ?? DateTime(0)).compareTo(
                a.startedAt ?? DateTime(0),
              ),
            );
          case 'tokens':
            list.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
          default:
            list.sort(
              (a, b) => (activity[b.id] ?? 0).compareTo(activity[a.id] ?? 0),
            );
        }
      }
    }
    started.stop();
    if (started.elapsedMicroseconds > metrics.maxSessionProjectionMicros) {
      metrics.maxSessionProjectionMicros = started.elapsedMicroseconds;
    }
    return result;
  }

  _TimeGroup _effectiveGroup(SessionRow row, SubagentStore store) {
    if (row.archived || row.pinned) return _groupOf(row);
    if (row.effectivelyStreaming || _hasRunningDescendant(row, store)) {
      return _TimeGroup.running;
    }
    final activity = _activityMillis(row);
    if (activity == 0) return _TimeGroup.older;
    return _groupOf(
      SessionRow(id: row.id, lastMessageAt: activity, startedAt: row.startedAt),
    );
  }

  /// Builds one group's sliver, computing [_rowsInGroup] exactly once for
  /// the whole group rather than once per visible row. `itemCount` and
  /// every `itemBuilder` call used to invoke `_rowsInGroup` independently —
  /// it re-filters and re-sorts the *entire* `displayRows` list each time —
  /// and with `SliverList`/`SliverReorderableList` lazily rebuilding items
  /// as the user scrolls, that turned a session list of any real size
  /// (dozens to hundreds of rows) into a visible scroll-jank source.
  Widget _buildGroupSliver(
    BuildContext context,
    List<SessionRow> rowsForGroup,
    _TimeGroup g,
  ) {
    final visibleRows = _flattenVisibleSessionRows(rowsForGroup, g);
    final canReorderRoots =
        g == _TimeGroup.pinned &&
        !_selectMode &&
        visibleRows.length == rowsForGroup.length;
    if (canReorderRoots) {
      // Desktop parity: pinned rows are user-reorderable; order persists
      // client-side keyed by durable lineage id.
      return SliverReorderableList(
        itemCount: visibleRows.length,
        onReorderItem: (oldIndex, newIndex) =>
            _reorderPinned(rowsForGroup, g, oldIndex, newIndex),
        itemBuilder: (context, i) {
          final row = visibleRows[i].row;
          return Builder(
            builder: (context) => ReorderableDelayedDragStartListener(
              key: ValueKey('pinned-${row.id}'),
              index: i,
              child: _row(context, row, group: g),
            ),
          );
        },
      );
    }
    return SliverList.builder(
      itemCount: visibleRows.length,
      itemBuilder: (context, i) {
        return Builder(
          builder: (context) {
            final item = visibleRows[i];
            final row = item.row;
            final child = row.isChildSession
                ? _subagentRow(context, row)
                : _row(context, row, group: item.group);
            if (item.depth == 0) return child;
            return Padding(
              key: ValueKey('nested-session-${row.id}'),
              padding: EdgeInsetsDirectional.only(
                start: 28.0 + item.depth * 12,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_SessionVisibleRow> _flattenVisibleSessionRows(
    List<SessionRow> roots,
    _TimeGroup group,
  ) {
    final result = <_SessionVisibleRow>[];
    final path = <String>{};
    void append(SessionRow row, int depth) {
      if (!path.add(row.id)) return;
      result.add(_SessionVisibleRow(row, group: group, depth: depth));
      if (_expandedSessionIds.contains(row.id)) {
        for (final child in _childrenByParent[row.id] ?? const <SessionRow>[]) {
          append(child, depth + 1);
        }
      }
      path.remove(row.id);
    }

    for (final root in roots) {
      append(root, 0);
    }
    return result;
  }

  List<SessionRow> _rowsInGroup(List<SessionRow> rows, _TimeGroup g) {
    final session = context.read<SessionStore>();
    final subagents = context.read<SubagentStore>();
    final filtered = rows.where(_rowMatchesFilters).toList();
    // WebUI parity: child sessions with a visible parent nest under it and
    // never render as context-free top-level rows (any source).
    final visibleIds = {for (final row in filtered) row.id};
    final list = filtered
        .where(
          (r) =>
              !(r.isChildSession && visibleIds.contains(r.parentSessionId)) &&
              _effectiveGroup(r, subagents) == g,
        )
        .toList();
    // Running/pinned preserve natural order; time groups sort newest first.
    if (g == _TimeGroup.pinned) {
      // Desktop parity: user-reorderable pinned list backed by a persistent
      // client-side order atom (Hermes has no pin-order endpoint).
      return session.applyPinnedOrder(list);
    }
    if (g != _TimeGroup.running) {
      switch (session.sortMode) {
        case 'created':
          list.sort(
            (a, b) => (b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );
        case 'tokens':
          list.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
        default:
          list.sort((a, b) => _activityMillis(b).compareTo(_activityMillis(a)));
      }
    }
    return list;
  }

  // ── Unread dot cache (populated async then rebuilt when rows change) ──

  Future<void> _rebuildUnreadCache(List<SessionRow> rows) async {
    final session = context.read<SessionStore>();
    final snap = ++_unreadCacheKey;
    final all = await session.unreadForSessions(rows);
    if (snap != _unreadCacheKey) return; // stale async response
    final next = <String, bool>{
      for (final entry in all.entries)
        if (entry.value) entry.key: true,
    };
    if (!mounted) return;
    if (mapEquals(next, _unreadCache)) return;
    setState(() {
      _unreadCache
        ..clear()
        ..addAll(next);
      _unreadRevision++;
    });
  }

  ({List<SessionRow> displayRows, Map<_TimeGroup, List<SessionRow>> groups})
  _sessionProjection(List<SessionRow> rows) {
    final session = context.read<SessionStore>();
    final pullRequests = context.read<PullRequestStore>();
    final subagents = context.read<SubagentStore>();
    final normalizedQuery = _query.trim().toLowerCase();
    final reusable =
        identical(_projectionRowsIdentity, rows) &&
        _projectionQuery == normalizedQuery &&
        _projectionSessionRevision == session.sessionListRevision &&
        _projectionSidebarRevision == session.sidebarRevision &&
        _projectionPullRequestRevision == pullRequests.projectionRevision &&
        _projectionSubagentRevision == subagents.projectionRevision &&
        _projectionUnreadRevision == _unreadRevision;
    if (!reusable) {
      _cachedDisplayRows = normalizedQuery.isEmpty
          ? rows
          : rows
                .where((row) {
                  final haystack = [
                    row.title,
                    row.preview,
                    row.model,
                    row.profile,
                    row.cwd,
                    row.gitBranch,
                  ].whereType<String>().join('\n').toLowerCase();
                  return haystack.contains(normalizedQuery);
                })
                .toList(growable: false);
      _prepareChildren(_cachedDisplayRows);
      _cachedTimeGroups = _projectTimeGroups(_cachedDisplayRows);
      _projectionRowsIdentity = rows;
      _projectionQuery = normalizedQuery;
      _projectionSessionRevision = session.sessionListRevision;
      _projectionSidebarRevision = session.sidebarRevision;
      _projectionPullRequestRevision = pullRequests.projectionRevision;
      _projectionSubagentRevision = subagents.projectionRevision;
      _projectionUnreadRevision = _unreadRevision;
    }
    return (displayRows: _cachedDisplayRows, groups: _cachedTimeGroups);
  }

  void _showMenu(SessionRow row) {
    SessionRowActions.show(
      context,
      session: row,
      isArchived: row.archived,
      onRefreshed: () => _load(),
      onOpenCopy: _openCopy,
    );
  }

  /// After duplicating, resume the fresh copy and jump straight into it.
  Future<void> _openCopy(SessionRow copy) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SessionStore>().resumeSession(
        copy.id,
        profile: copy.profile,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.sessionOpenCopyFailed('$e'))),
      );
    }
  }

  /// Desktop parity: sidebar filter menu — status bucket multi-select plus
  /// the archived view toggle, all persisted across restarts.
  void _showFilterMenu(
    BuildContext context,
    SessionStore store,
    PullRequestStore pullRequests,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HermesRadius.sheet),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Widget bucketTile(String bucket, String label, IconData icon) {
              final selected = store.statusFilter.contains(bucket);
              return CheckboxListTile(
                value: selected,
                dense: true,
                secondary: Icon(icon, size: 20),
                title: Text(label),
                onChanged: (v) {
                  final next = Set<String>.of(store.statusFilter);
                  if (v == true) {
                    next.add(bucket);
                  } else {
                    next.remove(bucket);
                  }
                  setSheetState(() {});
                  store.setStatusFilter(next);
                },
              );
            }

            Widget prBucketTile(
              PullRequestBucket bucket,
              String label,
              IconData icon,
            ) {
              final selected = pullRequests.filter.contains(bucket);
              return CheckboxListTile(
                value: selected,
                dense: true,
                secondary: Icon(icon, size: 20),
                title: Text(label),
                onChanged: (value) {
                  final next = Set<PullRequestBucket>.of(pullRequests.filter);
                  if (value == true) {
                    next.add(bucket);
                  } else {
                    next.remove(bucket);
                  }
                  setSheetState(() {});
                  pullRequests.setFilter(next);
                },
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          ctx.l10n.sessionFilterTitle,
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (store.filtersActive || pullRequests.filtersActive)
                          TextButton(
                            onPressed: () {
                              setSheetState(() {});
                              store.setStatusFilter({});
                              store.setShowArchived(false);
                              pullRequests.setFilter({});
                            },
                            child: Text(ctx.l10n.sessionClearAll),
                          ),
                      ],
                    ),
                  ),
                  bucketTile(
                    'working',
                    ctx.l10n.sessionStatusWorking,
                    Icons.sync,
                  ),
                  bucketTile(
                    'attention',
                    ctx.l10n.sessionStatusAttention,
                    Icons.notification_important_outlined,
                  ),
                  bucketTile(
                    'idle',
                    ctx.l10n.sessionStatusIdle,
                    Icons.circle_outlined,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      ctx.l10n.sessionPullRequests,
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                  ),
                  prBucketTile(
                    PullRequestBucket.open,
                    ctx.l10n.sessionPrOpen,
                    Icons.call_made,
                  ),
                  prBucketTile(
                    PullRequestBucket.draft,
                    ctx.l10n.sessionPrDraft,
                    Icons.edit_outlined,
                  ),
                  prBucketTile(
                    PullRequestBucket.merged,
                    ctx.l10n.sessionPrMerged,
                    Icons.merge,
                  ),
                  prBucketTile(
                    PullRequestBucket.closed,
                    ctx.l10n.sessionPrClosed,
                    Icons.close,
                  ),
                  prBucketTile(
                    PullRequestBucket.none,
                    ctx.l10n.sessionPrNone,
                    Icons.remove,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      ctx.l10n.sessionSortTitle,
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                  ),
                  for (final entry in [
                    ('activity', ctx.l10n.sessionSortActivity, Icons.schedule),
                    (
                      'created',
                      ctx.l10n.sessionSortCreated,
                      Icons.event_outlined,
                    ),
                    ('tokens', ctx.l10n.sessionSortTokens, Icons.data_usage),
                  ])
                    ListTile(
                      dense: true,
                      leading: Icon(entry.$3, size: 20),
                      title: Text(entry.$2),
                      trailing: store.sortMode == entry.$1
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      onTap: () {
                        setSheetState(() {});
                        store.setSortMode(entry.$1);
                      },
                    ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: store.showArchived,
                    dense: true,
                    secondary: const Icon(Icons.inventory_2_outlined, size: 20),
                    title: Text(ctx.l10n.sessionArchiveView),
                    subtitle: Text(ctx.l10n.sessionArchiveViewDescription),
                    onChanged: (v) {
                      setSheetState(() {});
                      store.setShowArchived(v);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmDelete(SessionRow row) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.sessionDeleteTitle),
        content: Text(
          ctx.l10n.sessionDeleteDescription(
            row.title ?? ctx.l10n.sessionUntitled,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBatchDelete() async {
    final count = _selectedIds.length;
    if (count == 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionStore>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.sessionBatchDeleteTitle),
        content: Text(ctx.l10n.sessionBatchDeleteDescription(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.sessionConfirmDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ids = List<String>.from(_selectedIds);
    setState(() {
      _deleting = true;
    });
    try {
      final deletedCount = await session.deleteSessions(ids);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.sessionDeletedCount(deletedCount)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionDeleteFailed('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
          _selectMode = false;
          _selectedIds.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionStore>();
    context.select<SessionStore, int>(
      (store) => Object.hash(
        store.sessionListRevision,
        store.sidebarRevision,
        store.durableId,
        store.listHasMore,
        store.loadingMore,
      ),
    );
    final pullRequests = context.read<PullRequestStore>();
    context.select<PullRequestStore, int>((store) => store.projectionRevision);
    context.select<SubagentStore, int>((store) => store.projectionRevision);
    final rows = session.sessions ?? [];
    SessionRow? lastSession;
    for (final row in rows) {
      if (row.id == _lastSessionId) {
        lastSession = row;
        break;
      }
    }
    final unreadSignature = rows
        .map((row) => '${row.id}:${row.messageCount}:${row.lastMessageAt}')
        .join('|');
    if (_unreadRowsSignature != unreadSignature) {
      _unreadRowsSignature = unreadSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildUnreadCache(rows);
      });
    }

    final width = MediaQuery.sizeOf(context).width;
    final body = MobileSafeBody(child: _buildBody(context, rows, lastSession));
    return Scaffold(
      backgroundColor: HermesPalette.of(context).bg,
      appBar: AppBar(
        title: _selectMode
            ? Text(context.l10n.sessionSelectedCount(_selectedIds.length))
            : Text(context.l10n.sessionTitle),
        leading: _selectMode
            ? IconButton(
                tooltip: context.l10n.sessionCancelSelection,
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,
        actions: _selectMode
            ? [
                if (width >= HermesBreakpoints.navigation)
                  IconButton(
                    tooltip: context.l10n.sessionSelectAll,
                    icon: const Icon(Icons.select_all),
                    onPressed: () {
                      setState(() {
                        if (_selectedIds.length ==
                            rows.where((r) => !r.isDelegatedChild).length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(
                            rows
                                .where((r) => !r.isDelegatedChild)
                                .map((r) => r.id),
                          );
                        }
                      });
                    },
                  ),
                IconButton(
                  tooltip: context.l10n.sessionDeleteSelected,
                  icon: Icon(
                    Icons.delete_sweep,
                    color: _selectedIds.isNotEmpty ? HermesSemantic.red : null,
                  ),
                  onPressed: _selectedIds.isNotEmpty && !_deleting
                      ? () => _confirmBatchDelete()
                      : null,
                ),
              ]
            : [
                if (width >= HermesBreakpoints.navigation)
                  IconButton(
                    tooltip: context.l10n.sessionSelectMultiple,
                    icon: const Icon(Icons.checklist),
                    onPressed: () {
                      _recordInteraction();
                      setState(() => _selectMode = true);
                    },
                  ),
                // Desktop parity: `$sidebarGrouping` flat/project toggle.
                if (width >= HermesBreakpoints.navigation)
                  Builder(
                    builder: (context) {
                      final store = context.read<SessionStore>();
                      final projectMode = store.groupingMode == 'project';
                      return IconButton(
                        tooltip: projectMode
                            ? context.l10n.sessionGroupByTime
                            : context.l10n.sessionGroupByProject,
                        icon: Icon(
                          projectMode
                              ? Icons.account_tree
                              : Icons.account_tree_outlined,
                        ),
                        onPressed: () {
                          _recordInteraction();
                          store.setGroupingMode(
                            projectMode ? 'flat' : 'project',
                          );
                          if (!projectMode) _projectTree.refresh();
                        },
                      );
                    },
                  ),
                // Desktop parity: persistent filter menu (status buckets +
                // archived view), badges the icon while filters are active.
                if (width >= HermesBreakpoints.navigation)
                  Builder(
                    builder: (context) {
                      final store = context.read<SessionStore>();
                      return IconButton(
                        tooltip: context.l10n.sessionFilterTitle,
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              store.filtersActive || pullRequests.filtersActive
                                  ? Icons.filter_alt
                                  : Icons.filter_alt_outlined,
                            ),
                            if (store.filtersActive ||
                                pullRequests.filtersActive)
                              const Positioned(
                                right: -2,
                                top: -2,
                                child: HermesBadge(dot: true),
                              ),
                          ],
                        ),
                        onPressed: () {
                          _recordInteraction();
                          _showFilterMenu(context, store, pullRequests);
                        },
                      );
                    },
                  ),
                PopupMenuButton<String>(
                  tooltip: context.l10n.commonMore,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    _recordInteraction();
                    if (value == 'select') {
                      setState(() => _selectMode = true);
                    } else if (value == 'history') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                    } else if (value == 'manage') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SessionsScreen(),
                        ),
                      );
                    } else if (value == 'refresh') {
                      _load();
                    } else if (value == 'deep-search') {
                      _showSearch(context, rows);
                    } else if (value == 'filter') {
                      _showFilterMenu(context, session, pullRequests);
                    }
                  },
                  itemBuilder: (menuContext) => [
                    PopupMenuItem(
                      value: 'deep-search',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.manage_search),
                        title: Text(menuContext.l10n.sessionSearchMessages),
                      ),
                    ),
                    if (width < HermesBreakpoints.navigation)
                      PopupMenuItem(
                        value: 'filter',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.filter_alt_outlined),
                          title: Text(menuContext.l10n.sessionFilterTitle),
                        ),
                      ),
                    if (width < HermesBreakpoints.navigation)
                      PopupMenuItem(
                        value: 'select',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.checklist),
                          title: Text(menuContext.l10n.sessionSelectSessions),
                        ),
                      ),
                    PopupMenuItem(
                      value: 'history',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history),
                        title: Text(menuContext.l10n.sessionHistoryArchive),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'manage',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune),
                        title: Text(menuContext.l10n.sessionManage),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'refresh',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.refresh),
                        title: Text(menuContext.l10n.commonRefresh),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: context.l10n.sessionNew,
                  onPressed: () {
                    _recordInteraction();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NewSessionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
      ),
      body: width >= 1200
          ? Row(
              children: [
                SizedBox(width: 320, child: body),
                const VerticalDivider(width: 1),
                Expanded(
                  child: HermesEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: context.l10n.sessionSelectTitle,
                    description: context.l10n.sessionSelectDescription,
                  ),
                ),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width >= 600 && width < 840 ? 720 : double.infinity,
                ),
                child: body,
              ),
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<SessionRow> rows,
    SessionRow? lastSession,
  ) {
    final session = context.read<SessionStore>();
    // Honest skeleton: show placeholder content until the first real list
    // resolves (WebUI #4717 equivalent — skeleton based on known count).
    if (_loading && rows.isEmpty) {
      return _buildSkeleton(context);
    }
    if (_error != null && rows.isEmpty) {
      return HermesErrorState(description: _error, onRetry: _load);
    }
    if (rows.isEmpty) {
      return HermesEmptyState(
        icon: Icons.chat_bubble_outline,
        title: context.l10n.sessionEmptyTitle,
        description: context.l10n.sessionEmptyDescription,
        primaryLabel: context.l10n.sessionNew,
        onPrimary: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NewSessionScreen())),
      );
    }
    // Desktop parity: `$sidebarGrouping === 'project'` renders the
    // authoritative backend tree instead of time buckets.
    if (session.groupingMode == 'project' && !_selectMode) {
      return _buildProjectTreeBody(context, session);
    }
    final projection = _sessionProjection(rows);
    final projectedGroups = projection.groups;
    final groups = _TimeGroup.values
        .where((group) => projectedGroups[group]?.isNotEmpty == true)
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: _load,
      // Spec §186: virtualize with slivers so 1000+ sessions scroll smoothly.
      child: NotificationListener<UserScrollNotification>(
        onNotification: (_) {
          _recordInteraction();
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _sessionControls(session)),
            // P5-3: "continue last session" banner (state restoration).
            if (lastSession != null && session.durableId == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HermesSpacing.md,
                    HermesSpacing.md,
                    HermesSpacing.md,
                    0,
                  ),
                  child: _restoreBanner(context, lastSession),
                ),
              ),
            for (final g in groups) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: HermesMobileSectionLabel(
                    title: _groupTitle(context, g),
                  ),
                ),
              ),
              _buildGroupSliver(context, projectedGroups[g]!, g),
            ],
            if (groups.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: HermesEmptyState(
                  icon: Icons.search_off,
                  title: context.l10n.sessionNoMatchesTitle,
                  description: context.l10n.sessionNoMatchesDescription,
                  primaryLabel: context.l10n.sessionClearFilters,
                  onPrimary: () {
                    _queryController.clear();
                    setState(() => _query = '');
                    session.setStatusFilter({});
                    session.setShowArchived(false);
                  },
                ),
              ),
            // Desktop parity: manual "load more" row driven by the server's
            // paging window (has_more) rather than scroll guessing.
            if (session.listHasMore && !_selectMode)
              SliverToBoxAdapter(child: _loadMoreRow(context, session)),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  Widget _sessionControls(SessionStore session) {
    final palette = HermesPalette.of(context);
    final archived = session.showArchived;
    final filter = session.statusFilter;

    Widget pill({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: selected ? palette.accent : palette.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? palette.accent : palette.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : palette.text3,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    void select(Set<String> buckets, {bool showArchived = false}) {
      _recordInteraction();
      session.setStatusFilter(buckets);
      session.setShowArchived(showArchived);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('session-inline-search'),
            controller: _queryController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: context.l10n.sessionSearchTitleHint,
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.sessionClearSearch,
                      onPressed: () {
                        _queryController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close, size: 17),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                pill(
                  label: context.l10n.sessionFilterAll,
                  selected: filter.isEmpty && !archived,
                  onTap: () => select({}),
                ),
                pill(
                  label: context.l10n.sessionStatusWorking,
                  selected: filter.length == 1 && filter.contains('working'),
                  onTap: () => select({'working'}),
                ),
                pill(
                  label: context.l10n.sessionFilterApproval,
                  selected: filter.length == 1 && filter.contains('attention'),
                  onTap: () => select({'attention'}),
                ),
                pill(
                  label: context.l10n.sessionStatusIdle,
                  selected: filter.length == 1 && filter.contains('idle'),
                  onTap: () => select({'idle'}),
                ),
                pill(
                  label: context.l10n.sessionGroupArchived,
                  selected: archived,
                  onTap: () => select({}, showArchived: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadMoreRow(BuildContext context, SessionStore session) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: session.loadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: () async {
                  _recordInteraction();
                  await session.loadMoreSessions();
                  if (!context.mounted) return;
                  await context.read<PullRequestStore>().refreshForSessions(
                    session.sessions ?? const <SessionRow>[],
                  );
                },
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text(context.l10n.sessionLoadMore),
              ),
      ),
    );
  }

  Future<void> _reorderPinned(
    List<SessionRow> rows,
    _TimeGroup group,
    int oldIndex,
    int newIndex,
  ) async {
    final session = context.read<SessionStore>();
    final pinned = _rowsInGroup(rows, group);
    // onReorderItem already adjusts newIndex for the removed item.
    final moved = pinned.removeAt(oldIndex);
    pinned.insert(newIndex, moved);
    // Persist durable lineage ids so rotated runtime ids keep their order.
    await session.setPinnedOrder(
      pinned.map((r) => r.lineageRootId ?? r.id).toList(),
    );
  }

  // ─────────── Desktop parity: project grouping tree ───────────

  Widget _buildProjectTreeBody(BuildContext context, SessionStore session) {
    return ChangeNotifierProvider.value(
      value: _projectTree,
      child: Consumer<ProjectTreeStore>(
        builder: (context, tree, _) {
          if (tree.scope != null) {
            return _buildProjectDrillIn(context, session, tree);
          }
          return _buildProjectOverview(context, session, tree);
        },
      ),
    );
  }

  /// Overview: project cards (icon/label/count) → repos → lanes → previews.
  Widget _buildProjectOverview(
    BuildContext context,
    SessionStore session,
    ProjectTreeStore tree,
  ) {
    if (tree.loading && !tree.hasData) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (tree.error != null && !tree.hasData) {
      return HermesErrorState(description: tree.error, onRetry: tree.refresh);
    }
    final projects = tree.sortedProjects
        .where((p) => p.sessionCount > 0 || p.isNoProject)
        .toList();
    if (projects.isEmpty) {
      return HermesEmptyState(
        icon: Icons.folder_outlined,
        title: context.l10n.sessionNoProjectsTitle,
        description: context.l10n.sessionNoProjectsDescription,
        primaryLabel: context.l10n.sessionNew,
        onPrimary: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NewSessionScreen())),
      );
    }
    // Pinned rows stay on top in project mode too (desktop parity).
    final rows = session.sessions ?? const <SessionRow>[];
    final pinned = _rowsInGroup(rows, _TimeGroup.pinned);
    return RefreshIndicator(
      onRefresh: () async {
        _recordInteraction();
        await Future.wait([_load(), tree.refresh()]);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (pinned.isNotEmpty) ...[
            HermesSectionHeader(title: _groupTitle(context, _TimeGroup.pinned)),
            for (final row in pinned)
              _row(context, row, group: _TimeGroup.pinned),
          ],
          for (final project in projects)
            _projectCard(context, session, tree, project),
        ],
      ),
    );
  }

  Widget _projectCard(
    BuildContext context,
    SessionStore session,
    ProjectTreeStore tree,
    ProjectTreeNode project,
  ) {
    final open = tree.nodeOpen(
      project.id,
      defaultOpen: project.sessionCount <= 8,
    );
    final color = _projectColor(project);
    return HermesGlassCard(
      radius: HermesRadius.card,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(HermesRadius.card),
            onTap: () => tree.toggleNode(
              project.id,
              defaultOpen: project.sessionCount <= 8,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      project.isNoProject
                          ? Icons.home_outlined
                          : Icons.folder_outlined,
                      size: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _projectSubtitle(context, project),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => tree.enterProject(project.id),
                    child: Text(
                      context.l10n.sessionProjectEnter,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            _projectExpandedContent(context, session, tree, project),
          ],
        ],
      ),
    );
  }

  Widget _projectExpandedContent(
    BuildContext context,
    SessionStore session,
    ProjectTreeStore tree,
    ProjectTreeNode project,
  ) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    // Repo → lane headers with counts (desktop overview parity: lane
    // sessions stay unhydrated in overview; previews carry recent rows).
    for (final repo in project.repos) {
      if (project.repos.length > 1 || repo.label != project.label) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 12, 2),
            child: Row(
              children: [
                Icon(
                  Icons.commit,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    repo.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      for (final lane in repo.groups) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 4, 12, 0),
            child: Row(
              children: [
                Icon(
                  lane.isKanban
                      ? Icons.view_kanban_outlined
                      : lane.isMain
                      ? Icons.home_outlined
                      : Icons.call_split,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lane.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${lane.sessions.length}${lane.sessions.isEmpty ? '' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    // Preview sessions (desktop previewSessions parity, latest N rows).
    for (final preview in project.previewSessions) {
      rows.add(_previewRow(context, session, preview));
    }
    if (rows.isEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
          child: Text(
            context.l10n.sessionProjectNoSessions,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    rows.add(const SizedBox(height: 8));
    return Column(children: rows);
  }

  Widget _previewRow(
    BuildContext context,
    SessionStore session,
    SessionRow row,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _open(row),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 6, 12, 6),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                row.title?.isNotEmpty == true
                    ? row.title!
                    : context.l10n.sessionUntitled,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text(
              _fmtTime(
                context,
                row.lastMessageAt != null
                    ? DateTime.fromMillisecondsSinceEpoch(row.lastMessageAt!)
                    : row.startedAt,
              ),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Drill-in view (desktop `$projectScope` + EnteredProjectContent parity):
  /// hydrated lanes with full session rows, filter-aware, tap to resume.
  Widget _buildProjectDrillIn(
    BuildContext context,
    SessionStore session,
    ProjectTreeStore tree,
  ) {
    final project = tree.scopedProject;
    return Column(
      children: [
        Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.sessionProjectBack,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () {
                    _recordInteraction();
                    tree.exitProject();
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    project?.label ?? context.l10n.featureProjects,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.commonRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () {
                    _recordInteraction();
                    if (tree.scope != null) {
                      tree.enterProject(tree.scope!, persist: false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: tree.scopeLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : tree.scopeError != null
              ? HermesErrorState(
                  description: tree.scopeError,
                  onRetry: () {
                    final scope = tree.scope;
                    if (scope != null) {
                      tree.enterProject(scope, persist: false);
                    }
                  },
                )
              : project == null
              ? HermesEmptyState(
                  icon: Icons.folder_off_outlined,
                  title: context.l10n.sessionProjectUnavailable,
                )
              : _buildDrillInList(context, session, project),
        ),
      ],
    );
  }

  Widget _buildDrillInList(
    BuildContext context,
    SessionStore session,
    ProjectTreeNode project,
  ) {
    final rows = <Widget>[];
    for (final repo in project.repos) {
      if (project.repos.length > 1) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              repo.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      for (final lane in repo.groups) {
        if (repo.groups.length > 1) {
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 2),
              child: Row(
                children: [
                  Icon(
                    lane.isKanban
                        ? Icons.view_kanban_outlined
                        : lane.isMain
                        ? Icons.home_outlined
                        : Icons.call_split,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lane.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${lane.sessions.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // Lane sessions are hydrated (time-descending); filters still apply.
        final laneRows = lane.sessions.where(_rowMatchesFilters);
        for (final row in laneRows) {
          rows.add(_row(context, row, group: _TimeGroup.older));
        }
      }
    }
    if (rows.isEmpty) {
      return HermesEmptyState(
        icon: Icons.chat_bubble_outline,
        title: context.l10n.sessionProjectNoSessions,
      );
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
  }

  Color _projectColor(ProjectTreeNode project) {
    final hex = project.color;
    if (hex != null && hex.isNotEmpty) {
      final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
      if (parsed != null) {
        return Color(parsed < 0x1000000 ? 0xFF000000 | parsed : parsed);
      }
    }
    // Deterministic hue by label (desktop profileColor hash parity).
    final hue = (project.label.hashCode % 360 + 360) % 360;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();
  }

  String _projectSubtitle(BuildContext context, ProjectTreeNode project) {
    final parts = <String>[
      context.l10n.sessionProjectSessionCount(project.sessionCount),
    ];
    if (project.totalTokens > 0) {
      parts.add('${(project.totalTokens / 1000).toStringAsFixed(1)}k tokens');
    }
    if (project.totalCostUsd > 0) {
      parts.add('\$${project.totalCostUsd.toStringAsFixed(2)}');
    }
    return parts.join(' · ');
  }

  Widget _buildSkeleton(BuildContext context) {
    // Mirrors WebUI showSessionListSkeleton: ~8 placeholder rows with pulse.
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHigh;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 8,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => HermesGlassCard(
        radius: HermesRadius.card,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    margin: const EdgeInsets.only(right: 64),
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 140,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subagentAge(BuildContext context, DateTime when) {
    final difference = DateTime.now().difference(when.toLocal());
    if (difference.inMinutes < 1) return context.l10n.timeJustNow;
    if (difference.inHours < 1) {
      return context.l10n.timeMinutesAgo(difference.inMinutes);
    }
    if (difference.inDays < 1) {
      return context.l10n.timeHoursAgo(difference.inHours);
    }
    return context.l10n.timeDaysAgo(difference.inDays);
  }

  Widget _subagentRow(BuildContext context, SessionRow child) {
    final runtime = context.select<SubagentStore, SubagentNode?>(
      (store) => store.runtimeForChild(child.id),
    );
    final running =
        child.effectivelyStreaming ||
        runtime?.status == 'running' ||
        runtime?.status == 'queued';
    final when =
        runtime?.updatedAt ??
        runtime?.startedAt ??
        (child.lastMessageAt == null
            ? child.startedAt
            : DateTime.fromMillisecondsSinceEpoch(child.lastMessageAt!));
    final age = when == null ? '' : _subagentAge(context, when);
    final title = child.title?.trim();
    final metadata = [
      if (child.model?.isNotEmpty == true) child.model!,
      if (child.messageCount != null)
        context.l10n.sessionMessageCount(child.messageCount!),
    ].join(' · ');
    return Tooltip(
      message: title?.isNotEmpty == true
          ? title!
          : context.l10n.sessionDesktopFallback,
      child: InkWell(
        key: ValueKey('subagent-${child.id}'),
        onTap: () => _openSubagent(child),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          child: Row(
            children: [
              const Icon(Icons.subdirectory_arrow_right, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title?.isNotEmpty == true
                          ? title!
                          : context.l10n.sessionDesktopFallback,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (metadata.isNotEmpty)
                      Text(
                        metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              if (running) ...[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ],
              if (_unreadCache[child.id] == true) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: HermesSemantic.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              if ((_childrenByParent[child.id] ?? const <SessionRow>[])
                  .isNotEmpty)
                IconButton(
                  tooltip: _expandedSessionIds.contains(child.id)
                      ? context.l10n.sessionCollapseChildren
                      : context.l10n.sessionExpandChildren,
                  icon: Icon(
                    _expandedSessionIds.contains(child.id)
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      if (!_expandedSessionIds.add(child.id)) {
                        _expandedSessionIds.remove(child.id);
                      }
                    });
                  },
                ),
              if (age.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(age, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionTitleBlock(
    BuildContext context,
    SessionRow s, {
    required bool unread,
  }) {
    final location = sessionLocationLabel(s);
    final activity = sessionActivityTime(s);
    final preview = s.preview?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (s.pinned) ...[
              Icon(
                Icons.push_pin,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                s.title?.isNotEmpty == true
                    ? s.title!
                    : context.l10n.sessionUntitled,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            SessionMetaBadges(row: s),
          ],
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: context.l10n.sessionMessageCount(s.messageCount ?? 0),
              ),
              const TextSpan(text: ' · '),
              TextSpan(text: _fmtTime(context, activity)),
              if (preview.isNotEmpty) ...[
                const TextSpan(text: ' · '),
                TextSpan(
                  text: preview,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ],
            style: Theme.of(context).textTheme.bodySmall,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          [
            context.l10n.sessionToolCount(s.toolCallCount),
            '${s.apiCallCount} API',
            '${compactSessionTokenCount(s.totalTokens)} Token',
            if ((s.actualCostUsd ?? s.estimatedCostUsd) > 0)
              '\$${(s.actualCostUsd ?? s.estimatedCostUsd).toStringAsFixed(4)}',
            if (s.duration != null)
              formatSessionDurationLocalized(context, s.duration!),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 2),
        Text(
          [
            s.displaySource,
            if (s.model?.isNotEmpty == true) s.model!,
            if (s.profile?.isNotEmpty == true) s.profile!,
            if (s.handoffState?.isNotEmpty == true)
              context.l10n.sessionHandoff(s.handoffState!),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (location != null) ...[
          const SizedBox(height: 2),
          Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, SessionRow s, {required _TimeGroup group}) {
    final subagents = context.read<SubagentStore>();
    context.select<SubagentStore, int>((store) => store.projectionRevision);
    final durableCount =
        _projectedDurableCount[s.id] ?? _durableDescendantCount(s.id);
    final childrenCount =
        durableCount +
        (_projectedRuntimeCount[s.id] ??
            _runtimeDescendantCount(s.id, subagents));
    final expanded = _expandedSessionIds.contains(s.id);
    final sessionColor = context.select<SessionAppearanceStore, Color?>(
      (store) => store.colorFor(s.id),
    );
    final unread =
        _unreadCache[s.id] == true ||
        (_projectedUnread[s.id] ?? _hasUnreadDescendant(s));
    final attention = s.needsAttention;
    final working =
        !attention &&
        (s.isActivelyWorking ||
            (_projectedRunning[s.id] ?? _hasRunningDescendant(s, subagents)));
    final selected = _selectedIds.contains(s.id);
    // In select mode, wrap the row with a tap-to-toggle handler and
    // show a leading checkbox instead of the swipe-to-dismiss gesture.
    if (_selectMode) {
      return HermesGlassCard(
        radius: HermesRadius.card,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: () {
          setState(() {
            if (selected) {
              _selectedIds.remove(s.id);
              if (_selectedIds.isEmpty) _selectMode = false;
            } else {
              _selectedIds.add(s.id);
            }
          });
        },
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedIds.add(s.id);
                  } else {
                    _selectedIds.remove(s.id);
                    if (_selectedIds.isEmpty) _selectMode = false;
                  }
                });
              },
            ),
            const SizedBox(width: 4),
            Expanded(child: _sessionTitleBlock(context, s, unread: unread)),
            const SizedBox(width: 8),
            SessionStatusIndicator(attention: attention, working: working),
          ],
        ),
      );
    }
    return Dismissible(
      key: ValueKey('session-${s.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        color: HermesSemantic.blue.withValues(alpha: 0.8),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.push_pin, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: HermesSemantic.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        _recordInteraction();
        final session = context.read<SessionStore>();
        if (direction == DismissDirection.endToStart) {
          final confirmed = await _confirmDelete(s);
          if (confirmed == true) {
            await session.delete(s.id);
            return true;
          }
          return false;
        }
        await session.setPinned(s.id, !s.pinned);
        return false;
      },
      child: HermesGlassCard(
        radius: HermesMobileMetrics.groupRadius,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        onTap: () => _open(s),
        onLongPress: () {
          _recordInteraction();
          // Long press enters multi-select mode (WebUI parity: long-press
          // a sidebar row to start bulk selection).
          setState(() {
            _selectMode = true;
            _selectedIds.add(s.id);
          });
        },
        padding: const EdgeInsets.all(14),
        child: SessionCard(
          session: s,
          attention: attention,
          working: working,
          unread: unread,
          sessionColor: sessionColor,
          childrenCount: childrenCount,
          expanded: expanded,
          onToggleExpand: () => setState(() {
            if (expanded) {
              _expandedSessionIds.remove(s.id);
            } else {
              _expandedSessionIds.add(s.id);
            }
          }),
          onMore: () => _showMenu(s),
        ),
      ),
    );
  }

  void _showSearch(BuildContext context, List<SessionRow> rows) {
    final ctrl = TextEditingController();
    var results = <SessionRow>[];
    var searching = false;
    String? error;
    var tag = '';
    var rangeDays = 0;
    var requestVersion = 0;
    ApiClient? resultsApi;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          Future<void> search() async {
            final query = ctrl.text.trim();
            if (query.isEmpty) return;
            final version = ++requestVersion;
            setSheet(() {
              searching = true;
              error = null;
            });
            try {
              final api = context.read<SessionStore>().connection.api;
              if (api == null) {
                throw StateError(sheetCtx.l10n.sessionServerNotConnected);
              }
              final next = await api.searchSessions(query, limit: 100);
              if (!sheetCtx.mounted ||
                  version != requestVersion ||
                  !identical(
                    api,
                    context.read<SessionStore>().connection.api,
                  )) {
                return;
              }
              setSheet(() {
                results = next;
                resultsApi = api;
              });
            } catch (e) {
              if (!sheetCtx.mounted || version != requestVersion) return;
              setSheet(() => error = '$e');
            } finally {
              if (sheetCtx.mounted && version == requestVersion) {
                setSheet(() => searching = false);
              }
            }
          }

          final knownTags = <String>{
            for (final row in [...rows, ...results]) ...row.tags,
          }.toList()..sort();
          final now = DateTime.now();
          final filtered = results.where((row) {
            if (tag.isNotEmpty && !row.tags.contains(tag)) return false;
            if (rangeDays == 0) return true;
            final at = row.lastMessageAt == null
                ? row.startedAt
                : DateTime.fromMillisecondsSinceEpoch(row.lastMessageAt!);
            return at != null &&
                now.difference(at.toLocal()).inDays < rangeDays;
          }).toList();

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * .78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheetCtx.l10n.sessionDeepSearchTitle,
                      style: Theme.of(sheetCtx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => search(),
                            decoration: InputDecoration(
                              hintText: sheetCtx.l10n.sessionDeepSearchHint,
                              prefixIcon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: searching ? null : search,
                          child: Text(sheetCtx.l10n.commonSearch),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final days in const [0, 1, 7, 30])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(switch (days) {
                                  0 => sheetCtx.l10n.sessionTimeAll,
                                  1 => sheetCtx.l10n.dateToday,
                                  _ => sheetCtx.l10n.sessionWithinDays(days),
                                }),
                                selected: rangeDays == days,
                                onSelected: (_) =>
                                    setSheet(() => rangeDays = days),
                              ),
                            ),
                          if (knownTags.isNotEmpty)
                            PopupMenuButton<String>(
                              tooltip: sheetCtx.l10n.sessionFilterByTag,
                              onSelected: (value) =>
                                  setSheet(() => tag = value),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: '',
                                  child: Text(sheetCtx.l10n.sessionAllTags),
                                ),
                                for (final value in knownTags)
                                  PopupMenuItem(
                                    value: value,
                                    child: Text('#$value'),
                                  ),
                              ],
                              child: Chip(
                                avatar: const Icon(
                                  Icons.sell_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  tag.isEmpty
                                      ? sheetCtx.l10n.sessionAllTags
                                      : '#$tag',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (searching) const LinearProgressIndicator(),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          sheetCtx.l10n.sessionSearchFailed(error!),
                          style: TextStyle(
                            color: Theme.of(sheetCtx).colorScheme.error,
                          ),
                        ),
                      ),
                    if (!searching && results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          sheetCtx.l10n.sessionSearchResultCount(
                            results.length,
                            filtered.length,
                          ),
                        ),
                      ),
                    Expanded(
                      child: results.isEmpty && !searching
                          ? Center(
                              child: Text(sheetCtx.l10n.sessionSearchPrompt),
                            )
                          : filtered.isEmpty
                          ? Center(
                              child: Text(
                                sheetCtx.l10n.sessionSearchNoFilteredResults,
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final row = filtered[index];
                                final snippet =
                                    row.contentSnippet ?? row.preview;
                                return ListTile(
                                  leading: Icon(
                                    row.matchMessageId == null
                                        ? Icons.chat_bubble_outline
                                        : Icons.my_location_outlined,
                                  ),
                                  title: Text(
                                    row.title?.isNotEmpty == true
                                        ? row.title!
                                        : sheetCtx.l10n.sessionUntitled,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (snippet != null && snippet.isNotEmpty)
                                        Text(
                                          snippet,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (row.tags.isNotEmpty)
                                        Text(
                                          row.tags
                                              .map((value) => '#$value')
                                              .join(' '),
                                        ),
                                    ],
                                  ),
                                  trailing: row.matchMessageId == null
                                      ? null
                                      : const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                        ),
                                  onTap: () async {
                                    final currentApi = context
                                        .read<SessionStore>()
                                        .connection
                                        .api;
                                    if (resultsApi == null ||
                                        !identical(resultsApi, currentApi)) {
                                      setSheet(() {
                                        results = [];
                                        resultsApi = null;
                                        error =
                                            sheetCtx.l10n.backendDisconnected;
                                      });
                                      return;
                                    }
                                    Navigator.of(sheetCtx).pop();
                                    await _openSearchResult(
                                      row,
                                      query: ctrl.text.trim(),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSearchResult(
    SessionRow row, {
    required String query,
  }) async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await session.resumeSession(row.id, profile: row.profile);
      await session.setSessionViewedCount(row.id, row.messageCount ?? 0);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            initialMessageId: row.matchMessageId,
            initialSearchQuery: query,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.sessionSearchFailed('$e'))),
      );
    }
  }

  String _fmtTime(BuildContext context, DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return context.l10n.dateMonthDay(local.month, local.day);
  }
}
