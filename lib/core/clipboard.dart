import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

Future<bool> copyTextOrNotify(
  BuildContext context,
  String text, {
  String? successMessage,
  String? failureMessage,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final fallbackFailure = context.l10n.commonCopyFailed;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted && successMessage != null) {
      messenger?.showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      messenger?.showSnackBar(
        SnackBar(content: Text(failureMessage ?? fallbackFailure)),
      );
    }
    return false;
  }
}

Future<String?> readClipboardTextOrNotify(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failure = context.l10n.commonClipboardReadFailed;
  try {
    return (await Clipboard.getData('text/plain'))?.text;
  } catch (_) {
    if (context.mounted) {
      messenger?.showSnackBar(SnackBar(content: Text(failure)));
    }
    return null;
  }
}
