import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/pull_request_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_appearance_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/subagent_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/session_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PinRecordingApi extends ApiClient {
  _PinRecordingApi(this.rows) : super(baseUrl: 'http://pin-swipe.invalid', apiKey: 'test');

  final List<SessionRow> rows;
  int pinCalls = 0;

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    return SessionPage(sessions: rows, total: rows.length, offset: offset, hasMore: false);
  }

  @override
  Future<void> pinSession(String id, bool pinned, {String? profile}) async {
    pinCalls += 1;
  }

  @override
  Future<ProjectTreePayload> projectTree({int previewLimit = 3}) async {
    return const ProjectTreePayload(projects: []);
  }
}

class _OfflineCommandStore extends CommandStore {
  _OfflineCommandStore({required super.connection});

  @override
  Future<void> loadCatalog() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'swiping a session to pin it does not leave a stuck grey overlay while '
    'the row regroups',
    (tester) async {
      final now = DateTime.now();
      final api = _PinRecordingApi([
        SessionRow(id: 's1', title: 'Unpinned session', startedAt: now),
      ]);
      final connection = ConnectionStore()..api = api;
      final chat = ChatStore();
      final requests = RequestStore();
      final sessions = SessionStore(
        connection: connection,
        chat: chat,
        requests: requests,
      );
      final appearance = SessionAppearanceStore();
      final voice = VoiceStore(connection: connection);
      final commands = _OfflineCommandStore(connection: connection);
      final pullRequests = PullRequestStore(api: api);
      final subagents = SubagentStore(connection: connection);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            ChangeNotifierProvider<ChatStore>.value(value: chat),
            ChangeNotifierProvider<RequestStore>.value(value: requests),
            ChangeNotifierProvider<SessionStore>.value(value: sessions),
            ChangeNotifierProvider<SessionAppearanceStore>.value(
              value: appearance,
            ),
            ChangeNotifierProvider<VoiceStore>.value(value: voice),
            ChangeNotifierProvider<CommandStore>.value(value: commands),
            ChangeNotifierProvider<SubagentStore>.value(value: subagents),
            ChangeNotifierProvider<PullRequestStore>.value(value: pullRequests),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SessionListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unpinned session'), findsOneWidget);
      expect(find.text('置顶'), findsNothing);

      // Swipe right (startToEnd) far enough to trigger confirmDismiss, which
      // always returns false for the pin direction — Dismissible then
      // reverses the row back to rest over `movementDuration` while the
      // pin toggle (and the resulting sliver regroup) is scheduled to land
      // only after that same duration.
      await tester.fling(
        find.byKey(const ValueKey('session-s1')),
        const Offset(500, 0),
        1000,
      );
      await tester.pump();

      // Well before the ~200ms reverse animation (and the matching delayed
      // toggle) finishes: nothing should have thrown, and the row must
      // still be present exactly once — a regression here is what "blanks
      // the viewport" / shows as a stuck grey overlay.
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      expect(find.text('Unpinned session'), findsOneWidget);

      // Let the reverse animation and the pin toggle both settle.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(api.pinCalls, 1);
      expect(find.text('置顶'), findsOneWidget);
      expect(find.text('Unpinned session'), findsOneWidget);
    },
  );
}
