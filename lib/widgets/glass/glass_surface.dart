import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/hermes_glass_theme.dart';
import '../../theme/hermes_tokens.dart';

/// Bounded glass for navigation and controls; content stays on solid surfaces.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = HermesGlassTokens.controlRadius,
    this.thick = false,
  });
  final Widget child;
  final double radius;
  final bool thick;

  @override
  Widget build(BuildContext context) {
    final glass = HermesGlassTheme.of(context);
    if (!glass.enabled) return child;
    final palette = HermesPalette.of(context);
    final opaque =
        glass.reduceTransparency ||
        HermesA11y.highContrastOf(context) ||
        MediaQuery.highContrastOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.elevated.withValues(
              alpha: opaque
                  ? 1
                  : thick
                  ? HermesGlassTokens.thickTopAlpha
                  : HermesGlassTokens.regularTopAlpha,
            ),
            palette.surface.withValues(
              alpha: opaque
                  ? 1
                  : thick
                  ? HermesGlassTokens.thickBottomAlpha
                  : HermesGlassTokens.regularBottomAlpha,
            ),
          ],
        ),
        border: Border.all(
          color: opaque
              ? palette.borderStrong
              : dark
              ? HermesGlassTokens.darkHighlight
              : HermesGlassTokens.lightHighlight,
          width: opaque ? 1.5 : 1,
        ),
      ),
      child: child,
    );
    // Nested controls share their parent's sampled backdrop. This prevents
    // tool groups and nested sheets from stacking expensive blur passes.
    if (!opaque &&
        context.findAncestorWidgetOfExactType<GlassSurface>() == null) {
      content = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: HermesGlassTokens.blurSigma,
          sigmaY: HermesGlassTokens.blurSigma,
        ),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: dark || opaque
            ? const []
            : const [
                BoxShadow(
                  color: HermesGlassTokens.lightShadow,
                  blurRadius: HermesGlassTokens.shadowBlur,
                  offset: HermesGlassTokens.shadowOffset,
                ),
              ],
      ),
      child: ClipRRect(borderRadius: shape, child: content),
    );
  }
}
