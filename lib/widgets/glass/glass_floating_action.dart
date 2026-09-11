import 'package:flutter/material.dart';

import '../../theme/hermes_glass_theme.dart';
import 'glass_button.dart';
import 'glass_surface.dart';

/// A standalone action above content, sharing the app's glass control language.
class GlassFloatingAction extends StatelessWidget {
  const GlassFloatingAction({
    super.key,
    required this.heroTag,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.interactive = true,
  });

  final Object heroTag;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  /// Disable input and semantics immediately while the parent fades out.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      excluding: !interactive,
      child: ExcludeSemantics(
        excluding: !interactive,
        child: IgnorePointer(
          ignoring: !interactive,
          child: _buildAction(context),
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (!HermesGlassTheme.of(context).enabled) {
      return FloatingActionButton.small(
        heroTag: heroTag,
        tooltip: tooltip,
        onPressed: onPressed,
        child: child,
      );
    }
    return GlassSurface(
      radius: 24,
      role: HermesGlassRole.control,
      child: GlassButton(tooltip: tooltip, onPressed: onPressed, child: child),
    );
  }
}
