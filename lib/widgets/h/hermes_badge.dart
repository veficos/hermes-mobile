/// HermesBadge —— 数字角标（design-system.md §6.15）。
///
/// 审批、通知计数用：min 16px 圆/胶囊，error 底白字 px11；count > 99 显示
/// `99+`；[dot] 模式渲染为 8px 纯色圆点（无数字）。
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';

class HermesBadge extends StatelessWidget {
  /// 计数；`null` 且 [dot] 为 false 时不渲染。> 99 显示 `99+`。
  final int? count;

  /// 圆点模式：只显示一个 8px 语义色圆点，不显示数字。
  final bool dot;

  /// 底色；默认 error 语义色（随明暗解析）。
  final Color? color;

  const HermesBadge({super.key, this.count, this.dot = false, this.color});

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ??
        hermesSemantic(context, HermesSemantic.red, HermesSemanticDark.red);
    if (dot) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: resolved, shape: BoxShape.circle),
      );
    }
    final count = this.count;
    if (count == null || count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: context.l10n.badgeUnreadCount(label),
      child: Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: resolved,
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: HermesType.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}
