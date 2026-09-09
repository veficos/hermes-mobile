import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/files_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tablet split view: the embedded FileEditorScreen has no route of its own,
/// so PopScope cannot guard it. Tapping another file (or navigating) used to
/// silently destroy unsaved edits; the split view must now confirm first.
class _FilesApi extends ApiClient {
  _FilesApi() : super(baseUrl: 'http://files.invalid', apiKey: 'test');

  final Map<String, String> fileContents = {
    '/workspace/a.txt': 'aaa',
    '/workspace/b.txt': 'bbb',
  };

  @override
  Future<String> fsDefaultCwd() async => '/workspace';

  @override
  Future<Map<String, dynamic>> fsEntries(String path, {String? root}) async =>
      {
        'entries': [
          {
            'name': 'a.txt',
            'path': '/workspace/a.txt',
            'is_directory': false,
            'size': 3,
          },
          {
            'name': 'b.txt',
            'path': '/workspace/b.txt',
            'is_directory': false,
            'size': 3,
          },
        ],
      };

  @override
  Future<String> fsReadText(String path, {String? profile}) async =>
      fileContents[path]!;
}

Future<void> _pumpTablet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final connection = ConnectionStore()..api = _FilesApi();
  addTearDown(connection.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ConnectionStore>.value(
      value: connection,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FilesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switching files with unsaved edits asks before discarding', (
    tester,
  ) async {
    await _pumpTablet(tester);

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    expect(find.text('aaa'), findsOneWidget);

    // Dirty the embedded editor.
    await tester.enterText(find.text('aaa'), 'aaa edited');
    await tester.pump();

    // Tapping another file must confirm instead of silently dropping edits.
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    // Keep editing: selection stays on a.txt with the edits intact.
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('aaa edited'), findsOneWidget);
    expect(find.text('bbb'), findsNothing);

    // Discard: the new file loads.
    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.text('bbb'), findsOneWidget);
  });

  testWidgets('switching files without edits does not ask', (tester) async {
    await _pumpTablet(tester);

    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    expect(find.text('aaa'), findsOneWidget);

    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsNothing);
    expect(find.text('bbb'), findsOneWidget);
  });
}
