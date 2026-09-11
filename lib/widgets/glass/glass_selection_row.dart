import 'package:flutter/material.dart';
import '../../theme/hermes_glass_theme.dart';

/// Selection belongs on the shared sheet backdrop, without a blur per row.
class GlassSelectionRow extends StatelessWidget {
  const GlassSelectionRow({
    super.key,
    required this.selected,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
  });
  final bool selected;
  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final glass = HermesGlassTheme.of(context);
    if (!glass.enabled) return child;
    final colors = Theme.of(context).colorScheme;
    final popup = PopupMenuTheme.of(context);
    final foreground = colors.onPrimaryContainer;
    final content = selected
        ? PopupMenuTheme(
            data: popup.copyWith(
              textStyle:
                  (popup.textStyle ?? Theme.of(context).textTheme.labelLarge!)
                      .copyWith(color: foreground),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final base = popup.labelTextStyle?.resolve(states);
                if (states.contains(WidgetState.disabled)) return base;
                return (base ?? Theme.of(context).textTheme.labelLarge!)
                    .copyWith(color: foreground);
              }),
            ),
            child: ListTileTheme.merge(
              selectedColor: foreground,
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground),
                  child: child,
                ),
              ),
            ),
          )
        : child;
    return Padding(
      padding: margin,
      child: Material(
        animationDuration:
            MediaQuery.disableAnimationsOf(context) ||
                MediaQuery.accessibleNavigationOf(context)
            ? Duration.zero
            : HermesGlassTokens.feedbackDuration,
        color: selected
            ? colors.primaryContainer
            : glass.allowsTransparency(context)
            ? Colors.transparent
            : colors.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          selected: selected,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: content,
          ),
        ),
      ),
    );
  }
}
