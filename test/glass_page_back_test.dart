import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_page_scaffold.dart';

void main() {
  for (final customLeading in [false, true]) {
    testWidgets(
      'glass back preserves guard and explicit leading custom=$customLeading',
      (tester) async {
        var blockedAttempts = 0;
        var customPresses = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PopScope<void>(
                        canPop: false,
                        onPopInvokedWithResult: (didPop, result) {
                          if (!didPop) blockedAttempts++;
                        },
                        child: HermesPageScaffold(
                          title: 'Protected',
                          leading: customLeading
                              ? IconButton(
                                  key: const ValueKey('custom-leading'),
                                  onPressed: () => customPresses++,
                                  icon: const Icon(Icons.menu),
                                )
                              : null,
                          body: const Text('Unsaved content'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (customLeading) {
          expect(find.byType(GlassButton), findsNothing);
          await tester.tap(find.byKey(const ValueKey('custom-leading')));
          expect(customPresses, 1);
          expect(blockedAttempts, 0);
        } else {
          await tester.tap(find.byType(GlassButton));
          await tester.pumpAndSettle();
          expect(blockedAttempts, 1);
        }
        expect(find.text('Unsaved content'), findsOneWidget);
        expect(find.text('Open'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final fullscreen in [false, true]) {
    for (final nested in [false, true]) {
      testWidgets('glass dismiss fullscreen=$fullscreen nested=$nested', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: fullscreen,
                      builder: (_) => HermesPageScaffold(
                        title: 'Detail',
                        scrollBodyBehindHeader: nested,
                        body: nested
                            ? ListView(children: const [Text('Content')])
                            : const Text('Content'),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final button = find.byType(GlassButton);
        expect(button, findsOneWidget);
        expect(
          tester.widget<GlassButton>(button).tooltip,
          fullscreen ? 'Close' : 'Back',
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Detail'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
