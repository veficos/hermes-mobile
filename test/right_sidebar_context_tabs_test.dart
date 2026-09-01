import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/preview_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/mcp_logs_screen.dart';
import 'package:hermes_mobile/widgets/right_sidebar/right_sidebar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SidebarApi extends ApiClient {
  _SidebarApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int logCalls = 0;

  @override
  Future<List<ArtifactItem>> artifacts({
    String? sessionId,
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<dynamic> getLogs({
    String file = 'agent',
    int lines = 200,
    String? level,
    String? component,
    String? search,
  }) async {
    logCalls++;
    return {
      'lines': ['real server log line'],
    };
  }
}

class _SidebarSession extends SessionStore {
  _SidebarSession({
    required super.connection,
    required super.chat,
    required super.requests,
  });

  @override
  String? get durableId => 'session-1';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('active right sidebar exposes artifacts and real server logs', (
    tester,
  ) async {
    final api = _SidebarApi();
    final connection = ConnectionStore()..api = api;
    final chat = ChatStore();
    final requests = RequestStore();
    final session = _SidebarSession(
      connection: connection,
      chat: chat,
      requests: requests,
    );
    final preview = PreviewStore(connection);
    addTearDown(() {
      preview.dispose();
      session.dispose();
      requests.dispose();
      chat.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<SessionStore>.value(value: session),
          ChangeNotifierProvider<PreviewStore>.value(value: preview),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: RightSidebar(initialTab: RightSidebarTab.artifacts),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artifacts'), findsOneWidget);
    expect(find.text('No artifacts yet'), findsOneWidget);

    await tester.drag(find.byType(TabBar), const Offset(-220, 0));
    await tester.pump();
    await tester.tap(find.text('Logs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(McpLogsScreen), findsOneWidget);
    expect(api.logCalls, greaterThan(0));
    expect(find.textContaining('real server log line'), findsOneWidget);
  });
}
