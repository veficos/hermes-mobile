import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';

void main() {
  test(
    'background runtimes assemble independently and restore on activation',
    () async {
      var active = 'a';
      final events = StreamController<GatewayEvent>();
      final chat = ChatStore()
        ..bindSessionSource(() => active)
        ..activateRuntime(active)
        ..attachEvents(events.stream);
      addTearDown(chat.dispose);
      addTearDown(events.close);

      events.add(
        GatewayEvent(type: 'message.start', payload: const {}, sessionId: 'b'),
      );
      events.add(
        GatewayEvent(
          type: 'message.delta',
          payload: const {'text': 'background'},
          sessionId: 'b',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages, isEmpty);

      active = 'b';
      chat.activateRuntime(active);
      expect(chat.streamingMessage?.fullText, 'background');
      expect(chat.busy, isTrue);

      events.add(
        GatewayEvent(
          type: 'message.complete',
          payload: const {'text': 'done'},
          sessionId: 'b',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages.last.fullText, 'done');
    },
  );

  test('background running=false settles its cached partial stream', () async {
    var active = 'a';
    final events = StreamController<GatewayEvent>();
    final chat = ChatStore()
      ..bindSessionSource(() => active)
      ..activateRuntime(active)
      ..attachEvents(events.stream);
    addTearDown(chat.dispose);
    addTearDown(events.close);

    events.add(
      GatewayEvent(type: 'message.start', payload: const {}, sessionId: 'b'),
    );
    events.add(
      GatewayEvent(
        type: 'message.delta',
        payload: const {'text': 'kept partial'},
        sessionId: 'b',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final settled = chat.applyRuntimeRunning('b', false);
    expect(settled.settled, isTrue);

    active = 'b';
    chat.activateRuntime(active);
    expect(chat.busy, isFalse);
    expect(chat.isStreaming, isFalse);
    expect(chat.messages.single.fullText, 'kept partial');
    expect(chat.messages.single.pending, isFalse);
  });

  test('hydrated and live reactions survive switching away and back', () async {
    var active = 'a';
    final events = StreamController<GatewayEvent>();
    final chat = ChatStore()
      ..bindSessionSource(() => active)
      ..activateRuntime(active)
      ..loadHistory([
        ChatMessage(
          id: 'assistant-history',
          role: 'assistant',
          parts: [ChatPart.text('answer')],
          rowId: 41,
          reactions: const [
            MessageReaction(emoji: '👍', author: 'user', at: 1),
          ],
        ),
      ], hasMore: false)
      ..attachEvents(events.stream);
    addTearDown(chat.dispose);
    addTearDown(events.close);

    chat.applyResumeProjection(const {
      'session_id': 'a',
      'inflight': {'assistant': 'partial', 'streaming': true},
    }, markBusy: true);
    events.add(
      GatewayEvent(
        type: 'message.reaction',
        payload: const {
          'row_id': 41,
          'role': 'assistant',
          'reactions': [
            {'emoji': '✨', 'author': 'agent', 'at': 2},
          ],
        },
        sessionId: 'a',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(chat.messages.first.rowId, 41);
    expect(chat.messages.first.reactions.single.emoji, '✨');

    active = 'b';
    chat.activateRuntime(active);
    active = 'a';
    chat.activateRuntime(active);

    expect(chat.messages.first.rowId, 41);
    expect(chat.messages.first.reactions.single.emoji, '✨');
    expect(chat.streamingMessage?.fullText, 'partial');
  });
}
