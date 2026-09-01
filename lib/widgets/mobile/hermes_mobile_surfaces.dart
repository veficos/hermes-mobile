import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

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
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: palette.text3,
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
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
    final palette = HermesPalette.of(context);
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.border),
        boxShadow: hermesShadow(context),
      ),
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tone;
  final Widget? iconWidget;

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
                    Text(
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(HermesRadius.capsule),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 12, color: color)
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
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
