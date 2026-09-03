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

    test('standalone vibe reaction emits only ephemeral UI signal', () async {
      expect(chat.vibeBurstRevision, 0);

      await emit('reaction', const {});
      expect(chat.vibeBurstRevision, 1);
      expect(chat.messages, isEmpty);
      expect(chat.streamingMessage, isNull);

      await emit('reaction', const {'kind': 'other'});
      expect(chat.vibeBurstRevision, 1);
    });

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

    test('streaming materialization is reused within one tick', () async {
      await emit('message.start', const {});
      await emit('message.delta', const {'text': 'one'});

      final first = chat.streamingMessage;
      expect(chat.streamingMessage, same(first));
      expect(chat.messages.last, same(first));

      await emit('message.delta', const {'text': ' two'});
      final second = chat.streamingMessage;
      expect(second, isNot(same(first)));
      expect(second!.fullText, 'one two');
    });

    test('streaming structure reads remain stable and zero-copy', () async {
      chat.loadHistory(
        List.generate(
          100,
          (index) => ChatMessage(
            id: 'history-$index',
            role: index.isEven ? 'user' : 'assistant',
            parts: [ChatPart.text('$index')],
          ),
        ),
        hasMore: false,
      );
      await emit('message.start', const {});
      final structure = chat.transcriptStructure;
      await emit('message.delta', const {'text': 'new token'});
      expect(chat.transcriptStructure, same(structure));
      expect(chat.transcriptStructure.last.fullText, isEmpty);
      expect(chat.streamingMessage!.fullText, 'new token');
    });

    test(
      'successful image tool removes an earlier streamed image echo',
      () async {
        await emit('message.start', const {});
        await emit('message.delta', const {
          'text': 'Here it is. ![cat](/sandbox/cat.png)',
        });
        await emit('tool.complete', const {
          'tool_id': 'image-1',
          'name': 'image_generate',
          'result': {
            'success': true,
            'host_image': '/host/cat.png',
            'agent_visible_image': '/sandbox/cat.png',
          },
        });

        final message = chat.streamingMessage!;
        expect(message.fullText, 'Here it is.');
        expect(
          message.parts.where((part) => part.kind == 'tool'),
          hasLength(1),
        );
      },
    );

    test('streamed image echo after a successful tool stays hidden', () async {
      await emit('message.start', const {});
      await emit('tool.complete', const {
        'tool_id': 'image-1',
        'name': 'image_generate',
        'result': {'success': true, 'image': '/host/cat.png'},
      });
      await emit('message.delta', const {
        'text': 'Done. ![cat](/host/cat.png)',
      });

      expect(chat.streamingMessage!.fullText, 'Done.');
    });

    test(
      'authoritative final image echo stays in the tool slot only',
      () async {
        await emit('message.start', const {});
        await emit('tool.complete', const {
          'tool_id': 'image-1',
          'name': 'image_generate',
          'result': {'success': true, 'image': 'https://cdn.invalid/cat.png'},
        });
        await emit('message.complete', const {
          'status': 'complete',
          'text': 'Finished. ![cat](https://cdn.invalid/cat.png)',
        });

        expect(chat.messages.last.fullText, 'Finished.');
        expect(
          chat.messages.last.parts.where((part) => part.kind == 'tool'),
          hasLength(1),
        );
      },
    );

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

    test('structured gateway error survives and disables retry', () async {
      await emit('message.start', const {});
      await emit('error', const {
        'message': 'invalid credentials',
        'error_surface': {
          'layer': 'auth',
          'code': 'invalid_api_key',
          'retryable': false,
          'provider': 'openai',
          'model': 'gpt-5',
        },
      });

      final message = chat.messages.last;
      expect(message.errorSurface?.layer, 'auth');
      expect(message.errorSurface?.retryable, isFalse);
      expect(chat.recoveryJournal.first.retryable, isFalse);
      expect(chat.recoveryJournal.first.errorSurface?.code, 'invalid_api_key');
    });

    test(
      'message.complete preserves whole-turn duration and surface',
      () async {
        chat.loadHistory([
          ChatMessage(
            id: 'u-before-error',
            role: 'user',
            parts: [ChatPart.text('try this')],
          ),
        ], hasMore: false);
        await emit('message.start', const {});
        await emit('message.complete', const {
          'status': 'error',
          'text': 'partial',
          'duration_s': 2.75,
          'error_surface': {
            'layer': 'provider',
            'code': 'overloaded',
            'retryable': true,
          },
        });

        expect(chat.messages.last.durationS, 2.75);
        expect(chat.messages.last.errorSurface?.code, 'overloaded');
        expect(chat.recoveryJournal.first.retryText, isNotNull);
      },
    );

    test(
      'message.complete exposes and clears a structured billing block',
      () async {
        await emit('message.start', const {});
        await emit('message.complete', const {
          'status': 'error',
          'error': 'credit exhausted',
          'billing': {
            'provider': 'openrouter',
            'provider_label': 'OpenRouter',
            'model': 'some-model',
            'billing_url': 'https://openrouter.ai/settings/credits',
            'is_nous': false,
            'message': 'Add credits to continue.\nMore detail',
          },
        });

        expect(chat.billingBlock?.provider, 'openrouter');
        expect(chat.billingBlock?.providerLabel, 'OpenRouter');
        expect(
          chat.billingBlock?.billingUrl.toString(),
          'https://openrouter.ai/settings/credits',
        );
        expect(chat.billingBlock?.isNous, isFalse);

        await emit('message.start', const {});
        expect(chat.billingBlock, isNull);
      },
    );

    test('gateway error also preserves structured billing metadata', () async {
      await emit('error', const {
        'message': 'payment required',
        'billing': {
          'provider': 'nous',
          'provider_label': 'Nous',
          'billing_url': null,
          'is_nous': true,
          'message': 'Top up your account',
        },
      });

      expect(chat.billingBlock?.provider, 'nous');
      expect(chat.billingBlock?.isNous, isTrue);
      chat.dismissBillingBlock();
      expect(chat.billingBlock, isNull);
    });

    test(
      'running=false settles partial output without message.complete',
      () async {
        await emit('message.start', const {});
        await emit('message.delta', const {'text': 'partial answer'});

        final result = chat.applySessionRunning(false);

        expect(result.settled, isTrue);
        expect(result.hadAssistantPayload, isTrue);
        expect(chat.busy, isFalse);
        expect(chat.isStreaming, isFalse);
        expect(chat.messages.last.fullText, 'partial answer');
        expect(chat.messages.last.pending, isFalse);
      },
    );

    test('running=false drops an empty streaming shell', () async {
      await emit('message.start', const {});

      final result = chat.applySessionRunning(false);

      expect(result.settled, isTrue);
      expect(result.hadAssistantPayload, isFalse);
      expect(chat.messages, isEmpty);
      expect(chat.busy, isFalse);
    });

    test(
      'pre-start running=false keeps a newly submitted turn armed',
      () async {
        await chat.submit(() async => const {}, text: 'hello');

        final result = chat.applySessionRunning(false);

        expect(result.settled, isFalse);
        expect(chat.busy, isTrue);
        expect(chat.messages.single.role, 'user');
      },
    );

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

    test('review summary becomes a persistent transcript note', () async {
      await emit('review.summary', const {
        'id': 'review-1',
        'text': '💾 Self-improvement review: Saved a reusable skill',
      });

      expect(chat.statusItems, isEmpty);
      expect(chat.messages, hasLength(1));
      expect(
        chat.messages.single.fullText,
        'review:Self-improvement review: Saved a reusable skill',
      );
      expect(chat.messages.single.role, 'system');

      await emit('review.summary', const {
        'id': 'review-1',
        'text': 'duplicate replay',
      });
      expect(chat.messages, hasLength(1));
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

    test('live reaction binds row id to the newest optimistic role', () async {
      chat.loadHistory([
        ChatMessage(
          id: 'u-live',
          role: 'user',
          parts: [ChatPart.text('hello')],
        ),
      ], hasMore: false);
      await emit('message.reaction', const {
        'row_id': 17,
        'role': 'user',
        'reactions': [
          {'emoji': '❤️', 'author': 'agent', 'at': 2},
        ],
      });

      expect(chat.messages.single.rowId, 17);
      expect(chat.messages.single.reactions.single.emoji, '❤️');
    });

    test('reaction metadata survives live streaming materialization', () async {
      await emit('message.start', const {});
      await emit('message.delta', const {'text': 'answer'});
      await emit('message.reaction', const {
        'row_id': 18,
        'role': 'assistant',
        'reactions': [
          {'emoji': '✨', 'author': 'agent', 'at': 3},
        ],
      });
      await emit('message.delta', const {'text': ' continued'});
      await emit('message.complete', const {'text': 'answer continued'});

      final message = chat.messages.last;
      expect(message.rowId, 18);
      expect(message.reactions.single.emoji, '✨');
    });

    test('optimistic attachment metadata rebuilds retry prompt', () async {
      await chat.submit(
        () async => const <String, dynamic>{},
        text: '@image:/tmp/a.png\n@file:/tmp/a.txt\ncaption',
      );

      final message = chat.messages.single;
      expect(message.fullText, 'caption');
      expect(message.attachmentRefs, ['@image:/tmp/a.png', '@file:/tmp/a.txt']);
      expect(chat.lastUserText(), contains('@image:/tmp/a.png'));
      expect(chat.lastUserText(), endsWith('caption'));
    });

    test('resume projection restores retained failed turn', () {
      chat.loadHistory([
        ChatMessage(
          id: 'stored-user',
          role: 'user',
          parts: [ChatPart.text('same prompt')],
        ),
      ], hasMore: false);
      chat.applyResumeProjection(const {
        'session_id': 'runtime-a',
        'running': false,
        'inflight': {
          'user': 'same prompt',
          'assistant': 'partial answer',
          'streaming': false,
          'error': 'provider disconnected',
          'recoverable': true,
          'error_surface': {
            'layer': 'streaming',
            'code': 'connection_reset',
            'retryable': true,
          },
        },
      }, markBusy: false);

      expect(
        chat.messages.where((message) => message.role == 'user'),
        hasLength(1),
      );
      final assistant = chat.messages.last;
      expect(assistant.fullText, 'partial answer');
      expect(assistant.isError, isTrue);
      expect(assistant.errorSurface?.code, 'connection_reset');
      expect(chat.recoveryJournal.first.retryText, 'same prompt');
    });

    test('resume projection lifts queued attachment refs out of prose', () {
      chat.applyResumeProjection(const {
        'session_id': 'runtime-a',
        'queued': {'user': '@file:/tmp/report.txt\nreview this'},
      }, markBusy: false);

      final queued = chat.messages.single;
      expect(queued.id, 'user-queued-runtime-a');
      expect(queued.fullText, 'review this');
      expect(queued.attachmentRefs, ['@file:/tmp/report.txt']);
      expect(queued.promptText, '@file:/tmp/report.txt\nreview this');
    });

    test('resume projection orders steer corrections by output offsets', () {
      chat.applyResumeProjection(const {
        'session_id': 'runtime-a',
        'running': true,
        'inflight': {
          'user': 'start',
          'assistant': 'before after',
          'streaming': true,
          'corrections': ['change direction'],
          'correction_offsets': [7],
        },
        'queued': {'user': 'next prompt'},
      }, markBusy: true);

      expect(chat.messages.map((message) => message.role), [
        'user',
        'assistant',
        'user',
        'assistant',
        'user',
      ]);
      expect(chat.messages[1].fullText, 'before ');
      expect(chat.messages[1].interim, isTrue);
      expect(chat.messages[3].fullText, 'after');
      expect(chat.messages[3].pending, isTrue);
      expect(chat.busy, isTrue);
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

    test(
      'compacted and process updates do not leave fake running rows',
      () async {
        await emit('status.update', const {
          'kind': 'compacting',
          'text': '正在压缩上下文',
        });
        expect(
          chat.statusItems.where((item) => item.kind == 'compacting'),
          hasLength(1),
        );

        await emit('status.update', const {
          'kind': 'compacted',
          'text': '压缩完成',
        });
        await emit('status.update', const {
          'kind': 'process',
          'text': '后台进程状态已变化',
        });

        expect(chat.statusItems, isEmpty);
        expect(chat.providerStatus, isNull);
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

    test('subagent progress updates the attributed activity', () async {
      await emit('message.start', const {});
      await emit('subagent.start', const {
        'subagent_id': 'worker-1',
        'goal': 'Audit the protocol',
      });
      await emit('subagent.progress', const {
        'subagent_id': 'worker-1',
        'message': 'Compared 12 event families',
        'progress': 0.75,
      });

      final activity = chat.streamingMessage!.parts.singleWhere(
        (part) => part.kind == 'subagent',
      );
      expect(activity.subagent!['event'], 'progress');
      expect(activity.subagent!['message'], 'Compared 12 event families');
      expect(activity.subagent!['progress'], 0.75);
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

    test('continuous final settles onto interim without duplication', () async {
      await emit('message.start', const {});
      await emit('message.delta', const {'text': 'partial'});
      await emit('message.interim', const {'text': 'partial'});
      await emit('message.complete', const {
        'text': 'partial answer continued',
      });

      final matching = chat.messages.where(
        (message) => message.fullText.contains('partial'),
      );
      expect(matching, hasLength(1));
      expect(matching.single.fullText, 'partial answer continued');
      expect(matching.single.interim, isFalse);
    });

    test(
      'already-streamed interim seals and later final stays visible',
      () async {
        await emit('message.start', const {});
        await emit('message.delta', const {'text': 'checking files'});
        await emit('message.interim', const {
          'text': 'checking files',
          'already_streamed': true,
        });
        await emit('message.delta', const {'text': 'second pass'});
        await emit('message.interim', const {
          'text': 'second pass',
          'already_streamed': true,
        });
        await emit('message.complete', const {'text': 'all done'});

        final assistants = chat.messages
            .where(
              (message) =>
                  message.role == 'assistant' && message.fullText.isNotEmpty,
            )
            .toList();
        expect(assistants.map((message) => message.fullText), [
          'checking files',
          'second pass',
          'all done',
        ]);
        expect(assistants.take(2).every((message) => message.interim), isTrue);
        expect(assistants.last.interim, isFalse);
      },
    );

    test('previewed final settles an interim rewrite in place', () async {
      await emit('message.start', const {});
      await emit('message.interim', const {'text': 'draft wording'});
      await emit('message.complete', const {
        'text': 'rewritten final',
        'response_previewed': true,
      });

      final assistants = chat.messages.where(
        (message) => message.role == 'assistant' && message.fullText.isNotEmpty,
      );
      expect(assistants, hasLength(1));
      expect(assistants.single.fullText, 'rewritten final');
      expect(assistants.single.interim, isFalse);
    });

    test('terminal error frame respects partial response semantics', () async {
      await emit('message.start', const {});
      await emit('message.delta', const {'text': 'half an answer'});
      await emit('message.complete', const {
        'status': 'error',
        'text': 'half an answer',
        'error': 'connection reset',
        'partial': true,
      });
      expect(chat.messages.last.fullText, 'half an answer');
      expect(chat.messages.last.isError, isTrue);
      expect(
        chat.recoveryJournal.first.diagnostics,
        contains('connection reset'),
      );

      await emit('message.start', const {});
      await emit('message.delta', const {'text': 'temporary text'});
      await emit('message.complete', const {
        'status': 'error',
        'text': 'temporary text',
        'error': 'invalid model slug',
      });
      expect(chat.messages.last.fullText, 'invalid model slug');
      expect(chat.messages.last.isError, isTrue);
    });

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
