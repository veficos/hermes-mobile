import 'package:flutter/material.dart';
import '../../theme/hermes_glass_theme.dart';
import 'glass_surface.dart';

/// Shared alert material. Route dismissal policy belongs to the caller.
class GlassAlertDialog extends StatelessWidget {
  const GlassAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = 480,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  /// Wider content such as side-by-side source comparisons can opt in.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!HermesGlassTheme.of(context).enabled) {
      return AlertDialog(title: title, content: content, actions: actions);
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassSurface(
        radius: 28,
        role: HermesGlassRole.overlay,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        namesRoute: true,
                        header: true,
                        child: DefaultTextStyle(
                          style: Theme.of(context).textTheme.titleLarge!,
                          child: title,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DefaultTextStyle(
                        style: Theme.of(context).textTheme.bodyMedium!,
                        child: content,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
