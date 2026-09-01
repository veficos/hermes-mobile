/// Tests for the WebUI chat-parity closing batch:
/// - B15: `/retry` local command (gateway dispatch when advertised, else the
///   real rewind+resubmit chain) + send auto-retry once on transport errors.
/// - C2: `/clear` local command (gateway dispatch when advertised, else the
///   WebUI `cmdClear` view-only clear).
/// - A18: saved prompt snippets (server-backed `/api/v1/prompts`).
/// - A15: session-scoped toolsets via gateway `toolsets.list` /
///   `tools.configure` with session_id.
/// - A14: full reasoning effort ladder (none…max).
/// - A16: ambient provider quota chip, rendered only with real backend data.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fakes

class _FakeGateway extends GatewayClient {
  _FakeGateway() : super(serverBaseUrl: 'http://contract.invalid', apiKey: 't');

  final List<(String, Map<String, dynamic>)> calls = [];
  Map<String, dynamic> commandsCatalog = const {};
  Map<String, dynamic> slashCompletion = const {};
  Map<String, dynamic>? slashExecResult;

  /// When > 0, the next `prompt.submit` calls fail with this transport error.
  int failNextSubmits = 0;

  /// When set, every `prompt.submit` fails with this error (business error).
  Object? submitError;

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    calls.add((method, params));
    switch (method) {
      case 'session.create':
        return Future.value({
          'session_id': 'rt-1',
          'stored_session_id': 'sid-1',
        });
      case 'commands.catalog':
        return Future.value(commandsCatalog);
      case 'complete.slash':
        return Future.value(slashCompletion);
      case 'slash.exec':
        return Future.value(slashExecResult ?? const <String, dynamic>{});
      case 'prompt.submit':
        final error = submitError;
        if (error != null) return Future.error(error);
        if (failNextSubmits > 0) {
          failNextSubmits--;
          return Future.error(
            GatewayException(-1, 'gateway disconnected: boom'),
          );
        }
        return Future.value({'status': 'streaming'});
      case 'toolsets.list':
        return Future.value({
          'toolsets': [
            {'name': 'fs', 'enabled': true, 'tool_count': 5},
            {'name': 'web', 'enabled': false, 'tool_count': 3},
            {'name': 'debugging', 'enabled': false, 'tool_count': 7},
          ],
        });
      default:
        return Future.value(<String, dynamic>{});
    }
  }
}

class _FakeConnection extends ConnectionStore {
  _FakeConnection(_FakeGateway gw, ApiClient apiClient) {
    gateway = gw;
    api = apiClient;
  }

  @override
  Future<void> ensureConnected() async {}
}

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://contract.invalid', apiKey: 't');

  List<SavedPrompt> prompts = [
    SavedPrompt(id: 'p1', label: '代码评审', text: '请评审这段代码'),
  ];
  final List<String> savedTexts = [];
  final List<String> deletedPromptIds = [];
  final List<Map<String, dynamic>> configPatches = [];
  final List<bool> quotaRefreshCalls = [];
  final List<(String, bool)> toolsetToggles = [];
  Map<String, dynamic>? quotaStatus = {
    'status': 'available',
    'quota': {'limit_remaining': 3.5, 'usage': 1.5, 'limit': 5.0},
    'message': 'OpenRouter quota status loaded.',
  };

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => const {
    'reasoning': {'effort': 'medium'},
  };

  @override
  Future<void> putConfig(Map<String, dynamic> config, {String? profile}) async {
    configPatches.add(config);
  }

  @override
  Future<ProfilesPayload> listProfiles() async =>
      const ProfilesPayload(profiles: [], active: null, source: 'local');

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [
    ToolsetInfo(name: 'global-web', enabled: false, toolCount: 2),
  ];

  @override
  Future<void> toggleToolset(
    String name,
    bool enabled, {
    String? profile,
  }) async {
    toolsetToggles.add((name, enabled));
  }

  @override
  Future<String> fsDefaultCwd() async => 'D:/work/repo';

  @override
  Future<List<Map<String, dynamic>>> listProjects() async => const [];

  @override
  Future<ComposerDraft> getDraft(String sessionId, {String? profile}) async =>
      const ComposerDraft();

  @override
  Future<ComposerDraft> saveDraft(
    String sessionId, {
    String? text,
    List<dynamic>? files,
    String? profile,
  }) async => const ComposerDraft();

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async => const SessionPage(sessions: [], offset: 0, hasMore: false);

  @override
  Future<List<SavedPrompt>> savedPrompts() async => prompts;

  @override
  Future<SavedPrompt> savePrompt(String text, {String? label}) async {
    savedTexts.add(text);
    final saved = SavedPrompt(
      id: 'p${prompts.length + 1}',
      label: text,
      text: text,
    );
    prompts = [...prompts, saved];
    return saved;
  }

  @override
  Future<void> deletePrompt(String id) async {
    deletedPromptIds.add(id);
    prompts = prompts.where((p) => p.id != id).toList();
  }

  @override
  Future<Map<String, dynamic>> providerQuota({
    String? provider,
    bool refresh = false,
  }) async {
    quotaRefreshCalls.add(refresh);
    final status = quotaStatus;
    if (status == null) throw ApiException(404, 'not found');
    return status;
  }
}

class _ChatRig {
  _ChatRig() : gateway = _FakeGateway(), api = _FakeApi() {
    connection = _FakeConnection(gateway, api);
    chat = ChatStore();
    session = SessionStore(
      connection: connection,
      chat: chat,
      requests: RequestStore(),
    );
  }

  final _FakeGateway gateway;
  final _FakeApi api;
  late final ConnectionStore connection;
  late final ChatStore chat;
  late final SessionStore session;

  Widget app({Locale? locale}) => MultiProvider(
    providers: [
      ChangeNotifierProvider<ConnectionStore>.value(value: connection),
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: chat),
      ChangeNotifierProvider.value(value: VoiceStore(connection: connection)),
      ChangeNotifierProvider.value(value: CommandStore(connection: connection)),
    ],
    child: MaterialApp(
      locale: locale ?? const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(platform: TargetPlatform.linux),
      home: const ChatScreen(),
    ),
  );

  Future<void> sendFirstTurn(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();
    expect(session.durableId, 'sid-1');
  }

  Future<void> sendFromComposer(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
    // While a turn is busy the primary button is the steer icon (WebUI
    // getComposerPrimaryAction); tap whichever is showing.
    final send = find.byIcon(Icons.arrow_upward);
    final target = send.evaluate().isNotEmpty
        ? send
        : find.byIcon(Icons.explore_outlined);
    await tester.tap(target);
    await tester.pump();
    await tester.pump();
  }

  void dispose() {
    session.dispose();
    connection.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('B15 send auto-retry (store level)', () {
    test(
      'retryable transport error retries once and keeps a single bubble',
      () async {
        final rig = _ChatRig();
        rig.gateway.failNextSubmits = 1;
        var retryNoticed = 0;

        await rig.session.sendMessage(
          'hello',
          onAutoRetry: () => retryNoticed++,
        );

        final submits = rig.gateway.calls.where((c) => c.$1 == 'prompt.submit');
        expect(submits, hasLength(2));
        expect(retryNoticed, 1);
        final userBubbles = rig.chat.messages.where((m) => m.role == 'user');
        expect(userBubbles, hasLength(1));
        expect(userBubbles.single.isError, isFalse);
        rig.dispose();
      },
    );

    test('deterministic gateway errors are not retried', () async {
      final rig = _ChatRig();
      // 4009 = session busy: a business error that must surface as-is.
      rig.gateway.submitError = GatewayException(4009, 'session busy');
      var retryNoticed = 0;

      await expectLater(
        rig.session.sendMessage('hello', onAutoRetry: () => retryNoticed++),
        throwsA(isA<GatewayException>()),
      );

      expect(
        rig.gateway.calls.where((c) => c.$1 == 'prompt.submit'),
        hasLength(1),
      );
      expect(retryNoticed, 0);
      expect(rig.chat.messages.single.isError, isTrue);
      rig.dispose();
    });

    test('isRetryableSendError classifies transport vs business errors', () {
      expect(
        isRetryableSendError(GatewayException(-1, 'disconnected')),
        isTrue,
      );
      expect(isRetryableSendError(GatewayException(-2, 'timeout')), isTrue);
      expect(isRetryableSendError(GatewayException(4009, 'busy')), isFalse);
      expect(
        isRetryableSendError(GatewayException(-32601, 'unknown')),
        isFalse,
      );
      expect(isRetryableSendError(StateError('没有活动会话')), isFalse);
      expect(isRetryableSendError(TimeoutException('t')), isTrue);
    });
  });

  group('P0 slash skill contract', () {
    testWidgets('bare slash loads catalog skills under Skills', (tester) async {
      final rig = _ChatRig();
      rig.gateway.commandsCatalog = {
        'categories': [
          {
            'name': 'Session',
            'pairs': [
              ['/new', 'Start a session'],
            ],
          },
        ],
        'pairs': [
          ['/new', 'Start a session'],
          ['/research', 'Research a topic'],
        ],
        'skills': {
          '/research': {'origin': 'local', 'usage': 10},
        },
      };
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '/');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('/research'), findsOneWidget);
      rig.dispose();
    });

    testWidgets('typed skill shows metadata and selection keeps focus', (
      tester,
    ) async {
      final rig = _ChatRig();
      rig.gateway.slashCompletion = {
        'items': [
          {
            'text': '/research',
            'display': '/research',
            'meta': 'Research a topic',
            'group': 'Skills',
          },
        ],
      };
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      final composer = find.byType(TextField).first;
      await tester.enterText(composer, '/res');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('/research'), findsOneWidget);
      expect(find.text('Research a topic'), findsOneWidget);
      await tester.tap(find.text('/research'));
      await tester.pump();

      final field = tester.widget<TextField>(composer);
      expect(field.controller!.text, '/research ');
      expect(field.focusNode!.hasFocus, isTrue);
      rig.dispose();
    });

    testWidgets('argument completion honors replace_from', (tester) async {
      final rig = _ChatRig();
      rig.gateway.slashCompletion = {
        'replace_from': 11,
        'items': [
          {
            'text': 'smart',
            'display': 'smart',
            'meta': '自动判断审批',
            'group': 'Options',
          },
        ],
      };
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      final composer = find.byType(TextField).first;
      await tester.enterText(composer, '/approvals sm');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Options'), findsOneWidget);
      await tester.tap(find.text('smart'));
      await tester.pump();
      expect(
        tester.widget<TextField>(composer).controller!.text,
        '/approvals smart ',
      );
      rig.dispose();
    });

    testWidgets('keyboard arrows and enter accept a slash suggestion', (
      tester,
    ) async {
      final rig = _ChatRig();
      rig.gateway.slashCompletion = {
        'items': [
          {'text': '/first', 'display': '/first'},
          {'text': '/second', 'display': '/second'},
        ],
      };
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      final composer = find.byType(TextField).first;
      await tester.enterText(composer, '/f');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tester.widget<TextField>(composer).controller!.text, '/second ');
      rig.dispose();
    });

    testWidgets(
      'skill dispatch submits expanded prompt instead of invocation',
      (tester) async {
        final rig = _ChatRig();
        rig.gateway.slashExecResult = {
          'type': 'skill',
          'name': 'research',
          'message': 'EXPANDED_SKILL_PROMPT',
          'display': '/research topic',
        };
        await tester.pumpWidget(rig.app());
        await tester.pumpAndSettle();

        await rig.sendFirstTurn(tester, '/research topic');

        final slash = rig.gateway.calls
            .where((c) => c.$1 == 'slash.exec')
            .single;
        expect(slash.$2, {'session_id': 'rt-1', 'command': 'research topic'});
        final submits = rig.gateway.calls.where((c) => c.$1 == 'prompt.submit');
        expect(submits.single.$2['text'], 'EXPANDED_SKILL_PROMPT');
        expect(submits.single.$2['text'], isNot('/research topic'));
        rig.dispose();
      },
    );
  });

  group('B15 /retry local command', () {
    testWidgets('/retry appears in slash suggestions', (tester) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '/r');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // debounce
      await tester.pump();

      expect(find.text('/retry'), findsOneWidget);
      rig.dispose();
    });

    testWidgets(
      'sending /retry reruns the last turn via the real rewind chain',
      (tester) async {
        final rig = _ChatRig();
        await tester.pumpWidget(rig.app());
        await tester.pumpAndSettle();
        await rig.sendFirstTurn(tester, 'first turn');

        await rig.sendFromComposer(tester, '/retry');
        await tester.pumpAndSettle();

        // Catalog is empty in the fake → the rewind+resubmit chain fires:
        // prompt.submit with the same text and a truncate marker.
        final submits = rig.gateway.calls
            .where((c) => c.$1 == 'prompt.submit')
            .map((c) => c.$2)
            .toList();
        expect(submits, hasLength(2));
        expect(submits.last['text'], 'first turn');
        expect(submits.last['truncate_before_user_ordinal'], 0);
        // Never forwarded as literal prompt text.
        expect(submits.any((p) => p['text'] == '/retry'), isFalse);
        rig.dispose();
      },
    );
  });

  group('C2 /clear local command', () {
    testWidgets('/clear appears in suggestions and clears the view', (
      tester,
    ) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.sendFirstTurn(tester, 'first turn');
      expect(find.text('first turn'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '/c');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('/clear'), findsOneWidget);

      await rig.sendFromComposer(tester, '/clear');
      await tester.pumpAndSettle();

      // View cleared (WebUI cmdClear); no gateway dispatch without a
      // catalog-advertised clear command.
      expect(find.text('first turn'), findsNothing);
      expect(find.text('和 Hermes 开始对话吧'), findsOneWidget);
      expect(
        rig.gateway.calls.where((c) => c.$1 == 'command.dispatch'),
        isEmpty,
      );
      rig.dispose();
    });
  });

  group('A18 saved prompts', () {
    testWidgets(
      'bookmark entry opens the sheet; tapping a snippet inserts it',
      (tester) async {
        final rig = _ChatRig();
        await tester.pumpWidget(rig.app());
        await tester.pumpAndSettle();

        final entry = find.byTooltip('已保存的提示词');
        expect(entry, findsOneWidget);
        await tester.tap(entry);
        await tester.pumpAndSettle();

        expect(find.text('代码评审'), findsOneWidget);
        await tester.tap(find.text('代码评审'));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.controller!.text, contains('请评审这段代码'));
        rig.dispose();
      },
    );

    testWidgets('保存当前输入 persists through the API', (tester) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '总结一下当前目录');
      await tester.pump();
      await tester.tap(find.byTooltip('已保存的提示词'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存当前输入'));
      await tester.pumpAndSettle();

      expect(rig.api.savedTexts, ['总结一下当前目录']);
      rig.dispose();
    });
  });

  group('A15 session-scoped toolsets', () {
    testWidgets(
      'chip reflects the live session and toggles with session scope',
      (tester) async {
        final rig = _ChatRig();
        await tester.pumpWidget(rig.app());
        await tester.pumpAndSettle();
        await rig.sendFirstTurn(tester, 'hi');
        await tester.pumpAndSettle();

        // Session-scoped load: gateway toolsets.list carries the runtime id.
        final listCalls = rig.gateway.calls.where(
          (c) => c.$1 == 'toolsets.list',
        );
        expect(listCalls, isNotEmpty);
        expect(listCalls.last.$2['session_id'], 'rt-1');
        final toolsButton = find.byTooltip('当前会话工具集：1/3；全局 CLI 工具集：0/1');
        expect(toolsButton, findsOneWidget);
        expect(find.text('1/3 工具集'), findsNothing);

        await tester.ensureVisible(toolsButton);
        await tester.pumpAndSettle();
        await tester.tap(toolsButton);
        await tester.pumpAndSettle();
        expect(find.text('会话级工具集（仅当前会话生效）'), findsOneWidget);
        expect(find.text('当前会话工具集：1/3'), findsOneWidget);
        expect(find.text('全局 CLI 工具集：0/1'), findsOneWidget);
        expect(find.text('基础工具集'), findsOneWidget);
        expect(find.text('组合工具集'), findsOneWidget);
        expect(
          find.widgetWithText(SwitchListTile, 'debugging'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Hermes Agent 在本次会话运行时实际注册并可使用'),
          findsOneWidget,
        );
        expect(find.textContaining('不代表当前会话已全部加载'), findsOneWidget);

        final webTile = find.widgetWithText(SwitchListTile, 'web');
        await tester.tap(
          find.descendant(of: webTile, matching: find.byType(Switch)),
        );
        await tester.pump();
        await tester.pump();

        final configure = rig.gateway.calls.where(
          (c) => c.$1 == 'tools.configure',
        );
        expect(configure, hasLength(1));
        expect(configure.single.$2, {
          'action': 'enable',
          'names': ['web'],
          'session_id': 'rt-1',
        });

        await tester.tap(find.text('全局 CLI 工具集：0/1'));
        await tester.pumpAndSettle();
        expect(find.text('全局 CLI 工具集开关，立即生效'), findsOneWidget);
        expect(find.text('基础工具集'), findsNothing);
        expect(find.text('组合工具集'), findsNothing);
        final globalTile = find.widgetWithText(SwitchListTile, 'global-web');
        expect(globalTile, findsOneWidget);
        await tester.tap(
          find.descendant(of: globalTile, matching: find.byType(Switch)),
        );
        await tester.pump();
        expect(rig.api.toolsetToggles, [('global-web', true)]);
        rig.dispose();
      },
    );
  });

  group('A14 reasoning effort ladder', () {
    testWidgets('all seven levels are offered and written back via /config', (
      tester,
    ) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('难度：medium'));
      await tester.pumpAndSettle();
      for (final level in const [
        'none',
        'minimal',
        'low',
        'high',
        'xhigh',
        'max',
      ]) {
        expect(find.text(level), findsOneWidget, reason: level);
      }
      // The selected level remains visible in the sheet; the compact composer
      // exposes the current value through its icon tooltip.
      expect(find.text('medium'), findsOneWidget);

      await tester.tap(find.text('max'));
      await tester.pumpAndSettle();
      expect(rig.api.configPatches, [
        {
          'agent': {'reasoning_effort': 'max'},
        },
      ]);
      expect(find.text('max'), findsNothing);
      expect(find.byTooltip('难度：max'), findsOneWidget);
      rig.dispose();
    });
  });

  group('A16 provider quota chip', () {
    testWidgets('renders only with a real available quota payload', (
      tester,
    ) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      expect(find.text('\$3.50'), findsOneWidget);
      rig.dispose();
    });

    testWidgets('hidden when the backend has no quota route/data', (
      tester,
    ) async {
      final rig = _ChatRig();
      rig.api.quotaStatus = null; // 404 from the domain API
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      expect(find.textContaining('\$'), findsNothing);
      expect(find.byIcon(Icons.speed_outlined), findsNothing);
      rig.dispose();
    });
  });

  testWidgets('English chat surface does not leak Han-script UI copy', (
    tester,
  ) async {
    final rig = _ChatRig();
    await tester.pumpWidget(rig.app(locale: const Locale('en')));
    await tester.pumpAndSettle();

    final rendered = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .join('\n');
    expect(rendered, isNot(matches(RegExp(r'[\u3400-\u9fff]'))));
    expect(find.text('Start a conversation with Hermes'), findsOneWidget);
    rig.dispose();
  });
}
