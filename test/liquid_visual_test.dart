import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/appearance_preview.dart';

void main() {
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
                  child: AppearancePreview(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/preview_${style.name}_${brightness.name}.png',
          ),
        );
        await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.home_outlined), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline), findsNWidgets(2));
      });
    }
  }
}
