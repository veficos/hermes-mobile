import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ChatMessage _message(String id, String role, String text) =>
    ChatMessage(id: id, role: role, parts: [ChatPart.text(text)]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('slash status transitions in place from running to completed', () {
    final chat = ChatStore();
    final id = chat.appendSlashStatus('/status', '正在执行…', pending: true);

    expect(chat.messages, hasLength(1));
    expect(chat.messages.single.pending, isTrue);
    expect(chat.messages.single.fullText, 'slash:/status\n正在执行…');

    chat.completeSlashStatus(id, 'Session ready');
    expect(chat.messages, hasLength(1));
    expect(chat.messages.single.pending, isFalse);
    expect(chat.messages.single.fullText, 'slash:/status\nSession ready');
    expect(chat.messages.single.source, 'slash');
  });

  test('slash status persists and restores for its durable session', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ChatStore();
    first.bindDurableSessionSource(() => 'sid-1');
    final id = first.appendSlashStatus('/status', '正在执行…', pending: true);
    first.completeSlashStatus(id, 'ready');
    await Future<void>.delayed(Duration.zero);

    final restored = ChatStore();
    restored.bindDurableSessionSource(() => 'sid-1');
    await restored.restoreSlashStatuses('sid-1');
    expect(restored.messages.single.fullText, 'slash:/status\nready');
    expect(restored.messages.single.pending, isFalse);
  });

  test('branch count follows desktop copyable user/assistant spine', () {
    final messages = [
      _message('u1', 'user', 'question one'),
      _message('tool', 'tool', 'raw tool row'),
      _message('system', 'system', 'system note'),
      _message('blank', 'assistant', '   '),
      _message('a1', 'assistant', 'answer one'),
      _message('u2', 'user', 'question two'),
      _message('a2', 'assistant', 'answer two'),
    ];

    expect(branchMessageCount(messages, throughMessageId: 'a1'), 2);
    expect(branchMessageCount(messages, throughMessageId: 'u2'), 3);
    expect(branchMessageCount(messages), 4);
    expect(visibleUserOrdinal(messages, 'u1'), 0);
    expect(visibleUserOrdinal(messages, 'u2'), 1);
    expect(userTurnForMessage(messages, 'a1')?.id, 'u1');
    expect(userTurnForMessage(messages, 'a2')?.id, 'u2');
    expect(userTurnForMessage(messages, 'a1')?.fullText, 'question one');
  });

  test('userTurnForMessage skips scaffolding between prompt and answer', () {
    final messages = [
      _message('u1', 'user', 'topic question'),
      _message('tool', 'tool', 'tool row'),
      _message('blank', 'assistant', '   '),
      _message('a1', 'assistant', 'answer one'),
    ];
    expect(userTurnForMessage(messages, 'a1')?.id, 'u1');
  });

  test('userTurnForMessage crosses persisted assistant tool-loop rows', () {
    final messages = [
      _message('u1', 'user', 'topic question'),
      _message('a-tool', 'assistant', 'Calling search'),
      _message('tool', 'tool', 'search result'),
      _message('a1', 'assistant', 'final answer'),
    ];
    expect(userTurnForMessage(messages, 'a1')?.id, 'u1');
  });

  test('userTurnForMessage does not cross a completed prior answer', () {
    final messages = [
      _message('u1', 'user', 'old topic'),
      _message('a0', 'assistant', 'old answer'),
      _message('u2', 'user', 'new topic'),
      _message('a1', 'assistant', 'new answer'),
    ];
    expect(userTurnForMessage(messages, 'a1')?.id, 'u2');
    expect(userTurnForMessage(messages, 'a0')?.id, 'u1');
  });

  test('REST history preserves raw row id and branch ordinal', () {
    final messages = ChatStore().fromSessionMessages([
      {
        'id': 2442,
        'history_ordinal': 17,
        'role': 'user',
        'content': 'continue here',
      },
    ]);

    expect(messages.single.id, 'h-2442');
    expect(messages.single.rowId, 2442);
    expect(messages.single.historyOrdinal, 17);
  });

  test('first-turn rewind confirms an intentional empty truncation', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    await runChatRewind(
      request: (method, params) async {
        calls.add((method, params));
        return {};
      },
      sessionId: 'runtime-1',
      text: 'edited first question',
      ordinal: 0,
      interruptFirst: false,
    );

    expect(calls.single.$1, 'prompt.submit');
    expect(calls.single.$2, {
      'session_id': 'runtime-1',
      'text': 'edited first question',
      'confirm_truncate': true,
      'truncate_before_user_ordinal': 0,
      'confirm_empty_truncate': true,
    });
  });

  test(
    'rewind prefers stable history row id over a window-local ordinal',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      await runChatRewind(
        request: (method, params) async {
          calls.add((method, params));
          return {};
        },
        sessionId: 'runtime-1',
        text: 'regenerate this',
        ordinal: 0,
        rowId: 2442,
        interruptFirst: false,
      );

      expect(calls.single.$2['truncate_before_row_id'], 2442);
      expect(calls.single.$2, isNot(contains('truncate_before_user_ordinal')));
      expect(calls.single.$2['confirm_empty_truncate'], isTrue);
    },
  );

  test('busy rewind interrupts and retries the same truncation once', () async {
    final methods = <String>[];
    var submits = 0;
    await runChatRewind(
      request: (method, params) async {
        methods.add(method);
        if (method == 'prompt.submit' && submits++ == 0) {
          throw GatewayException(-32000, 'session busy');
        }
        return {};
      },
      sessionId: 'runtime-1',
      text: 'retry me',
      ordinal: 2,
      interruptFirst: false,
    );

    expect(methods, ['prompt.submit', 'session.interrupt', 'prompt.submit']);
  });
}
