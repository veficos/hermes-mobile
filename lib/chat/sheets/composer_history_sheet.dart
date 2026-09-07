/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

Future<String?> showChatComposerInputHistory(
  BuildContext context,
  List<String> entries,
) {
  return showMobileSheet<String>(
    context,
    (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              context.l10n.chatRecentInputs,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) => ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(
                  entries[index],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(sheetContext).pop(entries[index]),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
