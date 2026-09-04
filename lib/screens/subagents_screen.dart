/// Subagents screen (spec §137–141): live spawn-tree of sub-agents.
///
/// Renders a recursive [ExpansionTile] forest of [SubagentNode]s grouped by
/// session id. Each node shows the goal, status chip, model, current tool and
/// run duration. Long-press exposes "中断" and "打开会话" actions.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/connections/connection_registry.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/session_store.dart';
import '../core/stores/subagent_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/session/session_rich_card.dart';
import 'chat_screen.dart';

class SubagentsScreen extends StatefulWidget {
  const SubagentsScreen({super.key});

  @override
  State<SubagentsScreen> createState() => _SubagentsScreenState();
}

class _SubagentsScreenState extends State<SubagentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshAll();
    });
  }

  Future<void> _refreshAll() async {
    final store = context.read<SubagentStore>();
    try {
      await store.refreshProjection();
    } catch (_) {
      // The store exposes the error so the body can render a retry state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SubagentStore>();
    final session = context.watch<SessionStore>();
    final activeSessionId = session.durableId;
    final connectionId = context.watch<ConnectionStore>().activeConnectionId;

    SessionRow? rowFor(String id) =>
        session.sessions?.where((row) => row.id == id).firstOrNull;

    // Build the list of session ids to display: the active session first, then
    // any other sessions with known subagent activity.
    final ids = <String>[];
    if (activeSessionId != null && activeSessionId.isNotEmpty) {
      ids.add(activeSessionId);
    }
    for (final id in store.sessionIds) {
      if (!ids.contains(id)) ids.add(id);
    }

    final hasAny = ids.any((id) => store.forSession(id).isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.featureSubagents),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: store.error != null
          ? HermesErrorState(
              description: context.l10n.subagentsLoadFailed('${store.error}'),
              onRetry: _refreshAll,
            )
          : store.loading && !hasAny
          ? const Center(child: CircularProgressIndicator())
          : !hasAny
          ? HermesEmptyState(
              icon: Icons.account_tree_outlined,
              title: context.l10n.subagentsEmpty,
              description: activeSessionId == null
                  ? context.l10n.subagentsOpenSessionDescription
                  : context.l10n.subagentsCurrentSessionEmpty,
              primaryLabel: context.l10n.commonRefresh,
              onPrimary: _refreshAll,
            )
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(HermesSpacing.md),
                children: [
                  for (final id in ids)
                    if (store.forSession(id).isNotEmpty) ...[
                      _SessionBlock(
                        sessionId: id,
                        isActive: id == activeSessionId,
                        session: rowFor(id),
                        owner: OwnerRoute(
                          connectionId: connectionId,
                          profile:
                              rowFor(id)?.profile ??
                              (id == activeSessionId ? session.profile : null),
                        ),
                        nodes: store.forSession(id),
                      ),
                      const SizedBox(height: HermesSpacing.md),
                    ],
                ],
              ),
            ),
    );
  }
}

class _SessionBlock extends StatelessWidget {
  final String sessionId;
  final bool isActive;
  final SessionRow? session;
  final OwnerRoute owner;
  final List<SubagentNode> nodes;

  const _SessionBlock({
    required this.sessionId,
    required this.isActive,
    this.session,
    required this.owner,
    required this.nodes,
  });

  int get _nodeCount {
    var count = 0;
    void visit(SubagentNode node) {
      count++;
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final node in nodes) {
      visit(node);
    }
    return count;
  }

  List<_SubagentEntry> get _entries {
    final entries = <_SubagentEntry>[];
    void visit(SubagentNode node, int depth) {
      entries.add(_SubagentEntry(node, depth));
      for (final child in node.children) {
        visit(child, depth + 1);
      }
    }

    for (final node in nodes) {
      visit(node, 0);
    }
    return entries;
  }

  /// Aggregate token/cost/tool/file counts across every node in this
  /// session's tree — mirrors desktop's summary row (app/agents/index.tsx).
  ({
    int running,
    int failed,
    int tools,
    int files,
    int inputTokens,
    int outputTokens,
    double cost,
  })
  get _aggregate {
    var running = 0,
        failed = 0,
        tools = 0,
        files = 0,
        inputTokens = 0,
        outputTokens = 0;
    var cost = 0.0;
    void visit(SubagentNode node) {
      if (node.status == 'running' || node.status == 'queued') running++;
      if (node.status == 'failed') failed++;
      tools += node.toolCount ?? 0;
      files += node.filesRead.length + node.filesWritten.length;
      inputTokens += node.inputTokens ?? 0;
      outputTokens += node.outputTokens ?? 0;
      cost += node.costUsd ?? 0;
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final node in nodes) {
      visit(node);
    }
    return (
      running: running,
      failed: failed,
      tools: tools,
      files: files,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cost: cost,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agg = _aggregate;
    final entries = _entries;
    final running = entries
        .where((entry) => _isActiveStatus(entry.node.status))
        .toList(growable: false);
    final completed = entries
        .where((entry) => !_isActiveStatus(entry.node.status))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session != null) ...[
          SessionRichCard(row: session!, compact: true, selected: isActive),
          const SizedBox(height: HermesSpacing.sm),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: HermesSpacing.xs),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.chat_bubble : Icons.history,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isActive
                      ? context.l10n.subagentsCurrentSession
                      : context.l10n.subagentsSession(sessionId),
                  style: HermesType.onSurfaceVariant(
                    HermesType.subheadline,
                    theme,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                context.l10n.subagentsCount(_nodeCount),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (agg.tools > 0 ||
            agg.files > 0 ||
            agg.inputTokens + agg.outputTokens > 0 ||
            agg.cost > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: HermesSpacing.xs),
            child: _AggregateStatsRow(
              running: agg.running,
              failed: agg.failed,
              tools: agg.tools,
              files: agg.files,
              tokens: agg.inputTokens + agg.outputTokens,
              cost: agg.cost,
            ),
          ),
        _TaskSection(
          key: ValueKey('subagents-running-$sessionId'),
          title: context.l10n.commonRunning,
          icon: Icons.play_circle_outline,
          color: HermesSemantic.green,
          entries: running,
          sessionId: sessionId,
          owner: owner,
        ),
        const SizedBox(height: HermesSpacing.sm),
        _TaskSection(
          key: ValueKey('subagents-completed-$sessionId'),
          title: context.l10n.commonCompleted,
          icon: Icons.task_alt,
          color: theme.colorScheme.primary,
          entries: completed,
          sessionId: sessionId,
          owner: owner,
        ),
      ],
    );
  }
}

bool _isActiveStatus(String status) =>
    status == 'running' || status == 'queued';

class _SubagentEntry {
  final SubagentNode node;
  final int depth;

  const _SubagentEntry(this.node, this.depth);
}

class _TaskSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_SubagentEntry> entries;
  final String sessionId;
  final OwnerRoute owner;

  const _TaskSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.entries,
    required this.sessionId,
    required this.owner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HermesRadius.capsule),
                ),
                child: Text(
                  '${entries.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (entries.isNotEmpty)
          HermesGlassCard(
            radius: HermesRadius.largeCard,
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: HermesSpacing.xs,
            ),
            child: Column(
              children: [
                for (final entry in entries)
                  _SubagentTile(
                    node: entry.node,
                    sessionId: sessionId,
                    owner: owner,
                    depth: entry.depth,
                    showChildren: false,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Session-level rollup — running/failed counts, total tool calls, files
/// touched, tokens and cost. Matches desktop's summary line
/// (app/agents/index.tsx:186-223).
class _AggregateStatsRow extends StatelessWidget {
  final int running;
  final int failed;
  final int tools;
  final int files;
  final int tokens;
  final double cost;

  const _AggregateStatsRow({
    required this.running,
    required this.failed,
    required this.tools,
    required this.files,
    required this.tokens,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (running > 0) context.l10n.subagentsRunningCount(running),
      if (failed > 0) context.l10n.subagentsFailedCount(failed),
      if (tools > 0) context.l10n.subagentsToolCalls(tools),
      if (files > 0) context.l10n.subagentsFiles(files),
      if (tokens > 0) '${_compactCount(tokens)} tokens',
      if (cost > 0) '\$${cost.toStringAsFixed(cost < 1 ? 4 : 2)}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  static String _compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _SubagentTile extends StatelessWidget {
  final SubagentNode node;
  final String sessionId;
  final OwnerRoute owner;
  final int depth;
  final bool showChildren;

  const _SubagentTile({
    required this.node,
    required this.sessionId,
    required this.owner,
    required this.depth,
    this.showChildren = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChildren = showChildren && node.children.isNotEmpty;

    void showActions() {
      final l10n = context.l10n;
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isActiveStatus(node.status))
                ListTile(
                  leading: const Icon(
                    Icons.stop_circle_outlined,
                    color: HermesSemantic.red,
                  ),
                  title: Text(l10n.subagentsInterrupt),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await context.read<SubagentStore>().interrupt(
                        node.id,
                        ownerRoute: owner,
                      );
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.subagentsInterruptSent)),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.subagentsInterruptFailed('$e')),
                          ),
                        );
                      }
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(l10n.subagentsOpenSession),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final sid = node.sessionId;
                  if (sid == null || sid.isEmpty) return;
                  final session = context.read<SessionStore>();
                  try {
                    final childOwner = context
                        .read<SubagentStore>()
                        .routeForChildSession(sid, owner);
                    await session.openReadOnlyOwnedSession(sid, childOwner);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.subagentsOpenSessionFailed('$error'),
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  if (!context.mounted) return;
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
                },
              ),
            ],
          ),
        ),
      );
    }

    final title = node.goal.isNotEmpty ? node.goal : node.id;

    final tile = ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(
        left: HermesSpacing.md + depth * HermesSpacing.md,
        right: HermesSpacing.sm,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: HermesType.onSurface(HermesType.body, theme),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: node.status),
        ],
      ),
      subtitle: _NodeMeta(node: node),
      onLongPress: showActions,
    );

    if (!hasChildren) {
      return Column(
        children: [
          tile,
          Divider(
            height: 1,
            indent: HermesSpacing.md + depth * HermesSpacing.md,
            color: theme.colorScheme.outlineVariant,
          ),
        ],
      );
    }

    return GestureDetector(
      onLongPress: showActions,
      child: ExpansionTile(
        dense: true,
        tilePadding: EdgeInsets.only(
          left: depth * HermesSpacing.md,
          right: HermesSpacing.sm,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: HermesType.onSurface(HermesType.body, theme),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: node.status),
          ],
        ),
        subtitle: _NodeMeta(node: node),
        children: [
          for (final child in node.children)
            _SubagentTile(
              node: child,
              sessionId: sessionId,
              owner: owner,
              depth: depth + 1,
            ),
        ],
      ),
    );
  }
}

/// Last few lines of a subagent's live activity feed — a compact port of
/// desktop's `StreamLine` (app/agents/index.tsx), which renders up to 10;
/// mobile shows the last 3 to fit a list row.
class _StreamTail extends StatelessWidget {
  final List<SubagentStreamEntry> entries;

  const _StreamTail({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = entries.length > 3
        ? entries.sublist(entries.length - 3)
        : entries;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in recent)
            Text(
              entry.text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: entry.isError
                    ? HermesSemantic.red
                    : entry.kind == 'summary'
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontFamily: 'monospace',
                fontStyle: entry.kind == 'thinking' ? FontStyle.italic : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _NodeMeta extends StatelessWidget {
  final SubagentNode node;
  const _NodeMeta({required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (node.model != null && node.model!.isNotEmpty) {
      parts.add(node.model!);
    }
    if (node.currentTool != null && node.currentTool!.isNotEmpty) {
      parts.add(context.l10n.subagentsCurrentTool(node.currentTool!));
    }
    final duration = _formatDuration(node.startedAt, node.updatedAt);
    if (duration != null) parts.add(duration);

    // Second line: file/token/cost counters, when the backend has reported
    // any — mirrors desktop's per-node stats (files read/written, tokens,
    // cost, tool count).
    final statParts = <String>[
      if (node.toolCount != null && node.toolCount! > 0)
        context.l10n.subagentsTools(node.toolCount!),
      if (node.filesRead.isNotEmpty)
        context.l10n.subagentsFilesRead(node.filesRead.length),
      if (node.filesWritten.isNotEmpty)
        context.l10n.subagentsFilesWritten(node.filesWritten.length),
      if ((node.inputTokens ?? 0) + (node.outputTokens ?? 0) > 0)
        '${(node.inputTokens ?? 0) + (node.outputTokens ?? 0)} tok',
      if (node.costUsd != null && node.costUsd! > 0)
        '\$${node.costUsd!.toStringAsFixed(node.costUsd! < 1 ? 4 : 2)}',
    ];

    final taskIndex = node.taskIndex;
    final taskCount = node.taskCount;
    final progress = taskIndex != null && taskCount != null && taskCount > 0
        ? (taskIndex / taskCount).clamp(0.0, 1.0)
        : null;
    final summary = node.summary?.trim() ?? '';

    if (parts.isEmpty &&
        statParts.isEmpty &&
        node.stream.isEmpty &&
        progress == null &&
        summary.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parts.isNotEmpty)
            Text(
              parts.join(' · '),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (statParts.isNotEmpty)
            Text(
              statParts.join(' · '),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.75,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  context.l10n.subagentTaskProgress,
                  style: theme.textTheme.labelSmall,
                ),
                const Spacer(),
                Text(
                  '$taskIndex / $taskCount',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 3),
            LinearProgressIndicator(value: progress, minHeight: 4),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.subagentSummary,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 2),
            Text(
              summary,
              style: theme.textTheme.bodySmall,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (node.stream.isNotEmpty) _StreamTail(entries: node.stream),
        ],
      ),
    );
  }

  String? _formatDuration(DateTime? started, DateTime? updated) {
    final end = updated ?? DateTime.now();
    if (started == null) return null;
    final ms = end.difference(started).inMilliseconds;
    if (ms < 0) return null;
    final s = (ms / 1000).round();
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rs = s % 60;
    if (m < 60) return '${m}m${rs}s';
    final h = m ~/ 60;
    final rm = m % 60;
    return '${h}h${rm}m';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = _statusStyle(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HermesRadius.capsule),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color) _statusStyle(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'running':
        return (l10n.statusRunning, HermesSemantic.green);
      case 'queued':
        return (l10n.subagentsStatusQueued, HermesSemantic.orange);
      case 'completed':
        return (l10n.statusCompleted, HermesSemantic.blue);
      case 'failed':
        return (l10n.statusFailed, HermesSemantic.red);
      case 'interrupted':
        return (l10n.subagentsStatusInterrupted, HermesSemantic.gray);
      case 'cancelled':
        return (l10n.statusCancelled, HermesSemantic.gray);
      default:
        return (
          status.isEmpty ? l10n.subagentsStatusUnknown : status,
          HermesSemantic.gray,
        );
    }
  }
}
