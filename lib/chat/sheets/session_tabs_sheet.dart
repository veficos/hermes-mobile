/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/session_store.dart';
import '../../core/stores/session_tab_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/h/hermes_states.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

Future<void> showChatSessionTabs(BuildContext context) async {
  final tabs = context.read<SessionTabStore>();
  await showMobileSheet<void>(
    context,
    (sheetContext) => AnimatedBuilder(
      animation: tabs,
      builder: (context, _) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              title: Text(context.l10n.chatSessions),
              trailing: IconButton(
                tooltip: context.l10n.commonClose,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ),
            for (final tab in tabs.tabs)
              ListTile(
                leading: Icon(
                  tab.running ? Icons.sync : Icons.chat_bubble_outline,
                  color: tab.running
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: tab.unread
                    ? Text(context.l10n.sessionMarkedUnread)
                    : null,
                selected: tab.id == tabs.activeId,
                onTap: () {
                  unawaited(_activateTab(context, tab, tabs, sheetContext));
                },
                trailing: IconButton(
                  tooltip: context.l10n.commonClose,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _closeTab(context, tab, tabs, sheetContext),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _activateTab(
  BuildContext context,
  SessionTab tab,
  SessionTabStore tabs,
  BuildContext sheetContext,
) async {
  final session = context.read<SessionStore>();
  try {
    if (tab.readOnly) {
      await session.openReadOnlyOwnedSession(tab.id, tab.owner);
    } else if (tab.watch) {
      await session.openWatchOwnedSession(tab.id, tab.owner);
    } else {
      await session.resumeOwnedSession(tab.id, tab.owner);
    }
    if (!context.mounted) return;
    tabs.activate(tab.id);
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
  } catch (error) {
    if (!context.mounted) return;
    showHermesErrorSnackBar(
      context,
      error,
      fallback: context.l10n.sessionResumeFailed('$error'),
    );
  }
}

void _closeTab(
  BuildContext context,
  SessionTab tab,
  SessionTabStore tabs,
  BuildContext sheetContext,
) {
  tabs.close(tab.id);
  if (tab.id == context.read<SessionStore>().durableId) {
    Navigator.of(sheetContext).pop();
  }
}
