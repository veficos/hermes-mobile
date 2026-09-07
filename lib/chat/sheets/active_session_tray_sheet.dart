/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/active_session_tray_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

Future<ActiveSessionTrayItem?> showChatActiveSessionTraySheet(
  BuildContext context,
) {
  return showMobileSheet<ActiveSessionTrayItem>(
    context,
    (
      sheetContext,
    ) => Selector<ActiveSessionTrayStore, List<ActiveSessionTrayItem>>(
      selector: (_, store) => store.items,
      builder: (context, items, _) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                context.l10n.chatSessions,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Text(context.l10n.chatNoSessions),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final current =
                        item.row.id == context.read<SessionStore>().durableId;
                    final (icon, color, label) = switch (item.state) {
                      ActiveSessionState.queued => (
                        item.queue?.deliveryUncertain == true
                            ? Icons.sync_problem_outlined
                            : Icons.queue_play_next_outlined,
                        HermesSemantic.orange,
                        '${context.l10n.chatQueued} · ${item.queue?.count ?? 0}',
                      ),
                      ActiveSessionState.running => (
                        Icons.autorenew_rounded,
                        HermesSemantic.green,
                        context.l10n.commonRunning,
                      ),
                      ActiveSessionState.waiting => (
                        Icons.notification_important_outlined,
                        HermesSemantic.orange,
                        context.l10n.chatHandoffWaiting,
                      ),
                      ActiveSessionState.failed => (
                        Icons.error_outline_rounded,
                        Theme.of(context).colorScheme.error,
                        context.l10n.chatHandoffFailedStatus,
                      ),
                      ActiveSessionState.completed => (
                        Icons.check_circle_outline_rounded,
                        Theme.of(context).colorScheme.outline,
                        context.l10n.commonCompleted,
                      ),
                    };
                    final detail = item.row.lastActivityDescription?.trim();
                    return ListTile(
                      selected: current,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(HermesRadius.card),
                      ),
                      leading: Icon(icon, color: color),
                      title: Text(
                        item.row.title?.trim().isNotEmpty == true
                            ? item.row.title!.trim()
                            : context.l10n.chatUntitled,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        detail?.isNotEmpty == true ? '$label · $detail' : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: current
                          ? Icon(
                              Icons.radio_button_checked,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(sheetContext).pop(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
