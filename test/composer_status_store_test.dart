import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/composer_status_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_en.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/l10n/runtime_l10n.dart';

class _FakeRpc implements ComposerStatusRpc {
  var listCalls = <String>[];
  var killCalls = <(String, String)>[];
  List<GatewayProcessEntry> nextProcesses = const [];
  Exception? listError;
  Exception? killError;

  @override
  Future<List<Map<String, dynamic>>> listBackgroundProcesses(
    String sessionId,
  ) async {
    listCalls.add(sessionId);
    if (listError != null) throw listError!;
    return nextProcesses
        .map(
          (e) => <String, dynamic>{
            'session_id': e.sessionId,
            'command': e.command,
            'status': e.status,
            'exit_code': e.exitCode,
            'output_tail': e.outputTail,
          },
        )
        .toList();
  }

  @override
  Future<void> killBackgroundProcess(String sessionId, String processId) async {
    killCalls.add((sessionId, processId));
    if (killError != null) throw killError!;
  }
}

ComposerStatusItem _findItem(
  ComposerStatusStore store,
  String sessionId,
  String id,
) => store.itemsFor(sessionId).firstWhere((item) => item.id == id);

void main() {
  setUp(() => RuntimeL10n.use(AppLocalizationsEn()));

  test('background reconcile does not cancel typed lifecycle timers', () async {
    final store = ComposerStatusStore();
    store.upsertStatus(
      's1',
      const ComposerStatusItem(
        id: 'goal:1',
        type: ComposerStatusType.goal,
        state: ComposerStatusState.done,
        title: 'Done goal',
      ),
    );

    store.reconcileBackgroundProcesses('s1', const []);
    await Future<void>.delayed(const Duration(milliseconds: 4100));

    expect(store.itemsFor('s1'), isEmpty);
    store.dispose();
  });

  test('typed statuses are session scoped and ordered like desktop', () {
    final store = ComposerStatusStore();
    addTearDown(store.dispose);
    store.upsertStatus(
      's1',
      const ComposerStatusItem(
        id: 'subagent:1',
        type: ComposerStatusType.subagent,
        state: ComposerStatusState.running,
        title: 'delegate',
      ),
    );
    store.upsertStatus(
      's1',
      const ComposerStatusItem(
        id: 'goal:1',
        type: ComposerStatusType.goal,
        state: ComposerStatusState.running,
        title: 'goal',
      ),
    );
    store.replaceTodos('s1', const [
      ComposerStatusItem(
        id: 'todo:1',
        type: ComposerStatusType.todo,
        state: ComposerStatusState.running,
        title: 'todo',
        todoStatus: 'in_progress',
      ),
    ]);

    expect(store.itemsFor('s1').map((item) => item.type), [
      ComposerStatusType.goal,
      ComposerStatusType.todo,
      ComposerStatusType.subagent,
    ]);
    expect(store.itemsFor('s2'), isEmpty);
    expect(store.hasRunningFor('s1'), isTrue);
  });

  test('reconcile adds running background items', () {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(
        sessionId: 'p1',
        command: 'sleep 10',
        status: 'running',
      ),
    ]);

    final items = store.itemsFor('s1');
    expect(items, hasLength(1));
    expect(items.first.id, 'p1');
    expect(items.first.state, ComposerStatusState.running);
    expect(items.first.title, 'sleep 10');
  });

  test('live agent terminal events append output and close its view', () async {
    final events = StreamController<RoutedGatewayEvent>();
    final store = ComposerStatusStore()..attachRoutedEvents(events.stream);
    addTearDown(store.dispose);
    addTearDown(events.close);
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(
        sessionId: 'p1',
        command: 'long task',
        status: 'running',
        outputTail: 'first',
      ),
    ]);

    events.add(
      RoutedGatewayEvent(
        route: const OwnerRoute(connectionId: ConnectionId('local')),
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'agent.terminal.output',
          sessionId: 's1',
          payload: const {'process_id': 'p1', 'chunk': ' second'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(_findItem(store, 's1', 'p1').output, 'first second');

    events.add(
      RoutedGatewayEvent(
        route: const OwnerRoute(connectionId: ConnectionId('local')),
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'terminal.close',
          sessionId: 's1',
          payload: const {'process_id': 'p1'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.itemsFor('s1'), isEmpty);
  });

  test(
    'ownerless terminal close removes the matching process globally',
    () async {
      final events = StreamController<RoutedGatewayEvent>();
      final store = ComposerStatusStore()..attachRoutedEvents(events.stream);
      addTearDown(store.dispose);
      addTearDown(events.close);
      store.reconcileBackgroundProcesses('s1', const [
        GatewayProcessEntry(
          sessionId: 'p1',
          command: 'task',
          status: 'running',
        ),
      ]);

      events.add(
        RoutedGatewayEvent(
          route: const OwnerRoute(connectionId: ConnectionId('local')),
          socketGeneration: 1,
          event: GatewayEvent(
            type: 'terminal.close',
            payload: const {'process_id': 'p1'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.itemsFor('s1'), isEmpty);
    },
  );

  test('reconcile preserves order and flips status in place', () {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
      GatewayProcessEntry(sessionId: 'p2', command: 'b', status: 'running'),
    ]);

    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'exited'),
      GatewayProcessEntry(sessionId: 'p2', command: 'b', status: 'running'),
    ]);

    final items = store.itemsFor('s1');
    expect(items, hasLength(2));
    expect(items[0].id, 'p1');
    expect(items[0].state, ComposerStatusState.done);
    expect(items[1].id, 'p2');
    expect(items[1].state, ComposerStatusState.running);
  });

  test('reconcile appends new processes', () {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
    ]);
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
      GatewayProcessEntry(sessionId: 'p2', command: 'b', status: 'running'),
    ]);

    final items = store.itemsFor('s1');
    expect(items, hasLength(2));
    expect(items[0].id, 'p1');
    expect(items[1].id, 'p2');
  });

  test('dismissed ids stay gone across reconciles', () {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
    ]);
    store.dismissBackgroundProcess('s1', 'p1');
    expect(store.itemsFor('s1'), isEmpty);

    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
    ]);
    expect(store.itemsFor('s1'), isEmpty);
  });

  test('auto-clear removes finished items after delay', () async {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(
        sessionId: 'p1',
        command: 'a',
        status: 'exited',
        exitCode: 0,
      ),
    ]);
    expect(store.itemsFor('s1'), hasLength(1));

    // Wait just longer than the success linger (4s).
    await Future<void>.delayed(const Duration(milliseconds: 4100));
    expect(store.itemsFor('s1'), isEmpty);
  });

  test('failed items linger longer than successful ones', () async {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(
        sessionId: 'p1',
        command: 'a',
        status: 'exited',
        exitCode: 1,
      ),
    ]);

    // After success linger (4s) but before failure linger (12s).
    await Future<void>.delayed(const Duration(milliseconds: 5000));
    expect(store.itemsFor('s1'), hasLength(1));

    await Future<void>.delayed(const Duration(milliseconds: 7500));
    expect(store.itemsFor('s1'), isEmpty);
  });

  test('dismiss cancels auto-clear timer', () async {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(
        sessionId: 'p1',
        command: 'a',
        status: 'exited',
        exitCode: 0,
      ),
    ]);
    store.dismissBackgroundProcess('s1', 'p1');

    // Wait past the original auto-clear deadline.
    await Future<void>.delayed(const Duration(milliseconds: 4100));
    expect(store.itemsFor('s1'), isEmpty);
    // No exception/timer leak expected.
  });

  test('stopBackgroundProcess kills then dismisses', () async {
    final rpc = _FakeRpc();
    final store = ComposerStatusStore()..bindRpc(rpc);
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
    ]);

    await store.stopBackgroundProcess('s1', 'p1');
    expect(rpc.killCalls, [('s1', 'p1')]);
    expect(store.itemsFor('s1'), isEmpty);
  });

  test('stopBackgroundProcess rethrows and keeps row on failure', () async {
    final rpc = _FakeRpc()..killError = Exception('permission denied');
    final store = ComposerStatusStore()..bindRpc(rpc);
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
    ]);

    await expectLater(
      () => store.stopBackgroundProcess('s1', 'p1'),
      throwsA(isA<Exception>()),
    );
    expect(store.itemsFor('s1'), hasLength(1));
  });

  test('resetSessionBackground kills running and clears rows', () async {
    final rpc = _FakeRpc();
    final store = ComposerStatusStore()..bindRpc(rpc);
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
      GatewayProcessEntry(
        sessionId: 'p2',
        command: 'b',
        status: 'exited',
        exitCode: 0,
      ),
    ]);

    await store.resetSessionBackground('s1');
    await Future<void>.delayed(Duration.zero);

    expect(rpc.killCalls, [('s1', 'p1')]);
    expect(store.itemsFor('s1'), isEmpty);

    // A later reconcile must not resurrect the dismissed ids.
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
      GatewayProcessEntry(
        sessionId: 'p2',
        command: 'b',
        status: 'exited',
        exitCode: 0,
      ),
    ]);
    expect(store.itemsFor('s1'), isEmpty);
  });

  test(
    'refreshBackgroundProcesses calls process.list and reconciles',
    () async {
      final rpc = _FakeRpc()
        ..nextProcesses = const [
          GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
        ];
      final store = ComposerStatusStore()..bindRpc(rpc);

      await store.refreshBackgroundProcesses('s1');
      expect(rpc.listCalls, ['s1']);
      expect(store.itemsFor('s1'), hasLength(1));
    },
  );

  test('refreshBackgroundProcesses swallows list errors', () async {
    final rpc = _FakeRpc()..listError = Exception('socket gone');
    final store = ComposerStatusStore()..bindRpc(rpc);

    await store.refreshBackgroundProcesses('s1');
    expect(rpc.listCalls, ['s1']);
    expect(store.itemsFor('s1'), isEmpty);
  });

  test('completionEvents emits when a process finishes', () async {
    final store = ComposerStatusStore();
    final completions = <ComposerStatusItem>[];
    store.completionEvents.listen(completions.add);

    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
    ]);
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(
        sessionId: 'p1',
        command: 'a',
        status: 'exited',
        exitCode: 0,
      ),
    ]);

    await Future<void>.delayed(Duration.zero);
    expect(completions, hasLength(1));
    expect(completions.first.id, 'p1');
    expect(completions.first.state, ComposerStatusState.done);
  });

  test('itemsFor and hasRunningFor are session-scoped', () {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: 'a', status: 'running'),
    ]);
    store.reconcileBackgroundProcesses('s2', const [
      GatewayProcessEntry(
        sessionId: 'p2',
        command: 'b',
        status: 'exited',
        exitCode: 0,
      ),
    ]);

    expect(store.itemsFor('s1'), hasLength(1));
    expect(store.hasRunningFor('s1'), isTrue);
    expect(store.itemsFor('s2'), hasLength(1));
    expect(store.hasRunningFor('s2'), isFalse);
    expect(store.itemsFor('s3'), isEmpty);
  });

  test('exit codes produce failed state only when non-zero', () {
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(
        sessionId: 'p1',
        command: 'a',
        status: 'exited',
        exitCode: 0,
      ),
      GatewayProcessEntry(
        sessionId: 'p2',
        command: 'b',
        status: 'exited',
        exitCode: 1,
      ),
    ]);

    expect(_findItem(store, 's1', 'p1').state, ComposerStatusState.done);
    expect(_findItem(store, 's1', 'p2').state, ComposerStatusState.failed);
    expect(_findItem(store, 's1', 'p2').exitCode, 1);
  });

  test('empty background command uses the active locale', () {
    RuntimeL10n.use(AppLocalizationsZh());
    final store = ComposerStatusStore();
    store.reconcileBackgroundProcesses('s1', const [
      GatewayProcessEntry(sessionId: 'p1', command: '', status: 'running'),
    ]);

    expect(
      _findItem(store, 's1', 'p1').title,
      AppLocalizationsZh().backgroundProcessFallback,
    );
  });
}
