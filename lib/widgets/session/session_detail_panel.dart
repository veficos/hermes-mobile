import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/l10n.dart';
import 'session_list_meta.dart';

class SessionDetailPanel extends StatelessWidget {
  final SessionRow row;
  final VoidCallback? onOpen;
  final VoidCallback? onManage;
  final EdgeInsetsGeometry padding;

  const SessionDetailPanel({
    super.key,
    required this.row,
    this.onOpen,
    this.onManage,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = row.title?.trim().isNotEmpty == true
        ? row.title!.trim()
        : context.l10n.sessionUntitled;
    final cost = row.actualCostUsd ?? row.estimatedCostUsd;
    return ListView(
      padding: padding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(sessionSourceIcon(row), color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            SessionMetaBadges(row: row),
          ],
        ),
        if (row.preview?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Text(row.preview!.trim()),
        ],
        if (row.lastActivityDescription?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            row.lastActivityDescription!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric(
              icon: Icons.chat_bubble_outline,
              value: '${row.messageCount ?? 0}',
              label: context.l10n.sessionDetailMessages,
            ),
            _Metric(
              icon: Icons.build_outlined,
              value: '${row.toolCallCount}',
              label: context.l10n.sessionDetailTools,
            ),
            _Metric(
              icon: Icons.cloud_outlined,
              value: '${row.apiCallCount}',
              label: 'API',
            ),
            _Metric(
              icon: Icons.token_outlined,
              value: _compact(row.totalTokens),
              label: 'Token',
            ),
            if (cost > 0)
              _Metric(
                icon: Icons.attach_money,
                value: cost.toStringAsFixed(4),
                label: row.actualCostUsd == null
                    ? context.l10n.sessionDetailEstimated
                    : context.l10n.sessionDetailCost,
              ),
            if (row.duration != null)
              _Metric(
                icon: Icons.timer_outlined,
                value: _duration(context, row.duration!),
                label: context.l10n.sessionDetailDuration,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _section(context, context.l10n.sessionDetailInfo, [
          _Entry(
            Icons.hub_outlined,
            context.l10n.sessionDetailSource,
            sessionSourceLabel(row),
          ),
          if (row.profile?.isNotEmpty == true)
            _Entry(
              Icons.person_outline,
              context.l10n.sessionDetailProfile,
              row.profile!,
            ),
          if (row.model?.isNotEmpty == true)
            _Entry(
              Icons.smart_toy_outlined,
              context.l10n.sessionDetailModel,
              [
                row.provider,
                row.model,
              ].whereType<String>().where((v) => v.isNotEmpty).join(' / '),
            ),
          if (row.startedAt != null)
            _Entry(
              Icons.play_arrow,
              context.l10n.sessionDetailStarted,
              _date(row.startedAt!),
            ),
          if (row.lastActivityAt != null)
            _Entry(
              Icons.update,
              context.l10n.sessionDetailLastActivity,
              _date(row.lastActivityAt!),
            ),
          if (row.endedAt != null)
            _Entry(
              Icons.stop_outlined,
              context.l10n.sessionDetailEnded,
              _date(row.endedAt!),
            ),
          if (row.endReason?.isNotEmpty == true)
            _Entry(
              Icons.flag_outlined,
              context.l10n.sessionDetailEndReason,
              row.endReason!,
            ),
          if (row.handoffState?.isNotEmpty == true)
            _Entry(
              Icons.swap_horiz,
              context.l10n.sessionDetailHandoff,
              [
                row.handoffPlatform,
                row.handoffState,
              ].whereType<String>().join(' · '),
            ),
          if (row.handoffError?.isNotEmpty == true)
            _Entry(
              Icons.error_outline,
              context.l10n.sessionDetailHandoffError,
              row.handoffError!,
              error: true,
            ),
        ]),
        _section(context, context.l10n.sessionDetailTokensBilling, [
          _Entry(
            Icons.login,
            context.l10n.sessionDetailInputOutput,
            '${_compact(row.inputTokens)} / ${_compact(row.outputTokens)}',
          ),
          if (row.cacheReadTokens > 0 || row.cacheWriteTokens > 0)
            _Entry(
              Icons.cached,
              context.l10n.sessionDetailCacheReadWrite,
              '${_compact(row.cacheReadTokens)} / ${_compact(row.cacheWriteTokens)}',
            ),
          if (row.reasoningTokens > 0)
            _Entry(
              Icons.psychology_outlined,
              context.l10n.sessionDetailReasoningTokens,
              _compact(row.reasoningTokens),
            ),
          if (row.billingProvider?.isNotEmpty == true)
            _Entry(
              Icons.receipt_long_outlined,
              context.l10n.sessionDetailBillingSource,
              row.billingProvider!,
            ),
        ]),
        _section(context, context.l10n.sessionDetailContextSource, [
          if (row.cwd?.isNotEmpty == true)
            _Entry(
              Icons.folder_outlined,
              context.l10n.sessionDetailWorkingDirectory,
              row.cwd!,
            ),
          if (row.gitBranch?.isNotEmpty == true)
            _Entry(
              Icons.call_split,
              context.l10n.sessionDetailGitBranch,
              row.gitBranch!,
            ),
          if (row.displayName?.isNotEmpty == true)
            _Entry(
              Icons.badge_outlined,
              context.l10n.sessionDetailContact,
              row.displayName!,
            ),
          if (row.chatType?.isNotEmpty == true)
            _Entry(
              Icons.forum_outlined,
              context.l10n.sessionDetailChatType,
              row.chatType!,
            ),
          if (row.userId?.isNotEmpty == true)
            _Entry(
              Icons.fingerprint,
              context.l10n.sessionDetailUserId,
              row.userId!,
            ),
          if (row.parentSessionId?.isNotEmpty == true)
            _Entry(
              Icons.account_tree_outlined,
              context.l10n.sessionDetailParentSession,
              row.parentSessionId!,
            ),
          if (row.rewindCount > 0)
            _Entry(
              Icons.undo,
              context.l10n.sessionDetailRewindCount,
              '${row.rewindCount}',
            ),
          if (hasActiveCompressionFailure(row))
            _Entry(
              Icons.compress,
              context.l10n.sessionDetailCompressionFailed,
              row.compressionFailureError!,
              error: true,
            ),
        ]),
        if (onOpen != null || onManage != null) ...[
          const SizedBox(height: 16),
          if (onOpen != null)
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
              label: Text(context.l10n.sessionDetailOpen),
            ),
          if (onOpen != null && onManage != null) const SizedBox(height: 8),
          if (onManage != null)
            OutlinedButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.tune),
              label: Text(context.l10n.sessionManage),
            ),
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<_Entry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        for (final item in entries)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.icon,
              size: 19,
              color: item.error ? Theme.of(context).colorScheme.error : null,
            ),
            title: Text(item.label),
            subtitle: Text(
              item.value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  static String _duration(BuildContext context, Duration value) {
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

  static String _date(DateTime value) {
    final v = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${v.year}-${two(v.month)}-${two(v.day)} ${two(v.hour)}:${two(v.minute)}';
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Metric({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16),
    label: Text('$value $label'),
    visualDensity: VisualDensity.compact,
  );
}

class _Entry {
  final IconData icon;
  final String label;
  final String value;
  final bool error;
  const _Entry(this.icon, this.label, this.value, {this.error = false});
}

IconData sessionSourceIcon(SessionRow row) {
  switch ((row.source ?? row.sessionSource ?? '').toLowerCase()) {
    case 'weixin':
      return Icons.wechat;
    case 'cli':
      return Icons.terminal;
    case 'cron':
      return Icons.schedule;
    case 'subagent':
      return Icons.account_tree_outlined;
    case 'mobile':
      return Icons.phone_android;
    case 'telegram':
      return Icons.send_outlined;
    case 'discord':
      return Icons.forum_outlined;
    default:
      return Icons.chat_bubble_outline;
  }
}

String sessionSourceLabel(SessionRow row) {
  final source = row.displaySource;
  final contact = row.displayName?.trim();
  final type = row.chatType?.trim();
  return [
    source,
    if (contact?.isNotEmpty == true) contact,
    if (type?.isNotEmpty == true) type,
  ].whereType<String>().join(' · ');
}
