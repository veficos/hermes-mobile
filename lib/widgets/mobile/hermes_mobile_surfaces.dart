import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../h/hermes_glass.dart';
import '../h/hermes_status.dart';

/// Shared mobile surfaces copied from the interactive prototype. Feature
/// screens keep their existing stores and callbacks while sharing one visual
/// hierarchy.
abstract final class HermesMobileMetrics {
  static const pagePadding = 14.0;
  static const groupRadius = 15.0;
  static const tileRadius = 14.0;
  static const iconRadius = 9.0;
  static const rowHorizontal = 14.0;
  static const rowVertical = 12.0;
}

/// 移动端分组标签。实现已并入 [HermesSectionHeader]（同一文字样式），
/// 此处仅做兼容委托，保留原有 padding（左右 4、可调 top），避免既有
/// 移动端页面漂移。新代码请直接使用 [HermesSectionHeader]。
@Deprecated('Use HermesSectionHeader from widgets/h/hermes_glass.dart instead.')
class HermesMobileSectionLabel extends StatelessWidget {
  const HermesMobileSectionLabel({
    super.key,
    required this.title,
    this.trailing,
    this.top = 18,
  });

  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) => HermesSectionHeader(
    title: title,
    trailing: trailing,
    padding: EdgeInsets.fromLTRB(4, top, 4, 8),
  );
}

class HermesMobileCard extends StatelessWidget {
  const HermesMobileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.radius = HermesMobileMetrics.groupRadius,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      // 装饰统一走 hermesCardDecoration()（design-system.md §6.3）；
      // padding/radius 默认值保持本类既有约定不变，避免调用方视觉漂移。
      decoration: hermesCardDecoration(context, radius: radius, tint: color),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

class HermesMobileGroup extends StatelessWidget {
  const HermesMobileGroup({
    super.key,
    required this.children,
    this.margin = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(HermesMobileMetrics.groupRadius),
        border: Border.all(color: palette.border),
        boxShadow: hermesShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, color: palette.border),
          ],
        ],
      ),
    );
  }
}

class HermesMobileRow extends StatelessWidget {
  const HermesMobileRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.tone,
    this.iconWidget,
    this.titleTrailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tone;
  final Widget? iconWidget;
  final Widget? titleTrailing;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final resolvedTone = tone ?? palette.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HermesMobileMetrics.rowHorizontal,
            vertical: HermesMobileMetrics.rowVertical,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 31,
                child:
                    iconWidget ??
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: resolvedTone.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(
                          HermesMobileMetrics.iconRadius,
                        ),
                      ),
                      child: Icon(icon, size: 16, color: resolvedTone),
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 14.5,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (titleTrailing != null) ...[
                          const SizedBox(width: 5),
                          titleTrailing!,
                        ],
                      ],
                    ),
                    if (subtitleWidget != null ||
                        subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      subtitleWidget ??
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text3,
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(Icons.chevron_right, size: 18, color: palette.text4),
            ],
          ),
        ),
      ),
    );
  }
}

/// 移动端状态 Chip。视觉已统一到 [HermesStatusChip]（design-system.md
/// §6.4：pill 高 24、语义色 10%(light)/18%(dark) 透明度底），此处仅做
/// 兼容委托。新代码请直接使用 [HermesStatusChip]。
@Deprecated('Use HermesStatusChip from widgets/h/hermes_status.dart instead.')
class HermesMobileStatusChip extends StatelessWidget {
  const HermesMobileStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      HermesStatusChip(color: color, label: label, icon: icon);
}

class HermesMobileQuickTile extends StatelessWidget {
  const HermesMobileQuickTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(HermesMobileMetrics.tileRadius),
        border: Border.all(color: palette.border),
        boxShadow: hermesShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.accentBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: palette.accent),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text3,
                    fontSize: 10.5,
                    height: 1.2,
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
