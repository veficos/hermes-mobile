/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/local_slash_commands.dart';
import '../../core/stores/command_store.dart';
import '../../l10n/l10n.dart';

Future<void> showChatSlashHelpDialog(BuildContext context) async {
  final local = localSlashCommandPairs(context.l10n);
  final catalog = context.read<CommandStore>().catalog;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(context.l10n.chatSlashCommands),
        content: SizedBox(
          width: 420,
          height: 420,
          child: ListView(
            children: [
              Text(
                context.l10n.chatLocalCommands,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final pair in local)
                ListTile(
                  dense: true,
                  title: Text('/${pair.$1}'),
                  subtitle: Text(pair.$2),
                ),
              const Divider(),
              Text(
                context.l10n.chatServerCatalog,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (catalog.isEmpty)
                ListTile(
                  dense: true,
                  title: Text(context.l10n.chatCatalogEmpty),
                )
              else
                for (final cmd in catalog)
                  if (!isMobileSlashSuggestionHidden(cmd.name))
                    ListTile(
                      dense: true,
                      title: Text(
                        cmd.name.startsWith('/') ? cmd.name : '/${cmd.name}',
                      ),
                      subtitle: cmd.description == null
                          ? null
                          : Text(cmd.description!),
                    ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonClose),
          ),
        ],
      );
    },
  );
}
