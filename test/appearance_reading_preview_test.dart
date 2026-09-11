import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/appearance_preview.dart';
import 'support/review_capture.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final opaque in [false, true]) {
      for (final locale in ['zh', 'en', 'ar']) {
        testWidgets('reading preview $brightness $opaque $locale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildHermesTheme(
                brightness: brightness,
                visualStyle: HermesVisualStyle.liquid,
                reduceTransparency: opaque,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: const RepaintBoundary(
                key: ValueKey('appearance-review'),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: AppearancePreview(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          const reviewDir = String.fromEnvironment('UI_REVIEW_DIR');
          if (reviewDir.isNotEmpty) {
            await captureReview(
              tester,
              find.byKey(const ValueKey('appearance-review')),
              '$reviewDir/appearance-${brightness.name}-2.0-$locale-$opaque.png',
            );
          }
          final reading = tester.widget<Container>(
            find.byKey(const ValueKey('appearance-preview-reading-plane')),
          );
          expect((reading.decoration! as ShapeDecoration).color!.a, 1);
          expect(find.byType(TextField), findsNothing);
          expect(
            find.byType(BackdropFilter),
            opaque ? findsNothing : findsNWidgets(3),
          );
          final chat = find.byIcon(Icons.chat_bubble_outline).last;
          await tester.ensureVisible(chat);
          await tester.tap(chat);
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.chat_bubble_outline), findsNWidgets(2));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
