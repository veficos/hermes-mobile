import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../core/connection_reload_mixin.dart';
import '../core/performance_metrics.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/session_store.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/session/session_list_meta.dart';
import '../widgets/session/session_rich_card.dart';
import '../widgets/session/session_detail_panel.dart';
import 'chat_screen.dart';
import 'sessions_screen.dart';

/// Stored session history (durable ids only) + the session management sheet
/// (D8: rename / archive / context usage / compress).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with ConnectionReloadMixin<HistoryScreen> {
  static const _bucketPinned = 'pinned';
  static const _bucketToday = 'today';
  static const _bucketYesterday = 'yesterday';
  static const _bucketThisWeek = 'this-week';
  static const _bucketLastWeek = 'last-week';
  static const _bucketEarlier = 'earlier';
  bool _loading = false;
  String? _error;
  bool _showArchived = false;
  final _searchCtrl = TextEditingController();
  final Set<String> _collapsedGroups = <String>{};
  final Set<String> _expandedSessionIds = <String>{};
  SessionRow? _selectedRow;
  final List<SessionRow> _rows = [];
  bool _hasMore = false;
  int? _total;
  Timer? _searchDebounce;
  int _loadGeneration = 0;
  ApiClient? _loadedApi;
  List<SessionRow>? _projectedRowsIdentity;
  late Map<String, List<SessionRow>> _cachedChildren = const {};
  late List<SessionRow> _cachedRoots = const [];
  late List<_HistoryGroup> _cachedGroups = const [];
  int? _cachedGroupDay;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    setState(() {
      _rows.clear();
      _selectedRow = null;
      _loadedApi = null;
      _hasMore = false;
      _total = null;
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _searchDebounce?.cancel();
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchCtrl.text.trim();
      final includeArchived = _showArchived;
      final page = query.isEmpty
          ? await api.listSessionsPage(
              limit: 50,
              includeArchived: includeArchived,
            )
          : SessionPage(
              sessions: await api.searchSessions(
                query,
                limit: 100,
                includeArchived: includeArchived,
              ),
              total: null,
              offset: 0,
              hasMore: false,
            );
      if (mounted &&
          generation == _loadGeneration &&
          query == _searchCtrl.text.trim() &&
          includeArchived == _showArchived &&
          identical(api, connection.api)) {
        setState(() {
          _rows
            ..clear()
            ..addAll(page.sessions);
          _projectedRowsIdentity = null;
          _hasMore = page.hasMore;
          _total = page.total;
          _loadedApi = api;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, connection.api)) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final connection = context.read<ConnectionStore>();
    final api = _loadedApi;
    if (api == null ||
        !identical(api, connection.api) ||
        _loading ||
        !_hasMore) {
      return;
    }
    final generation = _loadGeneration;
    final includeArchived = _showArchived;
    final offset = _rows.length;
    setState(() => _loading = true);
    try {
      final page = await api.listSessionsPage(
        limit: 50,
        offset: offset,
        includeArchived: includeArchived,
      );
      if (mounted &&
          generation == _loadGeneration &&
          includeArchived == _showArchived &&
          offset == _rows.length &&
          identical(api, connection.api)) {
        setState(() {
          final knownIds = _rows.map((row) => row.id).toSet();
          _rows.addAll(page.sessions.where((row) => knownIds.add(row.id)));
          _projectedRowsIdentity = null;
          _hasMore = page.hasMore;
          _total = page.total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, connection.api)) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openSession(SessionRow row) async {
    final session = context.read<SessionStore>();
    final connection = context.read<ConnectionStore>();
    final api = _loadedApi;
    if (api == null || !identical(api, connection.api)) return;
    try {
      requireActiveApi(context, connection, api);
      await session.resumeSession(row.id, profile: row.profile);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } catch (e) {
      if (!mounted || !identical(api, connection.api)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.historyResumeFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The private backing list is never exposed outside this State. Keeping
    // its identity stable lets the adjacency projection survive unrelated
    // rebuilds (selection, theme, progress indicators).
    final rows = _rows;
    final width = MediaQuery.sizeOf(context).width;
    final content = _buildBody(context, rows);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.historyTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.historyManageSessions,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SessionsScreen()));
            },
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: _showArchived
                ? context.l10n.historyHideArchived
                : context.l10n.historyShowArchived,
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _load();
            },
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: width >= 1200
          ? Row(
              children: [
                Expanded(child: content),
                const VerticalDivider(width: 1),
                SizedBox(width: 320, child: _detailPanel(context)),
              ],
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width >= 600 && width < 840 ? 720 : double.infinity,
                ),
                child: content,
              ),
            ),
    );
  }

  Widget _detailPanel(BuildContext context) {
    final row = _selectedRow;
    if (row == null) {
      return HermesEmptyState(
        icon: Icons.touch_app_outlined,
        title: context.l10n.historySelectTitle,
        description: context.l10n.historySelectDescription,
      );
    }
    return SessionDetailPanel(
      row: row,
      onOpen: () => _openSession(row),
      onManage: () => _showManageSheet(row),
    );
  }

  Widget _buildBody(BuildContext context, List<SessionRow> rows) {
    if (_loading && rows.isEmpty) {
      return HermesLoadingState(label: context.l10n.historyLoading);
    }
    if (_error != null && rows.isEmpty) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    final filtered = _filterRows(rows);
    final groups = _groupRows(filtered);
    final visibleItems = _projectVisibleItems(groups);
    return Column(
      children: [
        if (_error != null)
          MaterialBanner(
            content: Text(
              _error == connectionOfflineErrorCode
                  ? context.l10n.backendDisconnected
                  : _error!,
            ),
            actions: [
              TextButton(
                onPressed: _load,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SearchBar(
            controller: _searchCtrl,
            hintText: context.l10n.historySearchHint,
            leading: const Icon(Icons.search, size: 20),
            trailing: [
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  tooltip: context.l10n.historyClearSearch,
                  onPressed: _searchCtrl.clear,
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Text(
                    rows.isEmpty
                        ? context.l10n.historyEmpty
                        : context.l10n.historyNoMatches,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: visibleItems.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < visibleItems.length) {
                        final item = visibleItems[index];
                        if (item is _HistoryHeaderItem) {
                          return _buildGroupHeader(context, item);
                        }
                        final session = item as _HistorySessionItem;
                        return _buildSessionRow(
                          context,
                          session.row,
                          key: ValueKey('history-${session.row.id}'),
                          depth: session.depth,
                          hasChildren: session.hasChildren,
                          expanded: session.expanded,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _loadMore,
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            _total == null
                                ? context.l10n.historyLoadMore
                                : context.l10n.historyLoadMoreCount(
                                    _rows.length,
                                    _total!,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  List<SessionRow> _filterRows(List<SessionRow> rows) {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return rows;
    // Search results are already filtered by the server. Re-scanning every
    // title/snippet/tag here doubled the work and could discard matches from
    // server-only indexed fields. The server also returns lineage context.
    return rows;
  }

  List<_HistoryGroup> _groupRows(List<SessionRow> rows) {
    final now = DateTime.now();
    final localNow = now.toLocal();
    final dayKey = localNow.year * 10000 + localNow.month * 100 + localNow.day;
    if (!identical(_projectedRowsIdentity, rows) || _cachedGroupDay != dayKey) {
      final byId = {for (final row in rows) row.id: row};
      final children = <String, List<SessionRow>>{};
      for (final row in rows) {
        final parentId = row.parentSessionId;
        if (parentId != null && byId.containsKey(parentId)) {
          (children[parentId] ??= <SessionRow>[]).add(row);
        }
      }
      _cachedChildren = children;
      _cachedRoots = rows
          .where(
            (row) =>
                row.parentSessionId == null ||
                !byId.containsKey(row.parentSessionId),
          )
          .toList(growable: false);
      final buckets = <String, List<SessionRow>>{};
      for (final root in _cachedRoots) {
        final label = root.pinned ? _bucketPinned : _dateBucket(root.startedAt);
        (buckets[label] ??= <SessionRow>[]).add(root);
      }
      const order = [
        _bucketPinned,
        _bucketToday,
        _bucketYesterday,
        _bucketThisWeek,
        _bucketLastWeek,
        _bucketEarlier,
      ];
      _cachedGroups = [
        for (final label in order)
          if (buckets[label]?.isNotEmpty == true)
            _HistoryGroup(label, buckets[label]!),
      ];
      _projectedRowsIdentity = rows;
      _cachedGroupDay = dayKey;
    }
    return _cachedGroups;
  }

  String _dateBucket(DateTime? value) {
    if (value == null) return _bucketEarlier;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = value.toLocal();
    final day = DateTime(date.year, date.month, date.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return _bucketToday;
    if (days == 1) return _bucketYesterday;
    if (days < 7) return _bucketThisWeek;
    if (days < 14) return _bucketLastWeek;
    return _bucketEarlier;
  }

  String _bucketLabel(BuildContext context, String bucket) => switch (bucket) {
    _bucketPinned => context.l10n.historyPinned,
    _bucketToday => context.l10n.historyToday,
    _bucketYesterday => context.l10n.historyYesterday,
    _bucketThisWeek => context.l10n.historyThisWeek,
    _bucketLastWeek => context.l10n.historyLastWeek,
    _ => context.l10n.historyEarlier,
  };

  List<_HistoryVisibleItem> _projectVisibleItems(List<_HistoryGroup> groups) {
    final started = Stopwatch()..start();
    final result = <_HistoryVisibleItem>[];
    void appendNode(SessionRow row, int depth, Set<String> path) {
      if (!path.add(row.id)) return;
      final children = _cachedChildren[row.id] ?? const <SessionRow>[];
      final expanded = _expandedSessionIds.contains(row.id);
      result.add(
        _HistorySessionItem(
          row,
          depth: depth,
          hasChildren: children.isNotEmpty,
          expanded: expanded,
        ),
      );
      if (expanded) {
        for (final child in children) {
          appendNode(child, depth + 1, path);
        }
      }
      path.remove(row.id);
    }

    for (final group in groups) {
      final collapsed = _collapsedGroups.contains(group.label);
      result.add(
        _HistoryHeaderItem(group.label, group.items.length, collapsed),
      );
      if (!collapsed) {
        for (final node in group.items) {
          appendNode(node, 0, <String>{});
        }
      }
    }
    final metrics = ClientPerformanceMetrics.instance;
    metrics.historyProjectionBuilds++;
    metrics.historyVisibleRows += result.length;
    started.stop();
    if (started.elapsedMicroseconds > metrics.maxHistoryProjectionMicros) {
      metrics.maxHistoryProjectionMicros = started.elapsedMicroseconds;
    }
    return result;
  }

  Widget _buildGroupHeader(BuildContext context, _HistoryHeaderItem item) {
    final collapsed = item.collapsed;
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        collapsed
            ? _collapsedGroups.remove(item.label)
            : _collapsedGroups.add(item.label);
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Row(
          children: [
            AnimatedRotation(
              turns: collapsed ? -.25 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: const Icon(Icons.arrow_drop_down, size: 20),
            ),
            if (item.label == _bucketPinned) ...[
              Icon(Icons.star, size: 14, color: accent),
              const SizedBox(width: 5),
            ],
            Text(
              _bucketLabel(context, item.label),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text(
              '${item.count}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionRow(
    BuildContext context,
    SessionRow row, {
    Key? key,
    int depth = 0,
    bool hasChildren = false,
    bool expanded = false,
  }) {
    final selected = context.read<SessionStore>().durableId == row.id;
    return Padding(
      key: key,
      padding: EdgeInsets.only(left: depth * 18.0, bottom: 6),
      child: SessionRichCard(
        row: row,
        depth: depth,
        selected: selected,
        onTap: () {
          if (MediaQuery.sizeOf(context).width >= 1200) {
            setState(() => _selectedRow = row);
          } else {
            _openSession(row);
          }
        },
        onLongPress: () => _showManageSheet(row),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasChildren)
              IconButton(
                tooltip: expanded
                    ? context.l10n.historyCollapseChildren
                    : context.l10n.historyExpandChildren,
                onPressed: () => setState(() {
                  expanded
                      ? _expandedSessionIds.remove(row.id)
                      : _expandedSessionIds.add(row.id);
                }),
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            PopupMenuButton<String>(
              tooltip: context.l10n.historySessionActions,
              onSelected: (value) => _handleRowAction(row, value),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'manage',
                  child: Text(context.l10n.historyManageSession),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.l10n.commonDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Kept temporarily as a visual fallback while the shared card rolls out.
  // ignore: unused_element
  Widget _buildLegacySessionRow(
    BuildContext context,
    SessionRow row, {
    int depth = 0,
    bool hasChildren = false,
    bool expanded = false,
  }) {
    final store = context.read<SessionStore>();
    final selected = store.durableId == row.id;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final background = selected
        ? accent.withValues(alpha: isDark ? .16 : .1)
        : Colors.transparent;
    final title = row.title?.trim().isNotEmpty == true
        ? row.title!.trim()
        : context.l10n.historyUntitled;
    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, bottom: 2),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (MediaQuery.sizeOf(context).width >= 1200) {
              setState(() => _selectedRow = row);
            } else {
              _openSession(row);
            }
          },
          onLongPress: () => _showManageSheet(row),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 22,
                  child: row.needsAttention
                      ? const SessionStatusIndicator(
                          attention: true,
                          working: false,
                          size: 16,
                        )
                      : row.isActivelyWorking
                      ? const SessionStatusIndicator(
                          attention: false,
                          working: true,
                          size: 16,
                        )
                      : Icon(
                          depth > 0
                              ? Icons.account_tree_outlined
                              : row.isCliSession
                              ? Icons.terminal
                              : Icons.chat_bubble_outline,
                          size: 17,
                          color: selected
                              ? accent
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (row.pinned) ...[
                            Icon(Icons.push_pin, size: 12, color: accent),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          SessionMetaBadges(row: row),
                          if (sessionActivityTime(row) != null)
                            Text(
                              _fmtTime(sessionActivityTime(row)!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      if (row.preview?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          row.preview!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (sessionLocationLabel(row) != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sessionLocationLabel(row)!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            context.l10n.historyMessageCount(
                              row.messageCount ?? 0,
                            ),
                            style: theme.textTheme.labelSmall,
                          ),
                          if (row.sourceLabel?.isNotEmpty == true) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                row.sourceLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          FutureBuilder<bool>(
                            future: store.hasUnreadForSession(row),
                            builder: (_, snapshot) => snapshot.data == true
                                ? Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasChildren)
                  IconButton(
                    tooltip: expanded
                        ? context.l10n.historyCollapseChildren
                        : context.l10n.historyExpandChildren,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        expanded
                            ? _expandedSessionIds.remove(row.id)
                            : _expandedSessionIds.add(row.id);
                      });
                    },
                    icon: AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: const Icon(Icons.expand_more, size: 19),
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: context.l10n.historySessionActions,
                  padding: EdgeInsets.zero,
                  iconSize: 19,
                  onSelected: (value) => _handleRowAction(row, value),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'manage',
                      child: Text(context.l10n.historyManageSession),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.commonDelete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRowAction(SessionRow row, String value) async {
    final connection = context.read<ConnectionStore>();
    final api = _loadedApi;
    if (api == null || !identical(api, connection.api)) return;
    if (value == 'manage') {
      _showManageSheet(row, api);
      return;
    }
    if (value != 'delete') return;
    final title = row.title?.trim().isNotEmpty == true
        ? row.title!.trim()
        : context.l10n.historyUntitled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.historyDeleteQuestion),
        content: Text(ctx.l10n.historyDeletePrompt(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      requireActiveApi(context, connection, api);
      await api.deleteSession(row.id);
      if (mounted) {
        requireActiveApi(context, connection, api);
        await _load();
      }
    } catch (error) {
      if (mounted && identical(api, connection.api)) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.historyDeleteFailed('$error'))),
        );
      }
    }
  }

  /// D8 session management: rename / archive / context usage / compress.
  void _showManageSheet(SessionRow row, [ApiClient? expectedApi]) {
    final ownerApi = expectedApi ?? _loadedApi;
    if (ownerApi == null ||
        !identical(ownerApi, context.read<ConnectionStore>().api)) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _SessionManageSheet(row: row, ownerApi: ownerApi, onChanged: _load),
    );
  }

  String _fmtTime(DateTime dt) {
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
    return '${local.month}/${local.day}';
  }
}

class _HistoryGroup {
  final String label;
  final List<SessionRow> items;

  const _HistoryGroup(this.label, this.items);
}

sealed class _HistoryVisibleItem {}

class _HistoryHeaderItem extends _HistoryVisibleItem {
  final String label;
  final int count;
  final bool collapsed;

  _HistoryHeaderItem(this.label, this.count, this.collapsed);
}

class _HistorySessionItem extends _HistoryVisibleItem {
  final SessionRow row;
  final int depth;
  final bool hasChildren;
  final bool expanded;

  _HistorySessionItem(
    this.row, {
    required this.depth,
    required this.hasChildren,
    required this.expanded,
  });
}

class _SessionManageSheet extends StatefulWidget {
  final SessionRow row;
  final ApiClient ownerApi;
  final VoidCallback onChanged;
  const _SessionManageSheet({
    required this.row,
    required this.ownerApi,
    required this.onChanged,
  });

  @override
  State<_SessionManageSheet> createState() => _SessionManageSheetState();
}

class _SessionManageSheetState extends State<_SessionManageSheet> {
  late final TextEditingController _titleCtrl;
  Map<String, dynamic> _usage = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.row.title ?? '');
    _loadUsage();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsage() async {
    final session = context.read<SessionStore>();
    final connection = context.read<ConnectionStore>();
    // Context usage needs the live session binding; only for the current one.
    if (session.durableId != widget.row.id ||
        !identical(connection.api, widget.ownerApi)) {
      return;
    }
    final usage = await session.usage();
    if (mounted && identical(connection.api, widget.ownerApi)) {
      setState(() => _usage = usage);
    }
  }

  Future<void> _rename() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    setState(() => _busy = true);
    try {
      requireActiveApi(context, connection, api);
      await api.setSessionTitle(widget.row.id, title);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.historyRenameFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _compress() async {
    final session = context.read<SessionStore>();
    final connection = context.read<ConnectionStore>();
    final sessionId = session.durableId;
    if (sessionId != widget.row.id) return;
    setState(() => _busy = true);
    try {
      requireActiveApi(context, connection, widget.ownerApi);
      final result = await session.compress();
      if (!mounted || session.durableId != sessionId) return;
      requireActiveApi(context, connection, widget.ownerApi);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.historyCompressed(result['removed'] ?? '?'),
          ),
        ),
      );
      await session.refreshTranscript();
    } catch (e) {
      if (mounted &&
          identical(widget.ownerApi, connection.api) &&
          session.durableId == sessionId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.historyCompressFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleArchive() async {
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    final next = !widget.row.archived;
    setState(() => _busy = true);
    try {
      requireActiveApi(context, connection, api);
      await api.setSessionArchived(widget.row.id, next);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next
                  ? context.l10n.historyArchiveFailed('$e')
                  : context.l10n.historyUnarchiveFailed('$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = _usage;
    final contextUsed = usage['context_used'] as num?;
    final contextMax = usage['context_max'] as num?;
    final percent = usage['context_percent'] as num?;
    final isCurrent = context.read<SessionStore>().durableId == widget.row.id;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.historyManagement,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: context.l10n.commonTitle,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _rename,
            child: Text(context.l10n.historySaveTitle),
          ),
          const SizedBox(height: 12),
          if (isCurrent && contextUsed != null && contextMax != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.historyContextUsage(
                    _fmtTokens(contextUsed),
                    _fmtTokens(contextMax),
                    percent == null ? '' : context.l10n.historyPercent(percent),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: contextMax > 0 ? contextUsed / contextMax : 0,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 12),
              ],
            ),
          Wrap(
            spacing: 8,
            children: [
              if (isCurrent)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _compress,
                  icon: const Icon(Icons.compress),
                  label: Text(context.l10n.historyCompress),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _toggleArchive,
                icon: Icon(
                  widget.row.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(
                  widget.row.archived
                      ? context.l10n.historyUnarchive
                      : context.l10n.historyArchive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtTokens(num v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toString();
  }
}
