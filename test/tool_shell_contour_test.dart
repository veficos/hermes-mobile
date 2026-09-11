import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_tool.dart';
import 'package:hermes_mobile/widgets/h/hermes_glass.dart';

void main() {
  for (final reduced in [false, true]) {
    for (final highContrast in [false, true]) {
      testWidgets('nested code material reduced=$reduced highContrast=$highContrast', (tester) async {
        late ShapeDecoration decoration;
        await tester.pumpWidget(MaterialApp(
          theme: buildHermesTheme(brightness: Brightness.light, visualStyle: HermesVisualStyle.liquid).copyWith(
            extensions: [HermesGlassTheme(enabled: true, reduceTransparency: reduced)],
          ),
          home: MediaQuery(
            data: MediaQueryData(highContrast: highContrast),
            child: Builder(builder: (context) {
              decoration = toolCodeBoxDecoration(context) as ShapeDecoration;
              return const SizedBox();
            }),
          ),
        ));
        expect(decoration.shape, isA<RoundedSuperellipseBorder>());
        expect(decoration.color!.a, closeTo(reduced || highContrast ? 1 : .82, .005));
      });
    }
  }
  for (final style in HermesVisualStyle.values) {
    testWidgets('tool shell contour and expansion $style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: style,
          ),
          home: const Scaffold(
            body: ToolCardShell(
              icon: Icons.terminal,
              title: 'terminal',
              children: [Text('result contents')],
            ),
          ),
        ),
      );
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ToolCardShell),
          matching: find.byType(Container),
        ),
      );
      final outer = containers.firstWhere(
        (c) => c.clipBehavior == Clip.antiAlias,
      );
      if (style == HermesVisualStyle.liquid) {
        expect(
          (outer.decoration! as ShapeDecoration).shape,
          isA<RoundedSuperellipseBorder>(),
        );
      } else {
        expect(outer.decoration, isA<BoxDecoration>());
      }
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.tap(find.text('terminal'));
      await tester.pumpAndSettle();
      expect(find.text('result contents'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('media content clipping $style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: style,
          ),
          home: const Scaffold(
            body: HermesGlassCard(
              clipBehavior: Clip.antiAlias,
              child: Text('media'),
            ),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(HermesGlassCard),
          matching: find.byType(Material),
        ),
      );
      expect(material.clipBehavior, Clip.antiAlias);
      if (style == HermesVisualStyle.liquid) {
        expect(material.shape, isA<RoundedSuperellipseBorder>());
      }
    });
  }
}
