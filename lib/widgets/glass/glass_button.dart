import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../../theme/hermes_glass_theme.dart';

/// Accessible control for a shared glass action group. No independent blur.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.tooltip,
    required this.child,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Semantics(
      selected: selected,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: child,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: selected ? palette.accent : palette.text2,
          backgroundColor: selected ? palette.accentBg : Colors.transparent,
          shape: const StadiumBorder(),
          side: selected ? BorderSide(color: palette.accent) : BorderSide.none,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : HermesGlassTokens.feedbackDuration,
        ),
      ),
    );
  }
}
