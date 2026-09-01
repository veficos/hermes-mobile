import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_glass.dart';
import 'session_detail_panel.dart';
import 'session_list_meta.dart';

/// Canonical history-session presentation used by every session surface.
class SessionRichCard extends StatelessWidget {
  final SessionRow row;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool selected;
  final bool compact;
  final int depth;

  const SessionRichCard({
    super.key,
    required this.row,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.selected = false,
    this.compact = false,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final title = row.title?.trim().isNotEmpty == true
        ? row.title!.trim()
        : context.l10n.sessionUntitled;
    final activity = sessionActivityTime(row);
    final cost = row.actualCostUsd ?? row.estimatedCostUsd;
    final location = sessionLocationLabel(row);
    return HermesGlassCard(
      onTap: onTap,
      onLongPress: onLongPress,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(compact ? 10 : 12),
      tint: selected ? accent.withValues(alpha: .08) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 30 : 36,
            height: compact ? 30 : 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: selected ? .2 : .11),
              borderRadius: BorderRadius.circular(compact ? 8 : 10),
            ),
            alignment: Alignment.center,
            child: row.needsAttention || row.isActivelyWorking
                ? SessionStatusIndicator(
                    attention: row.needsAttention,
                    working: row.isActivelyWorking,
                    size: compact ? 15 : 17,
                  )
                : Icon(
                    depth > 0
                        ? Icons.account_tree_outlined
                        : sessionSourceIcon(row),
                    size: compact ? 16 : 18,
                    color: accent,
                  ),
          ),
          SizedBox(width: compact ? 8 : 11),
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
                    SessionMetaBadges(row: row, iconSize: compact ? 11 : 13),
                  ],
                ),
                if (row.preview?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    row.preview!.trim(),
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Wrap(
                  spacing: 9,
                  runSpacing: 4,
                  children: [
                    _stat(
                      Icons.chat_bubble_outline,
                      context.l10n.sessionMessageCount(row.messageCount ?? 0),
                    ),
                    _stat(
                      Icons.build_outlined,
                      context.l10n.sessionToolCount(row.toolCallCount),
                    ),
                    _stat(
                      Icons.cloud_outlined,
                      context.l10n.sessionApiCallCount(row.apiCallCount),
                    ),
                    _stat(
                      Icons.token_outlined,
                      context.l10n.sessionTokenCount(_compact(row.totalTokens)),
                    ),
                    if (cost > 0)
                      _stat(Icons.attach_money, cost.toStringAsFixed(4)),
                    if (row.duration != null)
                      _stat(
                        Icons.timer_outlined,
                        _duration(context, row.duration!),
                      ),
                    if (activity != null)
                      _stat(Icons.schedule, _time(activity)),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _tag(context, sessionSourceLabel(row), Icons.hub_outlined),
                    if (row.model?.isNotEmpty == true)
                      _tag(context, row.model!, Icons.smart_toy_outlined),
                    if (row.profile?.isNotEmpty == true)
                      _tag(context, row.profile!, Icons.person_outline),
                    if (location != null)
                      _tag(context, location, Icons.folder_outlined),
                    if (row.handoffState?.isNotEmpty == true)
                      _tag(
                        context,
                        context.l10n.sessionHandoff(row.handoffState!),
                        Icons.swap_horiz,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 10)),
    ],
  );

  Widget _tag(BuildContext context, String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(HermesRadius.capsule),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  String _duration(BuildContext context, Duration value) {
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

  static String _time(DateTime value) {
    final v = value.toLocal();
    final now = DateTime.now();
    if (v.year == now.year && v.month == now.month && v.day == now.day) {
      return '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
    }
    return '${v.month}/${v.day}';
  }
}
