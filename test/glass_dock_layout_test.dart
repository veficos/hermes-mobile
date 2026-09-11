import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/glass/glass_dock_layout.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('dock samples moving backdrop reduced=$reduced', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const capture = ValueKey('dock-capture');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
            reduceTransparency: reduced,
          ),
          home: Center(
            child: RepaintBoundary(
              key: capture,
              child: SizedBox(
                width: 320,
                height: 500,
                child: GlassDockLayout(
                  enabled: !reduced,
                  bodyBuilder: (_, inset) => ListView(
                    controller: controller,
                    padding: EdgeInsets.only(bottom: inset),
                    children: const [
                      SizedBox(
                        height: 600,
                        child: ColoredBox(color: Colors.red),
                      ),
                      SizedBox(
                        height: 900,
                        child: ColoredBox(color: Colors.blue),
                      ),
                    ],
                  ),
                  dock: const GlassSurface(
                    thick: true,
                    radius: 26,
                    child: SizedBox(height: 80, width: double.infinity),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<List<int>> sample(double offset) async {
        controller.jumpTo(offset);
        await tester.pumpAndSettle();
        late List<int> pixel;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          final rendered = await boundary.toImage(pixelRatio: 1);
          final data = (await rendered.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final index = (460 * rendered.width + 160) * 4;
          pixel = List.generate(4, (channel) => data.getUint8(index + channel));
          rendered.dispose();
        });
        return pixel;
      }

      await tester.pumpAndSettle();
      final red = await sample(0);
      final blue = await sample(650);
      if (reduced) {
        expect(blue, red);
        expect(find.byType(BackdropFilter), findsNothing);
      } else {
        expect(red[0] - blue[0], greaterThan(15));
        expect(blue[2] - red[2], greaterThan(15));
        expect(find.byType(BackdropFilter), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final enabled in [true, false]) {
    testWidgets(
      'dock measures resize and preserves content clearance $enabled',
      (tester) async {
        final height = ValueNotifier<double>(80);
        addTearDown(height.dispose);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        double inset = -1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 500,
                child: GlassDockLayout(
                  enabled: enabled,
                  bodyBuilder: (context, bottom) {
                    inset = bottom;
                    return ListView(
                      controller: controller,
                      padding: EdgeInsets.only(bottom: bottom),
                      children: const [
                        SizedBox(height: 800),
                        SizedBox(key: ValueKey('last'), height: 60),
                      ],
                    );
                  },
                  dock: ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (_, value, _) =>
                        SizedBox(key: const ValueKey('dock'), height: value),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final value in [80.0, 160.0, 60.0]) {
          height.value = value;
          await tester.pumpAndSettle();
          expect(inset, enabled ? value : 0);
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          final dock = tester.getRect(find.byKey(const ValueKey('dock')));
          final list = tester.getRect(find.byType(ListView));
          expect(list.bottom, enabled ? dock.bottom : dock.top);
          expect(
            tester.getRect(find.byKey(const ValueKey('last'))).bottom,
            closeTo(dock.top, .01),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
