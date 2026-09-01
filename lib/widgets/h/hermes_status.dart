/// Status components: HermesStatusChip, HermesAgentStatusView,
/// HermesToolStatusView (design-system.md §6.4: pill 高 24、px11 字重 600、
/// 语义色文字 + 10%(light)/18%(dark) 透明度底、左 6px 圆点；运行中 1200ms
/// 呼吸动效).
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';

String _agentStatusLabel(BuildContext context, HermesAgentStatus status) =>
    switch (status) {
      HermesAgentStatus.idle => context.l10n.statusIdle,
      HermesAgentStatus.thinking => context.l10n.statusThinking,
      HermesAgentStatus.planning => context.l10n.statusPlanning,
      HermesAgentStatus.running => context.l10n.statusRunning,
      HermesAgentStatus.waiting => context.l10n.statusWaiting,
      HermesAgentStatus.approval => context.l10n.statusAwaitingApproval,
      HermesAgentStatus.paused => context.l10n.statusPaused,
      HermesAgentStatus.completed => context.l10n.statusCompleted,
      HermesAgentStatus.failed => context.l10n.statusFailed,
      HermesAgentStatus.stopped => context.l10n.statusStopped,
    };

String _toolStatusLabel(BuildContext context, HermesToolStatus status) =>
    switch (status) {
      HermesToolStatus.pending => context.l10n.statusWaiting,
      HermesToolStatus.running => context.l10n.statusRunning,
      HermesToolStatus.completed => context.l10n.statusCompleted,
      HermesToolStatus.failed => context.l10n.statusFailed,
      HermesToolStatus.cancelled => context.l10n.statusCancelled,
      HermesToolStatus.approval => context.l10n.statusAwaitingApproval,
    };

/// Compact status pill (design-system.md §6.4): height 24 / r-pill /
/// semantic tinted bg (10% light, 18% dark) + semantic 11px w600 label +
/// 6px leading dot. [pulse] adds the 1200ms breathing animation.
class HermesStatusChip extends StatelessWidget {
  final Color color;
  final String label;
  final IconData? icon;
  final bool pulse;

  const HermesStatusChip({
    super.key,
    required this.color,
    required this.label,
    this.icon,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: context.l10n.statusSemantics(label),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pulse)
              _PulseDot(color: color)
            else if (icon != null)
              Icon(icon, size: 12, color: color)
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
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
    // Reduce Motion（design-system.md §9）：系统减弱动态效果时静态圆点。
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_controller),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Agent status view: icon + label + color (spec §166).
class HermesAgentStatusView extends StatelessWidget {
  final HermesAgentStatus status;
  final bool showLabel;
  final bool animate;

  const HermesAgentStatusView({
    super.key,
    required this.status,
    this.showLabel = true,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color(context);
    final label = _agentStatusLabel(context, status);
    final pulse =
        status == HermesAgentStatus.running ||
        status == HermesAgentStatus.thinking ||
        status == HermesAgentStatus.planning;
    return Semantics(
      label: context.l10n.statusAgentSemantics(label),
      button: false,
      child: HermesStatusChip(
        color: color,
        label: showLabel ? label : '',
        pulse: animate && pulse,
      ),
    );
  }
}

/// Tool status view (spec §167).
class HermesToolStatusView extends StatelessWidget {
  final HermesToolStatus status;

  const HermesToolStatusView({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.color(context);
    final label = _toolStatusLabel(context, status);
    final pulse = status == HermesToolStatus.running;
    return Semantics(
      label: context.l10n.statusToolSemantics(label),
      child: HermesStatusChip(color: color, label: label, pulse: pulse),
    );
  }
}
