/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../screens/files_screen.dart';
import '../../widgets/adaptive_form_dialog.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';
import '../../widgets/glass/glass_selection_row.dart';
import '../../theme/hermes_glass_theme.dart';

Future<String?> showChatWorkspacePickerSheet(
  BuildContext context, {
  required String current,
  required String? defaultCwd,
  required String? sessionCwd,
  required List<Map<String, dynamic>> projects,
}) {
  final seen = <String>{};
  final options = <(String, IconData)>[];
  void add(String? path, IconData icon) {
    final value = (path ?? '').trim();
    if (value.isEmpty || !seen.add(value)) return;
    options.add((value, icon));
  }

  add(defaultCwd, Icons.folder_special);
  add(sessionCwd, Icons.folder);
  for (final project in projects) {
    var path = project['path']?.toString();
    if (path == null || path.trim().isEmpty) {
      final repos = project['repos'] as List? ?? const [];
      for (final repo in repos) {
        if (repo is Map && (repo['path']?.toString().isNotEmpty ?? false)) {
          path = repo['path'].toString();
          break;
        }
      }
    }
    add(path, Icons.source);
  }
  return showMobileSheet<String>(
    context,
    (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.l10n.chatChangeWorkspace),
              subtitle: Text(context.l10n.chatChangeWorkspaceDescription),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(context.l10n.chatBrowseFiles),
              subtitle: Text(context.l10n.chatBrowseFilesDescription),
              onTap: () async {
                final picked = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) =>
                        FilesScreen(initialPath: current, pickMode: true),
                  ),
                );
                if (picked != null &&
                    picked.isNotEmpty &&
                    sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(picked);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: Text(context.l10n.chatEnterOtherDirectory),
              subtitle: Text(context.l10n.chatAbsoluteServerPath),
              onTap: () async {
                final custom = await promptChatWorkspacePath(context, current);
                if (custom != null && sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(custom);
                }
              },
            ),
            if (options.isNotEmpty) const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, index) {
                  final (path, icon) = options[index];
                  final selected = path == current;
                  final liquid = HermesGlassTheme.of(sheetContext).enabled;
                  return GlassSelectionRow(
                    selected: selected,
                    child: ListTile(
                      selected: liquid && selected,
                      selectedColor: liquid
                          ? Theme.of(
                              sheetContext,
                            ).colorScheme.onPrimaryContainer
                          : null,
                      leading: Icon(icon),
                      title: Text(
                        path,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(path),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> promptChatWorkspacePath(
  BuildContext context,
  String current,
) async {
  final controller = TextEditingController(text: current);
  final result = await showAdaptiveFormDialog<String>(
    context: context,
    title: context.l10n.chatEnterWorkspacePath,
    content: TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: context.l10n.chatServerDirectory,
        hintText: '/home/user/project',
        helperText: context.l10n.chatServerDirectoryHelp,
      ),
      onSubmitted: (value) {
        final path = value.trim();
        if (path.isNotEmpty) Navigator.of(context).pop(path);
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () {
          final path = controller.text.trim();
          if (path.isNotEmpty) Navigator.of(context).pop(path);
        },
        child: Text(context.l10n.commonSwitch),
      ),
    ],
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  return result?.trim();
}
