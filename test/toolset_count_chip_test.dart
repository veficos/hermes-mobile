import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/tools/toolset_count_chip.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final brightness in Brightness.values) {
      for (final selected in [false, true]) {
        testWidgets('count chip $style $brightness selected=$selected', (tester) async {
          var taps = 0;
          final theme = buildHermesTheme(brightness: brightness, visualStyle: style);
          await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: Scaffold(body: Center(child: ToolsetCountChip(
              label: 'Tools', count: '3', selected: selected, onTap: () => taps++,
            ))),
          ));
          final chip = find.byType(ToolsetCountChip);
          final material = tester.widget<Material>(find.descendant(of: chip, matching: find.byType(Material)));
          expect(material.color, selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest);
          if (style == HermesVisualStyle.liquid) {
            expect(material.shape, isA<RoundedSuperellipseBorder>());
            expect(tester.getSize(chip).height, greaterThanOrEqualTo(44));
          }
          final semantics = tester.widgetList<Semantics>(find.descendant(of: chip, matching: find.byType(Semantics)));
          expect(semantics.any((s) => s.properties.selected == selected), isTrue);
          await tester.tap(find.text('Tools：3'));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
