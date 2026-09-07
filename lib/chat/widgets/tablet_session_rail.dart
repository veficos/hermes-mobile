/// TabletSessionRail — extracted from lib/screens/chat_screen.dart (pure
/// move, no behavior change): the compact session list for the tablet chat
/// layout (spec §176 left rail). Re-exported by chat_screen.dart.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/session_tree.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/session/session_detail_panel.dart';
import '../../widgets/session/session_list_meta.dart';

/// Compact session list for the tablet chat layout (spec §176 left rail).
class TabletSessionRail extends StatefulWidget {
  final double width;
  final Future<void> Function(SessionRow row) onOpen;
  final Future<void> Function() onNew;
  final List<SessionRow>? rows;
  final String? currentId;

  const TabletSessionRail({
    super.key,
    required this.width,
    required this.onOpen,
    required this.onNew,
    this.rows,
    this.currentId,
  });

  @override
  State<TabletSessionRail> createState() => _TabletSessionRailState();
}

class _TabletSessionRailState extends State<TabletSessionRail> {
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.rows == null) {
      context.read<SessionStore>().refreshList(limit: HermesPolicy.pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final rows = widget.rows ?? session.sessions ?? [];
    final items = buildVisibleSessionTree(rows, _expandedIds);
    final parentIds = {
      for (final row in rows)
        if (row.parentSessionId?.isNotEmpty == true) row.parentSessionId!,
    };
    final currentId = widget.currentId ?? session.durableId;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: widget.width,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.chatSessions,
                      style: HermesType.onSurface(
                        HermesType.headline,
                        Theme.of(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.chatNoSessions,
                        style: const TextStyle(fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final s = item.row;
                        final selected = s.id == currentId;
                        final hasChildren = parentIds.contains(s.id);
                        final expanded = _expandedIds.contains(s.id);
                        return ListTile(
                          key: ValueKey('tablet-session-tile-${s.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.only(
                            left: 16 + item.depth * 18.0,
                            right: 16,
                          ),
                          selected: selected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          leading: s.needsAttention || s.isActivelyWorking
                              ? SessionStatusIndicator(
                                  attention: s.needsAttention,
                                  working: s.isActivelyWorking,
                                  size: 18,
                                )
                              : Icon(
                                  key: ValueKey(
                                    'tablet-session-leading-${s.id}',
                                  ),
                                  item.depth > 0
                                      ? Icons.account_tree_outlined
                                      : sessionSourceIcon(s),
                                  size: 18,
                                ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.title?.isNotEmpty == true
                                      ? s.title!
                                      : context.l10n.chatUntitledSession,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              SessionMetaBadges(row: s, iconSize: 12),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.preview?.trim().isNotEmpty == true)
                                Text(
                                  s.preview!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                [
                                  context.l10n.chatMessageCount(
                                    s.messageCount ?? 0,
                                  ),
                                  context.l10n.chatToolCount(s.toolCallCount),
                                  '${s.apiCallCount} API',
                                  '${_compactSessionTokens(s.totalTokens)} Token',
                                  if ((s.actualCostUsd ?? s.estimatedCostUsd) >
                                      0)
                                    '\$${(s.actualCostUsd ?? s.estimatedCostUsd).toStringAsFixed(4)}',
                                  if (s.model?.isNotEmpty == true) s.model!,
                                  if (s.profile?.isNotEmpty == true) s.profile!,
                                  sessionSourceLabel(s),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: hasChildren
                              ? IconButton(
                                  key: ValueKey(
                                    'tablet-session-toggle-${s.id}',
                                  ),
                                  tooltip: expanded
                                      ? context.l10n.chatCollapseSubsessions
                                      : context.l10n.chatExpandSubsessions,
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  onPressed: () => setState(() {
                                    if (!_expandedIds.add(s.id)) {
                                      _expandedIds.remove(s.id);
                                    }
                                  }),
                                  icon: Icon(
                                    expanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                  ),
                                )
                              : null,
                          onTap: () => widget.onOpen(s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _compactSessionTokens(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
