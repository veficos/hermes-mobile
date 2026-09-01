import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/files_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AccessibleFilesApi extends ApiClient {
  _AccessibleFilesApi()
    : super(baseUrl: 'http://files.invalid', apiKey: 'test');

  @override
  Future<String> fsDefaultCwd() async => '/workspace';

  @override
  Future<Map<String, dynamic>> fsEntries(String path, {String? root}) async => {
    'entries': [
      {
        'name': 'long-file-name-for-selection-testing.md',
        'path': '/workspace/long-file-name-for-selection-testing.md',
        'is_directory': false,
        'size': 42,
      },
    ],
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('selection actions fit narrow Arabic layout at 2x text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final connection = ConnectionStore()..api = _AccessibleFilesApi();
    addTearDown(connection.dispose);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const FilesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.text('long-file-name-for-selection-testing.md'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.download_outlined), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(
      find.bySemanticsLabel(
        RegExp(
          RegExp.escape(
            AppLocalizations.of(
              tester.element(find.byType(FilesScreen)),
            ).filesDownload,
          ),
        ),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
