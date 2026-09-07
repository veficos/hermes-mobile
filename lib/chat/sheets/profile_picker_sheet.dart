/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/h/hermes_states.dart';
import 'option_sheet.dart';

Future<String?> showChatProfilePickerSheet(BuildContext context) async {
  final session = context.read<SessionStore>();
  final api = session.api;
  if (api == null) {
    showHermesToast(
      context,
      message: context.l10n.chatServerNotConnected,
      kind: HermesToastKind.error,
    );
    return null;
  }
  try {
    await session.refreshProfiles();
    if (!context.mounted) return null;
  } catch (e) {
    if (context.mounted) {
      showHermesErrorSnackBar(
        context,
        e,
        fallback: context.l10n.chatProfilesLoadFailed('$e'),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  if (session.profiles.isEmpty) {
    showHermesToast(context, message: context.l10n.chatNoProfiles);
    return null;
  }
  final picked = await showChatOptionSheet<String>(
    context,
    title: context.l10n.chatSelectProfile,
    subtitle: context.l10n.chatSelectProfileDescription,
    current: session.activeProfile ?? '',
    options: [for (final p in session.profiles) (p.name, Icons.person_outline)],
    selectedLabel: context.l10n.chatCurrentlyActive,
  );

  return picked;
}
