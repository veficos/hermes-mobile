import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_glass_theme.dart';
import '../../theme/hermes_tokens.dart';
import 'chat_timeline.dart';

class TurnActivityCard extends StatelessWidget {
  final TurnActivity activity;
  const TurnActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final duration = activity.duration;
    final liquid = HermesGlassTheme.of(context).enabled;
    final palette = HermesPalette.of(context);
    final opaque =
        HermesGlassTheme.of(context).reduceTransparency ||
        HermesA11y.highContrastOf(context) ||
        MediaQuery.highContrastOf(context);
    final label = [
      if (activity.toolCount > 0)
        context.l10n.turnActivityTools(activity.toolCount),
      if (activity.reasoningBlocks > 0)
        context.l10n.turnActivityReasoning(activity.reasoningBlocks),
      if (duration != null) '${duration.inMilliseconds}ms',
    ].join(' · ');
    if (liquid) {
      return Container(
        margin: const EdgeInsets.only(top: 2, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: opaque
              ? palette.surface
              : palette.surface.withValues(alpha: .78),
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
          border: Border.all(
            color: opaque
                ? palette.borderStrong
                : palette.border.withValues(alpha: .72),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activity.running ? Icons.timelapse : Icons.timeline_outlined,
              size: 14,
              color: activity.running ? palette.accent : palette.text3,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.labelSmall),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            activity.running ? Icons.timelapse : Icons.timeline_outlined,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            [
              if (activity.toolCount > 0)
                context.l10n.turnActivityTools(activity.toolCount),
              if (activity.reasoningBlocks > 0)
                context.l10n.turnActivityReasoning(activity.reasoningBlocks),
              if (duration != null) '${duration.inMilliseconds}ms',
            ].join(' · '),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
