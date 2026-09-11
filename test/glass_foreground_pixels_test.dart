import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/widgets/glass/scroll_edge_scrim.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_page_scaffold.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'edge lighting is directional and leaves center clear $brightness',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: brightness,
              visualStyle: HermesVisualStyle.liquid,
            ),
            home: const Center(
              child: GlassSurface(
                radius: 0,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        );
        final painter = tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('glass-edge-highlight')),
            )
            .painter!;
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          painter.paint(Canvas(recorder), const Size(100, 100));
          final picture = recorder.endRecording();
          final rendered = await picture.toImage(100, 100);
          final data = (await rendered.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int alpha(int x, int y) => data.getUint8((y * 100 + x) * 4 + 3);
          expect(alpha(10, 0), greaterThan(alpha(99, 50)));
          expect(alpha(50, 50), 0);
          expect(alpha(99, 90), greaterThan(alpha(99, 50)));
          rendered.dispose();
          picture.dispose();
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final reduced in [false, true]) {
    for (final nested in [false, true]) {
      for (final large in [false, true]) {
        testWidgets(
          'page header samples scrolling content reduced=$reduced nested=$nested large=$large',
          (tester) async {
            tester.view.physicalSize = const Size(390, 600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            const capture = ValueKey('page-capture');
            await tester.pumpWidget(
              MaterialApp(
                theme: buildHermesTheme(
                  brightness: Brightness.light,
                  visualStyle: HermesVisualStyle.liquid,
                  reduceTransparency: reduced,
                ),
                home: RepaintBoundary(
                  key: capture,
                  child: HermesPageScaffold(
                    title: 'Page',
                    titleMode: large
                        ? HermesPageTitleMode.large
                        : HermesPageTitleMode.compact,
                    scrollable: !nested,
                    scrollBodyBehindHeader: nested,
                    body: nested
                        ? ListView(
                            padding: EdgeInsets.zero,
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
                          )
                        : Column(
                            children: const [
                              SizedBox(
                                height: 600,
                                width: double.infinity,
                                child: ColoredBox(color: Colors.red),
                              ),
                              SizedBox(
                                height: 900,
                                width: double.infinity,
                                child: ColoredBox(color: Colors.blue),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (nested && large) {
              final outer = tester.state<ScrollableState>(
                find.byType(Scrollable).first,
              );
              outer.position.jumpTo(outer.position.maxScrollExtent);
              await tester.pumpAndSettle();
            }
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable).last,
            );
            Future<List<int>> sample(double offset) async {
              scroll.position.jumpTo(offset);
              await tester.pumpAndSettle();
              late List<int> color;
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(capture),
              );
              await tester.runAsync(() async {
                final rendered = await boundary.toImage(pixelRatio: 1);
                final data = (await rendered.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                final index = (28 * rendered.width + 300) * 4;
                color = data.buffer
                    .asUint8List(data.offsetInBytes + index, 4)
                    .toList();
                rendered.dispose();
              });
              return color;
            }

            // Large headers must be fully collapsed before sampling content.
            final red = await sample(large ? 250 : 100);
            final blue = await sample(750);
            if (reduced) {
              expect(blue, red);
            } else {
              expect(red[0] - blue[0], greaterThan(15));
              expect(blue[2] - red[2], greaterThan(15));
            }
            expect(find.text('Page').hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  for (final reduced in [false, true]) {
    testWidgets('glass pixels track moving backdrop reduced=$reduced', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      const capture = ValueKey('moving-backdrop');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
            reduceTransparency: reduced,
          ),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: capture,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    children: [
                      ListView(
                        controller: scroll,
                        padding: EdgeInsets.zero,
                        children: const [
                          SizedBox(
                            height: 200,
                            child: ColoredBox(color: Colors.red),
                          ),
                          SizedBox(
                            height: 200,
                            child: ColoredBox(color: Colors.blue),
                          ),
                        ],
                      ),
                      const Positioned(
                        left: 20,
                        top: 20,
                        width: 160,
                        height: 100,
                        child: GlassSurface(
                          thick: true,
                          child: SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>> sample() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        late List<int> color;
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 1);
          final data = (await rendered.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final offset = (70 * rendered.width + 100) * 4;
          color = data.buffer
              .asUint8List(data.offsetInBytes + offset, 4)
              .toList();
          rendered.dispose();
        });
        return color;
      }

      final red = await sample();
      scroll.jumpTo(200);
      await tester.pumpAndSettle();
      final blue = await sample();
      if (reduced) {
        expect(blue, red);
      } else {
        expect(red[0] - blue[0], greaterThan(15));
        expect(blue[2] - red[2], greaterThan(15));
      }
      expect(red[3], 255);
      expect(blue[3], 255);
      expect(tester.takeException(), isNull);
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('glass obeys transparency and keeps hit targets ($reduced)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.dark,
            visualStyle: HermesVisualStyle.liquid,
            reduceTransparency: reduced,
          ),
          home: Scaffold(
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
      );
      expect(
        find.byKey(const ValueKey('glass-specular-layer')),
        reduced ? findsNothing : findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('glass-edge-highlight')),
        reduced ? findsNothing : findsOneWidget,
      );
      expect(
        find.byType(BackdropFilter),
        reduced ? findsNothing : findsOneWidget,
      );
      await tester.tap(find.text('Action'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    for (final surface in [false, true]) {
      testWidgets(
        'foreground pixels survive glass effects: $brightness surface=$surface',
        (tester) async {
          const capture = ValueKey('capture');
          const foreground = SizedBox(
            width: 100,
            height: 100,
            child: ColoredBox(color: Color(0xFF123456)),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesTheme(
                brightness: brightness,
                visualStyle: HermesVisualStyle.liquid,
              ),
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: capture,
                    child: surface
                        ? const GlassSurface(child: foreground)
                        : const ScrollEdgeScrim(child: foreground),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          await tester.runAsync(() async {
            final rendered = await boundary.toImage(pixelRatio: 1);
            final pixels = (await rendered.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            // Near the top-left highlight, away from the rounded clip/border.
            final offset = (25 * rendered.width + 25) * 4;
            expect(
              pixels.buffer.asUint8List(pixels.offsetInBytes + offset, 4),
              [0x12, 0x34, 0x56, 0xff],
            );
            rendered.dispose();
          });
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
