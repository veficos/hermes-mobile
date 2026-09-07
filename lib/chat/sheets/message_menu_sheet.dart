/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat_message.dart';
import '../../core/clipboard.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/h/hermes_states.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

void showChatMessageMenu(
  BuildContext context,
  ChatMessage message, {
  required bool Function(ChatMessage) isMarked,
  required Future<void> Function(ChatMessage) onToggleMarker,
  required void Function(ChatMessage) onEdit,
  required void Function(ChatMessage) onRestore,
}) {
  final l10n = context.l10n;
  final session = context.read<SessionStore>();
  showMobileSheet(
    context,
    (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(context.l10n.chatCopyText),
            onTap: () {
              Navigator.of(ctx).pop();
              // Desktop parity: "Copy text" strips markdown syntax.
              final text = message.plainText;
              if (text.isEmpty) return;
              copyTextOrNotify(
                context,
                text,
                successMessage: context.l10n.commonCopied,
              );
            },
          ),
          ListTile(
            leading: Icon(
              isMarked(message)
                  ? Icons.bookmark_remove_outlined
                  : Icons.bookmark_add_outlined,
            ),
            title: Text(
              isMarked(message)
                  ? context.l10n.chatUnmarkMessage
                  : context.l10n.chatMarkMessage,
            ),
            onTap: () async {
              Navigator.of(ctx).pop();
              await onToggleMarker(message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.data_object_outlined),
            title: Text(context.l10n.chatCopyAsMarkdown),
            onTap: () {
              Navigator.of(ctx).pop();
              final text = message.fullText;
              if (text.isEmpty) return;
              copyTextOrNotify(
                context,
                text,
                successMessage: context.l10n.chatMarkdownCopied,
              );
            },
          ),
          if (!session.readOnly && message.role == 'assistant')
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(context.l10n.chatRegenerate),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await session.reloadFromMessage(message);
                } catch (e) {
                  if (context.mounted) {
                    showHermesErrorSnackBar(
                      context,
                      e,
                      fallback: context.l10n.chatRegenerateFailed('$e'),
                    );
                  }
                }
              },
            ),
          if (!session.readOnly &&
              message.role == 'assistant' &&
              message.isError &&
              message.errorSurface?.retryable != false)
            ListTile(
              leading: const Icon(Icons.replay),
              title: Text(context.l10n.commonRetry),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await session.reloadFromMessage(message);
                } catch (e) {
                  if (context.mounted) {
                    showHermesErrorSnackBar(
                      context,
                      e,
                      fallback: context.l10n.chatRetryFailed('$e'),
                    );
                  }
                }
              },
            ),
          if (!session.readOnly &&
              (message.role == 'user' || message.role == 'assistant') &&
              message.fullText.trim().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.call_split),
              title: Text(context.l10n.chatBranchInNewSession),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  final newId = await session.branchSession(
                    atMessageId: message.id,
                  );
                  if (!context.mounted) return;
                  showHermesToast(
                    context,
                    message: newId.isEmpty
                        ? l10n.chatBranchedHere
                        : l10n.chatBranchedWithId(newId),
                    kind: HermesToastKind.success,
                  );
                } catch (e) {
                  if (context.mounted) {
                    showHermesErrorSnackBar(
                      context,
                      e,
                      fallback: context.l10n.chatBranchFailed('$e'),
                    );
                  }
                }
              },
            ),
          if (!session.readOnly && message.role == 'user') ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.commonEdit),
              onTap: () {
                Navigator.of(ctx).pop();
                // WebUI .msg-edit-area: swap the bubble for an in-place
                // editor instead of opening a dialog.
                onEdit(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: Text(context.l10n.chatRestoreToMessage),
              onTap: () {
                Navigator.of(ctx).pop();
                onRestore(message);
              },
            ),
          ],
        ],
      ),
    ),
  );
}
