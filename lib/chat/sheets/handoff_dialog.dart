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
import '../../theme/hermes_glass_theme.dart';
import '../../widgets/glass/glass_selection_row.dart';
import '../../widgets/glass/glass_alert_dialog.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';
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
      builder: (ctx) => GlassAlertDialog(
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

  final picked = await showChatHandoffPlatformPicker(context, platforms);
  if (picked == null || !context.mounted) return;
  if (!identical(api, session.api) ||
      runtimeId != session.runtimeId ||
      sessionId != session.durableId) {
    return;
  }

  await _performHandoff(context, session, picked);
}

Future<MessagingPlatform?> showChatHandoffPlatformPicker(
  BuildContext context,
  List<MessagingPlatform> platforms,
) {
  if (HermesGlassTheme.of(context).enabled) {
    return showMobileSheet<MessagingPlatform>(
      context,
      (ctx) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      namesRoute: true,
                      child: Text(
                        ctx.l10n.chatHandoffToPlatform,
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: ctx.l10n.commonClose,
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: platforms.length,
                itemBuilder: (context, index) {
                  final platform = platforms[index];
                  return GlassSelectionRow(
                    selected: false,
                    child: ListTile(
                      onTap: () => Navigator.of(ctx).pop(platform),
                      leading: const Icon(Icons.forum_outlined),
                      title: Text(platform.displayName),
                      subtitle: Text(
                        platform.homeChannelName?.isNotEmpty == true
                            ? ctx.l10n.chatHomeChannel(
                                platform.homeChannelName!,
                              )
                            : ctx.l10n.chatHomeChannelNotSet,
                      ),
                      trailing: platform.gatewayRunning
                          ? const Icon(
                              Icons.circle,
                              size: 10,
                              color: HermesSemantic.green,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  return showDialog<MessagingPlatform>(
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
}

Future<void> _performHandoff(
  BuildContext context,
  SessionStore session,
  MessagingPlatform picked,
) async {
  final api = session.api;
  final runtimeId = session.runtimeId;
  final sessionId = session.durableId;

  final progress = ValueNotifier<String>('pending');
  var cancelled = false;
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: GlassAlertDialog(
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
