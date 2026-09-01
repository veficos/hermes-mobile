import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/widgets/h/hermes_states.dart';

void main() {
  const locales = [
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'Hant'),
    Locale('ja'),
    Locale('ar'),
  ];

  for (final locale in locales) {
    testWidgets('shared states localize for ${locale.toLanguageTag()}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Expanded(child: HermesErrorState(onRetry: () {})),
                  const Expanded(child: HermesLoadingState()),
                ],
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      expect(find.text(context.l10n.commonErrorTitle), findsOneWidget);
      expect(find.text(context.l10n.commonRetry), findsOneWidget);
      expect(find.text(context.l10n.commonLoading), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('error state remains semantic and stable at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: HermesErrorState(description: 'Connection unavailable'),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.text('Connection unavailable'));
    expect(semantics.label, contains('Connection unavailable'));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/hermes_error_state_large_text.png'),
    );
  });
}
