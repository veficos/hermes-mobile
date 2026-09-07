/// HermesSegmentedControl — 分段选择器（圆角 design-system.md §5.2 r-pill，
/// 配色 §3.1 调色板）。
///
/// 视觉对齐看板"列表/看板"切换（kanban_canonical_screen.dart）：codeBg 底
/// capsule 容器 + 3px 内边距，选中项 accentBg 底 + accent 文字。供看板
/// 列表/看板切换、时间范围选择等场景。
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

/// 分段选项。[icon] 可选，显示在 label 左侧。
class HermesSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const HermesSegment({required this.value, required this.label, this.icon});
}

/// 分段选择器：等宽选项横向排列，点击回调 [onChanged]。
class HermesSegmentedControl<T> extends StatelessWidget {
  final List<HermesSegment<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const HermesSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    // Reduce Motion（design-system.md §9）：系统减弱动态效果时瞬时切换。
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : HermesMotion.fast;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.codeBg,
        borderRadius: BorderRadius.circular(HermesRadius.capsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            Expanded(
              child: _SegmentItem(
                option: option,
                selected: option.value == selected,
                duration: duration,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentItem<T> extends StatelessWidget {
  final HermesSegment<T> option;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.option,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final color = selected ? palette.accent : palette.text3;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(HermesRadius.capsule),
        child: InkWell(
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
          onTap: onTap,
          child: AnimatedContainer(
            duration: duration,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? palette.accentBg : Colors.transparent,
              borderRadius: BorderRadius.circular(HermesRadius.capsule),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 14, color: color),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
