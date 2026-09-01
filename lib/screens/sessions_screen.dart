/// Batch 3: SessionsScreen — full session management UI with project picker,
/// search, filter chips, sort dropdown, sortable session list and a bottom
/// action bar. Data is read from [SessionStore.sessions]; null shows placeholders.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/session_tree.dart';
import '../core/stores/session_store.dart';
import '../core/stores/session_appearance_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/session/project_dialog.dart';
import '../widgets/session/session_list_meta.dart';
import '../widgets/session/session_detail_panel.dart';
import '../widgets/session/session_row_actions.dart';
import 'chat_screen.dart';
import 'new_session_screen.dart';
import 'settings_hub_screen.dart';

typedef SessionOpenCallback = void Function(SessionRow session);

enum _SessionFilter { all, today, week, archived, starred }

enum _SessionSort { timeDesc, timeAsc, title, messageCount }

class SessionsScreen extends StatefulWidget {
  final SessionOpenCallback? onOpen;
  final bool showSettings;

  const SessionsScreen({super.key, this.onOpen, this.showSettings = true});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Map<String, dynamic>? _selectedProject;
  _SessionFilter _filter = _SessionFilter.all;
  _SessionSort _sort = _SessionSort.timeDesc;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<SessionStore>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await session.refreshList(limit: 500);
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

  Future<void> _open(SessionRow row) async {
    if (widget.onOpen != null) {
      widget.onOpen!(row);
      return;
    }
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await session.resumeSession(row.id, profile: row.profile);
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionResumeFailed('$e'))),
        );
      }
    }
  }

  void _showProjectDialog() {
    showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => ProjectDialog(
        initialProject: _selectedProject,
        onSelected: (p) {
          if (mounted) setState(() => _selectedProject = p);
        },
      ),
    );
  }

  void _showSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsHubScreen()));
  }

  void _newSession() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewSessionScreen()));
  }

  List<SessionRow> _applyFilterSort(List<SessionRow> rows) {
    var list = rows.toList();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        final t = (r.title ?? '').toLowerCase();
        final p = (r.preview ?? '').toLowerCase();
        final c = (r.cwd ?? '').toLowerCase();
        return t.contains(q) || p.contains(q) || c.contains(q);
      }).toList();
    }
    if (_selectedProject != null) {
      final path =
          (_selectedProject!['primary_path'] ?? _selectedProject!['path'] ?? '')
              .toString()
              .toLowerCase();
      if (path.isNotEmpty) {
        list = list.where((r) {
          final cwd = (r.cwd ?? '').toLowerCase();
          return cwd.startsWith(path) || cwd.contains(path);
        }).toList();
      }
    }
    final now = DateTime.now();
    switch (_filter) {
      case _SessionFilter.today:
        list = list.where((r) {
          final t = (r.startedAt ?? now).toLocal();
          return t.year == now.year && t.month == now.month && t.day == now.day;
        }).toList();
        break;
      case _SessionFilter.week:
        final weekAgo = now.subtract(const Duration(days: 7));
        list = list.where((r) {
          final t = r.startedAt ?? now;
          return t.isAfter(weekAgo);
        }).toList();
        break;
      case _SessionFilter.archived:
        list = list.where((r) => r.archived).toList();
        break;
      case _SessionFilter.starred:
        list = list.where((r) => r.pinned).toList();
        break;
      case _SessionFilter.all:
        break;
    }
    switch (_sort) {
      case _SessionSort.timeDesc:
        list.sort(
          (a, b) => (b.startedAt ?? DateTime(0)).compareTo(
            a.startedAt ?? DateTime(0),
          ),
        );
        break;
      case _SessionSort.timeAsc:
        list.sort(
          (a, b) => (a.startedAt ?? DateTime(0)).compareTo(
            b.startedAt ?? DateTime(0),
          ),
        );
        break;
      case _SessionSort.title:
        list.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
        break;
      case _SessionSort.messageCount:
        list.sort(
          (a, b) => (b.messageCount ?? 0).compareTo(a.messageCount ?? 0),
        );
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final rawRows = session.sessions;
    final rows = rawRows == null ? <SessionRow>[] : _applyFilterSort(rawRows);
    final width = MediaQuery.sizeOf(context).width;
    final content = Column(
      children: [
        if (width >= 840)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _topBar(context)),
              Expanded(flex: 2, child: _searchBar(context)),
            ],
          )
        else ...[
          _topBar(context),
          _searchBar(context),
        ],
        _filterChips(context),
        _sortRow(context),
        Expanded(child: _buildBody(context, rawRows, rows)),
        _bottomBar(context),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const ValueKey('sessions-back-button'),
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(context.l10n.sessionManage),
      ),
      body: SafeArea(
        child: width >= 1200
            ? Row(
                children: [
                  Expanded(child: content),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 320,
                    child: _sessionDetails(
                      context,
                      rows.isEmpty ? null : rows.first,
                    ),
                  ),
                ],
              )
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width >= 600 && width < 840
                        ? 720
                        : double.infinity,
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }

  Widget _sessionDetails(BuildContext context, SessionRow? row) {
    if (row == null) {
      return HermesEmptyState(
        icon: Icons.info_outline,
        title: context.l10n.sessionsNoDetail,
        description: context.l10n.sessionsNoDetailDescription,
      );
    }
    return SessionDetailPanel(row: row, onOpen: () => _open(row));
  }

  void _showDetails(SessionRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .9,
        child: SessionDetailPanel(
          row: row,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          onOpen: () {
            Navigator.of(sheetContext).pop();
            _open(row);
          },
          onManage: () {
            Navigator.of(sheetContext).pop();
            SessionRowActions.show(
              context,
              session: row,
              onRefreshed: _load,
              isArchived: row.archived,
              isStarred: row.pinned,
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark
        ? HermesBackground.darkBorder
        : HermesBackground.lightBorder;
    final projectName = _selectedProject == null
        ? context.l10n.sessionsAllProjects
        : (_selectedProject!['name']?.toString() ??
              context.l10n.projectUntitled);
    final accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.md,
        HermesSpacing.sm,
        HermesSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showProjectDialog,
                borderRadius: BorderRadius.circular(HermesRadius.card),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HermesSpacing.sm,
                    vertical: HermesSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: border, width: 1),
                    borderRadius: BorderRadius.circular(HermesRadius.card),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            HermesRadius.smallCard,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.folder_outlined,
                          size: 18,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: HermesSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.sessionsProject,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? HermesText.darkQuaternary
                                    : HermesText.lightQuaternary,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              projectName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more, size: 20, color: accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: HermesSpacing.xs),
          HermesIconButton(
            icon: Icons.refresh,
            tooltip: context.l10n.commonRefresh,
            onTap: _load,
          ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.md,
        HermesSpacing.sm,
        HermesSpacing.md,
        0,
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: context.l10n.sessionsSearchHint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _filterChips(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final chips = [
      (
        _SessionFilter.all,
        context.l10n.sessionFilterAll,
        Icons.filter_alt_outlined,
      ),
      (_SessionFilter.today, context.l10n.sessionsToday, Icons.today_outlined),
      (
        _SessionFilter.week,
        context.l10n.sessionsThisWeek,
        Icons.view_week_outlined,
      ),
      (
        _SessionFilter.archived,
        context.l10n.sessionGroupArchived,
        Icons.archive_outlined,
      ),
      (_SessionFilter.starred, context.l10n.sessionsStarred, Icons.star_border),
    ];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: HermesSpacing.xs),
        itemBuilder: (context, i) {
          final (f, label, icon) = chips[i];
          final selected = _filter == f;
          final bg = selected
              ? accent
              : (isDark
                    ? HermesBackground.darkSecondary
                    : HermesBackground.lightSecondary);
          final fg = selected
              ? theme.colorScheme.onPrimary
              : (isDark ? HermesText.darkSecondary : HermesText.lightSecondary);
          final border = selected
              ? accent
              : (isDark
                    ? HermesBackground.darkBorder
                    : HermesBackground.lightBorder);
          return Material(
            color: bg,
            borderRadius: BorderRadius.circular(HermesRadius.capsule),
            child: InkWell(
              onTap: () => setState(() => _filter = f),
              borderRadius: BorderRadius.circular(HermesRadius.capsule),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HermesSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(HermesRadius.capsule),
                  border: Border.all(color: border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
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

  Widget _sortRow(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final options = [
      (_SessionSort.timeDesc, context.l10n.sessionsSortNewest, Icons.schedule),
      (_SessionSort.timeAsc, context.l10n.sessionsSortOldest, Icons.schedule),
      (_SessionSort.title, context.l10n.sessionsSortTitle, Icons.sort_by_alpha),
      (
        _SessionSort.messageCount,
        context.l10n.sessionsSortMessages,
        Icons.chat_bubble_outline,
      ),
    ];
    final current = options.firstWhere(
      (o) => o.$1 == _sort,
      orElse: () => options.first,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.md,
        4,
        HermesSpacing.md,
        HermesSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            context.l10n.sessionSortTitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? HermesText.darkTertiary
                  : HermesText.lightTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: HermesSpacing.xs),
          InkWell(
            onTap: () => _showSortSheet(context, options),
            borderRadius: BorderRadius.circular(HermesRadius.smallCard),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: HermesSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HermesRadius.smallCard),
                border: Border.all(
                  color: isDark
                      ? HermesBackground.darkBorder
                      : HermesBackground.lightBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(current.$3, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    current.$2,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.expand_more,
                    size: 16,
                    color: isDark
                        ? HermesText.darkTertiary
                        : HermesText.lightTertiary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  void _showSortSheet(
    BuildContext context,
    List<(_SessionSort, String, IconData)> options,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final surface = isDark
            ? HermesBackground.darkSecondary
            : HermesBackground.lightSecondary;
        final border = isDark
            ? HermesBackground.darkBorder
            : HermesBackground.lightBorder;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(HermesSpacing.md),
            padding: const EdgeInsets.only(top: HermesSpacing.sm),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(HermesRadius.sheet),
              border: Border.all(color: border, width: 1),
              boxShadow: hermesShadow(ctx, HermesShadowTier.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HermesSpacing.md,
                    vertical: HermesSpacing.xs,
                  ),
                  child: Text(
                    context.l10n.sessionsSortMethod,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                for (final o in options)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _sort = o.$1);
                        Navigator.of(ctx).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: HermesSpacing.md,
                          vertical: HermesSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              o.$3,
                              size: 20,
                              color: _sort == o.$1
                                  ? theme.colorScheme.primary
                                  : (isDark
                                        ? HermesText.darkTertiary
                                        : HermesText.lightTertiary),
                            ),
                            const SizedBox(width: HermesSpacing.md),
                            Expanded(
                              child: Text(
                                o.$2,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _sort == o.$1
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                  fontWeight: _sort == o.$1
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_sort == o.$1)
                              Icon(
                                Icons.check,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: HermesSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<SessionRow>? rawRows,
    List<SessionRow> rows,
  ) {
    if (rawRows == null) {
      return _placeholderList(context);
    }
    if (_loading && rawRows.isEmpty) {
      return HermesLoadingState(label: context.l10n.sessionsLoading);
    }
    if (_error != null && rawRows.isEmpty) {
      return HermesErrorState(description: _error, onRetry: _load);
    }
    if (rows.isEmpty) {
      final hasAny = rawRows.isNotEmpty;
      return HermesEmptyState(
        icon: Icons.chat_bubble_outline,
        title: hasAny
            ? context.l10n.sessionNoMatchesTitle
            : context.l10n.sessionEmptyTitle,
        description: hasAny
            ? context.l10n.sessionNoMatchesDescription
            : context.l10n.sessionEmptyDescription,
        primaryLabel: hasAny
            ? context.l10n.sessionClearFilters
            : context.l10n.sessionNew,
        onPrimary: hasAny
            ? () {
                _searchCtrl.clear();
                setState(() {
                  _filter = _SessionFilter.all;
                  _selectedProject = null;
                });
              }
            : _newSession,
      );
    }
    final items = buildSessionTree(rows);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          HermesSpacing.md,
          4,
          HermesSpacing.md,
          HermesSpacing.xxl,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: HermesSpacing.xs),
        itemBuilder: (context, i) {
          final item = items[i];
          return Padding(
            padding: EdgeInsets.only(left: item.depth * 20.0),
            child: _sessionRow(context, item.row, depth: item.depth),
          );
        },
      ),
    );
  }

  Widget _placeholderList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.md,
        4,
        HermesSpacing.md,
        HermesSpacing.xxl,
      ),
      itemCount: 8,
      separatorBuilder: (_, _) => const SizedBox(height: HermesSpacing.xs),
      itemBuilder: (_, _) => HermesGlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: HermesText.darkQuaternary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
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
                    decoration: BoxDecoration(
                      color: HermesText.darkQuaternary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 140,
                    height: 10,
                    decoration: BoxDecoration(
                      color: HermesText.darkQuaternary.withValues(alpha: 0.12),
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

  Widget _sessionRow(BuildContext context, SessionRow s, {int depth = 0}) {
    return _legacySessionRow(context, s, depth: depth);
  }

  Widget _legacySessionRow(
    BuildContext context,
    SessionRow s, {
    int depth = 0,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = HermesPalette.of(context);
    final archived = s.archived;
    final starred = s.pinned;
    final title = s.title?.isNotEmpty == true
        ? s.title!
        : context.l10n.sessionUntitled;
    final initial = title.isNotEmpty ? title[0].toUpperCase() : 'H';
    final accent =
        context.watch<SessionAppearanceStore>().colorFor(s.id) ??
        theme.colorScheme.primary;
    final attention = s.needsAttention;
    final working = !attention && s.isActivelyWorking;
    final location = sessionLocationLabel(s);
    final activity = sessionActivityTime(s);

    return HermesGlassCard(
      onTap: () => _open(s),
      onLongPress: () => SessionRowActions.show(
        context,
        session: s,
        onRefreshed: _load,
        isArchived: archived,
        isStarred: starred,
      ),
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: depth > 0
                ? const Icon(Icons.account_tree_outlined, size: 18)
                : Text(
                    initial,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SessionMetaBadges(row: s),
                    if (starred)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.star,
                          size: 14,
                          color: palette.accent,
                        ),
                      ),
                    if (archived)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.archive_outlined,
                          size: 14,
                          color: isDark
                              ? HermesText.darkTertiary
                              : HermesText.lightTertiary,
                        ),
                      ),
                    if (attention || working) ...[
                      const SizedBox(width: 6),
                      SessionStatusIndicator(
                        attention: attention,
                        working: working,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 12,
                      color: isDark
                          ? HermesText.darkTertiary
                          : HermesText.lightTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${s.messageCount ?? 0}',
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: isDark
                          ? HermesText.darkTertiary
                          : HermesText.lightTertiary,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        _fmtTime(context, activity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                if (s.preview?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.preview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? HermesText.darkTertiary
                          : HermesText.lightTertiary,
                    ),
                  ),
                ],
                if (location != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? HermesText.darkTertiary
                          : HermesText.lightTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _compactStat(
                      Icons.build_outlined,
                      context.l10n.sessionToolCount(s.toolCallCount),
                    ),
                    _compactStat(Icons.cloud_outlined, '${s.apiCallCount} API'),
                    _compactStat(
                      Icons.token_outlined,
                      '${_compactNumber(s.totalTokens)} Token',
                    ),
                    if ((s.actualCostUsd ?? s.estimatedCostUsd) > 0)
                      _compactStat(
                        Icons.attach_money,
                        (s.actualCostUsd ?? s.estimatedCostUsd).toStringAsFixed(
                          4,
                        ),
                      ),
                    if (s.duration != null)
                      _compactStat(
                        Icons.timer_outlined,
                        _fmtDuration(context, s.duration!),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (s.source?.isNotEmpty == true) _tag(context, s.source!),
                    if (s.gitBranch?.isNotEmpty == true)
                      _tag(context, '${s.gitBranch}', icon: Icons.call_split),
                    if (s.parentSessionId?.isNotEmpty == true)
                      _tag(
                        context,
                        context.l10n.chatBranch,
                        icon: Icons.device_hub,
                      ),
                    if (s.model?.isNotEmpty == true)
                      _tag(context, s.model!, icon: Icons.smart_toy_outlined),
                    if (s.profile?.isNotEmpty == true)
                      _tag(context, s.profile!, icon: Icons.person_outline),
                    if (s.handoffState?.isNotEmpty == true)
                      _tag(
                        context,
                        context.l10n.sessionHandoff(s.handoffState!),
                        icon: Icons.swap_horiz,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HermesIconButton(
                icon: Icons.info_outline,
                size: 30,
                tooltip: context.l10n.sessionsViewFullDetails,
                onTap: () => _showDetails(s),
              ),
              HermesIconButton(
                icon: Icons.more_horiz,
                size: 30,
                tooltip: context.l10n.sessionActions,
                onTap: () => SessionRowActions.show(
                  context,
                  session: s,
                  onRefreshed: _load,
                  isArchived: archived,
                  isStarred: starred,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String label, {IconData? icon}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? HermesBackground.darkTertiary
        : HermesBackground.lightTertiary;
    final fg = isDark ? HermesText.darkSecondary : HermesText.lightSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(HermesRadius.capsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactStat(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );

  static String _compactNumber(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  static String _fmtDuration(BuildContext context, Duration value) {
    if (value.inDays > 0) {
      return context.l10n.sessionDurationDaysHours(
        value.inDays,
        value.inHours % 24,
      );
    }
    if (value.inHours > 0) {
      return context.l10n.sessionDurationHoursMinutes(
        value.inHours,
        value.inMinutes % 60,
      );
    }
    return context.l10n.sessionDurationMinutes(value.inMinutes);
  }

  Widget _bottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark
        ? HermesBackground.darkBorder
        : HermesBackground.lightBorder;
    final surface = isDark
        ? HermesBackground.darkSecondary
        : HermesBackground.lightSecondary;
    final accent = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border, width: 1)),
        boxShadow: hermesShadow(context, HermesShadowTier.sm),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HermesSpacing.md,
            HermesSpacing.sm,
            HermesSpacing.md,
            HermesSpacing.md,
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: HermesSpacing.sm,
            runSpacing: HermesSpacing.sm,
            children: [
              if (widget.showSettings)
                OutlinedButton.icon(
                  onPressed: _showSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(context.l10n.sessionsSettings),
                ),
              FilledButton.icon(
                onPressed: _newSession,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  context.l10n.sessionNew,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtTime(BuildContext context, DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final diff = now.difference(local);
    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return context.l10n.chatYesterday;
    if (diff.inDays < 7) return context.l10n.timeDaysAgo(diff.inDays);
    return '${local.month}/${local.day}/${local.year.toString().substring(2)}';
  }
}
