import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/appearance_preview.dart';

void main() {
  testWidgets('preview releases interaction light after selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const Scaffold(body: Center(child: AppearancePreview())),
      ),
    );
    await tester.pumpAndSettle();
    final lights = find.byKey(const ValueKey('glass-interaction-light'));
    final idle = tester
        .widgetList<CustomPaint>(lights)
        .map((w) => w.painter!)
        .toList();
    expect(idle, hasLength(3));
    await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
    await tester.pumpAndSettle();
    final released = tester.widgetList<CustomPaint>(lights).toList();
    for (var i = 0; i < idle.length; i++) {
      expect(released[i].painter!.shouldRepaint(idle[i]), isFalse);
    }
    expect(tester.takeException(), isNull);
  });
  for (final highContrast in [false, true]) {
    testWidgets('preview opaque accessibility and large text ($highContrast)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
            reduceTransparency: !highContrast,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              highContrast: highContrast,
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 320, child: AppearancePreview()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      final background = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppearancePreview),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = background.decoration as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color!.a, 1);
      await tester.ensureVisible(find.byIcon(Icons.chat_bubble_outline).last);
      await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chat_bubble_outline), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    for (final style in HermesVisualStyle.values) {
      testWidgets('preview ${style.name} ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesTheme(brightness: brightness, visualStyle: style),
            home: const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SingleChildScrollView(child: AppearancePreview()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Selection changes must retain the preview's stable 44px control.
        final selectedButton = find.ancestor(
          of: find.byIcon(Icons.home_outlined).last,
          matching: find.byType(IconButton),
        );
        expect(tester.getSize(selectedButton).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(selectedButton).height, greaterThanOrEqualTo(44));
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/preview_${style.name}_${brightness.name}.png',
          ),
        );
        await tester.ensureVisible(find.byIcon(Icons.chat_bubble_outline).last);
        await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.home_outlined), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline), findsNWidgets(2));
      });
    }
  }
}
