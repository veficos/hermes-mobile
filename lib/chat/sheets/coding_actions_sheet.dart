/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/coding_status_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/adaptive_form_dialog.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

Future<void> showChatCodingActions(
  BuildContext context,
  CodingStatusStore coding,
  String cwd,
  String currentBranch,
) async {
  List<String> branches;
  try {
    branches = await coding.branches(cwd);
  } catch (error) {
    if (context.mounted) {
      showHermesToast(
        context,
        message: context.l10n.chatBranchesLoadFailed('$error'),
        kind: HermesToastKind.error,
      );
    }
    return;
  }
  if (!context.mounted) return;
  await showMobileSheet<void>(
    context,
    (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(context.l10n.gitSwitchBranch),
            subtitle: Text(context.l10n.chatLongPressCodingStatus),
          ),
          ListTile(
            leading: const Icon(Icons.call_split),
            title: Text(context.l10n.gitNewWorktree),
            subtitle: Text(context.l10n.chatNewWorktreeDescription),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await _createChatWorktree(context, coding, cwd, currentBranch);
            },
          ),
          const Divider(height: 1),
          for (final branch in branches)
            ListTile(
              leading: Icon(
                branch == currentBranch
                    ? Icons.check_circle
                    : Icons.account_tree_outlined,
              ),
              title: Text(branch),
              enabled: branch != currentBranch,
              onTap: branch == currentBranch
                  ? null
                  : () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await coding.switchBranch(cwd, branch);
                      } catch (error) {
                        if (context.mounted) {
                          showHermesToast(
                            context,
                            message: context.l10n.gitSwitchBranchFailed(
                              '$error',
                            ),
                            kind: HermesToastKind.error,
                          );
                        }
                      }
                    },
            ),
        ],
      ),
    ),
  );
}

Future<void> _createChatWorktree(
  BuildContext context,
  CodingStatusStore coding,
  String cwd,
  String currentBranch,
) async {
  final ctrl = TextEditingController();
  final name = await showAdaptiveFormDialog<String>(
    context: context,
    title: context.l10n.gitNewWorktree,
    content: TextField(
      controller: ctrl,
      autofocus: true,
      decoration: InputDecoration(
        labelText: context.l10n.commonName,
        hintText: context.l10n.gitWorktreeNameHint,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
        child: Text(context.l10n.commonCreate),
      ),
    ],
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  if (name == null || name.isEmpty || !context.mounted) return;
  try {
    final result = await coding.addWorktree(
      cwd,
      name: name,
      base: currentBranch,
    );
    final path = (result?['path'] ?? result?['worktreePath'])?.toString();
    if (path != null && path.isNotEmpty && context.mounted) {
      await context.read<SessionStore>().openNewSession(cwd: path);
    }
  } catch (error) {
    if (context.mounted) {
      showHermesToast(
        context,
        message: context.l10n.gitCreateWorktreeFailed('$error'),
        kind: HermesToastKind.error,
      );
    }
  }
}
