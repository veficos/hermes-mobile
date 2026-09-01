/// Desktop parity: `send-diagnostics-dialog.tsx` — a consent-gated upload of
/// redacted server logs + system/provider config via the gateway's
/// `diagnostics.share_nous` RPC, landing on a view link plus support links
/// (GitHub Issues / Discord). Desktop only ever opens this from a failed-turn
/// error card; mobile mirrored that (chat_screen's recovery banner) but had
/// no standalone entry point for a user who wants to report something that
/// *isn't* tied to a specific error — this is that shared flow, callable
/// with or without an [errorContext].
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import 'clipboard.dart';
import 'external_links.dart';
import 'stores/connection_store.dart';

const _kSupportLinks = [
  ('GitHub Issues', 'https://github.com/NousResearch/hermes-agent/issues'),
  ('Discord', 'https://discord.gg/NousResearch'),
];

Future<void> showSendDiagnosticsDialog(
  BuildContext context, {
  String? errorContext,
}) async {
  final l10n = context.l10n;
  final approved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.sendDiagnosticsTitle),
      content: Text(l10n.diagnosticsConsentDescription),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.diagnosticsApproveUpload),
        ),
      ],
    ),
  );
  if (approved != true || !context.mounted) return;

  final gateway = context.read<ConnectionStore>().gateway;
  final messenger = ScaffoldMessenger.of(context);
  if (gateway == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diagnosticsGatewayUnavailable)),
    );
    return;
  }

  try {
    final result = await gateway.request('diagnostics.share_nous', {
      if (errorContext != null && errorContext.isNotEmpty)
        'error_context': errorContext,
    }, timeout: const Duration(seconds: 120));
    if (result['ok'] != true) {
      throw StateError(
        result['error']?.toString() ?? l10n.diagnosticsUploadFailed,
      );
    }
    final url = result['view_url']?.toString();
    if (!context.mounted) return;
    if (url != null && url.isNotEmpty) {
      await copyTextOrNotify(context, url);
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.diagnosticsSentTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (url != null && url.isNotEmpty) ...[
              Text(l10n.diagnosticsLinkCopied),
              const SizedBox(height: 4),
              SelectableText(
                url,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            Text(l10n.diagnosticsSupportPrompt),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in _kSupportLinks)
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchExternalOrNotify(context, Uri.parse(link.$2)),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(link.$1),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diagnosticsSendFailed('$error'))),
      );
    }
  }
}
