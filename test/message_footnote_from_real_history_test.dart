import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/widgets/message_bubble.dart';

/// End-to-end: a historical assistant message shaped exactly like this
/// backend's real session data (float epoch-seconds timestamp, no
/// per-message `model`/`usage`, session-level model backfilled) must
/// actually render the B8 footnote — not just parse correctly in isolation.
void main() {
  testWidgets(
    'a real-shaped historical message renders time + model in its footnote',
    (tester) async {
      final messages = ChatStore().fromSessionMessages([
        {
          'role': 'user',
          'content': '给我发送一些图片',
          'timestamp': 1787905981.3742456,
        },
        {
          'role': 'assistant',
          'content': '给你生成了 3 张图片。',
          'timestamp': 1787906009.5372214,
        },
      ], sessionModel: 'custom:local-(127.0.0.1:8777)/gpt-5.6-sol');
      final assistant = messages.last;
      expect(assistant.timestamp, isNotNull);
      expect(assistant.model, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(message: assistant, showFooter: true),
            ),
          ),
        ),
      );
      await tester.pump();

      final footnote = find.byKey(const ValueKey('msg-footnote'));
      expect(footnote, findsOneWidget);
      final text = tester.widget<Text>(footnote).data!;
      expect(text, isNotEmpty);
      expect(text, contains('gpt-5.6-sol'));
    },
  );
}
