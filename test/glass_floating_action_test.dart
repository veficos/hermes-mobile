import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_floating_action.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    testWidgets(
      'hidden floating action excludes keyboard and semantics $style',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var taps = 0;
        var interactive = true;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: style,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Center(
                    child: GlassFloatingAction(
                      heroTag: 'test',
                      tooltip: 'Latest',
                      interactive: interactive,
                      onPressed: () => taps++,
                      child: const Icon(Icons.arrow_downward),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(taps, 1);
        update(() => interactive = false);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Latest'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.tapAt(tester.getCenter(find.byType(GlassFloatingAction)));
        await tester.pumpAndSettle();
        expect(taps, 1);
        update(() => interactive = true);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Latest'));
        expect(taps, 2);
        semantics.dispose();
      },
    );
    for (final opaque in [false, true]) {
      testWidgets('floating action $style opaque=$opaque', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme:
                buildHermesTheme(
                  brightness: Brightness.light,
                  visualStyle: style,
                ).copyWith(
                  extensions: [
                    HermesGlassTheme(
                      enabled: style == HermesVisualStyle.liquid,
                      reduceTransparency: opaque,
                    ),
                  ],
                ),
            home: Scaffold(
              body: Center(
                child: GlassFloatingAction(
                  heroTag: 'test',
                  tooltip: 'Latest',
                  onPressed: () => taps++,
                  child: const Icon(Icons.arrow_downward),
                ),
              ),
            ),
          ),
        );
        final liquid = style == HermesVisualStyle.liquid;
        expect(
          find.byType(GlassButton),
          liquid ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(FloatingActionButton),
          liquid ? findsNothing : findsOneWidget,
        );
        expect(
          find.byType(BackdropFilter),
          liquid && !opaque ? findsOneWidget : findsNothing,
        );
        if (liquid) {
          expect(
            tester.getSize(find.byType(GlassButton)).height,
            greaterThanOrEqualTo(44),
          );
        }
        await tester.tap(find.byTooltip('Latest'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
