/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/h/hermes_states.dart';

Future<void> showChatHandoffDialog(BuildContext context) async {
  final session = context.read<SessionStore>();
  final api = session.api;
  final runtimeId = session.runtimeId;
  final sessionId = session.durableId;
  if (api == null) {
    showHermesToast(
      context,
      message: context.l10n.chatServerNotConnected,
      kind: HermesToastKind.error,
    );
    return;
  }

  List<MessagingPlatform> platforms;
  try {
    platforms = (await api.messagingPlatforms(
      profile: session.profile ?? session.activeProfile,
    )).where((platform) => platform.canHandoff).toList(growable: false);
  } catch (error) {
    if (context.mounted && identical(api, session.api)) {
      showHermesErrorSnackBar(
        context,
        error,
        fallback: context.l10n.chatHandoffPlatformsFailed('$error'),
      );
    }
    return;
  }
  if (!context.mounted ||
      !identical(api, session.api) ||
      runtimeId != session.runtimeId ||
      sessionId != session.durableId) {
    return;
  }

  if (platforms.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.chatNoHandoffPlatforms),
        content: Text(context.l10n.chatNoHandoffPlatformsDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonGotIt),
          ),
        ],
      ),
    );
    return;
  }

  final picked = await showDialog<MessagingPlatform>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(context.l10n.chatHandoffToPlatform),
      children: [
        for (final platform in platforms)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(platform),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.forum_outlined),
              title: Text(platform.displayName),
              subtitle: Text(
                platform.homeChannelName?.isNotEmpty == true
                    ? context.l10n.chatHomeChannel(platform.homeChannelName!)
                    : context.l10n.chatHomeChannelNotSet,
              ),
              trailing: platform.gatewayRunning
                  ? const Icon(
                      Icons.circle,
                      size: 10,
                      color: HermesSemantic.green,
                    )
                  : null,
            ),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  if (!identical(api, session.api) ||
      runtimeId != session.runtimeId ||
      sessionId != session.durableId) {
    return;
  }

  final progress = ValueNotifier<String>('pending');
  var cancelled = false;
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(context.l10n.chatHandingOffTo(picked.displayName)),
        content: ValueListenableBuilder<String>(
          valueListenable: progress,
          builder: (_, state, _) => Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: HermesSpacing.md),
              Expanded(child: Text(_handoffStateLabel(context, state))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    ),
  );

  HandoffResult? result;
  try {
    result = await session
        .handoff(picked.name, onProgress: (state) => progress.value = state)
        .timeout(const Duration(seconds: 90));
  } on TimeoutException {
    result = null;
  } catch (_) {
    result = null;
  }
  if (context.mounted && !cancelled) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  await dialog;
  progress.dispose();
  if (!context.mounted ||
      cancelled ||
      !identical(api, session.api) ||
      runtimeId != session.runtimeId ||
      sessionId != session.durableId) {
    return;
  }
  showHermesToast(
    context,
    message: result != null && result.ok
        ? context.l10n.chatHandoffCompletedTo(picked.displayName)
        : context.l10n.chatHandoffFailed(
            result?.error ?? context.l10n.chatHandoffTimeout,
          ),
    kind: result != null && result.ok
        ? HermesToastKind.success
        : HermesToastKind.error,
  );
}

String _handoffStateLabel(BuildContext context, String state) =>
    switch (state) {
      'running' => context.l10n.chatHandoffGatewayRunning,
      'completed' => context.l10n.chatHandoffCompleted,
      'failed' => context.l10n.chatHandoffFailedStatus,
      _ => context.l10n.chatHandoffWaiting,
    };
