import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_selection_row.dart';

void main() {
  for (final accessible in [false, true]) {
    for (final disabled in [false, true]) {
      testWidgets(
        'selection motion accessible=$accessible disabled=$disabled',
        (tester) async {
          var selected = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesTheme(
                brightness: Brightness.dark,
                visualStyle: HermesVisualStyle.liquid,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  accessibleNavigation: accessible,
                  disableAnimations: disabled,
                ),
                child: child!,
              ),
              home: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: GlassSelectionRow(
                    selected: selected,
                    child: ListTile(
                      title: const Text('Option'),
                      onTap: () => setState(() => selected = !selected),
                    ),
                  ),
                ),
              ),
            ),
          );
          final material = find.descendant(
            of: find.byType(GlassSelectionRow),
            matching: find.byType(Material),
          );
          expect(
            tester.widget<Material>(material).animationDuration,
            accessible || disabled
                ? Duration.zero
                : HermesGlassTokens.feedbackDuration,
          );
          expect(
            tester.widget<Material>(material).shape,
            isA<RoundedSuperellipseBorder>(),
          );
          await tester.tap(find.text('Option'));
          await tester.pumpAndSettle();
          expect(selected, isTrue);
          final context = tester.element(material);
          expect(
            tester.widget<Material>(material).color,
            Theme.of(context).colorScheme.primaryContainer,
          );
          expect(find.byType(BackdropFilter), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
