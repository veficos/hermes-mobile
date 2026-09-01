import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';

ChatMessage _m(String id, String role, String text, {int? rowId}) =>
    ChatMessage(id: id, role: role, parts: [ChatPart.text(text)], rowId: rowId);

void main() {
  test('no version picker until a turn is superseded', () {
    final chat = ChatStore()
      ..loadHistory([
        _m('u1', 'user', 'question', rowId: 1),
        _m('a1', 'assistant', 'answer one'),
      ], hasMore: false);

    expect(chat.turnVersionCount('1'), 1);
    expect(chat.turnVersionCurrent('1'), 0);
    expect(chat.previewingHistory, isFalse);
  });

  test('rewinding a turn records its superseded tail as a version', () {
    final chat = ChatStore()
      ..loadHistory([
        _m('u1', 'user', 'question', rowId: 1),
        _m('a1', 'assistant', 'answer one'),
      ], hasMore: false);

    chat.rewindToUserMessage('u1', replacementText: 'edited question');

    // One superseded snapshot + the live turn.
    expect(chat.turnVersionCount('1'), 2);
    // Live is shown by default.
    expect(chat.turnVersionCurrent('1'), 1);

    // Selecting the older version overlays the old transcript, read-only.
    chat.selectTurnVersion('1', 0);
    expect(chat.previewingHistory, isTrue);
    expect(chat.turnVersionCurrent('1'), 0);
    expect(chat.messages.map((m) => m.fullText), ['question', 'answer one']);
    expect(chat.previewedVersionText(), 'question');
    expect(chat.previewedAnchorLiveMessage()?.id, 'u1');

    // Selecting the live index clears the preview.
    chat.selectTurnVersion('1', 1);
    expect(chat.previewingHistory, isFalse);
    expect(chat.messages.map((m) => m.fullText).first, 'edited question');
  });

  test(
    'dropLastTurnVersion undoes a recorded version (failed rewind rollback)',
    () {
      final chat = ChatStore()
        ..loadHistory([
          _m('u1', 'user', 'question', rowId: 1),
          _m('a1', 'assistant', 'answer one'),
        ], hasMore: false);

      final snapshot = chat.rewindToUserMessage('u1');
      expect(chat.turnVersionCount('1'), 2);

      chat.restoreSnapshot(snapshot);
      chat.dropLastTurnVersion('1');
      expect(chat.turnVersionCount('1'), 1);
    },
  );

  test('session reset clears version history', () {
    final chat = ChatStore()
      ..loadHistory([
        _m('u1', 'user', 'q', rowId: 1),
        _m('a1', 'assistant', 'a'),
      ], hasMore: false);
    chat.rewindToUserMessage('u1', replacementText: 'q2');
    expect(chat.turnVersionCount('1'), 2);

    chat.resetSession();
    expect(chat.turnVersionCount('1'), 1);
    expect(chat.previewingHistory, isFalse);
  });
}
