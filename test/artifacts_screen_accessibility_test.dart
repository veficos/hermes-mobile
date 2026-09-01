import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_ar.dart';
import 'package:hermes_mobile/screens/artifacts_screen.dart';
import 'package:provider/provider.dart';

class _ArtifactsApi extends ApiClient {
  _ArtifactsApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<List<ArtifactItem>> artifacts({
    String? sessionId,
    int limit = 50,
    int offset = 0,
  }) async => [
    ArtifactItem(
      id: 'artifact-1',
      kind: 'code',
      value: 'final value = aVeryLongIdentifierForNarrowLayoutCoverage;',
      label: 'A long artifact title for narrow layout coverage',
      sessionId: 'session-1',
      sessionTitle: 'A long session title for accessibility coverage',
    ),
  ];
}

void main() {
  testWidgets(
    'artifacts render at 320px Arabic RTL and 2x with button semantics',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final connection = ConnectionStore()..api = _ArtifactsApi();
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionStore>.value(
          value: connection,
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const ArtifactsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const title = 'A long artifact title for narrow layout coverage';
      final openLabel = AppLocalizationsAr().artifactsOpen(title);
      final card = find.bySemanticsLabel(openLabel);
      expect(card, findsOneWidget);
      expect(find.byType(ArtifactsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
