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
}
