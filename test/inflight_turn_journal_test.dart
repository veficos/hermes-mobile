import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/chat_message_codec.dart';
import 'package:hermes_mobile/core/inflight_turn_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _writeSnapshot(
  String sessionId,
  List<ChatMessage> messages, {
  String? streamId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'hm_inflight_journal_v1:$sessionId',
    jsonEncode({
      'version': 1,
      'streamId': streamId,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'messages': messages.map(chatMessageToJson).toList(growable: false),
    }),
  );
}

ChatMessage _user(String id, String text) {
  return ChatMessage(id: id, role: 'user', parts: [ChatPart.text(text)]);
}

ChatMessage _assistant(String id, String text, {bool pending = false}) {
  return ChatMessage(
    id: id,
    role: 'assistant',
    parts: [ChatPart.text(text)],
    pending: pending,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'recoverInflightTurnJournal appends uncommitted assistant tail',
    () async {
      const sid = 'sid-1';
      final base = [
        _user('u1', 'hello'),
        _assistant('a1', 'partial reply', pending: true),
      ];
      await _writeSnapshot(sid, [
        _user('u1', 'hello'),
        _assistant('a1', 'partial reply with more text', pending: true),
      ], streamId: 'a1');

      final recovery = await recoverInflightTurnJournal(
        sid,
        base,
        keepPending: true,
      );

      expect(recovery.applied, isTrue);
      expect(recovery.caughtUp, isFalse);
      expect(recovery.streamId, 'a1');
      expect(recovery.messages.length, 2);
      expect(recovery.messages.last.fullText, 'partial reply with more text');
      expect(recovery.messages.last.pending, isTrue);
    },
  );

  test(
    'recoverInflightTurnJournal caughtUp clears journal when tail committed',
    () async {
      const sid = 'sid-2';
      final base = [_user('u1', 'hello'), _assistant('a1', 'done reply')];
      await _writeSnapshot(sid, [
        _user('u1', 'hello'),
        _assistant('a1', 'done reply'),
      ]);

      final recovery = await recoverInflightTurnJournal(sid, base);
      expect(recovery.applied, isFalse);
      expect(recovery.caughtUp, isTrue);

      final snapshot = await readInflightSnapshot(sid);
      expect(snapshot, isNull);
    },
  );

  test('clearInflightTurnJournal removes persisted snapshot', () async {
    const sid = 'sid-3';
    await _writeSnapshot(sid, [
      _user('u1', 'hello'),
      _assistant('a1', 'streaming', pending: true),
    ], streamId: 'a1');

    await clearInflightTurnJournal(sid);
    final snapshot = await readInflightSnapshot(sid);
    expect(snapshot, isNull);
  });

  test('chat codec preserves desktop parity metadata', () {
    final source = ChatMessage(
      id: 'meta',
      role: 'assistant',
      parts: [ChatPart.text('failed')],
      isError: true,
      rowId: 9,
      durationS: 3.25,
      attachmentRefs: const ['@image:/tmp/a.png'],
      errorSurface: const ChatErrorSurface(
        layer: 'provider',
        code: 'overloaded',
        retryable: true,
        provider: 'openai',
        model: 'gpt-5',
      ),
      reactions: const [MessageReaction(emoji: '👍', author: 'agent', at: 1)],
    );

    final decoded = chatMessageFromJson(chatMessageToJson(source));
    expect(decoded.durationS, 3.25);
    expect(decoded.attachmentRefs, source.attachmentRefs);
    expect(decoded.errorSurface?.code, 'overloaded');
    expect(decoded.reactions.single.author, 'agent');
  });
}
