/// NotificationCenter (Q9, spec §109–110/§181–182): in-app list driven by
/// gateway events. Tapping deep-links to the originating Session (or opens
/// the approval sheet for approval notifications).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/notification_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_badge.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import 'chat_screen.dart';
import 'request_sheet.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  (IconData, Color) _visual(BuildContext context, NotificationKind kind) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (kind) {
      NotificationKind.info => (Icons.info_outline, HermesSemantic.blue),
      NotificationKind.success => (
        Icons.check_circle_outline,
        HermesSemantic.green,
      ),
      NotificationKind.warning => (
        Icons.warning_amber_outlined,
        isDark ? HermesSemanticDark.orange : HermesSemantic.orange,
      ),
      NotificationKind.error => (Icons.error_outline, HermesSemantic.red),
      NotificationKind.approval => (
        Icons.rule,
        isDark ? HermesSemanticDark.orange : HermesSemantic.orange,
      ),
    };
  }

  Future<void> _confirmClear(
    BuildContext context,
    NotificationStore store,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.notificationClearConfirmTitle),
        content: Text(context.l10n.notificationClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.notificationClear),
          ),
        ],
      ),
    );
    if (confirmed == true) store.clear();
  }

  Future<void> _open(BuildContext context, NotificationItem n) async {
    final store = context.read<NotificationStore>();
    store.markRead(n.id);
    if (n.kind == NotificationKind.approval) {
      await showRequestSheet(context);
      return;
    }
    final sessionId = n.sessionId;
    if (sessionId == null) return;
    final session = context.read<SessionStore>();
    try {
      await session.resumeSession(sessionId);
      if (!context.mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.notificationOpenFailed('$e'))),
        );
      }
    }
  }

  String _fmt(BuildContext context, DateTime t) {
    final local = t.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return context.l10n.timeJustNow;
    if (diff.inHours < 1) {
      return context.l10n.timeMinutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) return context.l10n.timeHoursAgo(diff.inHours);
    return '${local.month}/${local.day}';
  }

  String _dayLabel(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return context.l10n.dateToday;
    if (difference == 1) return context.l10n.dateYesterday;
    return context.l10n.dateMonthDay(local.month, local.day);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotificationStore>();
    final items = store.items;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= 840
        ? 960.0
        : width >= 600
        ? 720.0
        : double.infinity;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationTitle),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: store.markAllRead,
              child: Text(context.l10n.notificationMarkAllRead),
            ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: context.l10n.notificationClear,
              onPressed: () => _confirmClear(context, store),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: items.isEmpty
              ? HermesEmptyState(
                  icon: Icons.notifications_none,
                  title: context.l10n.notificationEmptyTitle,
                  description: context.l10n.notificationEmptyDescription,
                )
              : _notificationList(context, items),
        ),
      ),
    );
  }

  Widget _notificationList(BuildContext context, List<NotificationItem> items) {
    final sections = <String, List<NotificationItem>>{};
    for (final item in items) {
      sections.putIfAbsent(_dayLabel(context, item.time), () => []).add(item);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      children: [
        for (final section in sections.entries) ...[
          HermesMobileSectionLabel(title: section.key),
          HermesMobileGroup(
            children: [
              for (final item in section.value) _notificationRow(context, item),
            ],
          ),
        ],
      ],
    );
  }

  Widget _notificationRow(BuildContext context, NotificationItem n) {
    final palette = HermesPalette.of(context);
    final (icon, color) = _visual(context, n.kind);
    return Dismissible(
      key: ValueKey('notif-${n.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: HermesSemantic.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => context.read<NotificationStore>().remove(n.id),
      child: ListTile(
        onTap: () => _open(context, n),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            if (!n.read)
              Positioned(
                right: -2,
                top: -2,
                child: HermesBadge(dot: true, color: palette.accent),
              ),
          ],
        ),
        title: Text(
          n.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _fmt(context, n.time),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (n.sessionId != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        context.l10n.notificationOpenSession,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
