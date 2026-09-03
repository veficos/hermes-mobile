/// Hermes 品牌图。
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

class HermesLogo extends StatelessWidget {
  static const assetName = 'assets/hermes-logo.png';

  final double size;

  /// 为兼容旧调用保留；彩色品牌图不会被着色。
  final Color? color;

  const HermesLogo({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Image.asset(
      assetName,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.auto_awesome_outlined,
        size: size * 0.72,
        color: color ?? HermesPalette.of(context).accent,
      ),
    ),
  );
}

/// Hermes Agent 的统一圆形头像。
class HermesAgentAvatar extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;

  const HermesAgentAvatar({
    super.key,
    this.size = 32,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Semantics(
      image: true,
      label: 'Hermes',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? palette.accentBg,
          border: Border.all(
            color: borderColor ?? palette.border.withValues(alpha: 0.7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          HermesLogo.assetName,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.auto_awesome_outlined,
            size: size * 0.58,
            color: palette.accent,
          ),
        ),
      ),
    );
  }
}
