import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('Liquid segmented layout $direction', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: Directionality(textDirection: direction, child: child!),
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: GlassSurface(
                child: StatefulBuilder(
                  builder: (context, setState) => SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('System')),
                      ButtonSegment(value: 1, label: Text('Light')),
                      ButtonSegment(value: 2, label: Text('Dark')),
                    ],
                    selected: {selected},
                    onSelectionChanged: (value) =>
                        setState(() => selected = value.first),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final buttons = find.descendant(
        of: find.byType(SegmentedButton<int>),
        matching: find.byType(TextButton),
      );
      expect(buttons, findsNWidgets(3));
      for (final element in buttons.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(304));
      }
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(selected, 2);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = tester
          .widgetList<TextButton>(buttons)
          .where(
            (button) =>
                button.statesController!.value.contains(WidgetState.focused),
          )
          .toList();
      expect(focused, hasLength(1));
      final focusedLabel = find.descendant(
        of: find.byWidget(focused.single),
        matching: find.byType(Text),
      );
      final expected = [
        'System',
        'Light',
        'Dark',
      ].indexOf(tester.widget<Text>(focusedLabel).data!);
      expect(expected, greaterThanOrEqualTo(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, expected);
      expect(tester.takeException(), isNull);
    });
  }
}
