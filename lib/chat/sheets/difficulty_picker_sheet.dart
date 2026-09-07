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

Future<void> showChatDifficultyPicker(
  BuildContext context, {
  required String? current,
  required Map<String, dynamic> Function() serverConfig,
  required void Function(Map<String, dynamic> patch) onApplied,
}) async {
  final l10n = context.l10n;
  final session = context.read<SessionStore>();
  final api = session.api;
  final runtimeId = session.runtimeId;
  final configProfile = session.profile ?? session.activeProfile;
  if (api == null) {
    showHermesToast(
      context,
      message: l10n.chatServerNotConnected,
      kind: HermesToastKind.error,
    );
    return;
  }
  if (current == null) return; // pill is hidden in this state anyway
  // WebUI `/reasoning` ladder (commands.js:33): the full effort set the
  // backend accepts.
  const levels = [
    ('none', Icons.block),
    ('minimal', Icons.eco_outlined),
    ('low', Icons.sentiment_satisfied_alt),
    ('medium', Icons.trending_up),
    ('high', Icons.local_fire_department),
    ('xhigh', Icons.whatshot_outlined),
    ('max', Icons.rocket_launch_outlined),
  ];
  final options = [
    ...levels,
    if (!levels.any((l) => l.$1 == current)) (current, Icons.psychology),
  ];
  final picked = await showChatOptionSheet<String>(
    context,
    title: context.l10n.chatReasoningEffort,
    subtitle: context.l10n.chatReasoningEffortDescription,
    current: current,
    options: options,
  );
  if (picked == null || !context.mounted || picked == current) return;
  if (!identical(api, session.api) ||
      runtimeId != session.runtimeId ||
      configProfile != (session.profile ?? session.activeProfile)) {
    return;
  }
  // Always write the canonical shape: merge into the existing `agent` map.
  final patch = {
    'agent': {
      ...(serverConfig()['agent'] is Map
          ? (serverConfig()['agent'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{}),
      'reasoning_effort': picked,
    },
  };
  try {
    await api.putConfig(patch, profile: configProfile);
    if (!context.mounted ||
        !identical(api, session.api) ||
        runtimeId != session.runtimeId ||
        configProfile != (session.profile ?? session.activeProfile)) {
      return;
    }
    session.applyProfileConfigPatch(configProfile, patch);
    onApplied(patch);
    showHermesToast(
      context,
      message: l10n.chatReasoningEffortSet(picked),
      kind: HermesToastKind.success,
    );
  } catch (e) {
    if (context.mounted &&
        identical(api, session.api) &&
        runtimeId == session.runtimeId &&
        configProfile == (session.profile ?? session.activeProfile)) {
      showHermesErrorSnackBar(
        context,
        e,
        fallback: l10n.chatReasoningEffortSetFailed('$e'),
      );
    }
  }
}
