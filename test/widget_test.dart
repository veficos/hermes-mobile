import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chat message text parts assemble from deltas', () {
    final m = MutableAssistantMessage('a1');
    m.appendDelta('Hello ');
    m.appendDelta('world');
    m.finalize('Hello world', 'complete', null);
    expect(m.toChatMessage().fullText, 'Hello world');
  });

  test('transcript pagination prepends older messages', () {
    final chat = ChatStore();
    ChatMessage msg(String id) =>
        ChatMessage(id: id, role: 'user', parts: [ChatPart.text('m')]);
    chat.loadHistory([msg('m2'), msg('m3')], hasMore: true);
    expect(chat.hasMoreHistory, isTrue);
    expect(chat.loadedCount, 2);
    chat.appendOlderHistory([msg('m1')], hasMore: false);
    expect(chat.messages.first.id, 'm1');
    expect(chat.messages.length, 3);
    expect(chat.hasMoreHistory, isFalse);
    // Empty page terminates pagination.
    chat.appendOlderHistory(const [], hasMore: false);
    expect(chat.hasMoreHistory, isFalse);
    expect(chat.messages.length, 3);
  });

  test('agent session rows preserve WebUI management metadata', () {
    final row = SessionRow.fromJson({
      'session_id': 'session-123',
      'title': 'Agent session',
      'source': 'telegram',
      'source_label': 'Telegram',
      'project_id': 'project-7',
      'model': 'gpt-5',
      'model_provider': 'openai',
      'read_only': true,
      'is_cli_session': true,
      'share_token': 'share-token',
      'share_created_at': 1_700_000_000,
      'updated_at': 1_700_000_100,
      'worktree_path': '/tmp/worktree',
      'archived': true,
      'pinned': true,
      'tags': ['release', 'urgent'],
      'content_snippet': '…the matching deployment note…',
      'match_message_id': 'message-42',
    });

    expect(row.id, 'session-123');
    expect(row.displaySource, 'Telegram');
    expect(row.projectId, 'project-7');
    expect(row.provider, 'openai');
    expect(row.readOnly, isTrue);
    expect(row.isCliSession, isTrue);
    expect(row.shareCreatedAt, isNotNull);
    expect(row.lastMessageAt, 1_700_000_100_000);
    expect(row.worktreePath, '/tmp/worktree');
    expect(row.tags, ['release', 'urgent']);
    expect(row.contentSnippet, '…the matching deployment note…');
    expect(row.matchMessageId, 'message-42');
    expect(row.toJson()['share_token'], 'share-token');
  });

  test('file browser entries preserve WebUI filesystem metadata', () {
    final entry = FsEntry.fromJson({
      'name': 'src',
      'path': r'C:\repo\src',
      'type': 'directory',
      'size': 4096,
      'modified_at': 1_700_000_000,
      'readable': true,
      'writable': false,
    });

    expect(entry.isDirectory, isTrue);
    expect(entry.isLink, isFalse);
    expect(entry.size, 4096);
    expect(entry.modifiedAt?.millisecondsSinceEpoch, 1_700_000_000_000);
    expect(entry.readable, isTrue);
    expect(entry.writable, isFalse);
  });

  group('ChatStore delta shapes (F5)', () {
    late StreamController<GatewayEvent> events;
    late ChatStore chat;

    setUp(() {
      events = StreamController<GatewayEvent>();
      chat = ChatStore()..attachEvents(events.stream);
    });
    tearDown(() => events.close());

    Future<void> delta(dynamic text) async {
      events.add(GatewayEvent(type: 'message.delta', payload: {'text': text}));
      await pumpEventQueue();
    }

    test('string delta appends', () async {
      await delta('a');
      await delta('b');
      expect(chat.messages.last.fullText, 'ab');
    });

    test('single-map delta extracts text', () async {
      await delta({'text': 'x'});
      expect(chat.messages.last.fullText, 'x');
    });

    test('list-of-maps delta joins', () async {
      await delta([
        {'text': 'a'},
        {'output_text': 'b'},
        'c',
      ]);
      expect(chat.messages.last.fullText, 'abc');
    });
  });

  group('ChatStore tool merge (F4)', () {
    test('tool.complete preserves args captured at tool.start', () async {
      final events = StreamController<GatewayEvent>();
      final chat = ChatStore()
        ..bindSessionSource(() => 'runtime-a')
        ..attachEvents(events.stream);
      events.add(
        GatewayEvent(
          type: 'tool.start',
          payload: {'tool_id': 't1', 'name': 'shell', 'args_text': 'echo hi'},
        ),
      );
      await pumpEventQueue();
      // tool.complete has no args_text (F4) — the original must survive.
      events.add(
        GatewayEvent(
          type: 'tool.complete',
          payload: {'tool_id': 't1', 'name': 'shell', 'result': 'hi'},
        ),
      );
      await pumpEventQueue();
      final toolPart = chat.messages.last.parts.firstWhere(
        (p) => p.kind == 'tool',
      );
      expect(toolPart.tool?['args_text'], 'echo hi');
      expect(toolPart.tool?['running'], false);
      events.close();
    });

    test('todo tool.complete adds a plan part (HermesPlanCard)', () async {
      final events = StreamController<GatewayEvent>();
      final chat = ChatStore()..attachEvents(events.stream);
      events.add(
        GatewayEvent(
          type: 'tool.complete',
          payload: {
            'tool_id': 't2',
            'name': 'todo',
            'todos': [
              {'id': 'a', 'content': '探索代码', 'status': 'completed'},
              {'id': 'b', 'content': '写实现', 'status': 'in_progress'},
              {'id': 'c', 'content': '跑测试', 'status': 'pending'},
            ],
          },
        ),
      );
      await pumpEventQueue();
      final planPart = chat.messages.last.parts.firstWhere(
        (p) => p.kind == 'plan',
      );
      expect(planPart.plan, isNotNull);
      expect(planPart.plan, hasLength(3));
      expect(planPart.plan!.first['status'], 'completed');
      expect(planPart.plan![1]['status'], 'in_progress');
      events.close();
    });
  });

  test(
    'ChatStore merges subagent lifecycle into one structured timeline part',
    () async {
      final events = StreamController<GatewayEvent>();
      final chat = ChatStore()..attachEvents(events.stream);
      events.add(
        GatewayEvent(
          type: 'subagent.start',
          sessionId: 'runtime-a',
          payload: {
            'subagent_id': 'researcher-1',
            'name': '资料研究员',
            'goal': '整理构建方案',
            'task_index': 1,
            'task_count': 2,
          },
        ),
      );
      await pumpEventQueue();
      events.add(
        GatewayEvent(
          type: 'subagent.tool',
          sessionId: 'runtime-a',
          payload: {'subagent_id': 'researcher-1', 'tool_name': 'web_search'},
        ),
      );
      await pumpEventQueue();
      events.add(
        GatewayEvent(
          type: 'subagent.complete',
          sessionId: 'runtime-a',
          payload: {
            'subagent_id': 'researcher-1',
            'status': 'completed',
            'summary': '已完成整理',
          },
        ),
      );
      await pumpEventQueue();

      final parts = chat.messages.last.parts.where((p) => p.kind == 'subagent');
      expect(parts, hasLength(1));
      final activity = parts.single.subagent!;
      expect(activity['name'], '资料研究员');
      expect(activity['current_tool'] ?? activity['tool_name'], 'web_search');
      expect(activity['status'], 'completed');
      expect(activity['summary'], '已完成整理');
      await events.close();
    },
  );

  group('ChatStore interim (F7)', () {
    test('already_streamed interim seals the visible segment', () async {
      final events = StreamController<GatewayEvent>();
      final chat = ChatStore()..attachEvents(events.stream);
      events.add(
        GatewayEvent(
          type: 'message.interim',
          payload: {'text': 'dup', 'already_streamed': true},
        ),
      );
      await pumpEventQueue();
      expect(chat.messages, hasLength(1));
      expect(chat.messages.single.fullText, 'dup');
      expect(chat.messages.single.interim, isTrue);
      events.add(
        GatewayEvent(type: 'message.interim', payload: {'text': 'new'}),
      );
      await pumpEventQueue();
      expect(chat.messages.length, 2);
      events.close();
    });
  });

  group('ChatStore session filter (F8)', () {
    test('events from another session are dropped', () async {
      final events = StreamController<GatewayEvent>();
      final chat = ChatStore()..attachEvents(events.stream);
      chat.bindSessionSource(() => 'aaa11111');
      events.add(
        GatewayEvent(
          type: 'message.delta',
          sessionId: 'bbb22222',
          payload: {'text': 'stale'},
        ),
      );
      await pumpEventQueue();
      expect(chat.messages, isEmpty);
      events.add(
        GatewayEvent(
          type: 'message.delta',
          sessionId: 'aaa11111',
          payload: {'text': 'fresh'},
        ),
      );
      await pumpEventQueue();
      expect(chat.messages.last.fullText, 'fresh');
      events.close();
    });
  });

  group('RequestStore queue (F6/F10)', () {
    late StreamController<GatewayEvent> events;
    late RequestStore requests;

    setUp(() {
      events = StreamController<GatewayEvent>();
      requests = RequestStore()..attachEvents(events.stream);
    });
    tearDown(() => events.close());

    Future<void> approval(String id) async {
      events.add(
        GatewayEvent(
          type: 'approval.request',
          payload: {
            'request_id': id,
            'choices': ['once', 'deny'],
          },
        ),
      );
      await pumpEventQueue();
    }

    test('second request is queued, not dropped', () async {
      await approval('r1');
      await approval('r2');
      expect(requests.pendingCount, 2);
      expect(requests.current!.requestId, 'r1');
    });

    test('respond failure re-queues at head (F10)', () async {
      await approval('r1');
      try {
        await requests.respond((req) async => throw Exception('boom'));
      } catch (_) {}
      expect(requests.current!.requestId, 'r1');
    });

    test('successful respond drains the queue', () async {
      await approval('r1');
      final ok = await requests.respond((req) async => {});
      expect(ok, true);
      expect(requests.pendingCount, 0);
    });
  });
}
