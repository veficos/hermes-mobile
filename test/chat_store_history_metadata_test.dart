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
    test('lifts persisted image directives into attachment metadata', () {
      final messages = ChatStore().fromSessionMessages(const [
        {
          'id': 11,
          'role': 'user',
          'content': '@image:/tmp/a.png\n[screenshot]\n请检查图片',
        },
        {'id': 12, 'role': 'user', 'content': '@image:/tmp/only.png\n'},
      ]);

      expect(messages, hasLength(2));
      expect(messages.first.fullText, '请检查图片');
      expect(messages.first.attachmentRefs, ['@image:/tmp/a.png']);
      expect(messages.last.fullText, isEmpty);
      expect(messages.last.attachmentRefs, ['@image:/tmp/only.png']);
    });

    test('prefers display_content and restores refs from attached context', () {
      final messages = ChatStore().fromSessionMessages(const [
        {
          'id': 13,
          'role': 'user',
          'content': 'model-only expanded content',
          'display_content':
              'review this\n--- Attached Context ---\n@file:/tmp/a.dart\n--- Context Warnings ---\nignored',
        },
      ]);

      expect(messages.single.fullText, contains('review this'));
      expect(messages.single.fullText, contains('@file:/tmp/a.dart'));
      expect(messages.single.fullText, isNot(contains('model-only')));
      expect(messages.single.fullText, isNot(contains('Context Warnings')));
    });

    test('projects legacy expanded skill scaffolding to the invocation', () {
      final messages = ChatStore().fromSessionMessages(const [
        {
          'role': 'user',
          'content':
              '[IMPORTANT: The user has invoked the "work" skill. The full skill content is loaded below.]\nBODY\nThe user has provided the following instruction alongside the skill invocation: fix it\n\n[Runtime note: x]',
        },
      ]);

      expect(messages.single.fullText, '/work fix it');
    });

    test(
      'hydrates reasoning_details and string display metadata reactions',
      () {
        final messages = ChatStore().fromSessionMessages(const [
          {
            'id': 14,
            'role': 'assistant',
            'content': 'answer',
            'reasoning_details': 'thought process',
            'display_metadata':
                '{"reactions":[{"emoji":"✨","author":"agent","at":4}]}',
          },
        ]);

        expect(messages.single.parts.first.kind, 'reasoning');
        expect(messages.single.parts.first.text, 'thought process');
        expect(messages.single.reactions.single.emoji, '✨');
      },
    );

    test('dedupes repeated prose and generated image echoes', () {
      final messages = ChatStore().fromSessionMessages(const [
        {
          'role': 'assistant',
          'content': 'Done ![generated](https://echo.invalid/image.png)',
          'tool_calls': [
            {
              'id': 'image-1',
              'name': 'image_generate',
              'result':
                  '{"success":true,"image":"https://echo.invalid/image.png"}',
            },
          ],
        },
        {'role': 'assistant', 'content': 'Done'},
      ]);

      final textParts = messages.single.parts
          .where((part) => part.kind == 'text')
          .toList();
      expect(textParts, hasLength(1));
      expect(textParts.single.text, 'Done');
      expect(
        messages.single.parts.where((part) => part.kind == 'tool'),
        hasLength(1),
      );
    });
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
