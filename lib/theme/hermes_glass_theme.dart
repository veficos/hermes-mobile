import 'package:flutter/material.dart';
import 'hermes_tokens.dart';

enum HermesVisualStyle { classic, liquid }

/// Semantic ownership of a material plane, independent of its child content.
enum HermesGlassRole { navigation, control, overlay }

/// Comfortable phone directory typography; desktop keeps its compact density.
abstract final class HermesLiquidTypography {
  static const messageSize = 17.0;
  static const messageHeight = 1.6;

  static TextStyle messageBody(BuildContext context) => usesPhoneRows(context)
      ? HermesType.messageBody.copyWith(
          fontSize: messageSize,
          height: messageHeight,
        )
      : HermesType.messageBody;

  static const listTitleSize = 17.0;
  static const listSubtitleSize = 14.0;
  static const listTitleHeight = 1.3;
  static const listSubtitleHeight = 1.4;

  static bool usesPhoneRows(BuildContext context) =>
      HermesGlassTheme.of(context).enabled &&
      MediaQuery.sizeOf(context).width < HermesBreakpoints.phone;
}

/// Timing categories, not a blanket duration for every interaction.
abstract final class HermesGlassMotion {
  static const press = Duration(milliseconds: 120);
  static const expansion = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context)
      ? Duration.zero
      : duration;
}

@immutable
class HermesGlassRecipe {
  const HermesGlassRecipe({
    required this.topAlpha,
    required this.bottomAlpha,
    required this.radius,
    this.blurSigma = HermesGlassTokens.blurSigma,
  });

  final double topAlpha;
  final double bottomAlpha;
  final double radius;
  final double blurSigma;

  // Candidate hierarchy: navigation retains backdrop continuity, controls
  // keep their established density, overlays prioritize foreground reading.
  // These are product recipes, not native iOS optical constants.
  static HermesGlassRecipe forRole(HermesGlassRole role) => switch (role) {
    HermesGlassRole.navigation => navigation,
    HermesGlassRole.control => control,
    HermesGlassRole.overlay => overlay,
  };

  static const navigation = HermesGlassRecipe(
    topAlpha: .80,
    bottomAlpha: HermesGlassTokens.thickBottomAlpha,
    radius: HermesGlassTokens.controlRadius,
    blurSigma: 12,
  );
  static const control = HermesGlassRecipe(
    topAlpha: HermesGlassTokens.thickTopAlpha,
    bottomAlpha: HermesGlassTokens.thickBottomAlpha,
    radius: HermesGlassTokens.controlRadius,
  );
  static const overlay = HermesGlassRecipe(
    topAlpha: .90,
    bottomAlpha: .84,
    radius: HermesGlassTokens.sheetRadius,
    blurSigma: 20,
  );
}

/// Liquid-only material tokens. Content palettes remain owned by HermesPalette.
abstract final class HermesGlassTokens {
  static const double controlRadius = 24;
  static const double sheetRadius = 30;
  static const double blurSigma = 16;
  static const double regularTopAlpha = .68;
  static const double regularBottomAlpha = .54;
  static const double thickTopAlpha = .82;
  static const double thickBottomAlpha = .72;
  static const double darkMinimumBottomAlpha = .78;
  static const Color lightHighlight = Color(0xB3FFFFFF);
  static const Color darkHighlight = Color(0x2EFFFFFF);
  static const Color lightShadow = Color(0x0F000000);
  static const double shadowBlur = 20;
  static const Offset shadowOffset = Offset(0, 6);
  static const double edgeAlpha = .24;
  static const Duration feedbackDuration = HermesGlassMotion.press;
}

class HermesGlassTheme extends ThemeExtension<HermesGlassTheme> {
  const HermesGlassTheme({
    this.enabled = false,
    this.reduceTransparency = false,
  });
  final bool enabled;
  final bool reduceTransparency;

  /// Shared runtime policy, including system accessibility overrides.
  bool allowsTransparency(BuildContext context) =>
      enabled &&
      !reduceTransparency &&
      !HermesA11y.highContrastOf(context) &&
      !MediaQuery.highContrastOf(context);

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
