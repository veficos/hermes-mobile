import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_states.dart';
import 'support/review_capture.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'error retry remains readable and single shot $brightness $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var calls = 0;
          final theme = buildHermesTheme(
            brightness: brightness,
            visualStyle: HermesVisualStyle.liquid,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              locale: const Locale('ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('error-review'),
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showHermesErrorSnackBar(
                      context,
                      StateError('Connection unavailable'),
                      onRetry: () => calls++,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final retry = find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(TextButton),
          );
          expect(retry, findsOneWidget);
          final rect = tester.getRect(retry);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          expect(rect.height, greaterThanOrEqualTo(44));
          const captureDir = String.fromEnvironment('UI_REVIEW_DIR');
          if (captureDir.isNotEmpty) {
            await captureReview(
              tester,
              find.byKey(const ValueKey('error-review')),
              '$captureDir/feedback-error-ar-320-${brightness.name}-$scale.png',
            );
          }
          final button = tester.widget<TextButton>(retry);
          if (scale > 1.5) {
            final foreground = button.style!.foregroundColor!.resolve({})!;
            for (final backdrop in [Colors.black, Colors.white]) {
              final background = Color.alphaBlend(
                theme.snackBarTheme.backgroundColor!,
                backdrop,
              );
              final a = foreground.computeLuminance(),
                  b = background.computeLuminance();
              final ratio = a > b
                  ? (a + .05) / (b + .05)
                  : (b + .05) / (a + .05);
              expect(ratio, greaterThanOrEqualTo(4.5));
            }
          }
          // Two events before dismissal animation completes must not retry twice.
          button.onPressed!();
          button.onPressed!();
          expect(calls, 1);
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          bool retryFocused() {
            final context = FocusManager.instance.primaryFocus?.context;
            if (context == null) return false;
            var inSnackBar = false;
            context.visitAncestorElements((element) {
              if (element.widget is SnackBar) inSnackBar = true;
              return !inSnackBar;
            });
            return inSnackBar;
          }

          for (var step = 0; step < 12 && !retryFocused(); step++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          }
          expect(retryFocused(), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(calls, 2);
          expect(find.byType(SnackBar), findsNothing);
          expect(retryFocused(), isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
