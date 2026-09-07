/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/h/hermes_status.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

void showChatSessionInfo(BuildContext context) {
  final session = context.read<SessionStore>();
  final info = session.info;
  showMobileSheet(
    context,
    (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.chatSessionInfo,
              style: HermesType.onSurface(
                HermesType.headline,
                Theme.of(context),
              ),
            ),
            const SizedBox(height: 12),
            _infoRow(
              context,
              context.l10n.commonTitle,
              info?.title ?? context.l10n.chatUntitled,
            ),
            _infoRow(context, context.l10n.chatModel, info?.model ?? '—'),
            _infoRow(context, context.l10n.chatProvider, info?.provider ?? '—'),
            _infoRow(
              context,
              context.l10n.chatWorkingDirectory,
              info?.cwd ?? '—',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                HermesAgentStatusView(
                  status: info?.running == true
                      ? HermesAgentStatus.running
                      : HermesAgentStatus.idle,
                  showLabel: true,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(context.l10n.commonClose),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _infoRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
