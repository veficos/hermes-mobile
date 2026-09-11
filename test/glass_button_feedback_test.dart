import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';

void main() {
  testWidgets(
    'Liquid button keeps its painted control size with compact density',
    (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ).copyWith(visualDensity: VisualDensity.compact),
          home: Scaffold(
            body: Center(
              child: GlassButton(
                tooltip: 'Action',
                onPressed: () => presses++,
                child: const Icon(Icons.add, size: 18),
              ),
            ),
          ),
        ),
      );
      final material = find.descendant(
        of: find.byType(GlassButton),
        matching: find.byType(Material),
      );
      expect(tester.getSize(material).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(material).height, greaterThanOrEqualTo(44));
      await tester.tapAt(tester.getTopLeft(material) + const Offset(5, 22));
      await tester.pump();
      expect(presses, 1);
    },
  );
  for (final accent in HermesAccents.all) {
    for (final brightness in Brightness.values) {
      testWidgets('Liquid button paired selection ${accent.id} $brightness', (
        tester,
      ) async {
        final theme = buildHermesTheme(
          brightness: brightness,
          accent: accent,
          highContrast: true,
          visualStyle: HermesVisualStyle.liquid,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: GlassButton(
                tooltip: 'Selected',
                selected: true,
                onPressed: () {},
                child: const Icon(Icons.check),
              ),
            ),
          ),
        );
        final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
        expect(
          style.backgroundColor!.resolve({}),
          theme.colorScheme.primaryContainer,
        );
        expect(
          style.foregroundColor!.resolve({}),
          theme.colorScheme.onPrimaryContainer,
        );
        expect(style.side!.resolve({}), BorderSide.none);
        expect(
          style.side!.resolve({WidgetState.focused})!.color,
          theme.colorScheme.onPrimaryContainer,
        );
        final icon = IconTheme.of(tester.element(find.byIcon(Icons.check)));
        expect(icon.color, theme.colorScheme.onPrimaryContainer);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('disabled selected Liquid button uses a quiet outline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const Scaffold(
          body: GlassButton(
            tooltip: 'Unavailable',
            selected: true,
            onPressed: null,
            child: Icon(Icons.add),
          ),
        ),
      ),
    );
    final button = tester.widget<IconButton>(find.byType(IconButton));
    final disabled = button.style!.side!.resolve({
      WidgetState.disabled,
      WidgetState.focused,
    })!;
    final focused = button.style!.side!.resolve({WidgetState.focused})!;
    expect(disabled.width, 1);
    expect(disabled.color, isNot(focused.color));
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Liquid keyboard focus has a distinct ring and activates', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Scaffold(
          body: Center(
            child: GlassButton(
              tooltip: 'Action',
              onPressed: () => presses++,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.statesController!.value, contains(WidgetState.focused));
    expect(
      button.style!.side!.resolve(button.statesController!.value)!.width,
      2,
    );
    expect(button.style!.side!.resolve({}), BorderSide.none);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('accessible navigation suppresses scale and color transitions', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.dark,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: Scaffold(
            body: Center(
              child: GlassButton(
                tooltip: 'Action',
                selected: true,
                onPressed: () => presses++,
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(IconButton);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(
      tester.widget<IconButton>(button).style!.animationDuration,
      Duration.zero,
    );
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(presses, 1);
  });

  testWidgets('cancelled glass press restores scale without activation', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: false, accessibleNavigation: false),
          child: child!,
        ),
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Scaffold(
          body: Center(
            child: GlassButton(
              tooltip: 'Action',
              onPressed: () => presses++,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(IconButton);
    final rect = tester.getRect(button);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .92);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(tester.getRect(button), rect);
    expect(presses, 0);
  });
  for (final style in HermesVisualStyle.values) {
    for (final reduced in [false, true]) {
      testWidgets('button feedback $style reduced=$reduced', (tester) async {
        var presses = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: style,
            ),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: Center(
                  child: GlassButton(
                    tooltip: 'Action',
                    onPressed: () => presses++,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
          ),
        );
        final target = find.byType(IconButton);
        final rect = tester.getRect(target);
        final gesture = await tester.startGesture(rect.center);
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          style == HermesVisualStyle.liquid && !reduced ? .92 : 1,
        );
        expect(tester.getRect(target), rect);
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.height, greaterThanOrEqualTo(44));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(presses, 1);
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
