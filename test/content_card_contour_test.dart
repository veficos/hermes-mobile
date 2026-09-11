import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_glass.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('content card contour $style $brightness', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(brightness: brightness, visualStyle: style),
            home: Scaffold(
              body: HermesGlassCard(
                tint: Colors.white,
                radius: 20,
                onTap: () => taps++,
                child: const Text('Content'),
              ),
            ),
          ),
        );
        final card = find.byType(HermesGlassCard);
        final container = tester.widget<Container>(
          find.descendant(of: card, matching: find.byType(Container)),
        );
        if (style == HermesVisualStyle.liquid) {
          final decoration = container.decoration! as ShapeDecoration;
          expect(decoration.shape, isA<RoundedSuperellipseBorder>());
          expect(decoration.color, Colors.white);
          expect(
            tester.widget<InkWell>(find.byType(InkWell)).customBorder,
            isA<RoundedSuperellipseBorder>(),
          );
        } else {
          expect(container.decoration, isA<BoxDecoration>());
        }
        expect(find.byType(BackdropFilter), findsNothing);
        await tester.tap(find.text('Content'));
        expect(taps, 1);
      });
    }
  }
}
