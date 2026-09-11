import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';

void main() {
  testWidgets('drag clears press light before pointer release', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const Scaffold(
          body: Center(
            child: GlassSurface(child: SizedBox(width: 240, height: 180)),
          ),
        ),
      ),
    );
    final light = find.byKey(const ValueKey('glass-interaction-light'));
    final idle = tester.widget<CustomPaint>(light).painter!;
    final touch = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isTrue,
    );
    await touch.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isFalse,
    );
    await touch.moveBy(const Offset(0, -35));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isFalse,
    );
    await touch.up();
  });
  testWidgets('pointer movement does not repaint foreground content', (
    tester,
  ) async {
    var paints = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Scaffold(
          body: Center(
            child: GlassSurface(
              child: SizedBox(
                width: 240,
                height: 180,
                child: CustomPaint(painter: _PaintCounter(() => paints++)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = paints;
    final pointer = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await pointer.moveBy(const Offset(5, 0));
      await tester.pump();
    }
    await pointer.cancel();
    await tester.pump();
    expect(paints, initial);
  });
  testWidgets('runtime reduced motion clears active light before reenable', (
    tester,
  ) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: ValueListenableBuilder<bool>(
          valueListenable: reduced,
          builder: (context, value, child) => MediaQuery(
            data: MediaQueryData(disableAnimations: value),
            child: child!,
          ),
          child: const Scaffold(
            body: Center(
              child: GlassSurface(child: SizedBox(width: 240, height: 180)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final light = find.byKey(const ValueKey('glass-interaction-light'));
    final idle = tester.widget<CustomPaint>(light).painter!;
    final touch = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isTrue,
    );
    reduced.value = true;
    await tester.pump();
    expect(light, findsNothing);
    await touch.up();
    reduced.value = false;
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isFalse,
    );
    final next = await tester.startGesture(const Offset(390, 300));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isTrue,
    );
    await next.cancel();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('secondary touch cannot move or clear primary light', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const Scaffold(
          body: Center(
            child: GlassSurface(child: SizedBox(width: 240, height: 180)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final light = find.byKey(const ValueKey('glass-interaction-light'));
    final idle = tester.widget<CustomPaint>(light).painter!;
    final first = await tester.startGesture(const Offset(370, 300), pointer: 1);
    await tester.pump();
    final primary = tester.widget<CustomPaint>(light).painter!;
    expect(primary.shouldRepaint(idle), isTrue);
    final second = await tester.startGesture(
      const Offset(440, 300),
      pointer: 2,
    );
    await second.moveBy(const Offset(10, 10));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(primary),
      isFalse,
    );
    await second.up();
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(primary),
      isFalse,
    );
    await first.cancel();
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isFalse,
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'interaction pixels brighten locally and preserve foreground $brightness',
      (tester) async {
        const capture = ValueKey('light-pixels');
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: brightness,
              visualStyle: HermesVisualStyle.liquid,
            ),
            home: const Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: capture,
                  child: SizedBox(
                    width: 240,
                    height: 180,
                    child: GlassSurface(
                      child: Stack(
                        children: [
                          Positioned(
                            left: 110,
                            top: 70,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: ColoredBox(color: Color(0xFF123456)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<List<int>> pixels() async {
          late List<int> result;
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(capture))
                .toImage(pixelRatio: 1);
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            result = data.buffer
                .asUint8List(data.offsetInBytes, data.lengthInBytes)
                .toList();
            image.dispose();
          });
          return result;
        }

        List<int> at(List<int> data, int x, int y) =>
            data.sublist((y * 240 + x) * 4, (y * 240 + x) * 4 + 4);
        final before = await pixels();
        final touch = await tester.startGesture(
          tester.getTopLeft(find.byKey(capture)) + const Offset(70, 90),
        );
        await tester.pump();
        final active = await pixels();
        expect(at(active, 70, 90)[0], greaterThan(at(before, 70, 90)[0]));
        expect(at(active, 225, 90), at(before, 225, 90));
        expect(at(active, 120, 80), [18, 52, 86, 255]);
        await touch.cancel();
        await tester.pumpAndSettle();
        expect(await pixels(), before);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('nested glass shares hover light and clears on exit/cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const Scaffold(
          body: Center(
            child: GlassSurface(
              child: SizedBox(
                width: 200,
                height: 160,
                child: GlassSurface(child: Text('Nested')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final light = find.byKey(const ValueKey('glass-interaction-light'));
    expect(light, findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final idle = tester.widget<CustomPaint>(light).painter!;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(const Offset(400, 300));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isTrue,
    );
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isFalse,
    );
    await mouse.removePointer();
    final touch = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isTrue,
    );
    await touch.cancel();
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(light).painter!.shouldRepaint(idle),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets('pointer lighting preserves taps reduced=$reduced', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: Center(
                child: GlassSurface(
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('Action'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final light = find.byKey(const ValueKey('glass-interaction-light'));
      await tester.pumpAndSettle();
      expect(light, reduced ? findsNothing : findsOneWidget);
      final initial = reduced
          ? null
          : tester.widget<CustomPaint>(light).painter!;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Action')),
      );
      await tester.pump();
      if (!reduced) {
        expect(
          tester.widget<CustomPaint>(light).painter!.shouldRepaint(initial!),
          isTrue,
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      if (!reduced) {
        expect(
          tester.widget<CustomPaint>(light).painter!.shouldRepaint(initial!),
          isFalse,
        );
      }
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) => onPaint();
  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}
