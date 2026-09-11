import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_action_group.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';

void main() {
  for (final grouped in [false, true]) {
    testWidgets(
      'nested surface honors a local opaque override grouped=$grouped',
      (tester) async {
        final theme = buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        );
        const inner = ValueKey('local-opaque');
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Center(
              child: GlassSurface(
                child: Theme(
                  data: theme.copyWith(
                    extensions: [
                      const HermesGlassTheme(
                        enabled: true,
                        reduceTransparency: true,
                      ),
                    ],
                  ),
                  child: grouped
                      ? const GlassActionGroup(
                          key: inner,
                          child: SizedBox(width: 100, height: 60),
                        )
                      : const GlassSurface(
                          key: inner,
                          child: SizedBox(width: 100, height: 60),
                        ),
                ),
              ),
            ),
          ),
        );
        final fills = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byKey(inner),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((widget) => widget.decoration)
            .whereType<ShapeDecoration>()
            .where((decoration) => decoration.gradient != null);
        expect(fills, hasLength(1));
        expect(
          fills.single.gradient!.colors.every((color) => color.a == 1),
          isTrue,
        );
        expect(find.byType(BackdropFilter), findsOneWidget);
      },
    );
  }
  for (final brightness in Brightness.values) {
    for (final reduced in [false, true]) {
      testWidgets(
        'nested group preserves parent pixels $brightness reduced=$reduced',
        (tester) async {
          const capture = ValueKey('capture');
          Future<List<int>> render(
            bool grouped, {
            bool nestedSurface = false,
          }) async {
            const foreground = SizedBox(
              width: 100,
              height: 60,
              child: Center(child: Icon(Icons.add, color: Colors.orange)),
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: buildHermesTheme(
                  brightness: brightness,
                  visualStyle: HermesVisualStyle.liquid,
                  reduceTransparency: reduced,
                ),
                home: Center(
                  child: RepaintBoundary(
                    key: capture,
                    child: SizedBox(
                      width: 180,
                      height: 120,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red, Colors.blue],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: GlassSurface(
                              thick: true,
                              child: Center(
                                child: nestedSurface
                                    ? const GlassSurface(child: foreground)
                                    : grouped
                                    ? const GlassActionGroup(child: foreground)
                                    : foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(capture),
            );
            late List<int> pixels;
            await tester.runAsync(() async {
              final rendered = await boundary.toImage(pixelRatio: 1);
              final data = (await rendered.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              pixels = data.buffer
                  .asUint8List(data.offsetInBytes, data.lengthInBytes)
                  .toList();
              rendered.dispose();
            });
            return pixels;
          }

          final plain = await render(false);
          final grouped = await render(true);
          expect(grouped, orderedEquals(plain));
          final nested = await render(false, nestedSurface: true);
          expect(nested, orderedEquals(plain));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final nested in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets(
        'action group shares material nested=$nested reduced=$reduced',
        (tester) async {
          var taps = 0;
          final group = GlassActionGroup(
            child: GlassButton(
              tooltip: 'Action',
              onPressed: () => taps++,
              child: const Icon(Icons.add),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesTheme(
                brightness: Brightness.dark,
                visualStyle: HermesVisualStyle.liquid,
                reduceTransparency: reduced,
              ),
              home: Scaffold(
                body: Center(
                  child: nested ? GlassSurface(child: group) : group,
                ),
              ),
            ),
          );
          expect(find.byType(GlassSurface), findsNWidgets(nested ? 2 : 1));
          expect(find.byType(ClipRRect), findsNothing);
          expect(find.byType(ClipRSuperellipse), findsNWidgets(nested ? 2 : 1));
          expect(
            find.byType(BackdropFilter),
            reduced ? findsNothing : findsOneWidget,
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
            tester.getSize(find.byType(IconButton)).shortestSide,
            greaterThanOrEqualTo(44),
          );
          await tester.tap(find.byType(IconButton));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
