/// ToolsetCountChip — extracted from lib/screens/chat_screen.dart (pure
/// move, no behavior change): the session/global toolset count chip used by
/// the tools configuration sheet.
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

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
    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(HermesRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HermesRadius.card),
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
    );
  }
}
