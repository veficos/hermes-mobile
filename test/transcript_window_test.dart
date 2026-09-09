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
  test('deferred trim never discards the message being read', () {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    chat.loadHistory([
      for (var i = 100; i < 800; i++) _message(i, heavy: true),
    ], hasMore: true);
    chat.appendOlderHistory([
      for (var i = 0; i < 100; i++) _message(i, heavy: true),
    ], hasMore: false, deferTrim: true);
    chat.trimTranscriptWindowIfNeeded(preserveMessageId: 'm650');
    expect(chat.messages.any((message) => message.id == 'm650'), isTrue);
    expect(chat.hasNewerTranscriptWindow, isTrue);
    expect(chat.messages.last.id, 'm650');
  });

  test('newer recovery advances one adjacent page and retains its anchor', () {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    chat.loadHistory([
      for (var i = 100; i < 800; i++) _message(i, heavy: true),
    ], hasMore: true);
    chat.appendOlderHistory([
      for (var i = 0; i < 100; i++) _message(i, heavy: true),
    ], hasMore: false);
    final anchor = chat.messages.last.id;
    final last = int.parse(anchor.substring(1));
    chat.restoreNewerTranscriptWindow(pageSize: 50, preserveMessageId: anchor);
    expect(chat.messages.any((m) => m.id == anchor), isTrue);
    expect(chat.messages.last.id, 'm${last + 50}');
    expect(chat.hasNewerTranscriptWindow, isTrue);
    expect(chat.messages.map((m) => m.id).toSet().length, chat.messages.length);
  });

  test('ID-less pages use absolute raw positions including hidden rows', () {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    final newest = chat.fromSessionMessages([
      {'role': 'user', 'content': 'newer'},
    ], startOffset: 3);
    final older = chat.fromSessionMessages([
      {'role': 'user', 'content': 'first'},
      {'role': 'system', 'content': 'hidden', 'display_kind': 'hidden'},
      {'role': 'user', 'content': 'third'},
    ]);
    chat.loadHistory(newest, hasMore: true);
    chat.appendOlderHistory(older, hasMore: false);
    expect(chat.messages.map((m) => m.id), ['h-0', 'h-2', 'h-3']);
    expect(chat.messages.map((m) => m.fullText), ['first', 'third', 'newer']);
  });

  test('older cached pages remain reachable after restoring the newer end', () {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    chat.loadHistory([
      for (var i = 100; i < 500; i++) _message(i, heavy: true),
    ], hasMore: true);
    chat.appendOlderHistory([
      for (var i = 0; i < 100; i++) _message(i, heavy: true),
    ], hasMore: false);
    for (var round = 0; round < 3; round++) {
      chat.restoreNewerTranscriptWindow();
      expect(chat.messages.last.id, 'm499');
      var pages = 0;
      while (chat.restoreOlderTranscriptWindow(deferTrim: true)) {
        expect(++pages, lessThan(20));
      }
      expect(chat.messages.map((m) => m.id), [
        for (var i = 0; i < 500; i++) 'm$i',
      ]);
      expect(chat.hasMoreHistory, isFalse);
      chat.trimTranscriptWindowIfNeeded();
    }
    chat.clearView();
    expect(chat.hasNewerTranscriptWindow, isFalse);
    expect(chat.restoreOlderTranscriptWindow(), isFalse);
  });

  test('overlapping pages preserve unique IDs and the older boundary', () {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    chat.loadHistory([
      for (var i = 100; i < 500; i++) _message(i, heavy: true),
    ], hasMore: true);
    chat.appendOlderHistory(
      [
        for (var i = 0; i < 200; i++) _message(i, heavy: true),
        _message(0, heavy: true),
      ],
      hasMore: false,
      deferTrim: true,
    );
    expect(chat.messages.length, 500);
    expect(chat.messages.map((m) => m.id).toSet().length, 500);
    chat.trimTranscriptWindowIfNeeded();
    expect(chat.hasNewerTranscriptWindow, isTrue);
    expect(chat.hasMoreHistory, isFalse);
    chat.appendOlderHistory([_message(499)], hasMore: false);
    expect(chat.messages.first.id, 'm0');
    chat.restoreNewerTranscriptWindow();
    expect(chat.messages.map((m) => m.id).toSet().length, chat.messages.length);
  });

  test('viewport snapshots do not mutate underneath an old timeline', () {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    chat.loadHistory([_message(2), _message(3)], hasMore: true);
    final before = chat.transcriptStructure;
    expect(identical(before, chat.transcriptStructure), isTrue);
    chat.appendOlderHistory([_message(0), _message(1)], hasMore: false);
    expect(before.map((message) => message.id), ['m2', 'm3']);
    expect(chat.transcriptStructure.map((message) => message.id), [
      'm0',
      'm1',
      'm2',
      'm3',
    ]);
    expect(() => before.clear(), throwsUnsupportedError);
  });

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

  test(
    'deferTrim skips the window trim until trimTranscriptWindowIfNeeded runs',
    () {
      // Regression for the scroll-to-top jank bug: `chat_screen.dart`'s
      // viewport-preserving restore measures list extent before/after
      // `appendOlderHistory` and assumes the whole delta is the prepend at
      // the front. If a trim *also* silently removes messages from the
      // newer end in that same call, the removed extent partly cancels the
      // inserted extent in that delta and the restore lands the viewport
      // in the wrong place — every load-more near the top of a long
      // transcript, which is exactly "many messages, can't scroll smoothly
      // after reaching the top". `deferTrim: true` must leave the prepend
      // as the only source of extent change; the trim only happens once
      // `trimTranscriptWindowIfNeeded` is called separately.
      final chat = ChatStore();
      addTearDown(chat.dispose);
      chat.loadHistory([
        for (var index = 100; index < 500; index++)
          _message(index, heavy: true),
      ], hasMore: true);

      chat.appendOlderHistory(
        [
          for (var index = 0; index < 200; index++)
            _message(index, heavy: true),
        ],
        hasMore: false,
        deferTrim: true,
      );

      // Overlapping page IDs are deduplicated; no unique message is trimmed.
      expect(chat.messages.length, 500);
      expect(chat.hasNewerTranscriptWindow, isFalse);

      final revisionBeforeTrim = chat.transcriptStructureRevision;
      chat.trimTranscriptWindowIfNeeded();
      expect(chat.transcriptStructureRevision, greaterThan(revisionBeforeTrim));

      // Now it matches the non-deferred behavior from the test above.
      expect(chat.messages.length, lessThan(600));
      expect(chat.messages.first.id, 'm0');
      expect(chat.hasNewerTranscriptWindow, isTrue);
    },
  );

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
