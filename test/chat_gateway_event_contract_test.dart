import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/composer_status_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';

void main() {
  group('chat gateway event contract', () {
    late StreamController<GatewayEvent> events;
    late ChatStore chat;
    late ComposerStatusStore composer;

    setUp(() {
      events = StreamController<GatewayEvent>();
      composer = ComposerStatusStore();
      chat = ChatStore()
        ..bindSessionSource(() => 'runtime-a')
        ..bindComposerStatus(composer)
        ..attachEvents(events.stream);
    });

    tearDown(() async {
      chat.dispose();
      composer.dispose();
      await events.close();
    });

    Future<void> emit(String type, Map<String, dynamic> payload) async {
      events.add(
        GatewayEvent(type: type, payload: payload, sessionId: 'runtime-a'),
      );
      await Future<void>.delayed(Duration.zero);
    }

    test('tool progress updates the running tool row', () async {
      await emit('message.start', const {});
      await emit('tool.start', const {'tool_id': 't1', 'name': 'terminal'});
      await emit('tool.progress', const {
        'tool_id': 't1',
        'name': 'terminal',
        'message': '正在安装依赖',
      });

      final tool = chat.streamingMessage!.parts.singleWhere(
        (part) => part.kind == 'tool',
      );
      expect(tool.tool!['running'], isTrue);
      expect(tool.tool!['summary'], '正在安装依赖');
    });

    test(
      'tool.generating works before a tool id and clears on output',
      () async {
        await emit('message.start', const {});
        await emit('tool.generating', const {'name': 'terminal'});
        expect(chat.statusItems.single.kind, 'tool-drafting');
        expect(chat.statusItems.single.label, contains('terminal'));
        await emit('message.delta', const {'text': 'changed direction'});
        expect(
          chat.statusItems.where((item) => item.kind == 'tool-drafting'),
          isEmpty,
        );
      },
    );

    test('MoA events become visible reasoning and status', () async {
      await emit('moa.aggregating', const {});
      expect(chat.streamingMessage!.parts.single.text, contains('multi-model'));
      expect(chat.statusItems.single.kind, 'moa');
    });

    test('gateway error settles the answer in the timeline', () async {
      await emit('message.start', const {});
      await emit('message.delta', const {'text': '部分回答'});
      await emit('error', const {'message': '模型服务不可用'});

      expect(chat.busy, isFalse);
      expect(chat.isStreaming, isFalse);
      expect(chat.messages.last.isError, isTrue);
      expect(chat.messages.last.fullText, contains('模型服务不可用'));
      expect(chat.recoveryJournal.first.summary, '模型服务不可用');
    });

    test(
      'reclaimed is a lifecycle edge and does not leave a running status',
      () async {
        await emit('status.update', const {
          'id': 'provider-wait',
          'kind': 'provider',
          'message': '等待模型容量',
          'state': 'running',
        });
        await emit('session.reclaimed', const {});
        expect(chat.statusItems, isEmpty);
        expect(chat.providerStatus, isNull);
      },
    );

    test('notifications replace by key and clear by key', () async {
      await emit('notification.show', const {
        'key': 'credits.low',
        'message': '额度剩余 25%',
      });
      await emit('notification.show', const {
        'key': 'credits.low',
        'message': '额度剩余 10%',
      });
      expect(chat.notifications.single.label, '额度剩余 10%');
      await emit('notification.clear', const {'key': 'credits.low'});
      expect(chat.notifications, isEmpty);
    });

    test('live agent reaction merges into the persisted message row', () async {
      chat.loadHistory([
        ChatMessage(
          id: 'm1',
          role: 'user',
          rowId: 7,
          parts: [ChatPart.text('hello')],
        ),
      ], hasMore: false);
      await emit('message.reaction', const {
        'row_id': 7,
        'reactions': [
          {'emoji': '👍', 'author': 'agent', 'at': 1},
        ],
      });
      expect(chat.messages.single.reactions.single.emoji, '👍');
      expect(chat.messages.single.reactions.single.author, 'agent');
    });

    test('provider wait and compaction settle on stream edges', () async {
      await emit('thinking.delta', const {'text': '等待提供商容量'});
      await emit('status.update', const {
        'kind': 'compacting',
        'text': '正在压缩上下文',
      });
      expect(
        chat.statusItems.map((item) => item.kind),
        containsAll(<String>['provider', 'compacting']),
      );
      await emit('message.start', const {});
      expect(
        chat.statusItems.map((item) => item.kind),
        isNot(contains('compacting')),
      );
      expect(chat.providerStatus, isNull);
    });

    test(
      'mid-turn output settles compaction without a new message.start',
      () async {
        await emit('message.start', const {});
        await emit('status.update', const {
          'id': 'compact-1',
          'kind': 'compacting',
          'text': '正在压缩上下文',
        });
        await emit('tool.start', const {'tool_id': 't1', 'name': 'terminal'});
        expect(
          chat.statusItems.where((item) => item.kind == 'compacting'),
          isEmpty,
        );
      },
    );

    test('clarify and tool start coalesce in either arrival order', () async {
      for (final clarifyFirst in [true, false]) {
        await emit('message.start', const {});
        final ordered = clarifyFirst
            ? const [
                ('clarify.request', {'request_id': 'c1', 'question': '选择'}),
                ('tool.start', {'tool_id': 'c1', 'name': 'clarify'}),
              ]
            : const [
                ('tool.start', {'tool_id': 'c1', 'name': 'clarify'}),
                ('clarify.request', {'request_id': 'c1', 'question': '选择'}),
              ];
        for (final event in ordered) {
          await emit(event.$1, event.$2);
        }
        final matching = chat.streamingMessage!.parts.where(
          (part) =>
              part.interaction?['request_id'] == 'c1' ||
              part.tool?['tool_id'] == 'c1',
        );
        expect(matching, hasLength(1));
        expect(matching.single.kind, 'interaction');
      }
    });

    test('subagent spawn request creates attributed activity', () async {
      await emit('subagent.spawn_requested', const {
        'subagent_id': 'child-1',
        'task': '检查测试',
      });
      final status = composer.itemsFor('runtime-a').single;
      expect(status.type, ComposerStatusType.subagent);
      expect(status.state, ComposerStatusState.running);
      expect(chat.streamingMessage!.parts.single.kind, 'subagent');
    });

    test('interactive requests become durable timeline parts', () async {
      await emit('message.start', const {});
      await emit('clarify.request', const {
        'request_id': 'clarify-1',
        'question': '选择环境',
      });
      final interaction = chat.streamingMessage!.parts.singleWhere(
        (part) => part.kind == 'interaction',
      );
      expect(interaction.interaction!['request_id'], 'clarify-1');
      expect(interaction.interaction!['event_type'], 'clarify.request');
    });

    test(
      'interim survives a chained message.start without text duplication',
      () async {
        await emit('message.start', const {});
        await emit('message.delta', const {'text': '草稿'});
        await emit('message.interim', const {'text': '阶段结论'});
        await emit('message.start', const {});
        await emit('message.complete', const {'text': '最终结论'});

        expect(
          chat.messages
              .where((message) => message.interim)
              .map((message) => message.fullText),
          ['阶段结论'],
        );
        expect(
          chat.messages.where((message) => message.fullText == '最终结论'),
          hasLength(1),
        );
      },
    );

    test('sudo and secret requests are handled as interactive', () async {
      await emit('message.start', const {});
      await emit('sudo.request', const {
        'request_id': 'sudo-1',
        'title': '需要提权',
      });
      await emit('secret.request', const {
        'request_id': 'secret-1',
        'title': '需要凭据',
      });
      final interactions = chat.streamingMessage!.parts
          .where((part) => part.kind == 'interaction')
          .toList();
      expect(interactions, hasLength(2));
      expect(interactions[0].interaction!['event_type'], 'sudo.request');
      expect(interactions[1].interaction!['event_type'], 'secret.request');
    });

    test('interactive expire marks the matching request expired', () async {
      await emit('message.start', const {});
      await emit('clarify.request', const {
        'request_id': 'clarify-1',
        'question': '选择环境',
      });
      await emit('interactive.expire', const {'request_id': 'clarify-1'});
      final interaction = chat.streamingMessage!.parts.singleWhere(
        (part) => part.kind == 'interaction',
      );
      expect(interaction.interaction!['status'], 'expired');
    });

    test('browser progress becomes a browser status item', () async {
      await emit('browser.progress', const {
        'tool_id': 'b1',
        'url': 'https://example.com',
        'status': 'navigating',
      });
      expect(chat.statusItems.single.kind, 'browser');
      expect(chat.statusItems.single.state, 'navigating');
    });

    test('preview restart events surface progress then completion', () async {
      final notices = <ChatStatusItem>[];
      final sub = chat.notificationEvents.listen(notices.add);
      addTearDown(sub.cancel);
      await emit('preview.restart.progress', const {
        'task_id': 'pr-1',
        'text': '正在重启预览',
      });
      expect(chat.statusItems.single.state, 'running');
      await emit('preview.restart.complete', const {'task_id': 'pr-1'});
      expect(chat.statusItems, isEmpty);
      expect(notices.single.state, 'completed');
    });

    test(
      'background complete surfaces a notification, not stack work',
      () async {
        final notices = <ChatStatusItem>[];
        final sub = chat.notificationEvents.listen(notices.add);
        addTearDown(sub.cancel);
        await emit('background.complete', const {
          'task_id': 'bg-1',
          'text': '后台分析完成',
        });
        expect(chat.statusItems, isEmpty);
        expect(notices.single.kind, 'background');
        expect(notices.single.state, 'completed');
      },
    );
  });

  test('GatewayEvent preserves authoritative envelope profile', () {
    final event = GatewayEvent.fromFrame({
      'method': 'event',
      'params': {
        'type': 'session.info',
        'session_id': 'runtime-a',
        'profile': 'work',
        'payload': {'profile': 'wrong', 'title': 'A'},
      },
    });
    expect(event.profile, 'work');
    expect(event.sessionId, 'runtime-a');
  });

  test(
    'routed background runtime/profile events cannot mutate foreground',
    () async {
      final controller = StreamController<RoutedGatewayEvent>();
      final chat = ChatStore()
        ..bindSessionSource(() => 'runtime-a')
        ..bindProfileSource(() => 'work')
        ..bindOwnerRouteSource(
          () => const OwnerRoute(
            connectionId: ConnectionId('local'),
            profile: 'work',
          ),
        )
        ..attachRoutedEvents(controller.stream);
      addTearDown(chat.dispose);
      addTearDown(controller.close);

      void route(GatewayEvent event, {String connection = 'local'}) {
        controller.add(
          RoutedGatewayEvent(
            route: OwnerRoute(connectionId: ConnectionId(connection)),
            socketGeneration: 1,
            event: event,
          ),
        );
      }

      route(
        GatewayEvent(
          type: 'message.delta',
          payload: const {'text': 'wrong runtime'},
          sessionId: 'runtime-b',
          profile: 'work',
        ),
      );
      route(
        GatewayEvent(
          type: 'message.delta',
          payload: const {'text': 'wrong profile'},
          sessionId: 'runtime-a',
          profile: 'personal',
        ),
      );
      route(
        GatewayEvent(
          type: 'message.delta',
          payload: const {'text': 'wrong connection'},
          sessionId: 'runtime-a',
          profile: 'work',
        ),
        connection: 'remote',
      );
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages, isEmpty);

      route(
        GatewayEvent(
          type: 'message.delta',
          payload: const {'text': 'foreground'},
          sessionId: 'runtime-a',
          profile: 'work',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(chat.streamingMessage!.fullText, 'foreground');
    },
  );

  group('unscoped stream owner pinning', () {
    late StreamController<RoutedGatewayEvent> controller;
    late ChatStore chat;
    var runtime = 'runtime-a';
    var profile = 'work';
    var connection = 'local';

    void route(String type, Map<String, dynamic> payload, {String? on}) {
      controller.add(
        RoutedGatewayEvent(
          route: OwnerRoute(connectionId: ConnectionId(on ?? connection)),
          socketGeneration: 1,
          event: GatewayEvent(type: type, payload: payload),
        ),
      );
    }

    setUp(() {
      controller = StreamController<RoutedGatewayEvent>();
      chat = ChatStore()
        ..bindSessionSource(() => runtime)
        ..bindProfileSource(() => profile)
        ..bindOwnerRouteSource(
          () => OwnerRoute(
            connectionId: ConnectionId(connection),
            profile: profile,
          ),
        )
        ..activateRuntime(runtime, profile: profile, connectionId: connection)
        ..attachRoutedEvents(controller.stream);
    });

    tearDown(() async {
      chat.dispose();
      await controller.close();
    });

    test('switching session cannot steal an unscoped turn', () async {
      route('message.start', const {});
      await Future<void>.delayed(Duration.zero);
      runtime = 'runtime-b';
      chat.activateRuntime(runtime, profile: profile, connectionId: connection);
      route('message.delta', const {'text': 'belongs to A'});
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages, isEmpty);

      runtime = 'runtime-a';
      chat.activateRuntime(runtime, profile: profile, connectionId: connection);
      expect(chat.streamingMessage!.fullText, 'belongs to A');
    });

    test('switching profile cannot steal an unscoped turn', () async {
      route('message.start', const {});
      await Future<void>.delayed(Duration.zero);
      runtime = 'runtime-b';
      profile = 'personal';
      chat.activateRuntime(runtime, profile: profile, connectionId: connection);
      route('message.delta', const {'text': 'work result'});
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages, isEmpty);

      runtime = 'runtime-a';
      profile = 'work';
      chat.activateRuntime(runtime, profile: profile, connectionId: connection);
      expect(chat.streamingMessage!.fullText, 'work result');
    });

    test('switching connection cannot steal an unscoped turn', () async {
      route('message.start', const {}, on: 'local');
      await Future<void>.delayed(Duration.zero);
      runtime = 'runtime-b';
      connection = 'remote';
      chat.activateRuntime(runtime, profile: profile, connectionId: connection);
      route('message.delta', const {'text': 'local result'}, on: 'local');
      route('message.complete', const {'text': 'local done'}, on: 'local');
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages, isEmpty);

      runtime = 'runtime-a';
      connection = 'local';
      chat.activateRuntime(runtime, profile: profile, connectionId: connection);
      expect(chat.messages.last.fullText, 'local done');
    });

    test('unscoped subagent events are rejected', () async {
      route('subagent.text', const {'text': 'orphan'});
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages, isEmpty);
    });
  });

  test('MCP setup and batch clarify payloads are preserved', () {
    final requests = RequestStore();
    addTearDown(requests.dispose);
    final controller = StreamController<GatewayEvent>();
    addTearDown(controller.close);
    requests.attachEvents(controller.stream);

    controller.add(
      GatewayEvent(
        type: 'mcp.setup.request',
        payload: const {
          'request_id': 'm1',
          'server': 'github',
          'action': 'install',
        },
        sessionId: 'runtime-a',
      ),
    );
    controller.add(
      GatewayEvent(
        type: 'clarify.request',
        payload: const {
          'request_id': 'c1',
          'questions': [
            {
              'id': 'q1',
              'question': '选择环境',
              'choices': ['测试', '生产'],
            },
          ],
        },
        sessionId: 'runtime-a',
      ),
    );

    return Future<void>.delayed(Duration.zero).then((_) {
      expect(requests.pendingCount, 2);
      expect(requests.current!.kind, RequestKind.mcpSetup);
      requests.dismissCurrent();
      expect(requests.current!.questions.single.question, '选择环境');
    });
  });
}
