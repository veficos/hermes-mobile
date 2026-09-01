/// HermesGlassCard — core surface component (Phase 6: solid card + border +
/// shadow per the H5 design system; the old translucent look is gone, ADR 0004).
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';

/// Solid card: card surface + 1px border + shadow tier (design system).
/// Used by Composer, FAB, Toolbar, Overlay, Context Panel and Pickers.
class HermesGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry margin;
  final HermesShadowTier shadow;

  const HermesGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    // The mobile prototype uses one 15px radius for standalone surfaces.
    this.radius = 15,
    this.tint,
    this.onTap,
    this.onLongPress,
    this.margin = EdgeInsets.zero,
    this.shadow = HermesShadowTier.sm,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = hermesCardDecoration(
      context,
      radius: radius,
      tint: tint,
      shadow: shadow,
    );
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(radius),
                child: content,
              ),
      ),
    );
  }
}

/// Compact section label shared by secondary mobile pages.
class HermesSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const HermesSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.md,
        18,
        HermesSpacing.md,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                fontSize: 11.5,
                height: 1.2,
                color: HermesPalette.of(context).text3,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// HermesAvatar — round avatar with the theme-colored initial (design
/// system msg-avatar / chat-avatar). Optional status dot.
///
/// [gradient] switches to the prototype's session-list "logo" badge
/// (`docs/mobile-ui-prototype.html` `.avatar`): a rounded square filled with
/// a 135°-diagonal accent→accentHover gradient and a soft accent-tinted
/// shadow, instead of the flat-color circle used for chat/role avatars.
class HermesAvatar extends StatelessWidget {
  final String? label;
  final Color? color;
  final double size;
  final bool showStatus;
  final Color? statusColor;
  final bool gradient;

  const HermesAvatar({
    super.key,
    this.label,
    this.color,
    this.size = 36,
    this.showStatus = false,
    this.statusColor,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final bg = color ?? palette.accent;
    final initial = label?.isNotEmpty == true ? label![0].toUpperCase() : 'H';
    return Semantics(
      label: label != null
          ? context.l10n.avatarNamed(label!)
          : context.l10n.avatarUnnamed,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              width: size,
              height: size,
              decoration: gradient
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [bg, palette.accentHover],
                      ),
                      borderRadius: BorderRadius.circular(size * 0.3),
                      boxShadow: [
                        BoxShadow(
                          color: bg.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : BoxDecoration(color: bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  color: gradient
                      ? Colors.white
                      : Theme.of(context).colorScheme.onPrimary,
                  fontWeight: gradient ? FontWeight.w700 : FontWeight.w600,
                  fontSize: size * (gradient ? 0.38 : 0.42),
                ),
              ),
            ),
            if (showStatus)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: size * 0.28,
                  height: size * 0.28,
                  decoration: BoxDecoration(
                    color:
                        statusColor ??
                        hermesSemantic(
                          context,
                          HermesSemantic.green,
                          HermesSemanticDark.green,
                        ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// HermesHeroCard — gradient hero card (design-system.md §6.3):
/// accent 渐变底（accent-bg → surface），普通文字色；右上角装饰圆。
/// 用于首页 active-agent hero 与 Insights 头条指标。
class HermesHeroCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final IconData? deltaIcon;
  final Color? deltaColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const HermesHeroCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaIcon,
    this.deltaColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // §6.3 Hero 卡：accent 渐变底（accent-bg → surface）。
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.accentBg, palette.surface],
          ),
          borderRadius: BorderRadius.circular(HermesRadius.sheet),
          border: Border.all(color: palette.border),
          boxShadow: hermesShadow(context, HermesShadowTier.md),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: palette.text),
          child: Stack(
            children: [
              // Decorative circle in the top-right (design system ::after).
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(
                      alpha: isDark ? 0.18 : 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.text3,
                      letterSpacing: 0.36,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                            letterSpacing: -0.56,
                            height: 1.1,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  if (delta != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (deltaIcon != null) ...[
                          Icon(
                            deltaIcon,
                            size: 12,
                            color: deltaColor ?? palette.text2,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            delta!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: deltaColor ?? palette.text2,
                              letterSpacing: 0.12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// HermesStatCard — small 2-column data card (design system `.stat-card`):
/// white/card surface + 1px border + sm shadow + 22px stat number + 12px label.
class HermesStatCard extends StatelessWidget {
  final String number;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const HermesStatCard({
    super.key,
    required this.number,
    required this.label,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: hermesCardDecoration(context, shadow: HermesShadowTier.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: palette.accentBg,
                  borderRadius: BorderRadius.circular(HermesRadius.card),
                ),
                child: Icon(icon, size: 16, color: palette.accent),
              ),
            ],
            Text(
              number,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.text,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -0.01 * 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: palette.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HermesGridIcon — 48x48 rounded icon container with 8% theme tint
/// (design system `.grid-icon`). Tap scales down briefly (handled by parent).
class HermesGridIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const HermesGridIcon({super.key, required this.icon, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.accentBg,
        borderRadius: BorderRadius.circular(HermesRadius.largeCard),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: palette.accent, size: size * 0.46),
    );
  }
}

/// HermesNoticeBar — warning/info notice strip (design system `.notice-bar`):
/// 6% semantic bg + 15% border + semantic icon + body text.
class HermesNoticeBar extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const HermesNoticeBar({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c =
        color ??
        hermesSemantic(
          context,
          HermesSemantic.orange,
          HermesSemanticDark.orange,
        );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          // §3.6：语义色底 10%(light)/18%(dark)。
          color: c.withValues(alpha: isDark ? 0.18 : 0.10),
          border: Border.all(color: c.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(HermesRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: HermesPalette.of(context).text2,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HermesIconButton — 34x34 rounded icon button (design-system.md §6.1
/// Icon Button：无底无边、r-sm、icon 18px text-3 色、hover 6% 底、
/// disabled 38% 透明度)。用于 AppBar / 卡片头部。
class HermesIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;

  const HermesIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip ?? '',
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(HermesRadius.smallCard),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(HermesRadius.smallCard),
            hoverColor: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.06,
            ),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: 18, color: palette.text3),
            ),
          ),
        ),
      ),
    );
  }
}
