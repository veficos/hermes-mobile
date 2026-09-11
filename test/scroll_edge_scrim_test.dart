import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/scroll_edge_scrim.dart';

void main() {
  for (final top in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets('edge falloff top=$top reduced=$reduced', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
              reduceTransparency: reduced,
            ),
            home: Scaffold(
              body: ScrollEdgeScrim(
                top: top,
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Tap'),
                ),
              ),
            ),
          ),
        );
        final decorations = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(ScrollEdgeScrim),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>()
            .where((decoration) => decoration.gradient != null);
        if (reduced) {
          expect(decorations, isEmpty);
        } else {
          final gradient = decorations.single.gradient! as LinearGradient;
          expect(gradient.stops, [0, .25, .5, .75, 1]);
          expect(
            gradient.begin,
            top ? Alignment.topCenter : Alignment.bottomCenter,
          );
          final alpha = gradient.colors.map((color) => color.a).toList();
          expect(alpha.last, 0);
          expect(alpha[0] - alpha[1], lessThan(alpha[1] - alpha[2]));
          expect(alpha[3] - alpha[4], lessThan(alpha[2] - alpha[3]));
        }
        expect(find.byType(BackdropFilter), findsNothing);
        await tester.tap(find.text('Tap'));
        expect(taps, 1);
      });
    }
  }
}
