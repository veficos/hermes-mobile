import 'package:flutter/material.dart';

import '../../theme/hermes_glass_theme.dart';
import '../../theme/hermes_tokens.dart';

/// Adds restrained color fields behind Liquid controls so backdrop sampling
/// has meaningful context. Content remains the foreground surface.
class GlassEnvironment extends StatelessWidget {
  const GlassEnvironment({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = HermesGlassTheme.of(context);
    final palette = HermesPalette.of(context);
    if (!glass.enabled) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.bg,
            Color.alphaBlend(
              palette.accentBg.withValues(alpha: .22),
              palette.bg,
            ),
            palette.bg,
          ],
        ),
      ),
      child: child,
    );
  }
}
