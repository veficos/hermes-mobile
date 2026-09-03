import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/bot_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/runtime_l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnection extends ConnectionStore {
  final List<(String, Map<String, dynamic>)> calls = [];
  final List<(OwnerRoute, String, Map<String, dynamic>)> ownerCalls = [];
  final StreamController<RoutedGatewayEvent> routed =
      StreamController<RoutedGatewayEvent>.broadcast();
  final Map<
    String,
    FutureOr<Map<String, dynamic>> Function(Map<String, dynamic>)
  >
  handlers = {};

  @override
  Stream<RoutedGatewayEvent> get routedEvents => routed.stream;

  void emit(
    GatewayEvent event, {
    OwnerRoute route = const OwnerRoute(connectionId: ConnectionId('remote')),
  }) {
    routed.add(
      RoutedGatewayEvent(route: route, socketGeneration: 1, event: event),
    );
  }

  @override
  Future<Map<String, dynamic>> requestForOwner(
    OwnerRoute route,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    ownerCalls.add((route, method, params));
    final handler = handlers[method];
    if (handler == null) throw StateError('unexpected $method');
    return await handler(params);
  }
}

typedef _ReplyFor = String Function(String profile, int turn, String prompt);

Future<
  ({
    _FakeConnection connection,
    BotStore store,
    BotGroup group,
    BotIdentity researcher,
    BotIdentity writer,
    List<String> submitOrder,
  })
>
_groupHarness(_ReplyFor replyFor) async {
  final connection = _FakeConnection();
  final runtimeProfiles = <String, String>{};
  final storedRuntimes = <String, String>{};
  final messages = <String, List<Map<String, dynamic>>>{};
  final submitOrder = <String>[];
  var turn = 0;
  connection.handlers['session.list'] = (_) => {'sessions': const []};
  connection.handlers['session.create'] = (params) {
    final profile = params['profile'].toString();
    final runtime = 'runtime-$profile';
    final stored = 'stored-$profile';
    runtimeProfiles[runtime] = profile;
    storedRuntimes[stored] = runtime;
    messages.putIfAbsent(runtime, () => []);
    return {'stored_session_id': stored, 'session_id': runtime};
  };
  connection.handlers['prompt.submit'] = (params) async {
    final runtime = params['session_id'].toString();
    final profile = runtimeProfiles[runtime]!;
    submitOrder.add(profile);
    turn += 1;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    messages[runtime]!.add({
      'role': 'assistant',
      'content': replyFor(profile, turn, params['text'].toString()),
    });
    return <String, dynamic>{};
  };
  connection.handlers['session.resume'] = (params) {
    final requested = params['session_id'].toString();
    final runtime = storedRuntimes[requested] ?? requested;
    return {
      'session_id': runtime,
      'running': false,
      'messages': List<Map<String, dynamic>>.from(
        messages[runtime] ?? const [],
      ),
    };
  };
  connection.handlers['session.stop'] = (_) => <String, dynamic>{};
  final researcher = BotIdentity(
    route: const OwnerRoute(
      connectionId: ConnectionId('remote'),
      profile: 'researcher',
    ),
    profile: 'researcher',
    displayName: 'Researcher',
  );
  final writer = BotIdentity(
    route: const OwnerRoute(
      connectionId: ConnectionId('remote'),
      profile: 'writer',
    ),
    profile: 'writer',
    displayName: 'Writer',
  );
  final store = BotStore(connection)..bots = [researcher, writer];
  final group = await store.createGroup('Team', [researcher, writer]);
  return (
    connection: connection,
    store: store,
    group: group,
    researcher: researcher,
    writer: writer,
    submitOrder: submitOrder,
  );
}

class _UploadApi extends ApiClient {
  final List<String> uploads = [];

  _UploadApi() : super(baseUrl: 'http://remote.invalid', apiKey: 'test-key');

  @override
  Future<Map<String, dynamic>> uploadFile(String path, String dataUrl) async {
    uploads.add(path);
    return {'path': '/remote$path'};
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final route = OwnerRoute(
    connectionId: const ConnectionId('remote'),
    profile: 'researcher',
  );
  final bot = BotIdentity(
    route: route,
    profile: 'researcher',
    displayName: 'Researcher',
  );

  test(
    'canonical Bot Chat is found by exact hidden title and resolved tip',
    () async {
      final connection = _FakeConnection();
      connection.handlers['session.list'] = (_) => {
        'sessions': [
          {
            'id': 'root',
            'resolved_id': 'tip',
            'root_title': canonicalBotChatTitle,
          },
        ],
      };
      final store = BotStore(connection);
      addTearDown(store.dispose);

      expect(await store.ensureCanonicalChat(bot), 'tip');
      expect(connection.calls.single.$2['include_hidden'], true);
      expect(connection.calls.single.$2['title'], canonicalBotChatTitle);
      expect(
        connection.calls.where((call) => call.$1 == 'session.create'),
        isEmpty,
      );
    },
  );

  test('canonical creation is single-flight and born hidden', () async {
    final connection = _FakeConnection();
    final gate = Completer<Map<String, dynamic>>();
    connection.handlers['session.list'] = (_) => gate.future;
    connection.handlers['session.create'] = (_) => {
      'stored_session_id': 'stored',
      'session_id': 'runtime',
    };
    connection.handlers['session.title'] = (_) => <String, dynamic>{};
    final store = BotStore(connection);
    addTearDown(store.dispose);

    final first = store.ensureCanonicalChat(bot);
    final second = store.ensureCanonicalChat(bot);
    gate.complete({'sessions': const []});
    expect(await Future.wait([first, second]), ['stored', 'stored']);
    expect(
      connection.calls.where((call) => call.$1 == 'session.list').length,
      1,
    );
    final create = connection.calls.singleWhere(
      (call) => call.$1 == 'session.create',
    );
    expect(create.$2['hidden'], true);
    expect(create.$2['title'], canonicalBotChatTitle);
  });

  test('registry lookup failure fails closed and never creates', () async {
    final connection = _FakeConnection();
    connection.handlers['session.list'] = (_) => throw StateError('offline');
    final store = BotStore(connection);
    addTearDown(store.dispose);

    await expectLater(store.ensureCanonicalChat(bot), throwsStateError);
    expect(
      connection.calls.where((call) => call.$1 == 'session.create'),
      isEmpty,
    );
  });

  test('@mention targets one group member and stop closes the turn', () async {
    final connection = _FakeConnection();
    var sequence = 0;
    connection.handlers['session.list'] = (_) => {'sessions': const []};
    connection.handlers['session.create'] = (params) {
      sequence++;
      return {
        'stored_session_id': 'stored-$sequence',
        'session_id': 'runtime-$sequence',
      };
    };
    connection.handlers['prompt.submit'] = (_) => <String, dynamic>{};
    connection.handlers['session.stop'] = (_) => <String, dynamic>{};
    final writer = BotIdentity(
      route: const OwnerRoute(
        connectionId: ConnectionId('remote'),
        profile: 'writer',
      ),
      profile: 'writer',
      displayName: 'Writer',
    );
    final store = BotStore(connection)..bots = [bot, writer];
    addTearDown(store.dispose);
    final group = await store.createGroup('Team', [bot, writer]);

    await store.sendGroupPrompt(group, '@Researcher investigate this');

    expect(
      connection.calls.where((call) => call.$1 == 'prompt.submit').length,
      1,
    );
    expect(
      connection.calls
          .singleWhere((call) => call.$1 == 'session.create')
          .$2['profile'],
      'researcher',
    );
    expect(store.isGroupBusy(group.id), isTrue);

    await store.stopGroup(group);
    expect(store.isGroupBusy(group.id), isFalse);
    expect(
      connection.calls.where((call) => call.$1 == 'session.stop').length,
      1,
    );
  });

  test(
    'group attachments upload once per connection and use chat refs',
    () async {
      final connection = _FakeConnection();
      final api = _UploadApi();
      connection.registry.add(
        ConnectionRuntime(
          id: const ConnectionId('remote'),
          settings: ConnectionSettings(
            serverUrl: 'http://remote.invalid',
            apiKey: 'test-key',
          ),
          api: api,
          gateway: GatewayClient(
            serverBaseUrl: 'http://remote.invalid',
            apiKey: 'test-key',
          ),
        ),
        makeActive: true,
      );
      connection.handlers['session.list'] = (_) => {'sessions': const []};
      var sequence = 0;
      connection.handlers['session.create'] = (_) => {
        'stored_session_id': 'stored-${++sequence}',
        'session_id': 'runtime-$sequence',
      };
      connection.handlers['prompt.submit'] = (_) => <String, dynamic>{};
      connection.handlers['session.resume'] = (params) => {
        'session_id': params['session_id'],
        'running': false,
        'messages': const [
          {'role': 'assistant', 'content': '(pass)'},
        ],
      };
      final writer = BotIdentity(
        route: const OwnerRoute(
          connectionId: ConnectionId('remote'),
          profile: 'writer',
        ),
        profile: 'writer',
        displayName: 'Writer',
      );
      final store = BotStore(connection)..bots = [bot, writer];
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      final group = await store.createGroup('Team', [bot, writer]);

      await store.sendGroupPrompt(
        group,
        'review these',
        attachments: const [
          BotGroupAttachment(
            name: 'screen.png',
            dataUrl: 'data:image/png;base64,AA==',
            image: true,
          ),
          BotGroupAttachment(
            name: 'notes.txt',
            dataUrl: 'data:text/plain;base64,QQ==',
          ),
        ],
      );
      await _waitUntil(() => !store.isGroupBusy(group.id));

      expect(api.uploads, hasLength(2));
      final prompts = connection.calls
          .where((call) => call.$1 == 'prompt.submit')
          .map((call) => call.$2['text'].toString())
          .toList();
      expect(prompts, hasLength(2));
      expect(prompts, everyElement(contains('@image:/remote/hm-attachments/')));
      expect(prompts, everyElement(contains('[Attached files: /remote/')));
      expect(store.messagesFor(group.id).single.text, contains('screen.png'));
    },
  );

  test(
    'group rounds are serial, rotate speakers and stop after three rounds',
    () async {
      final harness = await _groupHarness(
        (profile, turn, prompt) => '$profile result $turn',
      );
      addTearDown(harness.store.dispose);

      await harness.store.sendGroupPrompt(harness.group, 'solve this together');
      await _waitUntil(() => !harness.store.isGroupBusy(harness.group.id));

      expect(harness.submitOrder, [
        'researcher',
        'writer',
        'researcher',
        'writer',
      ]);
      final replies = harness.store
          .messagesFor(harness.group.id)
          .where((message) => message.author != 'You' && message.author != 'System')
          .toList();
      expect(replies, hasLength(4));
      expect(replies.map((message) => message.author), [
        'Researcher',
        'Writer',
        'Researcher',
        'Writer',
      ]);
      // Every round kept producing new replies (thanks to the interleaved
      // watermark ordering), so the loop only stops because it exhausted its
      // round budget. That case must be visible to the user, not silent.
      final last = harness.store.messagesFor(harness.group.id).last;
      expect(last.author, 'System');
      expect(last.text, RuntimeL10n.current.botGroupRoundCapReached);
    },
  );

  test('(pass) settles the room without posting bot messages', () async {
    final harness = await _groupHarness((profile, turn, prompt) => '(pass)');
    addTearDown(harness.store.dispose);

    await harness.store.sendGroupPrompt(harness.group, 'status?');
    await _waitUntil(() => !harness.store.isGroupBusy(harness.group.id));

    expect(harness.submitOrder, ['researcher', 'writer']);
    expect(harness.store.messagesFor(harness.group.id), hasLength(1));
  });

  test('bot mention pulls a teammate into the following round', () async {
    final harness = await _groupHarness((profile, turn, prompt) {
      if (turn == 1) return '@Writer please verify';
      return '(pass)';
    });
    addTearDown(harness.store.dispose);

    await harness.store.sendGroupPrompt(
      harness.group,
      '@Researcher investigate',
    );
    await _waitUntil(() => !harness.store.isGroupBusy(harness.group.id));

    expect(harness.submitOrder, ['researcher', 'writer']);
  });

  test('stop mention holds a member and direct mention releases it', () async {
    final harness = await _groupHarness((profile, turn, prompt) => '(pass)');
    addTearDown(harness.store.dispose);

    await harness.store.sendGroupPrompt(harness.group, '@Researcher stop');
    await _waitUntil(() => !harness.store.isGroupBusy(harness.group.id));
    expect(
      harness.store.isMemberHeld(harness.group.id, harness.researcher.key),
      isTrue,
    );
    expect(harness.submitOrder, isEmpty);

    await harness.store.sendGroupPrompt(harness.group, '@Researcher continue');
    await _waitUntil(() => !harness.store.isGroupBusy(harness.group.id));
    expect(
      harness.store.isMemberHeld(harness.group.id, harness.researcher.key),
      isFalse,
    );
    expect(harness.submitOrder, ['researcher']);
  });

  test('thread watermarks do not leak messages into another thread', () async {
    final prompts = <String>[];
    final harness = await _groupHarness((profile, turn, prompt) {
      prompts.add(prompt);
      return '(pass)';
    });
    addTearDown(harness.store.dispose);

    await harness.store.sendGroupPrompt(
      harness.group,
      'alpha secret',
      threadId: 'alpha',
    );
    await _waitUntil(() => !harness.store.isGroupBusy(harness.group.id));
    final before = prompts.length;
    await harness.store.sendGroupPrompt(
      harness.group,
      'beta task',
      threadId: 'beta',
    );
    await _waitUntil(() => !harness.store.isGroupBusy(harness.group.id));

    expect(prompts.skip(before), everyElement(contains('beta task')));
    expect(prompts.skip(before), everyElement(isNot(contains('alpha secret'))));
  });

  test(
    'clarify and approval requests are mirrored and routed to their owner',
    () async {
      final connection = _FakeConnection();
      connection.handlers['session.list'] = (_) => {'sessions': const []};
      connection.handlers['session.create'] = (_) => {
        'stored_session_id': 'stored-r',
        'session_id': 'runtime-r',
      };
      connection.handlers['prompt.submit'] = (_) => <String, dynamic>{};
      connection.handlers['clarify.respond'] = (_) => <String, dynamic>{};
      connection.handlers['approval.respond'] = (_) => <String, dynamic>{};
      final writer = BotIdentity(
        route: const OwnerRoute(
          connectionId: ConnectionId('remote'),
          profile: 'writer',
        ),
        profile: 'writer',
        displayName: 'Writer',
      );
      final store = BotStore(connection)..bots = [bot, writer];
      addTearDown(store.dispose);
      final group = await store.createGroup('Team', [bot, writer]);
      await store.sendGroupPrompt(group, '@Researcher investigate');

      connection.emit(
        GatewayEvent(
          type: 'clarify.request',
          sessionId: 'runtime-r',
          profile: 'researcher',
          payload: {
            'request_id': 'clarify-1',
            'questions': [
              {
                'id': 'scope',
                'question': 'Which scope?',
                'choices': ['A', 'B'],
              },
            ],
          },
        ),
        route: route,
      );
      await _waitUntil(() => store.pendingRequestsFor(group.id).isNotEmpty);
      final clarify = store.pendingRequestsFor(group.id).single;
      await store.respondToGroupRequest(clarify, answers: const {'scope': 'A'});
      final clarifyCall = connection.ownerCalls.lastWhere(
        (call) => call.$2 == 'clarify.respond',
      );
      expect(clarifyCall.$1, route);
      expect(clarifyCall.$3['question_id'], 'scope');

      connection.emit(
        GatewayEvent(
          type: 'approval.request',
          sessionId: 'runtime-r',
          profile: 'researcher',
          payload: {
            'request_id': 'approval-1',
            'command': 'deploy',
            'choices': ['once', 'deny'],
          },
        ),
        route: route,
      );
      await _waitUntil(() => store.pendingRequestsFor(group.id).isNotEmpty);
      final approval = store.pendingRequestsFor(group.id).single;
      await store.respondToGroupRequest(approval, choice: 'once');
      final approvalCall = connection.ownerCalls.lastWhere(
        (call) => call.$2 == 'approval.respond',
      );
      expect(approvalCall.$1, route);
      expect(approvalCall.$3['choice'], 'once');

      connection.emit(
        GatewayEvent(
          type: 'message.complete',
          sessionId: 'runtime-r',
          payload: const {'text': '(pass)'},
        ),
        route: route,
      );
      await _waitUntil(() => !store.isGroupBusy(group.id));
    },
  );

  test('server projection stays below the conservative 48KB cap', () async {
    final connection = _FakeConnection();
    final rooms = <String, dynamic>{};
    for (var room = 0; room < 80; room++) {
      rooms['id:room-$room'] = {
        'name': 'Room $room',
        'roomId': 'room-$room',
        'revision': 1,
        'members': [
          {'name': 'researcher', 'connectionId': 'remote'},
          {'name': 'writer', 'connectionId': 'remote'},
        ],
        'log': [
          for (var message = 0; message < 16; message++)
            {
              'id': '$room-$message',
              'from': {'kind': 'member', 'name': 'Bot'},
              'text': List.filled(800, '界').join(),
              'at': room * 100 + message,
              'thread': 'thread-$room',
            },
        ],
      };
    }
    connection.handlers['profiles.list'] = (_) => {
      'profiles': [
        {
          'name': 'default',
          'ui_meta': {
            'hermes-bots-groups': {
              'version': 3,
              'rooms': rooms,
              'deleted': const {},
            },
          },
        },
      ],
    };
    final store = BotStore(connection);
    addTearDown(store.dispose);
    connection.registry.add(
      ConnectionRuntime(
        id: const ConnectionId('remote'),
        settings: const ConnectionSettings(),
        api: _UploadApi(),
        gateway: GatewayClient(serverBaseUrl: 'http://invalid', apiKey: 'x'),
      ),
      makeActive: true,
    );

    await store.refresh();

    expect(store.debugServerSnapshotBytes(), lessThanOrEqualTo(48000));
    final projectedRooms = store.debugServerSnapshot()['rooms'] as Map;
    expect(projectedRooms.length, lessThan(rooms.length));
  });

  test(
    'server sync retries a CAS conflict and verifies applied revision',
    () async {
      final connection = _FakeConnection();
      var revision = 4;
      var configureCalls = 0;
      connection.handlers['profiles.list'] = (_) => {
        'profiles': [
          {
            'name': 'default',
            'ui_meta': const {'hermes-bots-groups': <String, dynamic>{}},
            'ui_meta_revisions': {'hermes-bots-groups': revision},
          },
        ],
      };
      connection.handlers['profiles.configure'] = (params) {
        configureCalls += 1;
        if (configureCalls == 1) {
          revision += 1;
          return {
            'applied': {
              'ui_meta': false,
              'ui_meta_revisions': {'hermes-bots-groups': revision},
            },
          };
        }
        revision += 1;
        return {
          'applied': {
            'ui_meta': true,
            'ui_meta_revisions': {'hermes-bots-groups': revision},
          },
        };
      };
      connection.registry.add(
        ConnectionRuntime(
          id: const ConnectionId('remote'),
          settings: const ConnectionSettings(),
          api: _UploadApi(),
          gateway: GatewayClient(serverBaseUrl: 'http://invalid', apiKey: 'x'),
        ),
        makeActive: true,
      );
      final store = BotStore(connection)..bots = [bot];
      addTearDown(store.dispose);
      await store.debugSyncServerState(allowEmpty: true);

      expect(configureCalls, 2);
      final configs = connection.calls
          .where((call) => call.$1 == 'profiles.configure')
          .toList();
      expect(configs.last.$2['ui_meta_expected_revisions'], {
        'hermes-bots-groups': 5,
      });
    },
  );

  test('duplicate bot uses target profiles.create with clone_from', () async {
    final connection = _FakeConnection();
    connection.handlers['profiles.create'] = (_) => {'ok': true};
    final store = BotStore(connection)..bots = [bot];
    addTearDown(store.dispose);

    await store.duplicateBot(bot);

    final call = connection.calls.first;
    expect(call.$1, 'profiles.create');
    expect(call.$2['name'], 'researcher-2');
    expect(call.$2['clone_from'], 'researcher');
  });

  test(
    'scoped routine list trusts the profile-scoped gateway result',
    () async {
      final connection = _FakeConnection();
      connection.handlers['cron.manage'] = (params) => {
        'scoped': 'researcher',
        'jobs': [
          {
            'job_id': 'plain',
            'name': 'Server scoped task',
            'schedule': 'every 1h',
            'prompt_preview': 'Inspect the queue',
          },
          {
            'job_id': 'tagged-elsewhere',
            'name': '[bot:writer] Legacy-looking task',
            'schedule': '0 9 * * *',
          },
        ],
      };
      final store = BotStore(connection);
      addTearDown(store.dispose);

      final routines = await store.listBotRoutines(bot);

      expect(routines.map((routine) => routine.id), [
        'plain',
        'tagged-elsewhere',
      ]);
      expect(connection.ownerCalls.single.$1, route);
      expect(connection.ownerCalls.single.$3, {
        'action': 'list',
        'include_disabled': true,
        'profile': 'researcher',
      });
    },
  );

  test(
    'legacy unscoped routine list filters tags to the selected bot',
    () async {
      final connection = _FakeConnection();
      connection.handlers['cron.manage'] = (_) => {
        'jobs': [
          {
            'job_id': 'mine',
            'name': '[bot:researcher] Mine',
            'schedule': 'every 1h',
          },
          {
            'job_id': 'other',
            'name': '[bot:writer] Other',
            'schedule': 'every 1h',
          },
          {'job_id': 'default', 'name': 'Untagged', 'schedule': 'every 1h'},
        ],
      };
      final store = BotStore(connection);
      addTearDown(store.dispose);

      final routines = await store.listBotRoutines(bot);

      expect(routines.map((routine) => routine.id), ['mine']);
      expect(routines.single.title, 'Mine');
    },
  );

  test('legacy shell-delegated bot routine is paused before display', () async {
    final connection = _FakeConnection();
    connection.handlers['cron.manage'] = (params) {
      if (params['action'] == 'pause') return {'ok': true};
      return {
        'jobs': [
          {
            'job_id': 'unsafe',
            'name': '[bot:researcher] Old delegation',
            'schedule': '0 9 * * *',
            'enabled': true,
            'prompt_preview':
                'You are running the scheduled routine "Old delegation". Use shell delegation.',
          },
        ],
      };
    };
    final store = BotStore(connection);
    addTearDown(store.dispose);

    final routines = await store.listBotRoutines(bot);

    expect(routines.single.legacyUnsafe, true);
    expect(routines.single.active, false);
    final pause = connection.ownerCalls.last;
    expect(pause.$1, route);
    expect(pause.$2, 'cron.manage');
    expect(pause.$3, {
      'action': 'pause',
      'name': 'unsafe',
      'profile': 'researcher',
    });
  });

  test('bot routine add preserves scope and delivery options', () async {
    final connection = _FakeConnection();
    connection.handlers['cron.manage'] = (_) => {'ok': true};
    final store = BotStore(connection);
    addTearDown(store.dispose);

    await store.createBotRoutine(
      bot,
      const BotRoutineDraft(
        title: '  Morning brief  ',
        instruction: '  Review overnight alerts  ',
        schedule: '  0 9 * * 1-5  ',
        repeat: 8,
        continuity: true,
        deliverToBotChat: true,
      ),
    );

    expect(connection.ownerCalls.single.$1, route);
    expect(connection.ownerCalls.single.$3, {
      'action': 'add',
      'name': '[bot:researcher] Morning brief',
      'schedule': '0 9 * * 1-5',
      'prompt': 'Review overnight alerts',
      'profile': 'researcher',
      'repeat': 8,
      'continuity': true,
      'deliver': 'bot-chat',
    });
  });

  test('routine mutations remain on the bot owner route', () async {
    final connection = _FakeConnection();
    connection.handlers['cron.manage'] = (_) => {'ok': true};
    final store = BotStore(connection);
    addTearDown(store.dispose);

    for (final action in ['pause', 'resume', 'remove']) {
      await store.mutateBotRoutine(bot, 'routine-1', action);
    }

    expect(connection.ownerCalls.map((call) => call.$1), everyElement(route));
    expect(connection.ownerCalls.map((call) => call.$3['action']), [
      'pause',
      'resume',
      'remove',
    ]);
    expect(
      connection.ownerCalls.map((call) => call.$3['profile']),
      everyElement('researcher'),
    );
  });

  test('routine validation rejects empty and NUL-bearing fields', () async {
    final connection = _FakeConnection();
    final store = BotStore(connection);
    addTearDown(store.dispose);

    for (final draft in [
      const BotRoutineDraft(title: '', instruction: 'work', schedule: '1h'),
      const BotRoutineDraft(title: 'name', instruction: '', schedule: '1h'),
      const BotRoutineDraft(title: 'name', instruction: 'work', schedule: ''),
      const BotRoutineDraft(
        title: 'name',
        instruction: 'work',
        schedule: 'every\u00001h',
      ),
    ]) {
      await expectLater(
        store.createBotRoutine(bot, draft),
        throwsArgumentError,
      );
    }
    await expectLater(
      store.mutateBotRoutine(bot, 'routine-1', 'run'),
      throwsArgumentError,
    );
    expect(connection.calls, isEmpty);
  });
}
