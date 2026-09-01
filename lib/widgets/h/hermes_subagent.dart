import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/stores/session_store.dart';
import '../../core/stores/subagent_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';

String _normalizeGoal(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Expandable task record for a delegated agent in the parent chat timeline.
class HermesSubagentCard extends StatefulWidget {
  final Map<String, dynamic> data;

  const HermesSubagentCard({super.key, required this.data});

  @override
  State<HermesSubagentCard> createState() => _HermesSubagentCardState();
}

class _HermesSubagentCardState extends State<HermesSubagentCard> {
  bool _expanded = true;
  Map<String, dynamic> _effectiveData = const {};

  /// Desktop parity (`mergeDelegateRows`): live state wins wherever it
  /// exists — a settled result only tells you a child finished, but the
  /// subagent store knows what it is doing *right now*. Matches by id first
  /// (native `subagent.*` events carry the real id), then by normalized goal
  /// text (the delegate-call fallback keys rows by task order, so id alone
  /// won't line up); when neither matches, the call's own static data
  /// stands as-is.
  Map<String, dynamic> _mergeLive(List<SubagentNode> live) {
    final data = widget.data;
    if (live.isEmpty) return data;
    final id = (data['subagent_id'] ?? data['id'] ?? '').toString();
    final goal = _normalizeGoal(
      (data['task'] ?? data['goal'] ?? '').toString(),
    );
    SubagentNode? match;
    if (id.isNotEmpty) {
      for (final node in live) {
        if (node.id == id) {
          match = node;
          break;
        }
      }
    }
    if (match == null && goal.isNotEmpty) {
      for (final node in live) {
        if (_normalizeGoal(node.goal) == goal) {
          match = node;
          break;
        }
      }
    }
    if (match == null) return data;
    final stream = match.stream;
    return {
      ...data,
      'subagent_id': match.id,
      'status': match.status,
      if (match.model != null) 'model': match.model,
      if (match.currentTool != null) 'current_tool': match.currentTool,
      if (match.summary != null)
        'summary': match.summary
      else if (stream.isNotEmpty)
        'summary': stream.last.text,
      if (match.taskIndex != null) 'task_index': match.taskIndex,
      if (match.taskCount != null) 'task_count': match.taskCount,
      if (match.sessionId != null) 'child_session_id': match.sessionId,
    };
  }

  String _value(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = _effectiveData[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  int? _intValue(List<String> keys) {
    for (final key in keys) {
      final value = _effectiveData[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _agentName(BuildContext context) => _value(const [
    'name',
    'agent_name',
    'agent',
    'label',
    'subagent_id',
    'id',
  ], fallback: context.l10n.subagentFallbackName);

  String _task(BuildContext context) => _value(const [
    'task',
    'goal',
    'prompt',
    'title',
    'instruction',
  ], fallback: context.l10n.subagentNoTask);

  String get _status =>
      _value(const ['status', 'state'], fallback: 'running').toLowerCase();

  String _statusLabel(BuildContext context) => switch (_status) {
    'queued' => context.l10n.subagentsStatusQueued,
    'running' ||
    'started' ||
    'in_progress' => context.l10n.subagentsStatusRunning,
    'completed' ||
    'complete' ||
    'done' ||
    'success' => context.l10n.subagentsStatusCompleted,
    'failed' || 'error' => context.l10n.subagentsStatusFailed,
    'interrupted' ||
    'cancelled' ||
    'canceled' => context.l10n.subagentsStatusInterrupted,
    _ => _status,
  };

  Color _statusColor(BuildContext context) => switch (_status) {
    'completed' || 'complete' || 'done' || 'success' => hermesSemantic(
      context,
      HermesSemantic.green,
      HermesSemanticDark.green,
    ),
    'failed' || 'error' => hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    ),
    'interrupted' || 'cancelled' || 'canceled' => hermesSemantic(
      context,
      HermesSemantic.orange,
      HermesSemanticDark.orange,
    ),
    _ => hermesSemantic(context, HermesSemantic.blue, HermesSemanticDark.blue),
  };

  IconData get _statusIcon => switch (_status) {
    'completed' || 'complete' || 'done' || 'success' => Icons.check_circle,
    'failed' || 'error' => Icons.error_outline,
    'interrupted' || 'cancelled' || 'canceled' => Icons.pause_circle_outline,
    'queued' => Icons.schedule_outlined,
    _ => Icons.play_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    // Nullable watches: a test harness may render this card with no
    // SubagentStore/SessionStore above it — in that case the call's own
    // static data stands as-is, same as before live-merging existed.
    final subagents = context.watch<SubagentStore?>();
    final sessionId = context.watch<SessionStore?>()?.runtimeId;
    _effectiveData = subagents == null
        ? widget.data
        : _mergeLive(subagents.forSession(sessionId));
    final theme = Theme.of(context);
    final color = _statusColor(context);
    final agentName = _agentName(context);
    final task = _task(context);
    final statusLabel = _statusLabel(context);
    final model = _value(const ['model', 'model_name']);
    final currentTool = _value(const ['current_tool', 'tool_name', 'tool']);
    final summary = _value(const [
      'summary',
      'result',
      'result_text',
      'output',
      'text',
    ]);
    final index = _intValue(const ['task_index', 'step', 'completed_tasks']);
    final count = _intValue(const ['task_count', 'total_steps', 'total_tasks']);
    final progress = index != null && count != null && count > 0
        ? (index / count).clamp(0.0, 1.0)
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // §3.6：语义色底 10%(light)/18%(dark)。
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? .18 : .10,
        ),
        borderRadius: BorderRadius.circular(HermesRadius.card),
        border: Border.all(color: color.withValues(alpha: .36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 18, color: color),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.subagentCardTitle(agentName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task,
                          maxLines: _expanded ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(color, statusLabel),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: color.withValues(alpha: .25)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detail(context, context.l10n.subagentTask, task),
                  if (model.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detail(context, context.l10n.subagentModel, model),
                  ],
                  if (currentTool.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detail(
                      context,
                      context.l10n.subagentCurrentTool,
                      currentTool,
                    ),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          context.l10n.subagentTaskProgress,
                          style: theme.textTheme.labelSmall,
                        ),
                        const Spacer(),
                        Text(
                          '$index / $count',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      color: color,
                    ),
                  ],
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _detail(context, context.l10n.subagentSummary, summary),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(Color color, String statusLabel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? .18 : .10),
        borderRadius: BorderRadius.circular(HermesRadius.capsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    // Prototype parity (`chip(label, tone, a.status==='running')`'s pulse):
    // the running-state chip breathes, matching the plan card's own
    // in-progress breathing dot.
    const runningStates = {'running', 'started', 'in_progress'};
    return runningStates.contains(_status)
        ? _PulsingOpacity(child: chip)
        : chip;
  }

  Widget _detail(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 3),
      SelectableText(value, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// 1200ms breathing opacity, matching `_BreathingStepIcon` in
/// `hermes_plan.dart` (§6.8) — static under "reduce motion".
class _PulsingOpacity extends StatefulWidget {
  final Widget child;
  const _PulsingOpacity({required this.child});

  @override
  State<_PulsingOpacity> createState() => _PulsingOpacityState();
}

class _PulsingOpacityState extends State<_PulsingOpacity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.5).animate(_controller),
      child: widget.child,
    );
  }
}
