import 'package:flutter/material.dart';

import '../../theme/hermes_glass_theme.dart';
import 'glass_surface.dart';

/// One bounded material for a related set of controls, not one blur per icon.
class GlassActionGroup extends StatelessWidget {
  const GlassActionGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!HermesGlassTheme.of(context).enabled) return child;
    return GlassSurface(radius: 24, thick: true, child: child);
  }
}
