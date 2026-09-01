import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage: opening a chat with a long, variable-height history
/// (rich text + tool-call groups) used to land the initial "scroll to
/// bottom" short of the true end — Flutter's sliver list only discovers an
/// item's real extent once it's actually laid out, so a single
/// `jumpTo(maxScrollExtent)` right on entry jumps to an ESTIMATE, not the
/// true bottom. The reported symptom: the transcript looks blank/short
/// until the user manually drags the screen, which forces a relayout that
/// corrects the estimate. `_settleInitialScrollToBottom` re-checks across a
/// few more frames and jumps again while the estimate is still growing, so
/// entry alone should settle it — no manual drag needed.
///
/// Caveat: `pumpAndSettle` keeps pumping frames until nothing is scheduled,
/// which already drives even a single unguarded `jumpTo` to the right spot
/// in this synchronous test harness — this test does NOT actually fail
/// without `_settleInitialScrollToBottom` (verified), so it locks in the
/// end-state invariant (entry lands on the true bottom) rather than proving
/// the fix's specific mechanism. The real bug is a real-device frame-
/// scheduling gap this harness can't reproduce: nothing else requests a
/// follow-up frame once the first, estimate-based `jumpTo` completes, so a
/// single miss just stays missed until a user gesture requests one.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => const {};

  @override
  Future<ProfilesPayload> listProfiles() async =>
      const ProfilesPayload(profiles: [], active: null, source: 'local');

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => const [];

  @override
  Future<String> fsDefaultCwd() async => 'D:/work/repo';

  @override
  Future<List<Map<String, dynamic>>> listProjects() async => const [];

  @override
  Future<ComposerDraft> getDraft(String sessionId) async =>
      const ComposerDraft();
}

List<ChatMessage> _longHistory() {
  final messages = <ChatMessage>[];
  for (var turn = 0; turn < 25; turn++) {
    messages.add(
      ChatMessage(
        id: 'u$turn',
        role: 'user',
        parts: [ChatPart.text('第 $turn 轮的问题内容，稍微长一点，用来撑开消息高度。')],
      ),
    );
    messages.add(
      ChatMessage(
        id: 'a$turn',
        role: 'assistant',
        parts: [
          ChatPart.text(
            '第 $turn 轮的回答。' * 6, // varied, non-trivial text height
          ),
          ChatPart.toolCall({
            'tool_id': 't$turn-1',
            'name': 'terminal',
            'running': false,
            'result_text': 'output for turn $turn',
          }),
          ChatPart.toolCall({
            'tool_id': 't$turn-2',
            'name': 'read_file',
            'running': false,
            'args': {'path': 'lib/file_$turn.dart'},
            'result_text': 'file contents $turn',
          }),
        ],
      ),
    );
  }
  return messages;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'entering a long chat settles the scroll on the true bottom message '
    'without a manual drag',
    (tester) async {
      final connection = ConnectionStore()..api = _FakeApi();
      final chat = ChatStore();
      final session = SessionStore(
        connection: connection,
        chat: chat,
        requests: RequestStore(),
      );
      addTearDown(() {
        session.dispose();
        connection.dispose();
      });

      // Mirrors the real entry path: history is fully loaded into the
      // store BEFORE the screen ever mounts (session_list_screen._open
      // awaits resumeSession before pushing ChatScreen).
      chat.loadHistory(_longHistory(), hasMore: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            ChangeNotifierProvider<SessionStore>.value(value: session),
            ChangeNotifierProvider<ChatStore>.value(value: chat),
            ChangeNotifierProvider.value(
              value: VoiceStore(connection: connection),
            ),
            ChangeNotifierProvider.value(
              value: CommandStore(connection: connection),
            ),
            ChangeNotifierProvider(create: (_) => ToolDismissStore()),
          ],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      // Give the settle loop's chained postFrameCallbacks room to run —
      // this is exactly what happens on a real device with no user
      // interaction at all (no simulated drag/scroll gesture below).
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(
        position.pixels,
        closeTo(position.maxScrollExtent, 1),
        reason:
            'the transcript must land on its own true bottom on entry — '
            'stopping short here is exactly the reported "blank until a '
            'manual drag" symptom',
      );
      expect(
        find.textContaining('第 24 轮的回答'),
        findsOneWidget,
        reason:
            'the last turn must actually be built/visible, not just '
            'numerically close in scroll-extent terms',
      );
    },
  );
}
