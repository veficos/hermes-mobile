import 'package:flutter/material.dart';

import '../../theme/hermes_glass_theme.dart';
import '../../theme/hermes_tokens.dart';

/// A non-interactive edge fade. Unlike glass it adds no backdrop filter.
class ScrollEdgeScrim extends StatelessWidget {
  const ScrollEdgeScrim({super.key, required this.child, this.top = true});

  final Widget child;
  final bool top;

  @override
  Widget build(BuildContext context) {
    if (!HermesGlassTheme.of(context).enabled) return child;
    final color = HermesPalette.of(context).surface;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: [
                    color.withValues(alpha: HermesGlassTokens.edgeAlpha),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
