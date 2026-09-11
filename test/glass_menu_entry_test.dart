import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_menu_entry.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/widgets/glass/glass_selection_row.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('single glass menu preserves selection ($reduced)', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
            reduceTransparency: reduced,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showMenu<String>(
                    context: context,
                    position: const RelativeRect.fromLTRB(770, 570, 0, 0),
                    color: Colors.transparent,
                    elevation: 0,
                    menuPadding: EdgeInsets.zero,
                    items: const [
                      GlassMenuEntry(
                        initialValue: 'details',
                        entries: [
                          PopupMenuItem<String>(
                            enabled: false,
                            child: Text('Usage'),
                          ),
                          PopupMenuItem<String>(
                            value: 'compress',
                            child: Text('Compress'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'details',
                            child: Text('Details'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.byType(BackdropFilter),
        reduced ? findsNothing : findsOneWidget,
      );
      final panel = tester.getRect(find.byType(GlassSurface));
      final rows = tester
          .widgetList<GlassSelectionRow>(find.byType(GlassSelectionRow))
          .toList();
      expect(rows, hasLength(3));
      expect(rows.map((row) => row.selected), [false, false, true]);
      final selectionSemantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(GlassSelectionRow),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        selectionSemantics.where((node) => node.properties.selected == true),
        hasLength(1),
      );
      expect(find.byType(PopupMenuDivider), findsOneWidget);
      for (final row in find.byType(GlassSelectionRow).evaluate()) {
        expect(
          tester.getSize(find.byWidget(row.widget)).height,
          greaterThanOrEqualTo(56),
        );
      }
      expect(panel.right, lessThanOrEqualTo(800));
      expect(panel.bottom, lessThanOrEqualTo(600));
      expect(panel.left, greaterThanOrEqualTo(0));
      expect(panel.top, greaterThanOrEqualTo(0));
      await tester.tap(find.text('Usage'));
      expect(result, isNull);
      await tester.tap(find.text('Compress'));
      await tester.pumpAndSettle();
      expect(result, 'compress');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Compress'), findsNothing);
      expect(result, 'compress');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, 'details');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Compress'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
