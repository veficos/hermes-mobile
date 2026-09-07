/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

Future<T?> showChatOptionSheet<T extends String>(
  BuildContext context, {
  required String title,
  required String subtitle,
  required T current,
  required List<(T, IconData)> options,
  String? selectedLabel,
}) {
  return showMobileSheet<T>(
    context,
    (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: HermesType.onSurface(
                HermesType.headline,
                Theme.of(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final (value, icon) = options[i];
                  final selected = value == current;
                  final colors = Theme.of(context).colorScheme;
                  return Semantics(
                    selected: selected,
                    child: ListTile(
                      leading: Icon(
                        icon,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      title: Text(
                        value,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                      trailing: selected
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: colors.primary),
                                if (selectedLabel != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    selectedLabel,
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          HermesRadius.smallCard,
                        ),
                        side: BorderSide(
                          color: selected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      tileColor: selected
                          ? colors.primary.withValues(alpha: 0.16)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(value),
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
