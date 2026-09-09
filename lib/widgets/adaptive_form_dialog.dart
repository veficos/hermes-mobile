import 'package:flutter/material.dart';

import '../theme/hermes_tokens.dart';
import '../theme/hermes_glass_theme.dart';
import 'glass/glass_surface.dart';
import 'mobile/mobile_page_scaffold.dart';

/// Keyboard-safe editing surface: a scrollable sheet on phones, dialog on
/// larger windows. Confirmation alerts should continue to use AlertDialog.
Future<T?> showAdaptiveFormDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  if (MediaQuery.sizeOf(context).width < HermesBreakpoints.phone) {
    return showMobileSheet<T>(
      context,
      // The form keeps its own AnimatedPadding for keyboard avoidance so the
      // inset animates instead of jumping.
      avoidViewInsets: false,
      (sheetContext) => AnimatedPadding(
        key: const ValueKey('adaptive-phone-form-sheet'),
        duration: MediaQuery.disableAnimationsOf(sheetContext)
            ? Duration.zero
            : HermesMotion.fast,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: content,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  if (HermesGlassTheme.of(context).enabled) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        key: const ValueKey('adaptive-wide-form-dialog'),
        backgroundColor: Colors.transparent,
        child: GlassSurface(
          radius: HermesGlassTokens.sheetRadius,
          thick: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    namesRoute: true,
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(child: SingleChildScrollView(child: content)),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (_) => AlertDialog(
      key: const ValueKey('adaptive-wide-form-dialog'),
      title: Text(title),
      content: content,
      actions: actions,
    ),
  );
}
