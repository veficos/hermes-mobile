import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('shared action silhouettes $style $brightness', (
        tester,
      ) async {
        final theme = buildHermesTheme(
          brightness: brightness,
          visualStyle: style,
        );
        for (final buttonStyle in [
          theme.filledButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
          theme.textButtonTheme.style!,
        ]) {
          for (final states in <Set<WidgetState>>[
            {},
            {WidgetState.pressed},
            {WidgetState.focused},
            {WidgetState.disabled},
          ]) {
            expect(
              buttonStyle.shape!.resolve(states),
              style == HermesVisualStyle.liquid
                  ? isA<StadiumBorder>()
                  : isA<RoundedRectangleBorder>(),
            );
          }
        }
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          onPressed: () => taps++,
                          child: const Text('Confirm'),
                        ),
                        OutlinedButton(
                          onPressed: () => taps++,
                          child: const Text('Review'),
                        ),
                        TextButton(
                          onPressed: () => taps++,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final label in ['Confirm', 'Review', 'Cancel']) {
          final button = find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              )
              .first;
          expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
          await tester.tap(find.text(label));
        }
        expect(taps, 3);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
