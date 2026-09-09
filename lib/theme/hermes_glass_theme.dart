import 'package:flutter/material.dart';

enum HermesVisualStyle { classic, liquid }

/// Liquid-only material tokens. Content palettes remain owned by HermesPalette.
abstract final class HermesGlassTokens {
  static const double controlRadius = 24;
  static const double sheetRadius = 30;
  static const double blurSigma = 16;
  static const double regularTopAlpha = .82;
  static const double regularBottomAlpha = .68;
  static const double thickTopAlpha = .94;
  static const double thickBottomAlpha = .90;
  static const Color lightHighlight = Color(0xB3FFFFFF);
  static const Color darkHighlight = Color(0x2EFFFFFF);
  static const Color lightShadow = Color(0x0F000000);
  static const double shadowBlur = 20;
  static const Offset shadowOffset = Offset(0, 6);
  static const double edgeAlpha = .24;
  static const Duration feedbackDuration = Duration(milliseconds: 120);
}

class HermesGlassTheme extends ThemeExtension<HermesGlassTheme> {
  const HermesGlassTheme({
    this.enabled = false,
    this.reduceTransparency = false,
  });
  final bool enabled;
  final bool reduceTransparency;

  static HermesGlassTheme of(BuildContext context) =>
      Theme.of(context).extension<HermesGlassTheme>() ??
      const HermesGlassTheme();

  @override
  HermesGlassTheme copyWith({bool? enabled, bool? reduceTransparency}) =>
      HermesGlassTheme(
        enabled: enabled ?? this.enabled,
        reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      );

  @override
  HermesGlassTheme lerp(HermesGlassTheme? other, double t) =>
      t < .5 ? this : other ?? this;
}
