/// VibeHeartBurst — extracted from lib/screens/chat_screen.dart (pure move,
/// no behavior change): the ephemeral "heart burst" overlay for standalone
/// gateway `reaction` events.
library;

import 'package:flutter/material.dart';

/// Ephemeral desktop-parity feedback for the standalone gateway `reaction`
/// event ("ily", "<3", "good bot"). Persistent per-message reactions
/// continue to render inside [MessageBubble]; this overlay intentionally owns
/// no transcript state and never intercepts gestures.
class VibeHeartBurst extends StatefulWidget {
  const VibeHeartBurst({
    super.key,
    required this.revision,
    required this.animationsDisabled,
  });

  final int revision;
  final bool animationsDisabled;

  @override
  State<VibeHeartBurst> createState() => _VibeHeartBurstState();
}

class _VibeHeartBurstState extends State<VibeHeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
  }

  @override
  void didUpdateWidget(covariant VibeHeartBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision && widget.revision > 0) {
      if (widget.animationsDisabled) {
        _controller.value = 0;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animationsDisabled) return const SizedBox.expand();
    const hearts = <(double, double, double)>[
      (0.28, 0.00, 24),
      (0.40, 0.14, 31),
      (0.52, 0.04, 27),
      (0.63, 0.18, 34),
      (0.73, 0.08, 25),
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          if (_controller.value == 0 || _controller.isDismissed) {
            return const SizedBox.expand();
          }
          final opacity =
              (1 -
                      Curves.easeIn.transform(
                        ((_controller.value - 0.55) / 0.45).clamp(0.0, 1.0),
                      ))
                  .clamp(0.0, 1.0);
          return LayoutBuilder(
            builder: (context, constraints) => Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (x, delay, size) in hearts)
                  if (_controller.value > delay)
                    Positioned(
                      left: constraints.maxWidth * x - size / 2,
                      bottom:
                          24 +
                          (constraints.maxHeight *
                              0.42 *
                              ((t - delay).clamp(0.0, 1.0))),
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.rotate(
                          angle: (x - 0.5) * 0.55,
                          child: Transform.scale(
                            scale: 0.55 + 0.45 * t,
                            child: Text('❤️', style: TextStyle(fontSize: size)),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
