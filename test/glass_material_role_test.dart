import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';

void main() {
  test('material hierarchy separates navigation controls and overlays', () {
    const navigation = HermesGlassRecipe.navigation;
    const control = HermesGlassRecipe.control;
    const overlay = HermesGlassRecipe.overlay;
    expect(navigation.blurSigma, lessThan(control.blurSigma));
    expect(control.blurSigma, lessThan(overlay.blurSigma));
    expect(navigation.topAlpha, lessThan(control.topAlpha));
    expect(control.topAlpha, lessThan(overlay.topAlpha));
    expect(control.bottomAlpha, lessThan(overlay.bottomAlpha));
  });
  test('roles own contours while explicit geometry remains supported', () {
    for (final role in HermesGlassRole.values) {
      expect(
        GlassSurface(role: role, child: const SizedBox()).radius,
        HermesGlassRecipe.forRole(role).radius,
      );
      expect(
        GlassSurface(role: role, radius: 0, child: const SizedBox()).radius,
        0,
      );
    }
    expect(const GlassSurface(child: SizedBox()).radius, 24);
  });

  for (final brightness in Brightness.values) {
    for (final opaque in [false, true]) {
      for (final role in HermesGlassRole.values) {
        testWidgets('$role $brightness opaque=$opaque shares one plane', (
          tester,
        ) async {
          final theme = buildHermesTheme(
            brightness: brightness,
            visualStyle: HermesVisualStyle.liquid,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.copyWith(
                extensions: [
                  ...theme.extensions.values.where(
                    (e) => e is! HermesGlassTheme,
                  ),
                  HermesGlassTheme(enabled: true, reduceTransparency: opaque),
                ],
              ),
              home: Scaffold(
                body: GlassSurface(
                  role: role,
                  child: const GlassSurface(
                    role: HermesGlassRole.control,
                    child: SizedBox(
                      width: 200,
                      height: 80,
                      child: Text('Readable'),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.byType(BackdropFilter), findsNWidgets(opaque ? 0 : 1));
          expect(find.text('Readable'), findsOneWidget);
          final gradients = tester
              .widgetList<DecoratedBox>(find.byType(DecoratedBox))
              .map((box) => box.decoration)
              .whereType<ShapeDecoration>()
              .map((shape) => shape.gradient)
              .whereType<LinearGradient>();
          final recipe = HermesGlassRecipe.forRole(role);
          expect(
            gradients.any(
              (g) =>
                  (g.colors.first.a - (opaque ? 1 : recipe.topAlpha)).abs() <
                      .005 &&
                  (g.colors.last.a -
                              (opaque
                                  ? 1
                                  : brightness == Brightness.dark
                                  ? recipe.bottomAlpha.clamp(
                                      HermesGlassTokens.darkMinimumBottomAlpha,
                                      1.0,
                                    )
                                  : recipe.bottomAlpha))
                          .abs() <
                      .005,
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
