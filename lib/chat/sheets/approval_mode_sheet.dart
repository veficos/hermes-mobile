/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

Future<String?> showChatApprovalModeSheet(
  BuildContext context, {
  required String current,
}) {
  const options = ['manual', 'smart', 'off'];
  final labels = {
    'manual': context.l10n.chatApprovalManual,
    'smart': context.l10n.chatApprovalSmart,
    'off': context.l10n.chatApprovalOff,
  };
  final descriptions = {
    'manual': context.l10n.chatApprovalManualDescription,
    'smart': context.l10n.chatApprovalSmartDescription,
    'off': context.l10n.chatApprovalOffDescription,
  };
  return showMobileSheet<String>(
    context,
    (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.chatApprovalMode,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          RadioGroup<String>(
            groupValue: current,
            onChanged: (value) => Navigator.pop(sheetContext, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  RadioListTile<String>(
                    value: option,
                    title: Text(labels[option] ?? option),
                    subtitle: Text(descriptions[option] ?? ''),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
