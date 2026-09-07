import 'package:flutter/material.dart';

import '../../chat/content/diff_view.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_tool.dart';
import 'tool_payload.dart';

/// Rich card rendering an inline unified diff for `edit_file` / `patch` /
/// `write_file` (and diff-carrying `changed_files` family) tool calls.
/// Extracted verbatim from `lib/widgets/message_bubble.dart` (formerly the
/// private `_InlineDiffToolCard`); behavior unchanged.
class InlineDiffToolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const InlineDiffToolCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final diff = inlineDiffText(data);
    final args = data['args'] is Map ? data['args'] as Map : const {};
    final rawPath = args['path'] ?? args['file'] ?? data['path'];
    final path = rawPath?.toString() ?? context.l10n.messageFileChanges;
    // Desktop `FileDiffPanel` parity: a `+N −M` hunk-stats line.
    final stats = diffLineStats(diff);
    final palette = HermesPalette.of(context);
    final good = hermesSemantic(
      context,
      HermesSemantic.green,
      HermesSemanticDark.green,
    );
    final bad = hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    );
    return ToolCardShell(
      key: ValueKey('inline-diff-$path'),
      icon: Icons.difference_outlined,
      title: path,
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.messageViewDiff,
            style: TextStyle(fontSize: 10.5, color: palette.text3),
          ),
          if (stats.added > 0 || stats.removed > 0) ...[
            const SizedBox(width: 8),
            Text(
              '+${stats.added}',
              style: TextStyle(
                color: good,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '−${stats.removed}',
              style: TextStyle(
                color: bad,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      children: [
        // Syntax-highlighted diff with tint + gutter accent + line numbers.
        FileDiffView(
          diff: diff,
          path: rawPath == null ? null : path,
          showLineNumbers: true,
        ),
      ],
    );
  }
}
