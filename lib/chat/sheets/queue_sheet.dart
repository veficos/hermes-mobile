/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

Future<void> showChatQueuePanel(BuildContext context) async {
  final session = context.read<SessionStore>();
  await showMobileSheet<void>(context, (ctx) {
    return ChangeNotifierProvider.value(
      value: session,
      child: Consumer<SessionStore>(
        builder: (_, s, child) {
          final queue = s.sendQueue;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.chatSendQueue,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${queue.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(ctx).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (queue.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            s.clearQueue();
                            Navigator.of(ctx).pop();
                          },
                          child: Text(context.l10n.commonCancelAll),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (queue.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 44,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.l10n.chatNoQueuedMessages,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: queue.length,
                      itemBuilder: (listCtx, i) {
                        final item = queue[i];
                        final preview = item.text.length > 140
                            ? '${item.text.substring(0, 140)}…'
                            : item.text;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: Theme.of(
                              listCtx,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(listCtx).colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              formatChatQueueTime(context, item.createdAt),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: context.l10n.commonCancel,
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => s.cancelQueued(item.id),
                          ),
                          dense: true,
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  });
}

String formatChatQueueTime(BuildContext context, DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inSeconds < 60) {
    return context.l10n.chatQueuedSecondsAgo(diff.inSeconds);
  }
  if (diff.inMinutes < 60) {
    return context.l10n.chatQueuedMinutesAgo(diff.inMinutes);
  }
  return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
