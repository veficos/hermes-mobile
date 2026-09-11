import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('continuous edge light stays in its corner ring $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: brightness,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: const Center(
            child: GlassSurface(
              radius: 30,
              child: SizedBox(width: 120, height: 100),
            ),
          ),
        ),
      );
      final surfaceDecoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(GlassSurface),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as ShapeDecoration;
      expect(
        surfaceDecoration.shadows,
        brightness == Brightness.dark ? isEmpty : isNotEmpty,
      );
      final painter = tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey('glass-edge-highlight')),
          )
          .painter!;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(120, 100));
        final picture = recorder.endRecording();
        final rendered = await picture.toImage(120, 100);
        final data = (await rendered.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final ringBorder = RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(width: 1),
        );
        const bounds = Rect.fromLTWH(0, 0, 120, 100);
        final outer = ringBorder.getOuterPath(bounds);
        final inner = ringBorder.getInnerPath(bounds);
        var lit = 0;
        var clear = 0;
        for (var y = 0; y < 100; y++) {
          for (var x = 0; x < 120; x++) {
            final point = Offset(x + .5, y + .5);
            final alpha = data.getUint8((y * 120 + x) * 4 + 3);
            if (alpha > 0) lit++;
            final near = [
              for (final dx in [-1.0, 0.0, 1.0])
                for (final dy in [-1.0, 0.0, 1.0]) point + Offset(dx, dy),
            ];
            // Leave an antialiasing margin around both boundaries.
            if (near.every(inner.contains) ||
                near.every((p) => !outer.contains(p))) {
              expect(alpha, 0, reason: 'Unexpected edge light at $point');
              clear++;
            }
          }
        }
        expect(lit, greaterThan(0));
        expect(clear, greaterThan(5000));
        rendered.dispose();
        picture.dispose();
      });
    });
  }
  testWidgets('nonzero glass corner clips foreground to a superellipse', (
    tester,
  ) async {
    const capture = ValueKey('capture');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const Center(
          child: RepaintBoundary(
            key: capture,
            child: SizedBox(
              width: 120,
              height: 100,
              child: GlassSurface(
                radius: 30,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClipRSuperellipse), findsOneWidget);
    const bounds = Rect.fromLTWH(0, 0, 120, 100);
    final continuous = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(30)),
    ).getOuterPath(bounds);
    final circular = Path()
      ..addRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(30)));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(capture),
    );
    await tester.runAsync(() async {
      final rendered = await boundary.toImage(pixelRatio: 1);
      final bytes = (await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var distinctInterior = 0;
      for (var y = 1; y < 30; y++) {
        for (var x = 1; x < 30; x++) {
          final point = Offset(x + .5, y + .5);
          final safelyInside = [
            const Offset(-1, -1),
            const Offset(1, -1),
            const Offset(-1, 1),
            const Offset(1, 1),
          ].every((delta) => continuous.contains(point + delta));
          if (continuous.contains(point) != circular.contains(point)) {
            distinctInterior++;
          }
          if (safelyInside) {
            final index = (y * 120 + x) * 4;
            expect(
              [
                for (var channel = 0; channel < 4; channel++)
                  bytes.getUint8(index + channel),
              ],
              [244, 67, 54, 255], // Material Colors.red, not pure RGB red.
            );
          }
        }
      }
      expect(distinctInterior, greaterThan(0));
      rendered.dispose();
    });
  });
}
