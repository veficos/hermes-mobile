import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';

void main() {
  for (final mode in ['normal', 'reduced', 'accessible']) {
    final reduced = mode != 'normal';
    testWidgets('Liquid composer send size and motion ($mode)', (tester) async {
      final controller = TextEditingController(text: 'Hello');
      addTearDown(controller.dispose);
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: mode == 'reduced',
              accessibleNavigation: mode == 'accessible',
            ),
            child: child!,
          ),
          home: Scaffold(
            body: HermesComposer(
              controller: controller,
              onSend: (_) => sends++,
              onModelTap: () {},
              modelLabel: 'model',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final send = find.byKey(const ValueKey('composer-send'));
      expect(tester.getSize(send), const Size(44, 44));
      final scale = find.descendant(
        of: send,
        matching: find.byType(AnimatedScale),
      );
      final gesture = await tester.startGesture(tester.getCenter(send));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<AnimatedScale>(scale).scale, reduced ? 1 : .92);
      expect(tester.widget<AnimatedScale>(scale).duration,
          reduced ? Duration.zero : HermesGlassMotion.press);
      expect(tester.widget<AnimatedScale>(scale).curve, HermesGlassMotion.curve);
      final tapTarget = find.descendant(
        of: send,
        matching: find.byType(InkWell),
      );
      expect(tester.getRect(tapTarget), tester.getRect(send));
      // The gesture target must be outside the visual transform.
      expect(
        find.descendant(of: scale, matching: find.byType(InkWell)),
        findsNothing,
      );
      if (reduced) {
        expect(tester.widget<AnimatedScale>(scale).duration, Duration.zero);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
