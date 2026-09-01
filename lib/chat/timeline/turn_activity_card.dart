import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'chat_timeline.dart';

class TurnActivityCard extends StatelessWidget {
  final TurnActivity activity;
  const TurnActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final duration = activity.duration;
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
