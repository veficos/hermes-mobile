import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProfileApi extends ApiClient {
  _ProfileApi({this.messageCount = 1})
    : super(baseUrl: 'http://profile.invalid', apiKey: 'test');

  final int messageCount;
  final List<(String, Map<String, String>?)> calls = [];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    calls.add((path, query));
    final isExperts = query?['profile'] == 'experts';
    if (path == '/api/v1/sessions/expert-session') {
      return {
        'id': 'expert-session',
        'message_count': isExperts ? messageCount : 0,
      };
    }
    if (path == '/api/v1/sessions/expert-session/messages') {
      final offset = int.parse(query?['offset'] ?? '0');
      return {
        'messages': isExperts
            ? [
                {
                  'id': offset + 1,
                  'role': 'user',
                  'content': offset == 0 && messageCount > 1
                      ? 'older expert history'
                      : 'expert history',
                },
              ]
            : <dynamic>[],
      };
    }
    throw StateError('unexpected GET $path');
  }
}

class _ProfileGateway extends GatewayClient {
  _ProfileGateway()
    : super(serverBaseUrl: 'http://profile.invalid', apiKey: 'test');

  final List<(String, Map<String, dynamic>)> calls = [];
  Completer<void>? closeGate;
  bool failOldRuntimeTruncate = false;

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    if (method == 'session.resume') {
      return {'session_id': 'runtime-expert'};
    }
    if (method == 'session.create') {
      return {'session_id': 'runtime-new'};
    }
    if (method == 'session.close') {
      await closeGate?.future;
      return {};
    }
    if (method == 'config.set') {
      return {'key': 'model', 'value': 'tencent/hy3:free', 'scope': 'session'};
    }
    if (method == 'prompt.submit') {
      if (failOldRuntimeTruncate &&
          params['session_id'] == 'runtime-expert' &&
          params['confirm_truncate'] == true) {
        throw GatewayException(
          5008,
          'failed to persist history truncation: FOREIGN KEY constraint failed',
        );
      }
      return {};
    }
    throw StateError('unexpected RPC $method');
  }
}

class _SwitchProfileApi extends ApiClient {
  _SwitchProfileApi()
    : super(baseUrl: 'http://profile.invalid', apiKey: 'test');

  String active = 'experts';
  List<ProfileInfo> availableProfiles = const [
    ProfileInfo(name: 'default'),
    ProfileInfo(name: 'experts'),
  ];
  final List<String> activations = [];
  final List<String?> configProfiles = [];
  final List<String?> sessionProfiles = [];
  final Map<String, Completer<void>> activationGates = {};
  final Map<String, Completer<void>> sessionGates = {};
  final Set<String> failingSessionRequests = {};
  final Set<String> failingActivations = {};
  final Set<String> failingConfigs = {};
  final Set<String> profilesWithMore = {};
  Map<String, dynamic> batchDeleteResult = const {
    'deleted': <String>[],
    'failed': <dynamic>[],
  };

  @override
  Future<ProfilesPayload> listProfiles() async => ProfilesPayload(
    profiles: availableProfiles,
    active: active,
    current: 'default',
    source: 'upstream',
  );

  @override
  Future<Map<String, dynamic>> activateProfile(String name) async {
    activations.add(name);
    await activationGates[name]?.future;
    if (failingActivations.contains(name)) {
      throw StateError('cannot activate $name');
    }
    active = name;
    return {'active': name, 'current': 'default'};
  }

  @override
  Future<Map<String, dynamic>> deleteSessions(
    List<String> ids, {
    String? profile,
  }) async => batchDeleteResult;

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async {
    configProfiles.add(profile);
    if (failingConfigs.contains(profile)) {
      throw StateError('cannot load config for $profile');
    }
    return {'profile': profile};
  }

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    sessionProfiles.add(profile);
    final scope = profile ?? 'unscoped';
    await sessionGates['$scope:$offset']?.future;
    if (failingSessionRequests.contains('$scope:$offset')) {
      throw StateError('failed $scope:$offset');
    }
    return SessionPage(
      sessions: [SessionRow(id: '$scope-$offset', profile: profile)],
      total: profilesWithMore.contains(scope) ? 2 : 1,
      offset: offset,
      hasMore: offset == 0 && profilesWithMore.contains(scope),
    );
  }
}

class _RaceApi extends ApiClient {
  _RaceApi() : super(baseUrl: 'http://race.invalid', apiKey: 'test');

  final calls = <(String, Map<String, String>?)>[];
  final messageGates = <String, Completer<void>>{};

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    calls.add((path, query));
    final segments = Uri.parse(path).pathSegments;
    final id = segments.last == 'messages'
        ? segments[segments.length - 2]
        : segments.last;
    if (segments.last == 'messages') {
      await messageGates[id]?.future;
      return {
        'messages': [
          {'id': 1, 'role': 'user', 'content': '$id/${query?['profile']}'},
        ],
      };
    }
    return {'id': id, 'message_count': 1};
  }
}

class _RaceGateway extends GatewayClient {
  _RaceGateway() : super(serverBaseUrl: 'http://race.invalid', apiKey: 'test');

  final calls = <(String, Map<String, dynamic>)>[];
  final gates = <String, Completer<void>>{};
  final errors = <String, Object>{};

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    final session = params['session_id']?.toString() ?? '';
    await gates['$method:$session']?.future;
    final error = errors['$method:$session'];
    if (error != null) throw error;
    if (method == 'session.resume') {
      return {'session_id': 'runtime-$session'};
    }
    if (method == 'session.create') return {'session_id': 'runtime-new'};
    if (method == 'session.branch') return {'stored_session_id': 'branch-a'};
    return {};
  }
}

class _ProfileConnection extends ConnectionStore {
  _ProfileConnection({
    required ApiClient apiClient,
    required GatewayClient gw,
  }) {
    api = apiClient;
    gateway = gw;
  }

  final eventController = StreamController<GatewayEvent>.broadcast();
  final reconnectController = StreamController<void>.broadcast();
  Completer<void>? ensureConnectedGate;
  int ensureConnectedCalls = 0;

  @override
  Stream<GatewayEvent> get events => eventController.stream;

  @override
  Stream<void> get reconnected => reconnectController.stream;

  @override
  Future<void> ensureConnected() async {
    ensureConnectedCalls++;
    await ensureConnectedGate?.future;
  }

  @override
  void dispose() {
    eventController.close();
    reconnectController.close();
    super.dispose();
  }
}

void main() {
  test('resuming a profile session loads its durable transcript', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _ProfileApi();
    final gateway = _ProfileGateway();
    final connection = _ProfileConnection(apiClient: api, gw: gateway);
    final chat = ChatStore();
    final store = SessionStore(
      connection: connection,
      chat: chat,
      requests: RequestStore(),
    );
    addTearDown(() {
      store.dispose();
      connection.dispose();
    });

    await store.resumeSession('expert-session', profile: 'experts');

    expect(gateway.calls.single.$2['profile'], 'experts');
    expect(chat.messages.map((message) => message.fullText), [
      'expert history',
    ]);
    expect(api.calls[0].$1, '/api/v1/sessions/expert-session');
    expect(api.calls[0].$2, {'profile': 'experts'});
    expect(api.calls[1].$1, '/api/v1/sessions/expert-session/messages');
    expect(api.calls[1].$2, {
      'limit': '50',
      'offset': '0',
      'profile': 'experts',
    });
  });

  test(
    'new session uses the active profile and keeps it without a durable id',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final gateway = _ProfileGateway();
      final connection = _ProfileConnection(apiClient: api, gw: gateway);
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(() {
        store.dispose();
        connection.dispose();
      });

      await store.refreshProfiles();
      await store.openNewSession();

      final create = gateway.calls.singleWhere(
        (call) => call.$1 == 'session.create',
      );
      expect(create.$2['profile'], 'experts');
      expect(store.profile, 'experts');
      expect(store.durableId, isNull);
      expect(store.runtimeId, 'runtime-new');
    },
  );

  test(
    'chat model switch targets the live session through config.set',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final gateway = _ProfileGateway();
      final connection = _ProfileConnection(apiClient: api, gw: gateway);
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(() {
        store.dispose();
        connection.dispose();
      });

      await store.refreshProfiles();
      await store.openNewSession();
      final result = await store.switchCurrentModel('nous', 'tencent/hy3:free');

      final call = gateway.calls.singleWhere((call) => call.$1 == 'config.set');
      expect(call.$2, {
        'session_id': 'runtime-new',
        'key': 'model',
        'value': 'tencent/hy3:free --provider nous',
      });
      expect(result['applied'], 'now');
      expect(store.info?.provider, 'nous');
      expect(store.info?.model, 'tencent/hy3:free');
    },
  );

  test(
    'profile switch intent blocks regenerate before session close completes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final closeGate = Completer<void>();
      final gateway = _ProfileGateway()
        ..closeGate = closeGate
        ..failOldRuntimeTruncate = true;
      final connection = _ProfileConnection(apiClient: api, gw: gateway);
      final chat = ChatStore();
      final store = SessionStore(
        connection: connection,
        chat: chat,
        requests: RequestStore(),
      );
      addTearDown(() {
        if (!closeGate.isCompleted) closeGate.complete();
        store.dispose();
        connection.dispose();
      });

      await store.resumeSession('expert-session', profile: 'experts');
      chat.loadHistory([
        ChatMessage(id: 'u1', role: 'user', parts: [ChatPart.text('question')]),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          parts: [ChatPart.text('answer')],
        ),
      ], hasMore: false);
      final switching = store.switchActiveProfile('default', listLimit: 20);
      while (!gateway.calls.any((call) => call.$1 == 'session.close')) {
        await Future<void>.delayed(Duration.zero);
      }

      await expectLater(
        store.reloadFromMessage(chat.messages.last),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The profile is switching. Try again shortly.',
          ),
        ),
      );
      expect(
        gateway.calls.where((call) => call.$1 == 'prompt.submit'),
        isEmpty,
      );
      expect(chat.messages.map((message) => message.id), ['u1', 'a1']);

      closeGate.complete();
      await switching;
    },
  );

  test(
    'rewind waiting for connection is cancelled when profile switch starts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final closeGate = Completer<void>();
      final connectionGate = Completer<void>();
      final gateway = _ProfileGateway()..closeGate = closeGate;
      final connection = _ProfileConnection(apiClient: api, gw: gateway);
      final chat = ChatStore();
      final store = SessionStore(
        connection: connection,
        chat: chat,
        requests: RequestStore(),
      );
      addTearDown(() {
        if (!connectionGate.isCompleted) connectionGate.complete();
        if (!closeGate.isCompleted) closeGate.complete();
        store.dispose();
        connection.dispose();
      });

      await store.resumeSession('expert-session', profile: 'experts');
      chat.loadHistory([
        ChatMessage(id: 'u1', role: 'user', parts: [ChatPart.text('question')]),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          parts: [ChatPart.text('answer')],
        ),
      ], hasMore: false);
      connection.ensureConnectedGate = connectionGate;
      final reloading = store.reloadFromMessage(chat.messages.last);
      while (connection.ensureConnectedCalls < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      final switching = store.switchActiveProfile('default', listLimit: 20);
      while (!gateway.calls.any((call) => call.$1 == 'session.close')) {
        await Future<void>.delayed(Duration.zero);
      }

      connectionGate.complete();
      await expectLater(
        reloading,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The profile is switching. Try again shortly.',
          ),
        ),
      );
      expect(
        gateway.calls.where((call) => call.$1 == 'prompt.submit'),
        isEmpty,
      );
      expect(chat.messages.map((message) => message.id), ['u1', 'a1']);

      closeGate.complete();
      await switching;
    },
  );

  test('regenerate works on the new runtime after profile switch', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _SwitchProfileApi();
    final gateway = _ProfileGateway()..failOldRuntimeTruncate = true;
    final connection = _ProfileConnection(apiClient: api, gw: gateway);
    final chat = ChatStore();
    final store = SessionStore(
      connection: connection,
      chat: chat,
      requests: RequestStore(),
    );
    addTearDown(() {
      store.dispose();
      connection.dispose();
    });

    await store.resumeSession('expert-session', profile: 'experts');
    await store.switchActiveProfile('default', listLimit: 20);
    await store.openNewSession();
    chat.loadHistory([
      ChatMessage(
        id: 'u-new',
        role: 'user',
        parts: [ChatPart.text('new question')],
      ),
      ChatMessage(
        id: 'a-new',
        role: 'assistant',
        parts: [ChatPart.text('new answer')],
      ),
    ], hasMore: false);

    await store.reloadFromMessage(chat.messages.last);

    final submit = gateway.calls.singleWhere(
      (call) => call.$1 == 'prompt.submit',
    );
    expect(submit.$2['session_id'], 'runtime-new');
    expect(submit.$2['confirm_truncate'], isTrue);
  });

  test(
    'switching sticky profile clears session context and refreshes target data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final gateway = _ProfileGateway();
      final connection = _ProfileConnection(apiClient: api, gw: gateway);
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(() {
        store.dispose();
        connection.dispose();
      });

      await store.resumeSession('expert-session', profile: 'experts');
      final result = await store.switchActiveProfile('default', listLimit: 20);

      expect(result.active, 'default');
      expect(result.current, 'default');
      expect(store.activeProfile, 'default');
      expect(store.profile, isNull);
      expect(store.durableId, isNull);
      expect(api.configProfiles, ['default']);
      expect(api.sessionProfiles, ['default']);
    },
  );

  test(
    'failed profile activation preserves the old UI and open session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi()..failingActivations.add('default');
      final gateway = _ProfileGateway();
      final connection = _ProfileConnection(apiClient: api, gw: gateway);
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(() {
        store.dispose();
        connection.dispose();
      });

      await store.loadProfileContext(listLimit: 20);
      await store.resumeSession('expert-session', profile: 'experts');

      await expectLater(
        store.switchActiveProfile('default', listLimit: 20),
        throwsStateError,
      );

      expect(store.activeProfile, 'experts');
      expect(store.sessionListProfile, 'experts');
      expect(store.durableId, 'expert-session');
      expect(store.profile, 'experts');
      expect(
        gateway.calls.where((call) => call.$1 == 'session.close'),
        isEmpty,
      );
    },
  );

  test('external active profile deletion closes its open session', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _SwitchProfileApi();
    final gateway = _ProfileGateway();
    final connection = _ProfileConnection(apiClient: api, gw: gateway);
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(() {
      store.dispose();
      connection.dispose();
    });

    await store.loadProfileContext(listLimit: 20);
    await store.resumeSession('expert-session', profile: 'experts');
    api
      ..availableProfiles = const [ProfileInfo(name: 'default')]
      ..active = '';
    final payload = ProfilesPayload(
      profiles: api.availableProfiles,
      active: null,
      current: 'default',
      source: 'upstream',
    );

    await store.syncProfilesFromBackend(payload, api);

    expect(store.durableId, isNull);
    expect(store.profile, isNull);
    expect(store.activeProfile, isNull);
    expect(store.sessionListProfile, isNull);
    expect(
      gateway.calls.where((call) => call.$1 == 'session.close'),
      hasLength(1),
    );
  });

  test('post-activation failure reconciles UI to backend profile', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _SwitchProfileApi()..failingConfigs.add('default');
    final gateway = _ProfileGateway();
    final connection = _ProfileConnection(apiClient: api, gw: gateway);
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(() {
      store.dispose();
      connection.dispose();
    });
    await store.loadProfileContext(listLimit: 20);
    await store.resumeSession('expert-session', profile: 'experts');

    await expectLater(
      store.switchActiveProfile('default', listLimit: 20),
      throwsStateError,
    );

    expect(api.active, 'default');
    expect(store.activeProfile, 'default');
    expect(store.sessionListProfile, 'default');
    expect(store.durableId, isNull);
    expect(store.profileConfig, isEmpty);
  });

  test('partial batch deletion keeps a current session that failed', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _SwitchProfileApi()
      ..batchDeleteResult = {
        'deleted': ['other-session'],
        'failed': [
          {'id': 'expert-session', 'error': 'busy'},
        ],
      };
    final gateway = _ProfileGateway();
    final connection = _ProfileConnection(apiClient: api, gw: gateway);
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(() {
      store.dispose();
      connection.dispose();
    });
    await store.resumeSession('expert-session', profile: 'experts');

    await expectLater(
      store.deleteSessions(['expert-session', 'other-session']),
      throwsStateError,
    );

    expect(store.durableId, 'expert-session');
    expect(store.profile, 'experts');
  });

  test(
    'session events and reconnects preserve the active list profile',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final gateway = _ProfileGateway();
      final connection = _ProfileConnection(apiClient: api, gw: gateway);
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(() {
        store.dispose();
        connection.dispose();
      });

      await store.loadProfileContext(listLimit: 20);
      api.sessionProfiles.clear();
      connection.eventController.add(
        GatewayEvent(type: 'sessions.changed', payload: const {}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      connection.reconnectController.add(null);
      await pumpEventQueue();

      expect(api.sessionProfiles, ['experts', 'experts']);
    },
  );

  test('profile switch publishes only consistent scoped snapshots', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _SwitchProfileApi();
    final connection = ConnectionStore()..api = api;
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(() {
      store.dispose();
      connection.dispose();
    });

    await store.loadProfileContext(listLimit: 20);
    final snapshots = <(String?, String?, String?)>[];
    store.addListener(() {
      snapshots.add((
        store.activeProfile,
        store.sessionListProfile,
        store.profileConfig['profile']?.toString(),
      ));
    });

    await store.switchActiveProfile('default', listLimit: 20);

    expect(snapshots, [('default', 'default', 'default')]);
  });

  test(
    'rapid profile switches are serialized so the latest intent wins',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final first = Completer<void>();
      api.activationGates['default'] = first;
      final connection = ConnectionStore()..api = api;
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(() {
        store.dispose();
        connection.dispose();
      });

      final defaultSwitch = store.switchActiveProfile('default', listLimit: 20);
      await Future<void>.delayed(Duration.zero);
      final expertsSwitch = store.switchActiveProfile('experts', listLimit: 20);
      first.complete();
      await Future.wait([defaultSwitch, expertsSwitch]);

      expect(api.activations, ['default', 'experts']);
      expect(store.activeProfile, 'experts');
      expect(store.profileConfig['profile'], 'experts');
      expect(api.sessionProfiles.last, 'experts');
    },
  );

  test(
    'profile switch keeps target rows when a background refresh starts later',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final defaultGate = Completer<void>();
      api.sessionGates['default:0'] = defaultGate;
      final connection = ConnectionStore()..api = api;
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(() {
        store.dispose();
        connection.dispose();
      });

      await store.loadProfileContext(listLimit: 20);
      final switching = store.switchActiveProfile('default', listLimit: 20);
      while (!api.sessionProfiles.contains('default')) {
        await Future<void>.delayed(Duration.zero);
      }
      final backgroundRefresh = store.refreshList(limit: 20);
      await Future<void>.delayed(Duration.zero);
      defaultGate.complete();
      await Future.wait([switching, backgroundRefresh]);

      expect(store.activeProfile, 'default');
      expect(store.sessionListProfile, 'default');
      expect(store.sessions, isNotEmpty);
      expect(store.sessions!.every((row) => row.profile == 'default'), isTrue);
    },
  );

  test('old profile pagination cannot merge into the switched list', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _SwitchProfileApi()..profilesWithMore.add('experts');
    final expertsPageGate = Completer<void>();
    api.sessionGates['experts:1'] = expertsPageGate;
    final connection = ConnectionStore()..api = api;
    final store = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(() {
      store.dispose();
      connection.dispose();
    });

    await store.loadProfileContext(listLimit: 20);
    final loadingMore = store.loadMoreSessions();
    while (api.sessionProfiles.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    await store.switchActiveProfile('default', listLimit: 20);
    expertsPageGate.complete();
    await loadingMore;

    expect(store.sessionListProfile, 'default');
    expect(store.sessions!.map((row) => row.id), ['default-0']);
    expect(store.sessions!.every((row) => row.profile == 'default'), isTrue);
  });

  test(
    'scoped refresh failure does not publish the shared session cache',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _SwitchProfileApi();
      final connection = ConnectionStore()..api = api;
      final store = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      addTearDown(() {
        store.dispose();
        connection.dispose();
      });

      await store.refreshList();
      await pumpEventQueue();
      store.clearSessionList(notify: false);
      api.failingSessionRequests.add('default:0');

      await store.refreshList(profile: 'default');

      expect(store.sessionListProfile, 'default');
      expect(store.sessions, anyOf(isNull, isEmpty));
    },
  );

  test('late close of session A does not reset opened session B', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _RaceApi();
    final gateway = _RaceGateway();
    final closeGate = Completer<void>();
    gateway.gates['session.close:runtime-a'] = closeGate;
    final connection = _ProfileConnection(apiClient: api, gw: gateway);
    final chat = ChatStore();
    final store = SessionStore(
      connection: connection,
      chat: chat,
      requests: RequestStore(),
    );
    addTearDown(() {
      if (!closeGate.isCompleted) closeGate.complete();
      store.dispose();
      connection.dispose();
    });

    await store.resumeSession('a', profile: 'experts');
    final closing = store.closeSession();
    await Future<void>.delayed(Duration.zero);
    await store.resumeSession('b', profile: 'default');
    closeGate.complete();
    await closing;

    expect(store.durableId, 'b');
    expect(store.runtimeId, 'runtime-b');
    expect(store.profile, 'default');
  });

  test(
    'late transcript A cannot overwrite B and keeps captured profile',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = _RaceApi();
      final gateway = _RaceGateway();
      final aGate = Completer<void>();
      api.messageGates['a'] = aGate;
      final connection = _ProfileConnection(apiClient: api, gw: gateway);
      final chat = ChatStore();
      final store = SessionStore(
        connection: connection,
        chat: chat,
        requests: RequestStore(),
      );
      addTearDown(() {
        if (!aGate.isCompleted) aGate.complete();
        store.dispose();
        connection.dispose();
      });

      final openingA = store.resumeSession('a', profile: 'experts');
      while (!api.calls.any((call) => call.$1.endsWith('/a/messages'))) {
        await Future<void>.delayed(Duration.zero);
      }
      await store.resumeSession('b', profile: 'default');
      aGate.complete();
      await openingA;

      expect(chat.messages.single.fullText, 'b/default');
      final aCalls = api.calls.where((call) => call.$1.contains('/sessions/a'));
      expect(aCalls.every((call) => call.$2?['profile'] == 'experts'), isTrue);
    },
  );

  test('older pages keep using the resumed session profile', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _ProfileApi(messageCount: 51);
    final gateway = _ProfileGateway();
    final connection = _ProfileConnection(apiClient: api, gw: gateway);
    final chat = ChatStore();
    final store = SessionStore(
      connection: connection,
      chat: chat,
      requests: RequestStore(),
    );
    addTearDown(() {
      store.dispose();
      connection.dispose();
    });

    await store.resumeSession('expert-session', profile: 'experts');
    await store.loadOlderMessages();

    expect(api.calls.last.$1, '/api/v1/sessions/expert-session/messages');
    expect(api.calls.last.$2, {
      'limit': '1',
      'offset': '0',
      'profile': 'experts',
    });
    expect(chat.messages.first.fullText, 'older expert history');
  });
}
