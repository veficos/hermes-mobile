/// Session row long-press / popup action menu (Batch 3: Sidebar + Session mgmt).
///
/// Provides the desktop-compatible row actions for a single [SessionRow]:
/// reference, rename, pin, project move, archive, branch, stop, export/delete.
/// Errors are surfaced via [ScaffoldMessenger] SnackBars so callers don't need
/// to catch and report individually.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/clipboard.dart';
import '../../core/connections/connection_registry.dart';
import '../../core/stores/connection_store.dart';
import '../../core/stores/pane_workspace_store.dart';
import '../../core/stores/session_appearance_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../screens/pane_workspace_screen.dart';
import '../../theme/hermes_tokens.dart';
import 'io_export.dart';
import 'project_dialog.dart';

/// Callback invoked when a menu action mutates session list state and the
/// caller (e.g. [SessionsScreen]) should refresh its list.
typedef SessionListRefresh = Future<void> Function();

/// Action sheet / popup menu shown when a session row is long-pressed or
/// its trailing "more" button is tapped.
class SessionRowActions extends StatelessWidget {
  final SessionRow session;
  final SessionListRefresh? onRefreshed;

  /// Invoked from the duplicate SnackBar action so the caller (which owns
  /// chat navigation) can resume and open the freshly copied session.
  final Future<void> Function(SessionRow copy)? onOpenCopy;
  final bool isArchived;
  final bool isStarred;
  final bool supportsSharing;

  const SessionRowActions({
    super.key,
    required this.session,
    this.onRefreshed,
    this.onOpenCopy,
    this.isArchived = false,
    this.isStarred = false,
    this.supportsSharing = true,
  });

  static Future<void> show(
    BuildContext context, {
    required SessionRow session,
    SessionListRefresh? onRefreshed,
    Future<void> Function(SessionRow copy)? onOpenCopy,
    bool isArchived = false,
    bool isStarred = false,
    bool? supportsSharing,
  }) {
    SessionStore? sessionStore;
    try {
      sessionStore = context.read<SessionStore>();
    } on ProviderNotFoundException {
      // The action sheet also supports standalone presentation in tests and
      // embedders. Companion sharing is the backwards-compatible default.
    }
    final resolvedSupportsSharing =
        supportsSharing ?? sessionStore?.api?.supportsSessionSharing ?? true;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SessionRowActions(
        session: session,
        onRefreshed: onRefreshed,
        onOpenCopy: onOpenCopy,
        isArchived: isArchived,
        isStarred: isStarred,
        supportsSharing: resolvedSupportsSharing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionContext = Navigator.of(context).context;
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark
        ? HermesBackground.darkSecondary
        : HermesBackground.lightSecondary;
    final border = isDark
        ? HermesBackground.darkBorder
        : HermesBackground.lightBorder;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(HermesSpacing.md),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(HermesRadius.sheet),
          border: Border.all(color: border, width: 1),
          boxShadow: hermesShadow(context, HermesShadowTier.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            _header(context),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  _tile(
                    context,
                    icon: Icons.view_quilt_outlined,
                    label: context.l10n.sessionActionOpenWorkspace,
                    showChevron: false,
                    onTap: () => _openInWorkspace(actionContext),
                  ),
                  const Divider(height: 1),
                  if (!session.readOnly) ...[
                    _tile(
                      context,
                      icon: Icons.drive_file_rename_outline,
                      label: context.l10n.chatRename,
                      onTap: () => _rename(actionContext),
                    ),
                    _tile(
                      context,
                      icon: session.pinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      label: session.pinned
                          ? context.l10n.sessionActionUnpin
                          : context.l10n.sessionActionPin,
                      showChevron: false,
                      onTap: () => _togglePin(actionContext),
                    ),
                    _tile(
                      context,
                      icon: Icons.palette_outlined,
                      label: context.l10n.sessionActionAppearance,
                      onTap: () => _chooseAppearance(actionContext),
                    ),
                    _tile(
                      context,
                      icon: Icons.content_copy_outlined,
                      label: context.l10n.chatCopySessionId,
                      showChevron: false,
                      onTap: () => _copyId(actionContext),
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      icon: Icons.call_split_outlined,
                      label: context.l10n.chatBranchInNewSession,
                      showChevron: false,
                      onTap: () => _branch(actionContext),
                    ),
                    _tile(
                      context,
                      icon: Icons.copy_all_outlined,
                      label: context.l10n.sessionActionDuplicate,
                      showChevron: false,
                      onTap: () => _duplicate(actionContext),
                    ),
                    if (supportsSharing)
                      _tile(
                        context,
                        icon: Icons.ios_share_outlined,
                        label: context.l10n.sessionActionShare,
                        showChevron: false,
                        onTap: () => _share(actionContext),
                      ),
                    _tile(
                      context,
                      icon: Icons.download_outlined,
                      label: context.l10n.sessionActionExport,
                      onTap: () => _export(actionContext),
                    ),
                    _tile(
                      context,
                      icon: Icons.drive_file_move_outline,
                      label: context.l10n.sessionActionMoveProject,
                      onTap: () => _moveToProject(actionContext),
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      icon: isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      label: isArchived
                          ? context.l10n.sessionActionUnarchive
                          : context.l10n.sessionActionArchive,
                      showChevron: false,
                      onTap: () => _toggleArchive(actionContext),
                    ),
                    if (session.activeStreamId?.isNotEmpty == true)
                      _tile(
                        context,
                        icon: Icons.stop_circle_outlined,
                        label: context.l10n.sessionActionStopResponse,
                        iconColor: HermesSemantic.red,
                        showChevron: false,
                        onTap: () => _stopResponse(actionContext),
                      ),
                  ],
                  if (session.readOnly)
                    _tile(
                      context,
                      icon: Icons.content_copy_outlined,
                      label: context.l10n.chatCopySessionId,
                      showChevron: false,
                      onTap: () => _copyId(actionContext),
                    ),
                  if (session.readOnly)
                    _tile(
                      context,
                      icon: Icons.download_outlined,
                      label: context.l10n.sessionActionExport,
                      onTap: () => _export(actionContext),
                    ),
                  if (!session.readOnly)
                    _tile(
                      context,
                      icon: Icons.delete_outline,
                      label: context.l10n.sessionDeleteTitle,
                      iconColor: HermesSemantic.red,
                      textColor: HermesSemantic.red,
                      showChevron: false,
                      onTap: () => _confirmDelete(actionContext),
                    ),
                ],
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _handle() {
    return Padding(
      padding: const EdgeInsets.only(top: HermesSpacing.sm),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: HermesText.darkQuaternary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final title = session.title?.isNotEmpty == true
        ? session.title!
        : context.l10n.sessionUntitled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.md,
        HermesSpacing.sm,
        HermesSpacing.md,
        HermesSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.l10n.sessionMessageCount(session.messageCount ?? 0)} · ${session.displaySource} · ${_fmtId(session.id)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    bool showChevron = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg =
        textColor ??
        (isDark ? HermesText.darkPrimary : HermesText.lightPrimary);
    final ic =
        iconColor ??
        (isDark ? HermesText.darkTertiary : HermesText.lightTertiary);
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HermesSpacing.md,
          vertical: HermesSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ic),
            const SizedBox(width: HermesSpacing.md),
            Expanded(
              child: Text(label, style: TextStyle(color: fg, fontSize: 15)),
            ),
            if (showChevron) Icon(Icons.chevron_right, size: 18, color: ic),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> _openInWorkspace(BuildContext context) async {
    final connection = context.read<ConnectionStore>();
    final route =
        connection.sessionOwners.byDurable(session.id)?.route ??
        OwnerRoute(
          connectionId: connection.activeConnectionId,
          profile: session.profile,
        );
    try {
      await context.read<PaneWorkspaceStore>().openSession(
        durableId: session.id,
        title: session.title ?? context.l10n.sessionUntitled,
        owner: route,
        readOnly: session.readOnly,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PaneWorkspaceScreen()),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.workspaceOpenSessionFailed('$error')),
          ),
        );
      }
    }
  }

  Future<void> _copyId(BuildContext context) async {
    await copyTextOrNotify(
      context,
      session.id,
      successMessage: context.l10n.chatSessionIdCopied,
    );
  }

  Future<void> _chooseAppearance(BuildContext context) async {
    final appearance = context.read<SessionAppearanceStore>();
    final current = appearance.colorFor(session.id);
    final selected = await showDialog<Color?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.sessionActionAppearanceTitle),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            InkWell(
              key: const ValueKey('session-color-clear'),
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.of(dialogContext).pop(Colors.transparent),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current == null
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: current == null ? 3 : 1,
                  ),
                ),
                child: const Icon(Icons.block, size: 20),
              ),
            ),
            for (final color in SessionAppearanceStore.swatches)
              InkWell(
                key: ValueKey('session-color-${color.toARGB32()}'),
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.of(dialogContext).pop(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current?.toARGB32() == color.toARGB32()
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await appearance.setColor(
      session.id,
      selected == Colors.transparent ? null : selected,
    );
  }

  Future<void> _rename(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionStore = context.read<SessionStore>();
    final ctrl = TextEditingController(text: session.title ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.chatRenameSession),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.commonTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    final title = ctrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (ok != true) return;
    try {
      await sessionStore.renameStoredSession(session.id, title);
      await onRefreshed?.call();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionActionRenameFailed('$e'))),
        );
      }
    }
  }

  Future<void> _toggleArchive(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionStore = context.read<SessionStore>();
    try {
      await sessionStore.setArchived(session.id, !isArchived);
      await sessionStore.refreshList();
      await onRefreshed?.call();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isArchived
                  ? context.l10n.sessionActionUnarchived
                  : context.l10n.sessionActionArchived,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionActionFailed('$e'))),
        );
      }
    }
  }

  Future<void> _togglePin(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionStore = context.read<SessionStore>();
    try {
      await sessionStore.setPinned(session.id, !session.pinned);
      await onRefreshed?.call();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              session.pinned
                  ? context.l10n.sessionActionUnpinned
                  : context.l10n.sessionActionPinned,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionActionFailed('$e'))),
        );
      }
    }
  }

  Future<void> _moveToProject(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionStore = context.read<SessionStore>();
    final project = await ProjectDialog.showMoveTarget(
      context,
      currentProjectId: session.projectId,
      currentCwd: session.cwd,
    );
    if (project == null) return;
    final projectId = (project['project_id'] ?? project['id'])?.toString();
    if (projectId == null || projectId.isEmpty) return;
    try {
      await sessionStore.moveStoredSession(session.id, projectId);
      await onRefreshed?.call();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionActionMoved)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionActionMoveFailed('$e'))),
        );
      }
    }
  }

  Future<void> _branch(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionStore = context.read<SessionStore>();
    try {
      final branch = await sessionStore.branchStoredSession(session.id);
      await onRefreshed?.call();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.sessionActionBranchCreated(_fmtId(branch.id)),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatBranchFailed('$e'))),
        );
      }
    }
  }

  Future<void> _duplicate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionStore = context.read<SessionStore>();
    try {
      final copy = await sessionStore.duplicateStoredSession(session.id);
      await onRefreshed?.call();
      if (!context.mounted) return;
      final openCopy = onOpenCopy;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.sessionActionCopyCreated),
          action: openCopy == null
              ? null
              : SnackBarAction(
                  label: context.l10n.commonOpen,
                  onPressed: () => openCopy(copy),
                ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.sessionActionDuplicateFailed('$e')),
          ),
        );
      }
    }
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionStore = context.read<SessionStore>();
    try {
      final url = await sessionStore.createStoredSessionShare(session.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.sessionActionShareCreated),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.sessionActionShareWarning),
              const SizedBox(height: HermesSpacing.md),
              SelectableText(
                url,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.commonClose),
            ),
            FilledButton.icon(
              onPressed: () async {
                final copied = await copyTextOrNotify(context, url);
                if (copied && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (copied && context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.chatSessionShareLinkCopied),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: Text(context.l10n.chatCopySessionLink),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionActionShareFailed('$e'))),
        );
      }
    }
  }

  Future<void> _stopResponse(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SessionStore>().stopStoredSession(session);
      await onRefreshed?.call();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionActionStopRequested)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatStopProcessFailed('$e'))),
        );
      }
    }
  }

  Future<void> _export(BuildContext context) async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.l10n.sessionActionExport),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('html'),
            child: ListTile(
              leading: const Icon(Icons.html),
              title: const Text('HTML'),
              subtitle: Text(context.l10n.sessionActionExportMarkdownHint),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('json'),
            child: ListTile(
              leading: const Icon(Icons.data_object),
              title: const Text('JSON'),
              subtitle: Text(context.l10n.sessionActionExportJsonHint),
            ),
          ),
        ],
      ),
    );
    if (format == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await context.read<SessionStore>().exportStoredSession(
        session.id,
        format: format,
      );
      final content = result['content']?.toString() ?? '';
      if (!context.mounted) return;
      if (kIsWeb) {
        await copyTextOrNotify(
          context,
          content,
          successMessage: context.l10n.sessionActionExportCopiedWeb,
        );
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final exportDirectoryPath = p.join(directory.path, 'Hermes Exports');
      // Deferred dart:io usage via path_provider directory create through XFile write
      // is not available; use conditional import helper below.
      final savedPath = await writeExportFile(
        exportDirectoryPath,
        (result['filename'] ?? 'hermes-${session.id}.$format').toString(),
        content,
      );
      if (!context.mounted) return;
      await copyTextOrNotify(
        context,
        savedPath,
        successMessage: context.l10n.sessionActionExported(savedPath),
      );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionActionExportFailed('$e'))),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionStore = context.read<SessionStore>();
    final title = session.title?.isNotEmpty == true
        ? session.title!
        : context.l10n.sessionUntitled;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.sessionDeleteTitle),
        content: Text(context.l10n.sessionDeleteDescription(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await sessionStore.delete(session.id);
      await onRefreshed?.call();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionDeletedCount(1))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.sessionDeleteFailed('$e'))),
        );
      }
    }
  }

  static String _fmtId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }
}
