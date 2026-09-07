/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';

import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/mobile/hermes_adaptive_menu.dart';

Widget buildChatSessionMoreMenu(
  BuildContext context,
  SessionStore session, {
  required VoidCallback onWorkspace,
  required VoidCallback onRegenTitle,
  required VoidCallback onCopyId,
  required VoidCallback onCopyLink,
}) {
  final hasDurable = session.durableId != null;
  final supportsSharing = session.api?.supportsSessionSharing ?? false;
  return HermesAdaptiveMenuButton<String>(
    tooltip: context.l10n.chatSessionMenu,
    icon: const Icon(Icons.more_vert),
    onSelected: (value) {
      switch (value) {
        case 'workspace':
          onWorkspace();
        case 'regen_title':
          onRegenTitle();
        case 'copy_id':
          onCopyId();
        case 'copy_link':
          onCopyLink();
      }
    },
    itemBuilder: (ctx) => [
      PopupMenuItem(
        value: 'workspace',
        enabled: hasDurable && !session.readOnly,
        child: ListTile(
          leading: const Icon(Icons.drive_file_move_outline),
          title: Text(context.l10n.chatChangeWorkspace),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'regen_title',
        enabled: hasDurable && !session.readOnly,
        child: ListTile(
          leading: const Icon(Icons.auto_awesome_outlined),
          title: Text(context.l10n.chatRegenerateTitle),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      PopupMenuItem(
        value: 'copy_id',
        enabled: hasDurable,
        child: ListTile(
          leading: const Icon(Icons.content_copy_outlined),
          title: Text(context.l10n.chatCopySessionId),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      if (supportsSharing)
        PopupMenuItem(
          value: 'copy_link',
          enabled: hasDurable,
          child: ListTile(
            leading: const Icon(Icons.link_outlined),
            title: Text(context.l10n.chatCopySessionLink),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
    ],
  );
}
