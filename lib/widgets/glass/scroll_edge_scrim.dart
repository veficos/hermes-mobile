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
    if (!HermesGlassTheme.of(context).allowsTransparency(context)) return child;
    final color = HermesPalette.of(context).surface;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  // Approximate a smoothstep falloff: flatten both ends so
                  // the content edge does not read as a linear veil boundary.
                  stops: const [0, .25, .5, .75, 1],
                  colors: [
                    color.withValues(alpha: HermesGlassTokens.edgeAlpha),
                    color.withValues(
                      alpha: HermesGlassTokens.edgeAlpha * .84375,
                    ),
                    color.withValues(alpha: HermesGlassTokens.edgeAlpha * .5),
                    color.withValues(
                      alpha: HermesGlassTokens.edgeAlpha * .15625,
                    ),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
