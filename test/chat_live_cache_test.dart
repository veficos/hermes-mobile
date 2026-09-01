import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/gateway.dart';
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
}
