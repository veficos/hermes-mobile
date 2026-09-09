import 'package:flutter/material.dart';
import '../../theme/hermes_glass_theme.dart';
import 'glass_surface.dart';

/// Shared search control with one bounded Liquid material.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) {
    final liquid = HermesGlassTheme.of(context).enabled;
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: onClear ?? controller.clear,
                icon: const Icon(Icons.close, size: 18),
              ),
        border: liquid ? InputBorder.none : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
    return liquid
        ? GlassSurface(
            radius: HermesGlassTokens.controlRadius,
            thick: true,
            child: field,
          )
        : field;
  }
}
