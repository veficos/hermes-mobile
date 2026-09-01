import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';

/// Regression coverage for a real broken session: the backend reports
/// `timestamp` as epoch-seconds *float* (`1787905997.51`, not an int), and
/// stores `model`/`usage` on the session, not per-message. Before this fix,
/// `fromSessionMessages` produced a `ChatMessage` with a null timestamp
/// (the old `ts is int` check never matched a double), a null model, and a
/// null usage map — so the B8 footnote had nothing to show at all for any
/// replayed historical message.
void main() {
  group('fromSessionMessages history metadata', () {
    test('parses a float epoch-seconds timestamp (real backend shape)', () {
      final messages = ChatStore().fromSessionMessages([
        {'role': 'assistant', 'content': '你好', 'timestamp': 1787905997.51},
      ]);
      final ts = messages.single.timestamp;
      expect(ts, isNotNull);
      expect(ts!.millisecondsSinceEpoch, 1787905997510);
    });

    test('an integer timestamp still parses (backward compat)', () {
      final messages = ChatStore().fromSessionMessages([
        {'role': 'assistant', 'content': 'hi', 'timestamp': 1700000000},
      ]);
      expect(messages.single.timestamp, isNotNull);
    });

    test('a zero/negative/missing timestamp stays null (no fake time)', () {
      final messages = ChatStore().fromSessionMessages([
        {'role': 'assistant', 'content': 'a', 'timestamp': 0},
        {'role': 'assistant', 'content': 'b'},
      ]);
      expect(messages[0].timestamp, isNull);
      expect(messages[1].timestamp, isNull);
    });

    test('backfills the model from sessionModel when the message has none', () {
      final messages = ChatStore().fromSessionMessages([
        {'role': 'assistant', 'content': '你好'},
      ], sessionModel: 'custom:local/gpt-5.6-sol');
      expect(messages.single.model, 'custom:local/gpt-5.6-sol');
    });

    test('a message with its own model keeps it over sessionModel', () {
      final messages = ChatStore().fromSessionMessages([
        {'role': 'assistant', 'content': '你好', 'model': 'openai/gpt-4o'},
      ], sessionModel: 'custom:local/gpt-5.6-sol');
      expect(messages.single.model, 'openai/gpt-4o');
    });

    test('user messages never get a backfilled model', () {
      final messages = ChatStore().fromSessionMessages([
        {'role': 'user', 'content': '你好'},
      ], sessionModel: 'custom:local/gpt-5.6-sol');
      expect(messages.single.model, isNull);
    });

    test(
      'synthesizes usage.total_tokens from token_count when usage is absent',
      () {
        final messages = ChatStore().fromSessionMessages([
          {'role': 'assistant', 'content': '你好', 'token_count': 128},
        ]);
        expect(messages.single.usage, {'total_tokens': 128});
      },
    );

    test('an explicit usage map is never overridden by token_count', () {
      final messages = ChatStore().fromSessionMessages([
        {
          'role': 'assistant',
          'content': '你好',
          'token_count': 999,
          'usage': {'input_tokens': 10, 'output_tokens': 20},
        },
      ]);
      expect(messages.single.usage, {'input_tokens': 10, 'output_tokens': 20});
    });

    test('no token_count and no usage leaves usage null (no fake data)', () {
      final messages = ChatStore().fromSessionMessages([
        {'role': 'assistant', 'content': '你好'},
      ]);
      expect(messages.single.usage, isNull);
    });
  });
}
