import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/preview_store.dart';

class _TourConnection extends ConnectionStore {
  final controller = StreamController<RoutedGatewayEvent>.broadcast();
  final calls = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic> response = const {};

  @override
  Stream<RoutedGatewayEvent> get routedEvents => controller.stream;

  @override
  Future<Map<String, dynamic>> requestForOwner(
    OwnerRoute route,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    return response;
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

class _TourDriver implements PreviewDriver {
  final tours = <Map<String, dynamic>>[];
  final actions = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> act(Map<String, dynamic> action) async {
    actions.add(action);
    return {};
  }

  @override
  Future<Map<String, dynamic>> read({int? start, int? count}) async => {};

  @override
  Future<Map<String, dynamic>> tour(Map<String, dynamic> action) async {
    tours.add(action);
    return {'success': true, 'targets': const []};
  }
}

class _PreviewApi extends ApiClient {
  _PreviewApi() : super(baseUrl: 'https://example.invalid', apiKey: 'test');

  @override
  Future<String> fsReadText(String path, {String? profile}) async =>
      '# Hello';

  @override
  Future<String> fsReadDataUrl(String path) async =>
      'data:image/png;base64,AA==';

  @override
  Future<String> gitFileDiff(String path, String file) async =>
      'diff --git a/$file b/$file';
}

class _SequencedPreviewApi extends ApiClient {
  _SequencedPreviewApi()
    : super(baseUrl: 'https://example.invalid', apiKey: 'test');

  final reads = <Completer<String>>[];

  @override
  Future<String> fsReadText(String path, {String? profile}) {
    final read = Completer<String>();
    reads.add(read);
    return read.future;
  }
}

class _MutablePreviewApi extends ApiClient {
  _MutablePreviewApi()
    : super(baseUrl: 'https://example.invalid', apiKey: 'test');

  String content = 'first';
  int reads = 0;

  @override
  Future<String> fsReadText(String path, {String? profile}) async {
    reads++;
    return content;
  }

  @override
  Future<String> gitFileDiff(String path, String file) async => '';
}

class _CountingPreviewApi extends ApiClient {
  _CountingPreviewApi()
    : super(baseUrl: 'https://example.invalid', apiKey: 'test');

  int dataReads = 0;

  @override
  Future<String> fsReadDataUrl(String path) async {
    dataReads++;
    return 'data:application/pdf;base64,AA==';
  }
}

void main() {
  test('workspace file preview loads source and diff into one tab', () async {
    final connection = ConnectionStore();
    final api = _PreviewApi();
    final store = PreviewStore(connection, apiResolver: (_) => api);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    addTearDown(api.close);

    final tab = await store.openFile(
      '/workspace/README.md',
      repositoryRoot: '/workspace',
      title: 'README.md',
    );

    expect(tab.document?.source, '# Hello');
    expect(tab.document?.diff, contains('diff --git'));
    expect(tab.document?.editable, isTrue);
    expect(store.activeTab?.id, tab.id);
  });

  test(
    'older file read cannot overwrite a newer read of the same tab',
    () async {
      final connection = ConnectionStore();
      final api = _SequencedPreviewApi();
      final store = PreviewStore(connection, apiResolver: (_) => api);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      addTearDown(api.close);

      final older = store.openFile('/workspace/README.md');
      final newer = store.openFile('/workspace/README.md');
      api.reads[1].complete('new');
      await newer;
      api.reads[0].complete('old');
      await older;

      expect(store.activeTab?.document?.source, 'new');
      expect(store.tabs, hasLength(1));
    },
  );

  test('workspace change refreshes only the active matching file', () async {
    final connection = _TourConnection();
    final api = _MutablePreviewApi();
    final store = PreviewStore(connection, apiResolver: (_) => api);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    addTearDown(api.close);
    const route = OwnerRoute(
      connectionId: ConnectionId('primary'),
      profile: 'work',
    );

    await store.openFile(
      '/workspace/README.md',
      owner: route,
      repositoryRoot: '/workspace',
    );
    await store.openFile(
      '/workspace/other.md',
      owner: route,
      repositoryRoot: '/workspace',
    );
    store.activate('file:${route.key}:/workspace/README.md');
    expect(store.activeTab?.document?.path, '/workspace/README.md');
    api.content = 'updated';
    final refreshed = Completer<void>();
    void observeRefresh() {
      if (!refreshed.isCompleted &&
          store.activeTab?.document?.source == 'updated') {
        refreshed.complete();
      }
    }

    store.addListener(observeRefresh);
    addTearDown(() => store.removeListener(observeRefresh));

    connection.controller.add(
      RoutedGatewayEvent(
        route: route,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'workspace.changed',
          sessionId: 'runtime-a',
          profile: 'work',
          payload: const {
            'path': '/workspace/README.md',
            'revision': '2',
            'change_kind': 'modified',
            'full': false,
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.activeTab?.document?.stale, isTrue);
    await refreshed.future.timeout(const Duration(seconds: 2));

    expect(api.reads, 3);
    expect(
      store.tabs.map((tab) => (tab.document?.path, tab.document?.source)),
      [('/workspace/README.md', 'updated'), ('/workspace/other.md', 'first')],
    );
    expect(store.activeTab?.document?.source, 'updated');
    expect(store.activeTab?.document?.revision, '2');
  });

  test('background file is marked stale without downloading it', () async {
    final connection = _TourConnection();
    final api = _MutablePreviewApi();
    final store = PreviewStore(connection, apiResolver: (_) => api);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    addTearDown(api.close);
    const route = OwnerRoute(connectionId: ConnectionId('primary'));

    await store.openFile('/workspace/a.txt', owner: route);
    await store.openFile('/workspace/b.txt', owner: route);
    final readsBefore = api.reads;
    connection.controller.add(
      RoutedGatewayEvent(
        route: route,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'workspace.changed',
          payload: const {'path': '/workspace/a.txt', 'revision': '10'},
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 260));

    final background = store.tabs.singleWhere(
      (tab) => tab.document?.path == '/workspace/a.txt',
    );
    expect(background.document?.stale, isTrue);
    expect(background.document?.revision, '10');
    expect(api.reads, readsBefore);
  });

  test('older workspace revision cannot invalidate a newer preview', () async {
    final connection = _TourConnection();
    final api = _MutablePreviewApi();
    final store = PreviewStore(connection, apiResolver: (_) => api);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    addTearDown(api.close);
    const route = OwnerRoute(connectionId: ConnectionId('primary'));
    await store.openFile('/workspace/a.txt', owner: route);
    await store.openFile('/workspace/b.txt', owner: route);

    for (final revision in const ['20', '19']) {
      connection.controller.add(
        RoutedGatewayEvent(
          route: route,
          socketGeneration: 1,
          event: GatewayEvent(
            type: 'workspace.changed',
            payload: {'path': '/workspace/a.txt', 'revision': revision},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    final tab = store.tabs.singleWhere(
      (candidate) => candidate.document?.path == '/workspace/a.txt',
    );
    expect(tab.document?.revision, '20');
  });

  test(
    'workspace image preview uses a data URL without text decoding',
    () async {
      final connection = ConnectionStore();
      final api = _PreviewApi();
      final store = PreviewStore(connection, apiResolver: (_) => api);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      addTearDown(api.close);

      final tab = await store.openFile('/workspace/screen.png');

      expect(tab.document?.url, startsWith('data:image/png'));
      expect(tab.document?.editable, isFalse);
    },
  );

  test('large text preview defers reading until explicitly forced', () async {
    final connection = ConnectionStore();
    final api = _SequencedPreviewApi();
    final store = PreviewStore(connection, apiResolver: (_) => api);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    addTearDown(api.close);

    final placeholder = await store.openFile(
      '/workspace/large.log',
      byteSize: PreviewStore.textPreviewMaxBytes + 1,
    );
    expect(api.reads, isEmpty);
    expect(placeholder.document?.large, isTrue);
    expect(placeholder.document?.source, isNull);

    final forced = store.openFile(
      '/workspace/large.log',
      byteSize: PreviewStore.textPreviewMaxBytes + 1,
      force: true,
    );
    expect(api.reads, hasLength(1));
    api.reads.single.complete('loaded on demand');
    expect((await forced).document?.source, 'loaded on demand');
  });

  test('large PDF defers base64 allocation until explicitly forced', () async {
    final connection = ConnectionStore();
    final api = _CountingPreviewApi();
    final store = PreviewStore(connection, apiResolver: (_) => api);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    addTearDown(api.close);

    final deferred = await store.openFile(
      '/workspace/large.pdf',
      byteSize: PreviewStore.automaticPdfMaxBytes + 1,
      mimeType: 'application/pdf',
    );
    expect(deferred.document?.large, isTrue);
    expect(deferred.document?.url, isNull);
    expect(api.dataReads, 0);

    final loaded = await store.openFile(
      '/workspace/large.pdf',
      byteSize: PreviewStore.automaticPdfMaxBytes + 1,
      mimeType: 'application/pdf',
      force: true,
    );
    expect(loaded.document?.url, startsWith('data:application/pdf'));
    expect(api.dataReads, 1);
  });

  test(
    'preview tabs dedupe, activate and close without breaking active getters',
    () {
      final connection = ConnectionStore();
      final store = PreviewStore(connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);

      store.openUrl('https://example.com', title: 'Web');
      store.openHtml('<h1>One</h1>', title: 'HTML', sessionId: 's1');
      store.openUrl('https://example.com', title: 'Web updated');

      expect(store.tabs, hasLength(2));
      expect(store.title, 'Web updated');
      expect(store.url, 'https://example.com');

      final html = store.tabs.singleWhere((tab) => tab.html != null);
      store.activate(html.id);
      expect(store.html, '<h1>One</h1>');
      store.closeTab(html.id);
      expect(store.tabs, hasLength(1));
      expect(store.url, 'https://example.com');

      store.clear();
      expect(store.tabs, isEmpty);
      expect(store.hasContent, isFalse);
    },
  );

  test(
    'tour request drives the active preview and answers its request id',
    () async {
      final connection = _TourConnection();
      final store = PreviewStore(connection);
      final driver = _TourDriver();
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      const route = OwnerRoute(connectionId: ConnectionId('primary'));
      store
        ..openUrl('https://example.com', sessionId: 'runtime-a', owner: route)
        ..attachDriver(driver);

      connection.controller.add(
        RoutedGatewayEvent(
          route: route,
          socketGeneration: 1,
          event: GatewayEvent(
            type: 'tour.request',
            sessionId: 'runtime-a',
            payload: const {
              'request_id': 'tour-1',
              'surface': 'preview',
              'action': 'targets',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(driver.tours, hasLength(1));
      expect(connection.calls.single.$1, 'tour.respond');
      expect(connection.calls.single.$2['request_id'], 'tour-1');
      expect(
        jsonDecode(connection.calls.single.$2['text'] as String)['success'],
        isTrue,
      );
    },
  );

  test('native app tour is left to the native surface bridge', () async {
    final connection = _TourConnection();
    final store = PreviewStore(connection);
    final driver = _TourDriver();
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    const route = OwnerRoute(connectionId: ConnectionId('primary'));
    store
      ..openUrl('https://example.com', owner: route)
      ..attachDriver(driver);

    connection.controller.add(
      RoutedGatewayEvent(
        route: route,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'tour.request',
          payload: const {
            'request_id': 'tour-2',
            'surface': 'app',
            'action': 'targets',
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(driver.tours, isEmpty);
    expect(connection.calls, isEmpty);
  });

  test('tab-scoped drivers route requests to the owning session', () async {
    final connection = _TourConnection();
    final store = PreviewStore(connection);
    final first = _TourDriver();
    final second = _TourDriver();
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    const route = OwnerRoute(connectionId: ConnectionId('primary'));
    store.openUrl('https://one.example', sessionId: 'runtime-a', owner: route);
    final firstTab = store.activeTab!;
    store.openUrl('https://two.example', sessionId: 'runtime-b', owner: route);
    final secondTab = store.activeTab!;
    store
      ..attachDriver(first, tabId: firstTab.id)
      ..attachDriver(second, tabId: secondTab.id);

    connection.controller.add(
      RoutedGatewayEvent(
        route: route,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'tour.request',
          sessionId: 'runtime-a',
          payload: const {
            'request_id': 'tour-scoped',
            'surface': 'preview',
            'action': 'targets',
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(first.tours, hasLength(1));
    expect(second.tours, isEmpty);
  });

  test(
    'preview restart is owner scoped and reloads its tab on completion',
    () async {
      final connection = _TourConnection()
        ..response = const {'task_id': 'pr-1'};
      final store = PreviewStore(connection);
      final driver = _TourDriver();
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      const route = OwnerRoute(
        connectionId: ConnectionId('primary'),
        profile: 'work',
      );
      store.openUrl(
        'http://localhost:9000',
        sessionId: 'runtime-a',
        owner: route,
      );
      final tabId = store.activeTab!.id;
      store.attachDriver(driver, tabId: tabId);

      await store.restartServer(
        tabId,
        cwd: '/workspace',
        context: 'connection refused',
      );

      expect(connection.calls.single.$1, 'preview.restart');
      expect(connection.calls.single.$2, {
        'session_id': 'runtime-a',
        'url': 'http://localhost:9000',
        'cwd': '/workspace',
        'context': 'connection refused',
      });
      expect(store.restartStatus(tabId).phase, PreviewRestartPhase.running);

      connection.controller.add(
        RoutedGatewayEvent(
          route: route,
          socketGeneration: 1,
          event: GatewayEvent(
            type: 'preview.restart.complete',
            sessionId: 'runtime-a',
            payload: const {'task_id': 'pr-1', 'text': 'server started'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(store.restartStatus(tabId).phase, PreviewRestartPhase.completed);
      expect(driver.actions, [
        const {'action': 'reload'},
      ]);
    },
  );

  test('preview restart completion with error does not reload', () async {
    final connection = _TourConnection()..response = const {'task_id': 'pr-2'};
    final store = PreviewStore(connection);
    final driver = _TourDriver();
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    const route = OwnerRoute(connectionId: ConnectionId('primary'));
    store.openUrl(
      'http://localhost:9000',
      sessionId: 'runtime-a',
      owner: route,
    );
    final tabId = store.activeTab!.id;
    store.attachDriver(driver, tabId: tabId);
    await store.restartServer(tabId);

    connection.controller.add(
      RoutedGatewayEvent(
        route: route,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'preview.restart.complete',
          sessionId: 'runtime-a',
          payload: const {'task_id': 'pr-2', 'text': 'error: port unavailable'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(store.restartStatus(tabId).phase, PreviewRestartPhase.failed);
    expect(driver.actions, isEmpty);
  });

  test(
    'a stale restart completion cannot clobber a newer restart for the same tab',
    () async {
      final connection = _TourConnection()
        ..response = const {'task_id': 'pr-1'};
      final store = PreviewStore(connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      const route = OwnerRoute(connectionId: ConnectionId('primary'));
      store.openUrl(
        'http://localhost:9000',
        sessionId: 'runtime-a',
        owner: route,
      );
      final tabId = store.activeTab!.id;

      await store.restartServer(tabId);
      expect(store.restartStatus(tabId).taskId, 'pr-1');

      // The user grows impatient and taps restart again before the first
      // task's completion event arrives; this starts a second task that
      // supersedes the first for this tab.
      connection.response = const {'task_id': 'pr-2'};
      await store.restartServer(tabId);
      expect(store.restartStatus(tabId).taskId, 'pr-2');
      expect(store.restartStatus(tabId).phase, PreviewRestartPhase.running);

      // The FIRST task's completion event arrives late.
      connection.controller.add(
        RoutedGatewayEvent(
          route: route,
          socketGeneration: 1,
          event: GatewayEvent(
            type: 'preview.restart.complete',
            sessionId: 'runtime-a',
            payload: const {'task_id': 'pr-1', 'text': 'server started'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // The still-running second task's status must be unaffected.
      expect(store.restartStatus(tabId).taskId, 'pr-2');
      expect(store.restartStatus(tabId).phase, PreviewRestartPhase.running);

      // The SECOND task's own completion event still applies normally.
      connection.controller.add(
        RoutedGatewayEvent(
          route: route,
          socketGeneration: 1,
          event: GatewayEvent(
            type: 'preview.restart.complete',
            sessionId: 'runtime-a',
            payload: const {'task_id': 'pr-2', 'text': 'server started'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.restartStatus(tabId).taskId, 'pr-2');
      expect(store.restartStatus(tabId).phase, PreviewRestartPhase.completed);
    },
  );

  test(
    'restarting while the previous request has no task id yet is rejected',
    () async {
      final connection = _TourConnection()
        ..response = const {'task_id': 'pr-1'};
      final store = PreviewStore(connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      const route = OwnerRoute(connectionId: ConnectionId('primary'));
      store.openUrl(
        'http://localhost:9000',
        sessionId: 'runtime-a',
        owner: route,
      );
      final tabId = store.activeTab!.id;

      // Do not await: the request is still in flight, so no task id has
      // been assigned to this tab's restart status yet.
      final first = store.restartServer(tabId);
      expect(store.restartStatus(tabId).busy, isTrue);
      expect(store.restartStatus(tabId).taskId, isNull);

      await expectLater(store.restartServer(tabId), throwsStateError);
      await first;
    },
  );

  test('same preview URL is partitioned by profile owner', () {
    final connection = ConnectionStore();
    final store = PreviewStore(connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    const first = OwnerRoute(
      connectionId: ConnectionId('primary'),
      profile: 'default',
    );
    const second = OwnerRoute(
      connectionId: ConnectionId('primary'),
      profile: 'work',
    );

    store.openUrl('https://example.com', owner: first);
    store.openUrl('https://example.com', owner: second);

    expect(store.tabs, hasLength(2));
    expect(store.tabs.map((tab) => tab.id).toSet(), hasLength(2));
  });

  test(
    'agent preview open and close follow the visible session only',
    () async {
      final connection = _TourConnection();
      final store = PreviewStore(connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      const route = OwnerRoute(connectionId: ConnectionId('primary'));
      var runtimeId = 'runtime-a';
      store.bindVisibleSession(
        owner: () => route,
        runtimeId: () => runtimeId,
        durableId: () => 'durable-a',
      );

      void emit(String type, String sessionId, [String url = '']) {
        connection.controller.add(
          RoutedGatewayEvent(
            route: route,
            socketGeneration: 1,
            event: GatewayEvent(
              type: type,
              sessionId: sessionId,
              payload: {'url': url, 'label': 'Agent preview'},
            ),
          ),
        );
      }

      emit('preview.open', 'runtime-b', 'https://background.example');
      await Future<void>.delayed(Duration.zero);
      expect(store.tabs, isEmpty);

      emit('preview.open', 'runtime-a', 'https://visible.example');
      await Future<void>.delayed(Duration.zero);
      expect(store.tabs.single.url, 'https://visible.example');
      expect(store.tabs.single.title, 'Agent preview');

      emit('preview.close', 'runtime-a', 'https://visible.example');
      await Future<void>.delayed(Duration.zero);
      expect(store.tabs, isEmpty);

      runtimeId = 'runtime-b';
      emit('preview.open', 'runtime-b', 'https://now-visible.example');
      await Future<void>.delayed(Duration.zero);
      expect(store.tabs.single.url, 'https://now-visible.example');
    },
  );
}
