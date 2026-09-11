import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../../theme/hermes_glass_theme.dart';

/// Accessible control for a shared glass action group. No independent blur.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.tooltip,
    required this.child,
    required this.onPressed,
    this.selected = false,
    this.focusNode,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;
  final FocusNode? focusNode;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final liquid = HermesGlassTheme.of(context).enabled;
    final selected = widget.selected;
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final animate = liquid && !reduceMotion;
    return Semantics(
      selected: selected,
      child: IconButton(
        focusNode: widget.focusNode,
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
        statesController: _states,
        // Only the foreground deforms; the semantic and pointer target keeps
        // its full size. Button states cover pointer and keyboard activation.
        icon: ValueListenableBuilder<Set<WidgetState>>(
          valueListenable: _states,
          builder: (context, states, child) => AnimatedScale(
            scale:
                animate &&
                    widget.onPressed != null &&
                    states.contains(WidgetState.pressed)
                ? .92
                : 1,
            duration: animate
                ? HermesGlassTokens.feedbackDuration
                : Duration.zero,
            curve: HermesGlassMotion.curve,
            child: child,
          ),
          child: widget.child,
        ),
        style:
            IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
              foregroundColor: liquid
                  ? (selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant)
                  : (selected ? palette.accent : palette.text2),
              backgroundColor: selected
                  ? (liquid ? colors.primaryContainer : palette.accentBg)
                  : Colors.transparent,
              shape: const StadiumBorder(),
              side: selected
                  ? BorderSide(color: palette.accent)
                  : BorderSide.none,
              animationDuration: reduceMotion
                  ? Duration.zero
                  : HermesGlassTokens.feedbackDuration,
            ).copyWith(
              side: WidgetStateProperty.resolveWith((states) {
                if (liquid && states.contains(WidgetState.disabled)) {
                  return selected
                      ? BorderSide(color: palette.border)
                      : BorderSide.none;
                }
                if (liquid &&
                    states.contains(WidgetState.focused) &&
                    !states.contains(WidgetState.disabled)) {
                  return BorderSide(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                    width: 2,
                  );
                }
                if (liquid) return BorderSide.none;
                return selected
                    ? BorderSide(color: palette.accent)
                    : BorderSide.none;
              }),
            ),
      ),
    );
  }
}
