import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';

Future<bool> launchExternalOrNotify(
  BuildContext context,
  Uri uri, {
  String? failureMessage,
}) async {
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return true;
  } catch (_) {
    // The same user-facing failure covers launcher rejection and exceptions.
  }
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(failureMessage ?? context.l10n.pluginLinkOpenFailed),
      ),
    );
  }
  return false;
}
