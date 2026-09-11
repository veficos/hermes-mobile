import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/sheets/handoff_dialog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'Liquid handoff picker scrolls and returns selection ($reduced)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        addTearDown(tester.view.reset);
        final platforms = List.generate(
          20,
          (index) => MessagingPlatform.fromJson({
            'id': 'platform-$index',
            'name': 'Platform $index',
            'enabled': true,
            'configured': true,
          }),
        );
        MessagingPlatform? picked;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.dark,
              visualStyle: HermesVisualStyle.liquid,
              reduceTransparency: reduced,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    picked = await showChatHandoffPlatformPicker(
                      context,
                      platforms,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byType(BackdropFilter),
          reduced ? findsNothing : findsOneWidget,
        );
        expect(find.byIcon(Icons.close).hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Platform 19'),
          300,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text('Platform 19'));
        await tester.pumpAndSettle();
        expect(picked, same(platforms.last));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(picked, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
