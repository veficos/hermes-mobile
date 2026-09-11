import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_search_field.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('Liquid clear keyboard and press feedback reduced=$reduced', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'query');
      addTearDown(controller.dispose);
      final changes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: GlassSearchField(
                controller: controller,
                hintText: 'Search',
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      final button = find.byType(IconButton);
      final rect = tester.getRect(button);
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
      final gesture = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        reduced ? 1 : .92,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(controller.text, 'query');
      Focus.of(tester.element(find.byIcon(Icons.close))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(changes, ['']);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('empty action is replaced by clear and restored after clearing', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var refreshes = 0;
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Scaffold(
          body: GlassSearchField(
            controller: controller,
            hintText: 'Search',
            onChanged: changes.add,
            emptyAction: IconButton(
              onPressed: () => refreshes++,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.refresh));
    expect(refreshes, 1);
    await tester.enterText(find.byType(TextField), 'bot');
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(changes, ['bot', '']);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'internal focus resumes after custom clear without duplicate change',
    (tester) async {
      final controller = TextEditingController(text: 'query');
      addTearDown(controller.dispose);
      var clears = 0;
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.dark,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: Scaffold(
            body: GlassSearchField(
              controller: controller,
              hintText: 'Search',
              onChanged: (_) => changes++,
              onClear: () {
                clears++;
                controller.clear();
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(clears, 1);
      expect(changes, 0);
      expect(controller.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  for (final style in HermesVisualStyle.values) {
    testWidgets('search updates and clears with focus preserved: $style', (
      tester,
    ) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      final changes = <String>[];
      final submissions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: style,
          ),
          home: Scaffold(
            body: GlassSearchField(
              controller: controller,
              focusNode: focus,
              hintText: 'Search',
              onChanged: changes.add,
              onSubmitted: submissions.add,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.close), findsNothing);
      await tester.enterText(find.byType(TextField), 'query');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submissions, ['query']);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(focus.hasFocus, isTrue);
      expect(changes, ['query', '']);
      expect(find.byIcon(Icons.close), findsNothing);
      controller.text = 'external update';
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      if (style == HermesVisualStyle.liquid) {
        expect(decoration.filled, isFalse);
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
        final ring = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('glass-search-focus-ring')),
        );
        final focusBorder =
            (ring.decoration as ShapeDecoration).shape
                as RoundedSuperellipseBorder;
        expect(focusBorder.side.width, 2);
        expect(
          focusBorder.side.color,
          Theme.of(tester.element(find.byType(TextField))).colorScheme.primary,
        );
        expect(
          focusBorder.borderRadius,
          BorderRadius.circular(HermesGlassTokens.controlRadius),
        );
        expect(find.byType(BackdropFilter), findsOneWidget);
        final textBeforeBlur = controller.text;
        focus.unfocus();
        await tester.pumpAndSettle();
        final idleRing = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('glass-search-focus-ring')),
        );
        expect(
          ((idleRing.decoration as ShapeDecoration).shape
                  as RoundedSuperellipseBorder)
              .side,
          BorderSide.none,
        );
        expect(controller.text, textBeforeBlur);
      } else {
        expect(decoration.filled, isNull);
        expect(decoration.focusedBorder, isNull);
        expect(find.byType(BackdropFilter), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
