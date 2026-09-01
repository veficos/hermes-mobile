import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/screens/mcp_logs_screen.dart';
import 'package:provider/provider.dart';

/// `McpLogsScreen` polls `getLogs` every 2s for as long as it's mounted —
/// this test avoids `pumpAndSettle` (which would spin forever against a
/// timer that keeps rescheduling itself) and instead drives frames/time
/// manually, popping the screen before advancing past its next poll so the
/// already-scheduled timer fires into the disposed-guard and exits cleanly
/// (no pending-timer teardown failure).
class _LogsApi extends ApiClient {
  _LogsApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int calls = 0;
  String? lastFile;
  String? lastSearch;

  @override
  Future<dynamic> getLogs({
    String file = 'agent',
    int lines = 200,
    String? level,
    String? component,
    String? search,
  }) async {
    calls++;
    lastFile = file;
    lastSearch = search;
    if (file == 'mcp') {
      return {
        'lines': [
          "===== [t] starting MCP server 'filesystem' =====",
          'filesystem: ready',
          "===== [t] starting MCP server 'other' =====",
          'other: ready',
        ],
      };
    }
    return {
      'lines': ['agent log line mentioning filesystem'],
    };
  }
}

void main() {
  testWidgets('shows only the selected server\'s stdio section', (tester) async {
    final api = _LogsApi();
    final connection = ConnectionStore()..api = api;
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const McpLogsScreen(serverName: 'filesystem'),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('filesystem: ready'), findsOneWidget);
    expect(find.textContaining('other: ready'), findsNothing);
    expect(api.lastFile, 'mcp');

    // Pop before the next 2s poll fires; then advance past it so the
    // already-scheduled timer runs into the disposed guard and stops.
    Navigator.of(tester.element(find.text('open'))).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  });
}
