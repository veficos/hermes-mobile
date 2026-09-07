/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/stores/chat_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';
import '../../widgets/web_preview.dart';

Future<void> showChatArtifactVersions(
  BuildContext context,
  ChatStore chat,
) async {
  await showMobileSheet<void>(
    context,
    (sheetContext) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .72,
        child: ListView(
          children: [
            ListTile(
              title: Text(context.l10n.chatCurrentSessionArtifacts),
              subtitle: Text(context.l10n.chatBrowseArtifactsDescription),
            ),
            for (final entry in chat.artifactRegistry.entries)
              ExpansionTile(
                leading: const Icon(Icons.code_outlined),
                title: Text(entry.key.toUpperCase()),
                subtitle: Text(
                  context.l10n.chatVersionCount(entry.value.length),
                ),
                children: [
                  for (var index = 0; index < entry.value.length; index++)
                    ListTile(
                      dense: true,
                      title: Text(context.l10n.chatVersionNumber(index + 1)),
                      subtitle: Text(
                        entry.value[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WebPreviewPage(
                              html: entry.key == 'html'
                                  ? entry.value[index]
                                  : '<pre>${const HtmlEscape().convert(entry.value[index])}</pre>',
                              title:
                                  '${entry.key.toUpperCase()} · v${index + 1}',
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
