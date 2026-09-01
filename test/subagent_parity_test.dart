import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/session_tree.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/subagent_store.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProjectionApi extends ApiClient {
  _ProjectionApi(this.projection)
    : super(baseUrl: 'http://subagent.invalid', apiKey: 'test');

  SubagentProjection projection;
  int calls = 0;

  @override
  Future<SubagentProjection> subagentProjection() async {
    calls++;
    return projection;
  }
}

class _TestConnectionStore extends ConnectionStore {
  final StreamController<GatewayEvent> eventController =
      StreamController<GatewayEvent>.broadcast();
  final StreamController<void> reconnectController =
      StreamController<void>.broadcast();

  @override
  Stream<GatewayEvent> get events => eventController.stream;

  @override
  Stream<void> get reconnected => reconnectController.stream;

  @override
  void dispose() {
    eventController.close();
    reconnectController.close();
    super.dispose();
  }
}

SessionRow child(String id, String parentId) => SessionRow.fromJson({
  'session_id': id,
  'source': 'subagent',
  'parent_session_id': parentId,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'delegated child requires source and parent and is always read-only',
    () {
      final delegated = SessionRow.fromJson({
        'session_id': 'child',
        'source': 'subagent',
        'parent_session_id': 'parent',
        'is_cli_session': true,
      });
      final missingParent = SessionRow.fromJson({
        'session_id': 'orphan',
        'source': 'subagent',
      });

      expect(delegated.isDelegatedChild, isTrue);
      expect(delegated.readOnly, isTrue);
      expect(delegated.isCliSession, isFalse);
      expect(missingParent.isDelegatedChild, isFalse);
    },
  );

  test('session tree nests delegated children and hides delegated orphans', () {
    final tree = buildSessionTree([
      SessionRow(id: 'parent', title: 'Parent'),
      child('child', 'parent'),
      child('orphan', 'missing'),
    ]);

    expect(tree.map((item) => item.row.id), ['parent', 'child']);
    expect(tree.map((item) => item.depth), [0, 1]);
  });

  test('session tree nests desktop/weixin children regardless of source', () {
    SessionRow typed(String id, String parentId, String source) =>
        SessionRow.fromJson({
          'session_id': id,
          'source': source,
          'parent_session_id': parentId,
        });
    final tree = buildSessionTree([
      SessionRow(id: 'parent', title: 'Parent'),
      typed('desktop-child', 'parent', 'desktop'),
      typed('weixin-child', 'parent', 'weixin'),
      typed('desktop-orphan', 'missing', 'desktop'),
    ]);

    expect(tree.map((item) => item.row.id), [
      'parent',
      'desktop-child',
      'weixin-child',
    ]);
    expect(tree.map((item) => item.depth), [0, 1, 1]);
    // Non-subagent children are NOT forced read-only.
    expect(tree[1].row.readOnly, isFalse);
    expect(tree[2].row.readOnly, isFalse);
  });

  test('gateway event merges params and payload field shapes', () {
    final event = GatewayEvent.fromFrame({
      'params': {
        'type': 'subagent.start',
        'session_id': 'parent',
        'parent_id': 'fallback-parent',
        'payload': {
          'parent_session_id': 'nested-parent',
          'child_session_id': 'child',
        },
      },
    });

    expect(event.sessionId, 'parent');
    expect(event.payload['parent_id'], 'fallback-parent');
    expect(event.payload['parent_session_id'], 'nested-parent');
    expect(event.payload['child_session_id'], 'child');
  });

  test('gateway event accepts a nested payload session id', () {
    final event = GatewayEvent.fromFrame({
      'method': 'event',
      'params': {
        'type': 'message.delta',
        'payload': {'session_id': 'nested-session', 'text': 'hello'},
      },
    });

    expect(event.sessionId, 'nested-session');
    expect(event.payload['text'], 'hello');
  });

  test('SubagentNode never treats parent session_id as child id', () {
    final node = SubagentNode.fromJson({
      'subagent_id': 'agent',
      'session_id': 'parent',
      'child_session_id': 'child',
    });
    final withoutChild = SubagentNode.fromJson({
      'subagent_id': 'agent-2',
      'session_id': 'parent',
    });

    expect(node.sessionId, 'child');
    expect(withoutChild.sessionId, isNull);
  });

  test('user subagent actions fail while disconnected', () async {
    final connection = _TestConnectionStore();
    final store = SubagentStore(connection: connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);

    await expectLater(store.interrupt('child'), throwsStateError);
    await expectLater(store.refreshTree('parent'), throwsStateError);
    await expectLater(store.refreshSessions(['parent']), throwsStateError);
  });

  test(
    'runtime tree deduplicates durable children and reparents out-of-order nodes',
    () async {
      final connection = _TestConnectionStore();
      final api = _ProjectionApi(
        SubagentProjection(
          sessions: [child('durable-child', 'parent-session')],
          bySession: {
            'parent-session': [
              SubagentNode(
                id: 'child-agent',
                parentId: 'parent-agent',
                goal: 'child',
                status: 'running',
              ),
              SubagentNode(
                id: 'parent-agent',
                goal: 'parent',
                sessionId: 'durable-child',
                status: 'running',
              ),
            ],
          },
          total: 2,
        ),
      );
      connection.api = api;
      final store = SubagentStore(connection: connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);

      await store.refreshProjection();

      expect(store.forSession('parent-session').single.id, 'child-agent');
      expect(store.forSession('parent-session').single.sessionId, isNull);
      expect(store.runtimeDescendantCount('parent-session'), 1);
    },
  );

  test(
    'events accept parent fallbacks and sessions.changed/reconnect refresh',
    () async {
      final connection = _TestConnectionStore();
      final api = _ProjectionApi(
        const SubagentProjection(sessions: [], bySession: {}, total: 0),
      );
      connection.api = api;
      final store = SubagentStore(connection: connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);

      connection.eventController.add(
        GatewayEvent.fromFrame({
          'params': {
            'type': 'subagent.start',
            'parent_id': 'parent',
            'subagent_id': 'agent',
            'child_session_id': 'child',
          },
        }),
      );
      await pumpEventQueue();
      expect(store.forSession('parent').single.sessionId, 'child');

      connection.eventController.add(
        GatewayEvent(type: 'sessions.changed', payload: const {}),
      );
      await pumpEventQueue();
      connection.reconnectController.add(null);
      await pumpEventQueue();
      expect(api.calls, 2);
    },
  );

  test(
    'progress/thinking/tool events accumulate a capped, deduped stream',
    () async {
      final connection = _TestConnectionStore();
      final api = _ProjectionApi(
        const SubagentProjection(sessions: [], bySession: {}, total: 0),
      );
      connection.api = api;
      final store = SubagentStore(connection: connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);

      connection.eventController.add(
        GatewayEvent.fromFrame({
          'params': {
            'type': 'subagent.start',
            'parent_id': 'parent',
            'subagent_id': 'agent',
          },
        }),
      );
      await pumpEventQueue();

      connection.eventController.add(
        GatewayEvent.fromFrame({
          'params': {
            'type': 'subagent.progress',
            'parent_id': 'parent',
            'subagent_id': 'agent',
            'text': 'Reading the config file',
          },
        }),
      );
      await pumpEventQueue();

      connection.eventController.add(
        GatewayEvent.fromFrame({
          'params': {
            'type': 'subagent.tool',
            'parent_id': 'parent',
            'subagent_id': 'agent',
            'tool_name': 'read_file',
            'tool_preview': 'config.yaml',
          },
        }),
      );
      await pumpEventQueue();

      final node = store.forSession('parent').single;
      expect(node.stream.map((e) => e.kind), ['progress', 'tool']);
      expect(node.stream[0].text, 'Reading the config file');
      expect(node.stream[1].text, 'Read File("config.yaml")');

      // An exact repeat of the last line is deduped, not appended twice.
      connection.eventController.add(
        GatewayEvent.fromFrame({
          'params': {
            'type': 'subagent.tool',
            'parent_id': 'parent',
            'subagent_id': 'agent',
            'tool_name': 'read_file',
            'tool_preview': 'config.yaml',
          },
        }),
      );
      await pumpEventQueue();
      expect(store.forSession('parent').single.stream, hasLength(2));
    },
  );

  test(
    'a terminal event appends a summary line for the final status',
    () async {
      final connection = _TestConnectionStore();
      final api = _ProjectionApi(
        const SubagentProjection(sessions: [], bySession: {}, total: 0),
      );
      connection.api = api;
      final store = SubagentStore(connection: connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);

      connection.eventController.add(
        GatewayEvent.fromFrame({
          'params': {
            'type': 'subagent.start',
            'parent_id': 'parent',
            'subagent_id': 'agent',
          },
        }),
      );
      await pumpEventQueue();

      connection.eventController.add(
        GatewayEvent.fromFrame({
          'params': {
            'type': 'subagent.complete',
            'parent_id': 'parent',
            'subagent_id': 'agent',
            'status': 'completed',
            'summary': 'Updated 3 files.',
          },
        }),
      );
      await pumpEventQueue();

      final node = store.forSession('parent').single;
      expect(node.status, 'completed');
      expect(node.stream.last.kind, 'summary');
      expect(node.stream.last.text, 'Updated 3 files.');
      expect(node.stream.last.isError, isFalse);
    },
  );

  test('files/tokens/cost accumulate from event payloads', () async {
    final connection = _TestConnectionStore();
    final api = _ProjectionApi(
      const SubagentProjection(sessions: [], bySession: {}, total: 0),
    );
    connection.api = api;
    final store = SubagentStore(connection: connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);

    connection.eventController.add(
      GatewayEvent.fromFrame({
        'params': {
          'type': 'subagent.start',
          'parent_id': 'parent',
          'subagent_id': 'agent',
        },
      }),
    );
    await pumpEventQueue();

    connection.eventController.add(
      GatewayEvent.fromFrame({
        'params': {
          'type': 'subagent.progress',
          'parent_id': 'parent',
          'subagent_id': 'agent',
          'files_read': ['a.py', 'b.py'],
          'files_written': ['c.py'],
          'input_tokens': 120,
          'output_tokens': 45,
          'tool_count': 3,
          'cost_usd': 0.0042,
        },
      }),
    );
    await pumpEventQueue();

    final node = store.forSession('parent').single;
    expect(node.filesRead, ['a.py', 'b.py']);
    expect(node.filesWritten, ['c.py']);
    expect(node.inputTokens, 120);
    expect(node.outputTokens, 45);
    expect(node.toolCount, 3);
    expect(node.costUsd, 0.0042);

    // A later event with no files reported keeps the last-known list rather
    // than clearing it (matches desktop: "filesRead.length ? filesRead :
    // prev?.filesRead ?? []").
    connection.eventController.add(
      GatewayEvent.fromFrame({
        'params': {
          'type': 'subagent.progress',
          'parent_id': 'parent',
          'subagent_id': 'agent',
          'input_tokens': 200,
        },
      }),
    );
    await pumpEventQueue();
    final updated = store.forSession('parent').single;
    expect(updated.filesRead, ['a.py', 'b.py']);
    expect(updated.inputTokens, 200);
  });

  testWidgets('read-only composer disables input and send', (tester) async {
    final controller = TextEditingController(text: 'cannot send');
    addTearDown(controller.dispose);
    var sends = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesComposer(
            controller: controller,
            readOnly: true,
            onSend: (_) => sends++,
          ),
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(find.text('子代理会话为只读'), findsOneWidget);
    final sendInk = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.byIcon(Icons.arrow_upward),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(sendInk.onTap, isNull);
    expect(sends, 0);
  });
}
