import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/screens/files_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chat's workspace picker jumps into the real file manager (rather than
/// only the flat candidate-list sheet) and lets the user confirm whatever
/// directory they've browsed to as the workspace — `FilesScreen(pickMode:
/// true)` is the surface that makes that possible.
class _FilesApi extends ApiClient {
  _FilesApi() : super(baseUrl: 'http://files.invalid', apiKey: 'test');

  @override
  Future<String> fsDefaultCwd() async => '/workspace/default';

  @override
  Future<Map<String, dynamic>> fsEntries(String path, {String? root}) async {
    return {'entries': <Map<String, dynamic>>[]};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'pick mode shows a confirm bar and returns the browsed directory',
    (tester) async {
      final api = _FilesApi();
      final connection = ConnectionStore()..api = api;
      addTearDown(connection.dispose);
      String? popped;

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionStore>.value(
          value: connection,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const FilesScreen(
                        initialPath: '/workspace/custom',
                        pickMode: true,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('选择工作区目录'), findsOneWidget);
      final confirm = find.textContaining('使用「custom」作为工作区');
      expect(confirm, findsOneWidget);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(popped, '/workspace/custom');
      // Back on the caller screen — the pushed FilesScreen popped itself.
      expect(find.text('选择工作区目录'), findsNothing);
    },
  );

  testWidgets('non-pick mode never shows the confirm bar', (tester) async {
    final api = _FilesApi();
    final connection = ConnectionStore()..api = api;
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: const MaterialApp(home: FilesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择工作区目录'), findsNothing);
    expect(find.textContaining('作为工作区'), findsNothing);
  });
}
