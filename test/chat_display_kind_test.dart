import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';

void main() {
  test('hidden rows are omitted and display timeline rows are normalized', () {
    final messages = ChatStore().fromSessionMessages(const [
      {
        'id': 1,
        'role': 'system',
        'display_kind': 'hidden',
        'content': 'secret',
      },
      {
        'id': 2,
        'role': 'system',
        'display_kind': 'model_switch',
        'content': 'raw',
      },
      {
        'id': 3,
        'role': 'system',
        'display_kind': 'auto_continue',
        'content': '',
      },
      {
        'id': 4,
        'role': 'system',
        'display_kind': 'async_delegation_complete',
        'display_metadata': '{"task_count":2}',
        'content': '',
      },
    ]);

    expect(messages, hasLength(3));
    expect(messages.map((message) => message.fullText), [
      'Model changed',
      'Interrupted turn continued',
      '2 background agent tasks completed',
    ]);
  });

  test('display rows use system role even when persisted role differs', () {
    final messages = ChatStore().fromSessionMessages(const [
      {
        'id': 5,
        'role': 'assistant',
        'display_kind': 'personality_switch',
        'content': 'raw',
      },
    ]);

    expect(messages.single.role, 'system');
    expect(messages.single.fullText, 'Personality changed');
  });

  test('adjacent assistant rows involving tools merge into one turn', () {
    final messages = ChatStore().fromSessionMessages(const [
      {
        'id': 6,
        'role': 'assistant',
        'content': 'checking',
        'tool_calls': [
          {
            'id': 't1',
            'name': 'terminal',
            'args': {'command': 'pwd'},
          },
        ],
      },
      {'id': 7, 'role': 'tool', 'tool_call_id': 't1', 'content': '/tmp'},
      {'id': 8, 'role': 'assistant', 'content': 'done'},
    ]);

    expect(messages, hasLength(1));
    expect(messages.single.fullText, 'checkingdone');
    expect(
      messages.single.parts.where((part) => part.kind == 'tool'),
      hasLength(1),
    );
  });
}
