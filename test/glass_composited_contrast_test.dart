import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';

void main() {
  for (final accent in HermesAccents.all) {
    for (final brightness in Brightness.values) {
      for (final role in HermesGlassRole.values) {
        testWidgets('composited glass ${accent.id} $brightness $role', (
          tester,
        ) async {
          final palette = accent.paletteOf(brightness);
          for (final backdrop in [Colors.white, Colors.black]) {
            for (final pressed in [false, true]) {
              const key = ValueKey('contrast-plane');
              await tester.pumpWidget(
                MaterialApp(
                  theme: buildHermesTheme(
                    brightness: brightness,
                    accent: accent,
                    visualStyle: HermesVisualStyle.liquid,
                  ),
                  home: Center(
                    child: RepaintBoundary(
                      key: key,
                      child: ColoredBox(
                        color: backdrop,
                        child: GlassSurface(
                          role: role,
                          child: const SizedBox(width: 200, height: 100),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final gesture = pressed
                  ? await tester.startGesture(tester.getCenter(find.byKey(key)))
                  : null;
              await tester.pump(const Duration(milliseconds: 150));
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(key),
              );
              await tester.runAsync(() async {
                final rendered = await boundary.toImage(pixelRatio: 1);
                final bytes = (await rendered.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                // A regular grid excludes only the outer 20px contour.
                for (final point in [
                  for (var y = 20; y <= 80; y += 10)
                    for (var x = 20; x <= 180; x += 10)
                      Offset(x.toDouble(), y.toDouble()),
                ]) {
                  final i =
                      (point.dy.toInt() * rendered.width + point.dx.toInt()) *
                      4;
                  final background = Color.fromARGB(
                    bytes.getUint8(i + 3),
                    bytes.getUint8(i),
                    bytes.getUint8(i + 1),
                    bytes.getUint8(i + 2),
                  );
                  expect(background.a, 1);
                  for (final foreground in [palette.text, palette.text2]) {
                    final a = Color.alphaBlend(
                      foreground,
                      background,
                    ).computeLuminance();
                    final b = background.computeLuminance();
                    expect(
                      ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
                      greaterThanOrEqualTo(4.5),
                      reason:
                          '$backdrop pressed=$pressed at $point foreground=$foreground',
                    );
                  }
                }
                rendered.dispose();
              });
              await gesture?.up();
              await tester.pumpAndSettle();
            }
          }
        });
      }
    }
  }
}
