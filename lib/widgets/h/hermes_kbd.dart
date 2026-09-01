/// HermesKbd —— 快捷键标签（design-system.md §6.15）。
///
/// 桌面/Web 命令面板与菜单中的快捷键提示：mono 11px + border 边框底 + r-sm。
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

class HermesKbd extends StatelessWidget {
  final String label;

  const HermesKbd(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(HermesRadius.smallCard),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: HermesType.code.copyWith(fontSize: 11, color: palette.text3),
      ),
    );
  }
}
