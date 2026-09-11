/// ToolsetCountChip — extracted from lib/screens/chat_screen.dart (pure
/// move, no behavior change): the session/global toolset count chip used by
/// the tools configuration sheet.
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../../theme/hermes_glass_theme.dart';

class ToolsetCountChip extends StatelessWidget {
  final String label;
  final String count;
  final bool selected;
  final VoidCallback? onTap;

  const ToolsetCountChip({
    super.key,
    required this.label,
    required this.count,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liquid = HermesGlassTheme.of(context).enabled;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(HermesRadius.card),
    );
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: liquid ? shape : null,
        borderRadius: liquid ? null : BorderRadius.circular(HermesRadius.card),
        child: InkWell(
          onTap: onTap,
          customBorder: liquid ? shape : null,
          borderRadius: BorderRadius.circular(HermesRadius.card),
          child: ConstrainedBox(
            constraints: liquid && onTap != null
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : const BoxConstraints(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '$label：$count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
