import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/kanban/models.dart';
import 'package:hermes_mobile/kanban/store.dart';

void main() {
  test('board filtering matches title, assignee, and tenant', () {
    final board = KanbanBoard.fromJson({
      'columns': [
        {
          'name': 'todo',
          'tasks': [
            {
              'id': '1',
              'title': 'Fix mobile',
              'status': 'todo',
              'assignee': 'a',
              'tenant': 'x',
            },
            {
              'id': '2',
              'title': 'Write docs',
              'status': 'todo',
              'assignee': 'b',
              'tenant': 'y',
            },
          ],
        },
      ],
    });
    final tasks = board.tasks
        .where(
          (t) =>
              t.title.toLowerCase().contains('mobile') &&
              t.assignee == 'a' &&
              t.tenant == 'x',
        )
        .toList();
    expect(tasks.map((t) => t.id), ['1']);
  });

  test('task copyWith preserves raw metadata while changing status', () {
    final task = KanbanTask.fromJson({
      'id': '1',
      'title': 'x',
      'status': 'todo',
      'warnings': {'count': 2},
    });
    final moved = task.copyWith(status: 'done');
    expect(moved.status, 'done');
    expect(moved.warnings?['count'], 2);
  });

  test('failed board selection rolls back the previous board slug', () async {
    final api = KanbanApi(_BoardSelectionClient(), boardSlug: 'current');
    final store = KanbanStore(api);
    addTearDown(store.dispose);

    await store.selectBoard('broken');

    expect(api.boardSlug, 'current');
    expect(store.error, contains('cannot load broken'));
  });

  test('disconnected API access reports a readable state error', () {
    final store = KanbanStore();
    addTearDown(store.dispose);

    expect(() => store.api, throwsStateError);
  });

  test(
    'an old connection board response cannot overwrite a new binding',
    () async {
      final oldClient = _DelayedBoardClient('old');
      final newClient = _DelayedBoardClient('new');
      final store = KanbanStore(KanbanApi(oldClient));
      addTearDown(store.dispose);
      final oldLoad = store.load();

      store.bindApi(KanbanApi(newClient));
      newClient.gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(store.boardData?.tasks.single.title, 'new');

      oldClient.gate.complete();
      await oldLoad;
      expect(store.boardData?.tasks.single.title, 'new');
    },
  );

  test(
    'an older load cannot overwrite a newer board on the same API',
    () async {
      final client = _RacingBoardClient();
      final api = KanbanApi(client, boardSlug: 'old');
      final store = KanbanStore(api);
      addTearDown(store.dispose);
      final oldLoad = store.load();

      api.boardSlug = 'new';
      final newLoad = store.load();
      client.gates['new']!.complete();
      await newLoad;
      expect(store.boardData?.tasks.single.title, 'new');

      client.gates['old']!.complete();
      await oldLoad;
      expect(store.boardData?.tasks.single.title, 'new');
    },
  );

  test('a detail response is discarded after the board changes', () async {
    final client = _RacingBoardClient();
    final api = KanbanApi(client, boardSlug: 'old');
    final store = KanbanStore(api);
    addTearDown(store.dispose);
    final oldDetail = store.loadDetail('same-id');

    api.boardSlug = 'new';
    client.detailGates['old']!.complete();
    expect(await oldDetail, isNull);

    final newDetail = store.loadDetail('same-id');
    client.detailGates['new']!.complete();
    expect((await newDetail)?.task.title, 'new detail');
  });

  test('detail cache is partitioned by board slug', () async {
    final client = _RacingBoardClient();
    final api = KanbanApi(client, boardSlug: 'old');
    final store = KanbanStore(api);
    addTearDown(store.dispose);

    final oldDetail = store.loadDetail('same-id');
    client.detailGates['old']!.complete();
    expect((await oldDetail)?.task.title, 'old detail');

    api.boardSlug = 'new';
    final newDetail = store.loadDetail('same-id');
    client.detailGates['new']!.complete();
    expect((await newDetail)?.task.title, 'new detail');
  });

  test('a stale board token cannot read or move a task', () async {
    final client = _RacingBoardClient();
    final api = KanbanApi(client, boardSlug: 'old');
    final store = KanbanStore(api);
    addTearDown(store.dispose);

    api.boardSlug = 'new';

    await expectLater(
      store.loadDetail('same-id', expectedApi: api, expectedBoardSlug: 'old'),
      throwsStateError,
    );
    await expectLater(
      store.moveTask(
        'same-id',
        'done',
        expectedApi: api,
        expectedBoardSlug: 'old',
      ),
      throwsStateError,
    );
  });

  test('a stale sheet API token cannot operate on a new connection', () async {
    final oldApi = KanbanApi(_BoardSelectionClient(), boardSlug: 'old');
    final newApi = KanbanApi(_BoardSelectionClient(), boardSlug: 'new');
    final store = KanbanStore(oldApi);
    addTearDown(store.dispose);

    store.bindApi(newApi);

    expect(() => store.requireApi(oldApi), throwsStateError);
    await expectLater(store.load(expectedApi: oldApi), throwsStateError);
    await expectLater(store.loadBoards(expectedApi: oldApi), throwsStateError);
    await expectLater(
      store.selectBoard('other', expectedApi: oldApi),
      throwsStateError,
    );
    expect(newApi.boardSlug, 'new');
  });

  test('an old failed move cannot roll its board into a new binding', () async {
    final oldClient = _DelayedPatchClient();
    final oldApi = KanbanApi(oldClient);
    final store = KanbanStore(oldApi)
      ..boardData = KanbanBoard.fromJson({
        'columns': [
          {
            'name': 'todo',
            'tasks': [
              {'id': 'old', 'title': 'old', 'status': 'todo'},
            ],
          },
        ],
      });
    addTearDown(store.dispose);

    final moving = store.moveTask('old', 'done');
    final newApi = KanbanApi(_DelayedBoardClient('new'));
    store.bindApi(newApi);
    store.boardData = KanbanBoard.fromJson({
      'columns': [
        {
          'name': 'todo',
          'tasks': [
            {'id': 'new', 'title': 'new', 'status': 'todo'},
          ],
        },
      ],
    });
    oldClient.gate.complete();
    await moving;

    expect(store.boardData?.tasks.single.id, 'new');
    expect(store.error, isNull);
  });
}

class _DelayedPatchClient extends ApiClient {
  _DelayedPatchClient()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final gate = Completer<void>();

  @override
  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    await gate.future;
    throw StateError('old backend failed');
  }
}

class _RacingBoardClient extends ApiClient {
  _RacingBoardClient()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final gates = {'old': Completer<void>(), 'new': Completer<void>()};
  final detailGates = {'old': Completer<void>(), 'new': Completer<void>()};

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final board = query?['board'] ?? '';
    if (path == '/api/v1/kanban/board') {
      await gates[board]!.future;
      return {
        'columns': [
          {
            'name': 'todo',
            'tasks': [
              {'id': board, 'title': board, 'status': 'todo'},
            ],
          },
        ],
      };
    }
    if (path == '/api/v1/kanban/tasks/same-id') {
      await detailGates[board]!.future;
      return {
        'task': {'id': 'same-id', 'title': '$board detail', 'status': 'todo'},
      };
    }
    if (path == '/api/v1/kanban/boards') {
      return {'current': board, 'boards': const []};
    }
    return <String, dynamic>{};
  }
}

class _DelayedBoardClient extends ApiClient {
  _DelayedBoardClient(this.title)
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final String title;
  final Completer<void> gate = Completer<void>();

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (path == '/api/v1/kanban/board') {
      await gate.future;
      return {
        'columns': [
          {
            'name': 'todo',
            'tasks': [
              {'id': title, 'title': title, 'status': 'todo'},
            ],
          },
        ],
      };
    }
    if (path == '/api/v1/kanban/boards') {
      return {'current': '', 'boards': const []};
    }
    return <String, dynamic>{};
  }
}

class _BoardSelectionClient extends ApiClient {
  _BoardSelectionClient()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (path == '/api/v1/kanban/board') {
      throw StateError('cannot load ${query?['board']}');
    }
    if (path == '/api/v1/kanban/boards') {
      return {'current': 'current', 'boards': const []};
    }
    return <String, dynamic>{};
  }
}
