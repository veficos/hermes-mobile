import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_badge.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('badge count has readable contrast $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: HermesBadge(count: 120))),
        ),
      );
      final text = tester.widget<Text>(find.text('99+'));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(HermesBadge),
          matching: find.byType(Container),
        ),
      );
      final background = (container.decoration! as BoxDecoration).color!;
      final a = text.style!.color!.computeLuminance();
      final b = background.computeLuminance();
      expect(
        ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
