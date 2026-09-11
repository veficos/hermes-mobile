/// showHermesConfirmDialog — 通用确认对话框（按钮规范 design-system.md
/// §6.1）。
///
/// 确认保持居中对话框形态；Liquid 使用共享玻璃材质，Classic 保持 AlertDialog。
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../glass/glass_alert_dialog.dart';
import 'hermes_button.dart';

/// 通用确认对话框：title + message + 取消/确认按钮，确认返回 true，取消或
/// 点击遮罩返回 false。[destructive] 为 true 时确认按钮使用语义 error 色。
Future<bool> showHermesConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        HermesButton(
          variant: HermesButtonVariant.ghost,
          label: cancelLabel ?? dialogContext.l10n.commonCancel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        HermesButton(
          variant: destructive
              ? HermesButtonVariant.destructive
              : HermesButtonVariant.primary,
          label: confirmLabel ?? dialogContext.l10n.commonConfirm,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
