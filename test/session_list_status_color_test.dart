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
import 'package:hermes_mobile/screens/session_list_screen.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_mobile_surfaces.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SessionListApi extends ApiClient {
  _SessionListApi(this.rows)
    : super(baseUrl: 'http://session-list.invalid', apiKey: 'test');

  final List<SessionRow> rows;

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    return SessionPage(
      sessions: rows,
      total: rows.length,
      offset: offset,
      hasMore: false,
    );
  }

  @override
  Future<ProjectTreePayload> projectTree({int previewLimit = 3}) async {
    return const ProjectTreePayload(projects: []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    // Prototype parity (`sessionCard()`: archived → gray chip, distinct from
    // completed's green): a plain green chip for archived rows would wrongly
    // read as "active/successful" instead of a neutral, past state.
    '归档会话的状态徽标使用灰色而非与已完成相同的绿色',
    (tester) async {
      final connection = ConnectionStore();
      final now = DateTime.now();
      connection.api = _SessionListApi([
        SessionRow(
          id: 'archived-session',
          title: '已归档的旧会话',
          messageCount: 5,
          startedAt: now,
          archived: true,
        ),
      ]);
      final chat = ChatStore();
      final requests = RequestStore();
      final sessions = SessionStore(
        connection: connection,
        chat: chat,
        requests: requests,
      );
      final appearance = SessionAppearanceStore();
      final voice = VoiceStore(connection: connection);
      final commands = CommandStore(connection: connection);
      final subagents = SubagentStore(connection: connection);
      final pullRequests = PullRequestStore(api: connection.api);
      addTearDown(() {
        sessions.dispose();
        voice.dispose();
        commands.dispose();
        subagents.dispose();
        pullRequests.dispose();
        appearance.dispose();
        requests.dispose();
        chat.dispose();
        connection.dispose();
      });

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
          child: const MaterialApp(home: SessionListScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Archived rows are hidden until the "已归档" filter chip is selected.
      expect(find.text('已归档的旧会话'), findsNothing);
      await tester.tap(find.text('已归档'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('已归档的旧会话'), findsOneWidget);
      final chip = tester.widget<HermesMobileStatusChip>(
        find.byType(HermesMobileStatusChip),
      );
      expect(chip.label, '已归档');
      final dark =
          Theme.of(
            tester.element(find.byType(HermesMobileStatusChip)),
          ).brightness ==
          Brightness.dark;
      expect(chip.color, dark ? HermesSemanticDark.gray : HermesSemantic.gray);
    },
  );
}
