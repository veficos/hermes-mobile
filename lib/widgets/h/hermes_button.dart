/// HermesButton — 统一按钮组件（design-system.md §6.1）。
///
/// 变体：primary（FilledButton）/ secondary（OutlinedButton）/ ghost
/// （TextButton）/ destructive（FilledButton + 语义 error 色）；尺寸：
/// regular / compact。颜色、圆角与 regular 尺寸样式由全局 ButtonTheme
/// 兜底（hermes_theme.dart），这里只覆盖 compact 尺寸与 destructive 配色。
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

enum HermesButtonVariant { primary, secondary, ghost, destructive }

enum HermesButtonSize { regular, compact }

/// 通用按钮：支持 leading icon 与 [loading] 态（spinner 替换 label 并禁用
/// 点击）。
class HermesButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final HermesButtonVariant variant;
  final HermesButtonSize size;
  final IconData? icon;
  final bool loading;

  const HermesButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HermesButtonVariant.primary,
    this.size = HermesButtonSize.regular,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isCompact = size == HermesButtonSize.compact;
    // loading 时禁用点击。
    final effectiveOnPressed = loading ? null : onPressed;

    final Widget child = loading
        ? SizedBox(
            width: isCompact ? 14 : 16,
            height: isCompact ? 14 : 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                switch (variant) {
                  HermesButtonVariant.primary =>
                    Theme.of(context).colorScheme.onPrimary,
                  HermesButtonVariant.destructive => Colors.white,
                  HermesButtonVariant.secondary => palette.text,
                  HermesButtonVariant.ghost => palette.accent,
                },
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: isCompact ? 15 : 17),
                const SizedBox(width: 6),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    // 稀疏 ButtonStyle：只覆盖尺寸/destructive 差异，其余交给全局
    // ButtonTheme（hermes_theme.dart 的 filled/outlined/textButtonTheme）。
    final style = ButtonStyle(
      padding: isCompact
          ? const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            )
          : null,
      textStyle: isCompact
          ? const WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            )
          : null,
      backgroundColor: variant == HermesButtonVariant.destructive
          ? WidgetStatePropertyAll(
              hermesSemantic(
                context,
                HermesSemantic.red,
                HermesSemanticDark.red,
              ),
            )
          : null,
      foregroundColor: variant == HermesButtonVariant.destructive
          ? const WidgetStatePropertyAll(Colors.white)
          : null,
    );

    final button = switch (variant) {
      HermesButtonVariant.primary ||
      HermesButtonVariant.destructive => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      HermesButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      HermesButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
    };

    // loading 时 label 被 spinner 替换，用 Semantics 保留可访问名称。
    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: label,
      child: button,
    );
  }
}
