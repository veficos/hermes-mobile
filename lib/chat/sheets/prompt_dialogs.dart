/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/adaptive_form_dialog.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/h/hermes_states.dart';

Future<void> showChatSteerDialog(BuildContext context) async {
  final l10n = context.l10n;
  final session = context.read<SessionStore>();
  final ctrl = TextEditingController();
  final text = await showAdaptiveFormDialog<String>(
    context: context,
    title: context.l10n.chatSteerMessage,
    content: TextField(
      controller: ctrl,
      autofocus: true,
      maxLines: 4,
      decoration: InputDecoration(labelText: context.l10n.chatSteerHint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
        child: Text(context.l10n.commonSend),
      ),
    ],
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  if (text == null || text.isEmpty) return;
  try {
    await session.steer(text);
    if (!context.mounted) return;
    showHermesToast(
      context,
      message: l10n.chatSteerInjected,
      kind: HermesToastKind.success,
    );
  } catch (e) {
    if (context.mounted) {
      showHermesErrorSnackBar(
        context,
        e,
        fallback: context.l10n.chatSteerNowFailed('$e'),
      );
    }
  }
}

Future<void> showChatBackgroundDialog(BuildContext context) async {
  final l10n = context.l10n;
  final session = context.read<SessionStore>();
  final ctrl = TextEditingController();
  final text = await showAdaptiveFormDialog<String>(
    context: context,
    title: context.l10n.chatRunInBackground,
    content: TextField(
      controller: ctrl,
      autofocus: true,
      maxLines: 4,
      decoration: InputDecoration(labelText: context.l10n.chatBackgroundPrompt),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
        child: Text(context.l10n.commonSubmit),
      ),
    ],
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  if (text == null || text.isEmpty) return;
  try {
    final taskId = await session.submitBackground(text);
    if (!context.mounted) return;
    showHermesToast(
      context,
      message: taskId.isEmpty
          ? l10n.chatBackgroundSubmitted
          : l10n.chatBackgroundSubmittedWithId(taskId),
      kind: HermesToastKind.success,
    );
  } catch (e) {
    if (context.mounted) {
      showHermesErrorSnackBar(
        context,
        e,
        fallback: context.l10n.chatBackgroundSubmitFailed('$e'),
      );
    }
  }
}

Future<String?> promptChatAttachmentUrl(BuildContext context) async {
  final ctrl = TextEditingController();
  final result = await showAdaptiveFormDialog<String>(
    context: context,
    title: context.l10n.chatAttachLink,
    content: TextField(
      controller: ctrl,
      autofocus: true,
      decoration: InputDecoration(
        labelText: context.l10n.commonUrl,
        hintText: 'https://example.com/article.pdf',
        prefixIcon: const Icon(Icons.link_outlined),
      ),
      keyboardType: TextInputType.url,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () {
          final v = ctrl.text.trim();
          Navigator.of(context).pop(v.isEmpty ? null : v);
        },
        child: Text(context.l10n.chatAttach),
      ),
    ],
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  return result;
}

Future<void> showChatRenameSessionDialog(BuildContext context) async {
  final session = context.read<SessionStore>();
  final ctrl = TextEditingController(text: session.info?.title ?? '');
  await showAdaptiveFormDialog<void>(
    context: context,
    title: context.l10n.chatRenameSession,
    content: TextField(
      controller: ctrl,
      autofocus: true,
      decoration: InputDecoration(labelText: context.l10n.commonTitle),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () async {
          await session.rename(ctrl.text.trim());
          if (context.mounted) Navigator.of(context).pop();
        },
        child: Text(context.l10n.commonSave),
      ),
    ],
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
}
