/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../../theme/hermes_glass_theme.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';
import '../../widgets/glass/glass_selection_row.dart';

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
                  if (HermesGlassTheme.of(ctx).enabled) {
                    return GlassSelectionRow(
                      selected: selected,
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () => Navigator.of(ctx).pop(value),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  color: selected
                                      ? colors.onPrimaryContainer
                                      : colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        value,
                                        style: TextStyle(
                                          color: selected
                                              ? colors.onPrimaryContainer
                                              : colors.onSurface,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      if (selected && selectedLabel != null)
                                        Text(
                                          selectedLabel,
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color:
                                                    colors.onPrimaryContainer,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.check_circle,
                                    color: colors.onPrimaryContainer,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
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
