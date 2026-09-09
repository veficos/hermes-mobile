/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/mobile_surface_store.dart';
import '../../core/stores/request_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';

Widget buildChatRequestBanner(
  BuildContext context, {
  required void Function(PendingRequest) onOpen,
}) {
  // Nullable watch: returns null (instead of ProviderNotFoundException)
  // where no RequestStore is scoped above the chat screen (unit tests).
  final requests = context.watch<RequestStore?>();
  final req = requests?.current;
  if (requests == null || req == null) return const SizedBox.shrink();
  final session = context.read<SessionStore>();
  // Some request flows (approval.request in particular — see the matching
  // fix in ChatStore.attachRoutedEvents) stamp session_id with the
  // durable/stored id rather than the live runtime id. Checking only
  // runtimeId here meant a foreground approval's own request never
  // matched, so this banner rendered a second, redundant copy floating
  // above the composer at the same time the inline interaction card
  // showed in the transcript.
  if (req.sessionId == null ||
      req.sessionId == session.runtimeId ||
      req.sessionId == session.durableId) {
    // Foreground requests are rendered at their exact timeline position by
    // the interaction ChatPart. Keep this strip for background requests.
    return const SizedBox.shrink();
  }
  final theme = Theme.of(context);
  final warning = theme.brightness == Brightness.dark
      ? HermesSemanticDark.orange
      : HermesSemantic.orange;
  final surfaces = Provider.of<MobileSurfaceStore?>(context, listen: false);
  return KeyedSubtree(
    key: surfaces?.targetKey('chat.requests'),
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: hermesTintAlpha(context, 0.10)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warning.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpen(req),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.rule, size: 16, color: warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  requests.pendingCount > 1
                      ? context.l10n.chatPendingRequests(
                          _requestKindLabel(context, req.kind),
                          requests.pendingCount,
                        )
                      : _requestKindLabel(context, req.kind),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: warning),
            ],
          ),
        ),
      ),
    ),
  );
}

String _requestKindLabel(BuildContext context, RequestKind kind) {
  switch (kind) {
    case RequestKind.approval:
      return context.l10n.chatRequestApproval;
    case RequestKind.clarify:
      return context.l10n.chatRequestQuestion;
    case RequestKind.mcpSetup:
      return context.l10n.chatRequestMcpConfig;
    case RequestKind.secret:
      return context.l10n.chatRequestSecret;
    case RequestKind.sudo:
      return context.l10n.chatRequestPassword;
    case RequestKind.terminalRead:
      return context.l10n.chatRequestTerminalInput;
  }
}
