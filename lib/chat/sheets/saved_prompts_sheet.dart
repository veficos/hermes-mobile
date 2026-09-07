/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/session_store.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/h/hermes_states.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

Future<void> showChatSavedPromptsSheet(
  BuildContext context, {
  required String Function() currentInput,
  required void Function(String) onInsert,
}) async {
  final l10n = context.l10n;
  final session = context.read<SessionStore>();
  final api = session.api;
  if (api == null) {
    showHermesToast(
      context,
      message: l10n.chatServerNotConnected,
      kind: HermesToastKind.error,
    );
    return;
  }
  List<SavedPrompt> prompts;
  try {
    prompts = await api.savedPrompts();
  } catch (e) {
    if (context.mounted && identical(api, session.api)) {
      showHermesErrorSnackBar(
        context,
        e,
        fallback: context.l10n.chatSavedPromptsLoadFailed('$e'),
      );
    }
    return;
  }
  if (!context.mounted || !identical(api, session.api)) return;
  await showMobileSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Text(
                context.l10n.chatSavedPrompts,
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (prompts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Text(context.l10n.chatNoSavedPrompts),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: prompts.length,
                  itemBuilder: (_, i) {
                    final p = prompts[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.notes, size: 18),
                      title: Text(
                        p.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        p.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: context.l10n.commonDelete,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          if (!identical(api, session.api)) return;
                          try {
                            await api.deletePrompt(p.id);
                            if (!ctx.mounted || !identical(api, session.api)) {
                              return;
                            }
                            setSheet(
                              () => prompts = prompts
                                  .where((x) => x.id != p.id)
                                  .toList(growable: false),
                            );
                          } catch (e) {
                            if (context.mounted &&
                                identical(api, session.api)) {
                              showHermesErrorSnackBar(
                                context,
                                e,
                                fallback: context.l10n.chatDeletePromptFailed(
                                  '$e',
                                ),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onInsert(p.text);
                      },
                    );
                  },
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(context.l10n.chatSaveCurrentInput),
                  onPressed: currentInput().isEmpty
                      ? null
                      : () async {
                          if (!identical(api, session.api)) return;
                          try {
                            final saved = await api.savePrompt(currentInput());
                            if (!ctx.mounted || !identical(api, session.api)) {
                              return;
                            }
                            setSheet(() => prompts = [...prompts, saved]);
                            showHermesToast(
                              ctx,
                              message: l10n.chatPromptSaved,
                              kind: HermesToastKind.success,
                            );
                          } catch (e) {
                            if (context.mounted &&
                                identical(api, session.api)) {
                              showHermesErrorSnackBar(
                                context,
                                e,
                                fallback: context.l10n.chatSavePromptFailed(
                                  '$e',
                                ),
                              );
                            }
                          }
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
