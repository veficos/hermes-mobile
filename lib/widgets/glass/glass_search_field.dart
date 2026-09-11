import 'package:flutter/material.dart';
import '../../theme/hermes_glass_theme.dart';
import 'glass_surface.dart';
import 'glass_button.dart';

/// Shared search control with one bounded Liquid material.
class GlassSearchField extends StatefulWidget {
  const GlassSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.autofocus = false,
    this.emptyAction,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// Optional action when the query is empty; typing replaces it with clear.
  final Widget? emptyAction;

  @override
  State<GlassSearchField> createState() => _GlassSearchFieldState();
}

class _GlassSearchFieldState extends State<GlassSearchField> {
  final _internalFocus = FocusNode();

  @override
  void dispose() {
    _internalFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final focusNode = widget.focusNode ?? _internalFocus;
    final hintText = widget.hintText;
    final onChanged = widget.onChanged;
    final onSubmitted = widget.onSubmitted;
    final liquid = HermesGlassTheme.of(context).enabled;
    void clear() {
      if (widget.onClear != null) {
        widget.onClear!();
      } else {
        controller.clear();
        onChanged?.call('');
      }
      if (mounted) focusNode.requestFocus();
    }

    final clearTooltip = MaterialLocalizations.of(context).deleteButtonTooltip;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final field = TextField(
          autofocus: widget.autofocus,
          focusNode: focusNode,
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: value.text.isEmpty
                ? widget.emptyAction
                : liquid
                ? GlassButton(
                    tooltip: clearTooltip,
                    onPressed: clear,
                    child: const Icon(Icons.close, size: 18),
                  )
                : IconButton(
                    tooltip: clearTooltip,
                    onPressed: clear,
                    icon: const Icon(Icons.close, size: 18),
                  ),
            filled: liquid ? false : null,
            fillColor: liquid ? Colors.transparent : null,
            border: liquid ? InputBorder.none : null,
            enabledBorder: liquid ? InputBorder.none : null,
            focusedBorder: liquid ? InputBorder.none : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        );
        return liquid
            ? GlassSurface(
                radius: HermesGlassTokens.controlRadius,
                role: HermesGlassRole.control,
                child: ListenableBuilder(
                  listenable: focusNode,
                  child: field,
                  builder: (context, child) => DecoratedBox(
                    key: const ValueKey('glass-search-focus-ring'),
                    position: DecorationPosition.foreground,
                    decoration: ShapeDecoration(
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(
                          HermesGlassTokens.controlRadius,
                        ),
                        side: focusNode.hasFocus
                            ? BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: child,
                  ),
                ),
              )
            : field;
      },
    );
  }
}
