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
import 'package:hermes_mobile/chat/timeline/turn_activity_card.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage: the `ChatTimelineTurnActivity` row (`TurnActivityCard`)
/// used to render with no key at all in the transcript's `ListView.builder`,
/// unlike every sibling timeline-row type (`ChatTimelineToolGroup`,
/// `ChatTimelineChangedFiles`, `ChatTimelineMessage`), which each key by
/// `keyForMessage(...)`/`timeline-row-${item.key}`. Without a key, prepending
/// older messages (pagination on a long transcript) lets ListView's default
/// index-based element reuse reattach a turn-activity Element to a different
/// logical turn at the same list slot — the reported "错屏" when scrolling a
/// transcript with many messages.
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

ChatPart _tool(String id) =>
    ChatPart.toolCall({'tool_id': id, 'name': 'terminal', 'running': false});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'every TurnActivityCard in the transcript carries a non-null key',
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

      // Two distinct assistant turns, each with its own tool count, so each
      // produces its own ChatTimelineTurnActivity with different content
      // ("2 个工具" vs "5 个工具").
      chat.loadHistory([
        ChatMessage(id: 'u1', role: 'user', parts: [ChatPart.text('第一轮')]),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          parts: [ChatPart.text('done 1'), _tool('t1'), _tool('t2')],
        ),
        ChatMessage(id: 'u2', role: 'user', parts: [ChatPart.text('第二轮')]),
        ChatMessage(
          id: 'a2',
          role: 'assistant',
          parts: [
            ChatPart.text('done 2'),
            _tool('t3'),
            _tool('t4'),
            _tool('t5'),
            _tool('t6'),
            _tool('t7'),
          ],
        ),
      ], hasMore: false);

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
      await tester.pump();
      await tester.pump();

      expect(find.text('2 个工具'), findsOneWidget);
      expect(find.text('5 个工具'), findsOneWidget);

      final cards = tester.widgetList<TurnActivityCard>(
        find.byType(TurnActivityCard),
      );
      expect(cards, hasLength(2));
      for (final card in cards) {
        expect(
          card.key,
          isNotNull,
          reason:
              'TurnActivityCard must carry the same timeline-row key as its '
              'sibling row types (ChatTimelineToolGroup/ChangedFiles/Message) '
              'so ListView.builder cannot silently reuse its Element for a '
              'different turn once older messages are prepended.',
        );
      }
      // The two cards must be independently identifiable, not sharing a key.
      expect(cards.first.key, isNot(cards.last.key));
    },
  );
}
