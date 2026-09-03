import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends ApiClient {
  _Api(String name)
    : super(baseUrl: 'http://$name.invalid', apiKey: 'test-key');

  @override
  Future<Map<String, dynamic>> sessionInfo(
    String id, {
    String? profile,
  }) async => const {'message_count': 0};

  @override
  Future<List<dynamic>> sessionMessagesRaw(
    String id, {
    int limit = 200,
    int offset = 0,
    String? profile,
  }) async => const [];
}

class _Gateway extends GatewayClient {
  final StreamController<GatewayEvent> controller =
      StreamController<GatewayEvent>.broadcast();
  final StreamController<String> drops = StreamController<String>.broadcast();
  final List<(String, Map<String, dynamic>)> calls = [];
  bool connected = false;
  Completer<Map<String, dynamic>>? resumeGate;
  Object? connectError;
  Completer<void>? connectGate;
  Completer<void>? disconnectGate;
  int connectCount = 0;
  int disconnectCount = 0;

  _Gateway(String name)
    : super(serverBaseUrl: 'http://$name.invalid', apiKey: 'test-key');

  @override
  Stream<GatewayEvent> get events => controller.stream;

  @override
  Stream<String> get onDisconnect => drops.stream;

  @override
  bool get isConnected => connected;

  @override
  Future<void> connect() async {
    connectCount++;
    final error = connectError;
    if (error != null) throw error;
    final gate = connectGate;
    if (gate != null) await gate.future;
    connected = true;
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    if (method == 'session.resume' && resumeGate != null) {
      return resumeGate!.future;
    }
    return {'ok': true};
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    final gate = disconnectGate;
    if (gate != null) await gate.future;
    connected = false;
  }
}

ConnectionRuntime _runtime(String id, _Gateway gateway) => ConnectionRuntime(
  id: ConnectionId(id),
  settings: ConnectionSettings(
    serverUrl: 'http://$id.invalid',
    apiKey: 'test-key',
  ),
  api: _Api(id),
  gateway: gateway,
);

class _FailingSessionStore extends SessionStore {
  _FailingSessionStore({
    required super.connection,
    required super.chat,
    required super.requests,
  });

  @override
  Future<void> sendMessage(
    String text, {
    void Function()? onAutoRetry,
    bool interrupted = false,
  }) async {
    throw GatewayException(-1, 'ambiguous disconnect');
  }
}

class _GatedSessionStore extends SessionStore {
  _GatedSessionStore({
    required super.connection,
    required super.chat,
    required super.requests,
  });

  final Completer<void> firstSend = Completer<void>();
  final List<String> sent = <String>[];

  @override
  Future<void> sendMessage(
    String text, {
    void Function()? onAutoRetry,
    bool interrupted = false,
  }) async {
    sent.add(text);
    if (sent.length == 1) await firstSend.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('registry keeps simultaneous runtimes and switches only the facade', () {
    final registry = ConnectionRegistry();
    final a = _runtime('a', _Gateway('a'));
    final b = _runtime('b', _Gateway('b'));
    addTearDown(registry.dispose);

    registry.add(a, makeActive: true);
    registry.add(b);
    expect(registry.runtimes.length, 2);
    expect(registry.active, same(a));

    registry.activate(const ConnectionId('b'));
    expect(registry.active, same(b));
    expect(registry.runtime(const ConnectionId('a')), same(a));
  });

  test('failed candidate connection preserves the active runtime', () async {
    final gatewayA = _Gateway('a')..connected = true;
    final gatewayB = _Gateway('b')..connectError = StateError('offline');
    final store = ConnectionStore(
      clientFactory: (id, settings) async =>
          (api: _Api(id.value), gateway: id.value == 'b' ? gatewayB : gatewayA),
    );
    addTearDown(store.dispose);
    await store.addConnection(
      const ConnectionId('a'),
      const ConnectionSettings(
        serverUrl: 'http://a.invalid',
        apiKey: 'test-key',
      ),
      makeActive: true,
    );
    final runtimeA = store.registry.runtime(const ConnectionId('a'))!;

    await expectLater(
      store.addConnection(
        const ConnectionId('b'),
        const ConnectionSettings(
          serverUrl: 'http://b.invalid',
          apiKey: 'test-key',
        ),
        makeActive: true,
      ),
      throwsStateError,
    );

    expect(store.activeConnectionId, const ConnectionId('a'));
    expect(store.registry.active, same(runtimeA));
    expect(store.registry.runtime(const ConnectionId('b')), isNull);
    expect(store.api, same(runtimeA.api));
  });

  test(
    'failed primary replacement preserves the old runtime and settings',
    () async {
      final oldGateway = _Gateway('old');
      final failedGateway = _Gateway('new')
        ..connectError = StateError('offline');
      final store = ConnectionStore(
        clientFactory: (id, settings) async => (
          api: _Api(settings.serverUrl.contains('new') ? 'new' : 'old'),
          gateway: settings.serverUrl.contains('new')
              ? failedGateway
              : oldGateway,
        ),
      );
      addTearDown(store.dispose);
      const oldSettings = ConnectionSettings(
        serverUrl: 'http://old.invalid',
        apiKey: 'old-key',
      );
      const newSettings = ConnectionSettings(
        serverUrl: 'http://new.invalid',
        apiKey: 'new-key',
      );
      await store.saveConnection(oldSettings);
      final oldRuntime = store.registry.runtime(
        ConnectionStore.primaryConnectionId,
      );

      await expectLater(store.saveConnection(newSettings), throwsStateError);

      expect(store.settings, oldSettings);
      expect(
        store.registry.runtime(ConnectionStore.primaryConnectionId),
        same(oldRuntime),
      );
      expect(store.api, same(oldRuntime!.api));
    },
  );

  test(
    'session request is routed to its owner, never the active runtime',
    () async {
      final store = ConnectionStore();
      final gatewayA = _Gateway('a');
      final gatewayB = _Gateway('b');
      store.registry.add(_runtime('a', gatewayA), makeActive: true);
      store.registry.add(_runtime('b', gatewayB));
      store.sessionOwners.remember(
        const SessionOwner(
          durableId: 'session-b',
          runtimeId: 'runtime-b',
          route: OwnerRoute(connectionId: ConnectionId('b'), profile: 'work'),
        ),
      );
      addTearDown(store.dispose);

      await store.requestForSession('session-b', 'session.interrupt', {
        'session_id': 'runtime-b',
      });

      expect(gatewayA.calls, isEmpty);
      expect(gatewayB.calls.single.$1, 'session.interrupt');
    },
  );

  test('unknown session owner fails closed', () async {
    final store = ConnectionStore();
    addTearDown(store.dispose);

    expect(
      () => store.requestForSession('missing', 'session.usage', const {}),
      throwsStateError,
    );
  });

  test('routed interactive requests retain their owning connection', () async {
    final controller = StreamController<RoutedGatewayEvent>.broadcast();
    final requests = RequestStore()..attachRoutedEvents(controller.stream);
    addTearDown(requests.dispose);
    addTearDown(controller.close);

    controller.add(
      RoutedGatewayEvent(
        route: const OwnerRoute(connectionId: ConnectionId('remote')),
        socketGeneration: 3,
        event: GatewayEvent(
          type: 'approval.request',
          sessionId: 'runtime-remote',
          payload: const {'request_id': 'approve-1'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(requests.current?.ownerRoute?.connectionId.value, 'remote');
    expect(requests.current?.sessionId, 'runtime-remote');
  });

  test('concurrent resume is single-flight per owner and durable id', () async {
    final connection = ConnectionStore();
    final gateway = _Gateway('remote')
      ..resumeGate = Completer<Map<String, dynamic>>();
    connection.registry.add(_runtime('remote', gateway), makeActive: true);
    final session = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(session.dispose);
    addTearDown(connection.dispose);

    final first = session.resumeSession('durable-1', profile: 'work');
    final second = session.resumeSession('durable-1', profile: 'work');
    await Future<void>.delayed(Duration.zero);
    expect(
      gateway.calls.where((call) => call.$1 == 'session.resume').length,
      1,
    );

    gateway.resumeGate!.complete({
      'session_id': 'runtime-new',
      'info': const <String, dynamic>{},
    });
    await first.timeout(const Duration(seconds: 1));
    await second.timeout(const Duration(seconds: 1));
    expect(session.runtimeId, 'runtime-new');
    expect(session.owner?.route.connectionId.value, 'remote');
  });

  test(
    'runtime reconnect increments generation and applies bounded backoff',
    () async {
      final gateway = _Gateway('remote');
      final runtime = _runtime('remote', gateway);
      addTearDown(runtime.dispose);
      await runtime.connect();
      expect(runtime.socketGeneration, 1);

      gateway.connected = false;
      gateway.drops.add('backend restarted');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(runtime.phase, RuntimePhase.connected);
      expect(runtime.socketGeneration, 2);
    },
  );

  test(
    'regained connectivity retries immediately instead of waiting out backoff',
    () async {
      final gateway = _Gateway('remote');
      final runtime = _runtime('remote', gateway);
      addTearDown(runtime.dispose);
      await runtime.connect();
      expect(gateway.connectCount, 1);

      gateway.connected = false;
      gateway.connectError = StateError('still down');
      gateway.drops.add('network blip');
      // Let the drop handler run and land in `reconnecting`, which
      // schedules its own backoff timer (>= 240ms for the first attempt —
      // 300ms base with -20% jitter at the floor).
      await Future<void>.delayed(Duration.zero);
      expect(runtime.phase, RuntimePhase.reconnecting);

      gateway.connectError = null; // "the network" is back
      runtime.notifyConnectivityRegained();
      // Far shorter than the shortest possible natural backoff — this only
      // passes if the pending timer was actually skipped, not just fast.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(runtime.phase, RuntimePhase.connected);
      expect(gateway.connectCount, greaterThanOrEqualTo(2));
    },
  );

  test('regained connectivity is a no-op while already connected', () async {
    final gateway = _Gateway('remote');
    final runtime = _runtime('remote', gateway);
    addTearDown(runtime.dispose);
    await runtime.connect();
    final before = gateway.connectCount;

    runtime.notifyConnectivityRegained();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(gateway.connectCount, before);
    expect(runtime.phase, RuntimePhase.connected);
  });

  test('foreground resume refreshes a potentially stale socket', () async {
    final gateway = _Gateway('remote');
    var reclaimed = 0;
    final runtime = ConnectionRuntime(
      id: const ConnectionId('remote'),
      settings: const ConnectionSettings(
        serverUrl: 'http://remote.invalid',
        apiKey: 'test-key',
      ),
      api: _Api('remote'),
      gateway: gateway,
      onReconnected: (_) => reclaimed++,
    );
    addTearDown(runtime.dispose);
    await runtime.connect();

    await runtime.reconnectAfterResume(refreshSocket: true);

    expect(gateway.disconnectCount, 1);
    expect(gateway.connectCount, 2);
    expect(runtime.phase, RuntimePhase.connected);
    expect(runtime.socketGeneration, 2);
    expect(reclaimed, 1);
  });

  test(
    'foreground resume restarts retries after an immediate failure',
    () async {
      final gateway = _Gateway('remote');
      final runtime = _runtime('remote', gateway);
      addTearDown(runtime.dispose);
      gateway.connectError = StateError('offline');

      await expectLater(runtime.reconnectAfterResume(), throwsStateError);
      expect(runtime.phase, RuntimePhase.reconnecting);

      gateway.connectError = null;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(runtime.phase, RuntimePhase.connected);
      expect(gateway.connectCount, 2);
    },
  );

  test(
    'background pauses retries until the runtime returns foreground',
    () async {
      final gateway = _Gateway('remote');
      final runtime = _runtime('remote', gateway);
      addTearDown(runtime.dispose);
      gateway.connectError = StateError('offline');
      runtime.setForeground(false);

      await expectLater(runtime.reconnectAfterResume(), throwsStateError);
      runtime.setForeground(false);
      gateway.connectError = null;
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(gateway.connectCount, 1);
      expect(runtime.phase, RuntimePhase.reconnecting);

      runtime.setForeground(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(gateway.connectCount, 2);
      expect(runtime.phase, RuntimePhase.connected);
    },
  );

  test('manual reconnect replaces a socket that only appears alive', () async {
    final gateway = _Gateway('remote');
    final store = ConnectionStore()
      ..settings = const ConnectionSettings(
        serverUrl: 'http://remote.invalid',
        apiKey: 'test-key',
      );
    final runtime = _runtime('remote', gateway);
    store.registry.add(runtime, makeActive: true);
    addTearDown(store.dispose);
    await runtime.connect();

    await store.reconnectAfterResume(refreshSocket: true);

    expect(gateway.disconnectCount, 1);
    expect(gateway.connectCount, 2);
    expect(store.phase, ConnectionPhase.connected);
    expect(store.isConnected, isTrue);
  });

  test(
    'forced reconnect disconnects every runtime before reconnecting any',
    () async {
      final firstGateway = _Gateway('first');
      final secondGateway = _Gateway('second');
      final store = ConnectionStore()
        ..settings = const ConnectionSettings(
          serverUrl: 'http://first.invalid',
          apiKey: 'test-key',
        );
      final first = _runtime('first', firstGateway);
      final second = _runtime('second', secondGateway);
      store.registry.add(first, makeActive: true);
      store.registry.add(second);
      addTearDown(store.dispose);
      await Future.wait([first.connect(), second.connect()]);
      firstGateway.disconnectGate = Completer<void>();
      secondGateway.disconnectGate = Completer<void>();

      final reconnect = store.reconnectAfterResume(refreshSocket: true);
      await Future<void>.delayed(Duration.zero);

      expect(firstGateway.disconnectCount, 1);
      expect(secondGateway.disconnectCount, 1);
      expect(firstGateway.connectCount, 1);
      expect(secondGateway.connectCount, 1);

      firstGateway.disconnectGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(firstGateway.connectCount, 1);
      expect(secondGateway.connectCount, 1);

      secondGateway.disconnectGate!.complete();
      await reconnect;

      expect(firstGateway.connectCount, 2);
      expect(secondGateway.connectCount, 2);
      expect(first.phase, RuntimePhase.connected);
      expect(second.phase, RuntimePhase.connected);
      expect(store.phase, ConnectionPhase.connected);
    },
  );

  test(
    'forced reconnect closes a socket completed by a stale handshake',
    () async {
      final gateway = _Gateway('remote')..connectGate = Completer<void>();
      final runtime = _runtime('remote', gateway);
      addTearDown(runtime.dispose);

      final staleConnect = runtime.connect();
      await Future<void>.delayed(Duration.zero);
      final reconnect = runtime.reconnectAfterResume(refreshSocket: true);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.disconnectCount, 1);

      gateway.connectGate!.complete();
      await staleConnect;
      await reconnect;

      expect(gateway.disconnectCount, 2);
      expect(gateway.connectCount, 2);
      expect(runtime.phase, RuntimePhase.connected);
    },
  );

  test('concurrent foreground resumes share one socket replacement', () async {
    final gateway = _Gateway('remote');
    final runtime = _runtime('remote', gateway);
    addTearDown(runtime.dispose);
    await runtime.connect();
    gateway.connectGate = Completer<void>();

    final first = runtime.reconnectAfterResume(refreshSocket: true);
    final second = runtime.reconnectAfterResume(refreshSocket: true);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.disconnectCount, 1);
    expect(gateway.connectCount, 2);
    gateway.connectGate!.complete();
    await Future.wait([first, second]);
    expect(runtime.socketGeneration, 2);
  });

  test('ambiguous send failure keeps queue durably partitioned', () async {
    final connection = ConnectionStore();
    final session = _FailingSessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(session.dispose);
    addTearDown(connection.dispose);

    await session.enqueueMessage('do not duplicate');
    expect(session.queueCount, 1);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hm_session_queues_v2');
    expect(raw, contains('do not duplicate'));
    expect(raw, contains('primary'));

    final restored = _FailingSessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(restored.dispose);
    await restored.restoreQueues();
    expect(restored.queueCount, 1);
    expect(restored.sendQueue.single.text, 'do not duplicate');
  });

  test('parked queue keeps later prompts until explicit resume', () async {
    final connection = ConnectionStore();
    final session = _GatedSessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(session.dispose);
    addTearDown(connection.dispose);

    final first = session.enqueueMessage('first');
    await Future<void>.delayed(Duration.zero);
    await session.enqueueMessage('second');
    session.parkQueue();
    session.firstSend.complete();
    await first;

    expect(session.sent, ['first']);
    expect(session.queueParked, isTrue);
    expect(session.sendQueue.single.text, 'second');

    await session.resumeQueue();
    expect(session.sent, ['first', 'second']);
    expect(session.sendQueue, isEmpty);
  });

  test(
    'queued message persists display text and attachment metadata',
    () async {
      final connection = ConnectionStore();
      final session = _FailingSessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(session.dispose);
      addTearDown(connection.dispose);

      await session.enqueueMessage(
        'expanded body',
        displayText: '/skill review',
        attachments: const [
          QueuedAttachment(
            kind: 'file',
            label: 'main.dart',
            occurrenceId: 'occ-1',
            path: '/main.dart',
          ),
        ],
      );
      final restored = _FailingSessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(restored.dispose);
      await restored.restoreQueues();
      expect(restored.sendQueue.single.displayText, '/skill review');
      expect(restored.sendQueue.single.attachments.single.path, '/main.dart');
      expect(
        restored.sendQueue.single.attachments.single.occurrenceId,
        'occ-1',
      );
    },
  );
}
