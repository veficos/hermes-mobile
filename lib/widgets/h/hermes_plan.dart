/// HermesPlanCard (spec §28–29): todo/plan list rendered from the `todo`
/// tool's payload (todos/result/args). Steps show ✓ completed / ● in progress
/// / ○ pending / ✕ cancelled; tapping a step expands nothing extra (mobile
/// keeps it flat), long-press copies the list.
library;

import 'package:flutter/material.dart';

import '../../core/clipboard.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import 'hermes_glass.dart';

class HermesPlanCard extends StatelessWidget {
  final List<Map<String, dynamic>> todos;
  final bool compact;

  const HermesPlanCard({super.key, required this.todos, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) return const SizedBox.shrink();
    final info = hermesSemantic(
      context,
      HermesSemantic.blue,
      HermesSemanticDark.blue,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: HermesGlassCard(
        radius: HermesRadius.card,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.list_alt_outlined, size: 16, color: info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.toolPlanTitle,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.toolPlanCopy,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      final text = todos
                          .map(
                            (t) =>
                                '${_statusIcon(t['status'].toString())} '
                                '${t['content'] ?? t['id'] ?? ''}',
                          )
                          .join('\n');
                      copyTextOrNotify(
                        context,
                        text,
                        successMessage: context.l10n.toolPlanCopied,
                      );
                    },
                  ),
                ],
              ),
            ),
            for (final t in todos)
              _stepRow(context, (t as Map).cast<String, dynamic>()),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(BuildContext context, Map<String, dynamic> todo) {
    final palette = HermesPalette.of(context);
    final status = (todo['status'] ?? 'pending').toString();
    final content = (todo['content'] ?? todo['id'] ?? '').toString();
    final inProgress = status == 'in_progress';
    // §6.8：✓ success / ● accent 呼吸 / ○ text-4 / ✕ error。
    final (icon, color) = switch (status) {
      'completed' => (
        Icons.check_circle,
        hermesSemantic(context, HermesSemantic.green, HermesSemanticDark.green),
      ),
      'in_progress' => (Icons.radio_button_checked, palette.accent),
      'cancelled' => (
        Icons.cancel_outlined,
        hermesSemantic(context, HermesSemantic.red, HermesSemanticDark.red),
      ),
      _ => (Icons.radio_button_unchecked, palette.text4),
    };
    return InkWell(
      onTap: () {
        copyTextOrNotify(
          context,
          content,
          successMessage: context.l10n.commonCopied,
        );
      },
      // §6.8：进行中步骤行 accent-bg 底高亮。
      child: Container(
        color: inProgress ? palette.accentBg : null,
        padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            inProgress
                ? _BreathingStepIcon(color: color)
                : Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                content,
                style: HermesType.body.copyWith(
                  decoration: status == 'completed'
                      ? TextDecoration.lineThrough
                      : null,
                  color: status == 'completed' || status == 'cancelled'
                      ? palette.text3
                      : palette.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusIcon(String status) => switch (status) {
    'completed' => '✓',
    'in_progress' => '●',
    'cancelled' => '✕',
    _ => '○',
  };
}

/// §6.8 进行中步骤的 ● accent 呼吸图标（1200ms；系统"减弱动态效果"时
/// 静态呈现，§9）。
class _BreathingStepIcon extends StatefulWidget {
  final Color color;
  const _BreathingStepIcon({required this.color});

  @override
  State<_BreathingStepIcon> createState() => _BreathingStepIconState();
}

class _BreathingStepIconState extends State<_BreathingStepIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.radio_button_checked,
      size: 16,
      color: widget.color,
    );
    if (MediaQuery.disableAnimationsOf(context)) return icon;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_controller),
      child: icon,
    );
  }
}
