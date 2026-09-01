import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/transcript_window.dart';

ChatMessage _message(int index, {bool heavy = false}) => ChatMessage(
  id: 'm$index',
  role: index.isEven ? 'user' : 'assistant',
  parts: [
    ChatPart.text(heavy ? '$index ${List.filled(1200, 'x').join()}' : '$index'),
  ],
);

void main() {
  test('prepending older history preserves it and windows the newer tail', () {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    chat.loadHistory([
      for (var index = 100; index < 500; index++) _message(index, heavy: true),
    ], hasMore: true);
    chat.appendOlderHistory([
      for (var index = 0; index < 200; index++) _message(index, heavy: true),
    ], hasMore: false);
    expect(chat.messages.length, lessThan(600));
    expect(chat.messages.first.id, 'm0');
    expect(chat.hasNewerTranscriptWindow, isTrue);

    chat.restoreNewerTranscriptWindow();
    expect(chat.messages.length, lessThan(600));
    expect(chat.messages.last.id, 'm499');
    expect(chat.hasNewerTranscriptWindow, isFalse);
    expect(chat.hasMoreHistory, isTrue);
  });

  test('window is weighted and keeps a sticky anchor within slack', () {
    final messages = [
      for (var index = 0; index < 80; index++)
        _message(index, heavy: index < 20),
    ];
    final selected = selectTranscriptWindow(
      messages,
      budget: 60,
      minimumMessages: 10,
    );
    expect(selected.start, greaterThan(0));

    final withOneMore = [...messages, _message(81)];
    final sticky = selectTranscriptWindow(
      withOneMore,
      budget: 60,
      minimumMessages: 10,
      stickyAnchorId: selected.anchorId,
    );
    expect(sticky.anchorId, selected.anchorId);
  });

  test('ten-thousand-message transcript remains render-budget bounded', () {
    final messages = [
      for (var index = 0; index < 10000; index++) _message(index),
    ];
    final selected = selectTranscriptWindow(messages);
    final visible = messages.length - selected.start;
    expect(visible, lessThan(2000));
    expect(selected.weight, greaterThanOrEqualTo(transcriptWindowBudget));
    expect(selected.anchorId, isNotNull);
  });
}
