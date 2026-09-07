import 'package:flutter/material.dart';

import '../../core/tool_card_models.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_tool.dart';

/// Rich card for `terminal` / `terminal_exec` / `execute` tool calls.
/// Extracted verbatim from `lib/widgets/message_bubble.dart` (formerly the
/// private `_TerminalToolCard`); behavior unchanged.
class TerminalToolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const TerminalToolCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final run = TerminalRunModel.from(data);
    final palette = HermesPalette.of(context);
    return ToolCardShell(
      key: ValueKey('tool-card-${data['tool_id'] ?? data['id'] ?? 'terminal'}'),
      icon: Icons.terminal,
      title: 'terminal',
      subtitle: run.command.isEmpty
          ? null
          : Text(
              run.command,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: palette.text3),
            ),
      trailing: run.running
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      failed: run.failed,
      initiallyExpanded: false,
      children: [
        if (run.command.isNotEmpty) ...[
          Text(
            context.l10n.toolCommand,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: toolCodeBoxDecoration(context),
            child: SelectableText(
              run.command,
              style: HermesType.code.copyWith(
                color: palette.text,
                fontSize: 12,
              ),
            ),
          ),
        ],
        if (run.exitCode != null || run.durationMs != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                if (run.exitCode != null)
                  context.l10n.toolExitCode(run.exitCode!),
                if (run.durationMs != null) '${run.durationMs}ms',
              ].join(' · '),
              style: TextStyle(fontSize: 11, color: palette.text3),
            ),
          ),
        if (run.output.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.toolOutput,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: toolCodeBoxDecoration(context),
            child: SingleChildScrollView(
              child: SelectableText(
                run.output,
                style: HermesType.code.copyWith(
                  color: palette.text,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
