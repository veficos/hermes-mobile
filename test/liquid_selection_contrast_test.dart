import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_selection_row.dart';
import 'package:hermes_mobile/widgets/glass/glass_menu_entry.dart';

void main() {
  for (final accent in HermesAccents.all) {
    for (final brightness in Brightness.values) {
      for (final highContrast in [false, true]) {
        test(
          'Liquid navigation colors ${accent.id} $brightness highContrast=$highContrast',
          () {
            final theme = buildHermesTheme(
              brightness: brightness,
              accent: accent,
              highContrast: highContrast,
              visualStyle: HermesVisualStyle.liquid,
            );
            final nav = theme.navigationBarTheme;
            const selected = {WidgetState.selected};
            // The icon is on the indicator; the label is below it on glass.
            expect(nav.indicatorColor, theme.colorScheme.primaryContainer);
            expect(
              nav.iconTheme!.resolve(selected)!.color,
              theme.colorScheme.onPrimaryContainer,
            );
            expect(
              nav.labelTextStyle!.resolve(selected)!.color,
              theme.colorScheme.onSurface,
            );
            if (highContrast) {
              expect(
                nav.iconTheme!.resolve({})!.color,
                theme.colorScheme.onSurfaceVariant,
              );
              expect(
                nav.labelTextStyle!.resolve({})!.color,
                theme.colorScheme.onSurfaceVariant,
              );
            }
          },
        );
      }
      testWidgets(
        'selected ListTile inherits readable foreground ${accent.id} $brightness',
        (tester) async {
          final theme = buildHermesTheme(
            brightness: brightness,
            accent: accent,
            visualStyle: HermesVisualStyle.liquid,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: GlassSelectionRow(
                  selected: true,
                  child: ListTile(
                    selected: true,
                    title: const Text('Selected workspace'),
                    subtitle: const Text('/workspace'),
                    trailing: const Icon(Icons.check),
                  ),
                ),
              ),
            ),
          );
          for (final label in ['Selected workspace', '/workspace']) {
            final inherited = DefaultTextStyle.of(
              tester.element(find.text(label)),
            ).style.color;
            expect(inherited, theme.colorScheme.onPrimaryContainer);
          }
          expect(
            IconTheme.of(tester.element(find.byIcon(Icons.check))).color,
            theme.colorScheme.onPrimaryContainer,
          );
          expect(tester.takeException(), isNull);
        },
      );
      test('Liquid selection contrast ${accent.id} $brightness', () {
        final colors = buildHermesTheme(
          brightness: brightness,
          accent: accent,
          visualStyle: HermesVisualStyle.liquid,
        ).colorScheme;
        final background = colors.primaryContainer;
        final foreground = Color.alphaBlend(
          colors.onPrimaryContainer,
          background,
        );
        final a = background.computeLuminance();
        final b = foreground.computeLuminance();
        final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      });
      for (final enabled in [false, true]) {
        testWidgets(
          'selected menu foreground ${accent.id} $brightness enabled=$enabled',
          (tester) async {
            final theme = buildHermesTheme(
              brightness: brightness,
              accent: accent,
              visualStyle: HermesVisualStyle.liquid,
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showMenu<String>(
                        context: context,
                        position: const RelativeRect.fromLTRB(20, 20, 0, 0),
                        items: [
                          GlassMenuEntry(
                            initialValue: 'selected',
                            entries: [
                              PopupMenuItem<String>(
                                enabled: enabled,
                                value: 'selected',
                                child: const Row(
                                  children: [
                                    Icon(Icons.check),
                                    Text('Selected menu'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            expect(
              DefaultTextStyle.of(
                tester.element(find.text('Selected menu')),
              ).style.color,
              enabled
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.popupMenuTheme.labelTextStyle!.resolve({
                      WidgetState.disabled,
                    })!.color,
            );
            expect(
              IconTheme.of(tester.element(find.byIcon(Icons.check))).color,
              theme.colorScheme.onPrimaryContainer,
            );
            final iconTheme = IconTheme.of(
              tester.element(find.byIcon(Icons.check)),
            );
            if (!enabled) {
              expect(iconTheme.opacity, lessThan(1));
              await tester.tap(find.text('Selected menu'));
              await tester.pumpAndSettle();
              expect(find.text('Selected menu'), findsOneWidget);
              final ink = tester
                  .widgetList<InkWell>(
                    find.descendant(
                      of: find.byType(PopupMenuItem<String>),
                      matching: find.byType(InkWell),
                    ),
                  )
                  .single;
              expect(ink.onTap, isNull);
              expect(ink.canRequestFocus, isFalse);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
