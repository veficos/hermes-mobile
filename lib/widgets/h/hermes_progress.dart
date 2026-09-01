/// HermesProgressBar —— 确定性进度条（design-system.md §6.15）。
///
/// 3px accent 轨道，border 色底；用于同步/上传等确定性进度。不定进度请用
/// HermesLoadingState / HermesLoadingPill。
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';

class HermesProgressBar extends StatelessWidget {
  /// 0.0 – 1.0（自动 clamp）。
  final double value;

  const HermesProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final t = value.clamp(0.0, 1.0);
    return Semantics(
      label: context.l10n.progressPercent((t * 100).round()),
      child: Container(
        height: 3,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.border,
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: t,
          child: Container(color: palette.accent),
        ),
      ),
    );
  }
}
