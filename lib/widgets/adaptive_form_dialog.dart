import 'package:flutter/material.dart';

import '../theme/hermes_tokens.dart';

/// Keyboard-safe editing surface: a scrollable sheet on phones, dialog on
/// larger windows. Confirmation alerts should continue to use AlertDialog.
Future<T?> showAdaptiveFormDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  if (MediaQuery.sizeOf(context).width < HermesBreakpoints.phone) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => AnimatedPadding(
        key: const ValueKey('adaptive-phone-form-sheet'),
        duration: HermesMotion.fast,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
            ],
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
