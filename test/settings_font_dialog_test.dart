import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/settings_screen.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

class _FontApi extends ApiClient {
  _FontApi() : super(baseUrl: 'http://test.invalid', apiKey: 'test');
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async => {
    'config': {
      'terminal': {'font_family': 'Menlo'},
    },
  };
}

class _FontConnection extends ConnectionStore {
  final _fontApi = _FontApi();
  @override
  ApiClient? get api => _fontApi;
}

void main() {
  testWidgets(
    'Liquid settings font suggestion reset and cancel preserve config',
    (tester) async {
      final connection = _FontConnection();
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionStore>.value(
          value: connection,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesTheme(
              brightness: Brightness.dark,
              visualStyle: HermesVisualStyle.liquid,
            ),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Menlo'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller!.text, 'Menlo');
      await tester.tap(find.widgetWithText(ActionChip, 'Consolas'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'Consolas');
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Menlo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
