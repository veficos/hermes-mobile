import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/model_catalog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract fake for the composer chips: every pill is fed by a real domain
/// API surface (profiles / config / tools / files / projects).
class _FakeChatApi extends ApiClient {
  _FakeChatApi({this.config = const {}})
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  Map<String, dynamic> config;
  String? activatedProfile;
  final List<String?> getConfigProfiles = [];
  final List<(String, bool)> toolsetToggles = [];
  Map<String, dynamic>? configPatch;
  String? putConfigProfile;
  String? workspaceCwd;
  ModelCatalog catalog = const ModelCatalog(
    currentProvider: 'catalog-provider',
    currentModel: 'catalog-model',
    providers: [
      ModelInfo(
        slug: 'session-provider',
        name: 'Session Provider',
        isCurrent: false,
        models: ['session-model'],
      ),
      ModelInfo(
        slug: 'catalog-provider',
        name: 'Catalog Provider',
        isCurrent: true,
        models: ['catalog-model'],
      ),
      ModelInfo(
        slug: 'selected-provider',
        name: 'Selected Provider',
        isCurrent: false,
        models: ['selected-model'],
      ),
    ],
  );
  Map<String, dynamic> setModelResult = const {
    'applied': 'now',
    'provider': 'final-provider',
    'model': 'final-model',
  };

  @override
  Future<ModelCatalog> modelCatalog({bool refresh = false}) async => catalog;

  @override
  Future<Map<String, dynamic>> setModel(String provider, String model) async =>
      setModelResult;

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async {
    getConfigProfiles.add(profile);
    return config;
  }

  @override
  Future<void> putConfig(Map<String, dynamic> patch, {String? profile}) async {
    configPatch = patch;
    putConfigProfile = profile;
  }

  @override
  Future<ProfilesPayload> listProfiles() async => ProfilesPayload(
    profiles: [
      const ProfileInfo(name: '代码专家', isActive: true),
      const ProfileInfo(name: '写作助手'),
    ],
    active: activatedProfile ?? '代码专家',
    source: 'local',
  );

  @override
  Future<Map<String, dynamic>> activateProfile(String name) async {
    activatedProfile = name;
    return {'ok': true, 'active': name};
  }

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [
    ToolsetInfo(name: 'fs', description: '文件系统', enabled: true, toolCount: 3),
    ToolsetInfo(name: 'web', enabled: false, toolCount: 2),
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
  Future<List<Map<String, dynamic>>> listProjects() async => [
    {'id': 'p1', 'path': 'D:/work/other-proj'},
  ];

  @override
  Future<void> setSessionWorkspace(
    String id,
    String cwd, {
    String? profile,
  }) async {
    workspaceCwd = cwd;
  }
}

class _ProfileSessionStore extends SessionStore {
  _ProfileSessionStore({
    required super.connection,
    required super.chat,
    required super.requests,
    this.testActiveProfile,
    this.testSessionProfile,
  });

  final String? testActiveProfile;
  final String? testSessionProfile;

  @override
  String? get activeProfile => testActiveProfile;

  @override
  String? get profile => testSessionProfile;
}

class _ModelSwitchSessionStore extends SessionStore {
  _ModelSwitchSessionStore({
    required super.connection,
    required super.chat,
    required super.requests,
    this.switchResult = const {
      'applied': 'now',
      'provider': 'final-provider',
      'model': 'final-model',
    },
  });

  Map<String, dynamic> switchResult;
  final List<(String, String)> switches = [];

  @override
  Future<Map<String, dynamic>> switchCurrentModel(
    String provider,
    String model,
  ) async {
    switches.add((provider, model));
    final finalProvider = switchResult['provider']?.toString() ?? provider;
    final finalModel = switchResult['model']?.toString() ?? model;
    applyModelSelection(finalProvider, finalModel);
    return switchResult;
  }
}

Widget _chatApp(
  _FakeChatApi api,
  ConnectionStore connection, {
  SessionStore? session,
  ChatScreen screen = const ChatScreen(),
}) {
  final chat = session?.chat ?? ChatStore();
  final requests = RequestStore();
  session ??= SessionStore(
    connection: connection,
    chat: chat,
    requests: requests,
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: connection),
      ChangeNotifierProvider<SessionStore>.value(value: session),
      ChangeNotifierProvider.value(value: chat),
      ChangeNotifierProvider.value(value: VoiceStore(connection: connection)),
      ChangeNotifierProvider.value(value: CommandStore(connection: connection)),
    ],
    child: MaterialApp(home: screen),
  );
}

Finder _composerCard() => find.byType(HermesComposer);

void _expectFullyInside(WidgetTester tester, Finder item, Rect bounds) {
  expect(item, findsOneWidget);
  final rect = tester.getRect(item);
  expect(
    rect.left,
    greaterThanOrEqualTo(bounds.left),
    reason: '$item starts outside $bounds: $rect',
  );
  expect(
    rect.right,
    lessThanOrEqualTo(bounds.right),
    reason: '$item ends outside $bounds: $rect',
  );
  expect(item.hitTestable(), findsOneWidget, reason: '$item is not visible');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('file handoff remains visible when server draft save fails', (
    tester,
  ) async {
    final api = _FakeChatApi();
    final connection = ConnectionStore()..api = api;
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      _chatApp(
        api,
        connection,
        screen: const ChatScreen(
          initialDraftText: '@workspace/report.md',
          initialDraftSaveError: 'offline',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('@workspace/report.md'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
  });

  testWidgets(
    'profile workspace and model are 34px icon buttons with accessible state',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var profileTaps = 0;
      var workspaceTaps = 0;
      var modelTaps = 0;
      var toolsTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HermesComposer(
              controller: controller,
              onSend: (_) {},
              personalityLabel: '默认',
              onPersonalityTap: () => profileTaps++,
              workspaceLabel: 'repo',
              onWorkspaceTap: () => workspaceTaps++,
              modelLabel: 'anthropic/claude-sonnet',
              onModelTap: () => modelTaps++,
              toolsLabel: '工具集：1/2 已启用',
              toolsSelected: true,
              onToolsTap: () => toolsTaps++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('默认'), findsNothing);
      expect(find.text('repo'), findsNothing);
      expect(find.text('anthropic/claude-sonnet'), findsNothing);
      expect(find.text('工具集：1/2 已启用'), findsNothing);
      for (final tooltip in [
        '配置档：默认',
        'Workspace：repo',
        '配置模型：anthropic/claude-sonnet',
        '工具集：1/2 已启用',
      ]) {
        final button = find.byTooltip(tooltip);
        expect(button, findsOneWidget);
        expect(tester.getSize(button), const Size(44, 44));
        await tester.tap(button);
      }
      expect((profileTaps, workspaceTaps, modelTaps, toolsTaps), (1, 1, 1, 1));

      final profileFinder = find.byTooltip('配置档：默认');
      final profileSemantics = tester.getSemantics(profileFinder);
      expect(
        profileSemantics.flagsCollection.isButton.toString().toLowerCase(),
        contains('true'),
      );
      // A profile is effectively always set, so highlighting this pill
      // whenever it merely *has* a label (the old `selected:
      // personalityLabel.isNotEmpty` bug) left it permanently lit —
      // meaningless noise. It should only ever reflect a real
      // toggle/override state, which nothing currently drives, so it
      // stays unselected.
      expect(
        profileSemantics.flagsCollection.isSelected.toString().toLowerCase(),
        contains('false'),
      );
      final profileMaterial = tester.widget<Material>(
        find
            .descendant(of: profileFinder, matching: find.byType(Material))
            .last,
      );
      final profileShape = profileMaterial.shape! as CircleBorder;
      expect(profileShape.side, BorderSide.none);
      expect(profileMaterial.color, Colors.transparent);

      final toolsFinder = find.byTooltip('工具集：1/2 已启用');
      final toolsSemantics = tester.getSemantics(toolsFinder);
      expect(
        toolsSemantics.flagsCollection.isSelected.toString().toLowerCase(),
        contains('true'),
      );
      final toolsMaterial = tester.widget<Material>(
        find.descendant(of: toolsFinder, matching: find.byType(Material)).last,
      );
      final toolsShape = toolsMaterial.shape! as CircleBorder;
      expect(toolsShape.side.width, 1.5);
      expect(toolsMaterial.color, isNot(Colors.transparent));
    },
  );

  testWidgets('empty selector values use choose tooltips', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesComposer(
            controller: controller,
            onSend: (_) {},
            personalityLabel: '',
            onPersonalityTap: () {},
            workspaceLabel: '',
            onWorkspaceTap: () {},
            modelLabel: '',
            onModelTap: () {},
          ),
        ),
      ),
    );
    expect(find.byTooltip('选择配置档'), findsOneWidget);
    expect(find.byTooltip('选择 Workspace'), findsOneWidget);
    expect(find.byTooltip('选择配置模型'), findsOneWidget);
    expect(find.byTooltip('配置工具集'), findsNothing);
  });

  testWidgets('composer config reads and writes the session profile', (
    tester,
  ) async {
    final api = _FakeChatApi(
      config: const {
        'agent': {'reasoning_effort': 'high'},
      },
    );
    final connection = ConnectionStore()..api = api;
    final session = _ProfileSessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
      testActiveProfile: '写作助手',
      testSessionProfile: '代码专家',
    );

    await tester.pumpWidget(_chatApp(api, connection, session: session));
    await tester.pumpAndSettle();

    expect(api.getConfigProfiles, ['代码专家']);
    await tester.tap(find.byTooltip('难度：high'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('max'));
    await tester.pumpAndSettle();

    expect(api.configPatch, {
      'agent': {'reasoning_effort': 'max'},
    });
    expect(api.putConfigProfile, '代码专家');
    session.dispose();
    connection.dispose();
  });

  testWidgets('composer chips render real backend data, mock copy is gone', (
    tester,
  ) async {
    final api = _FakeChatApi(
      config: {
        'reasoning': {'effort': 'high'},
        'yolo': true,
      },
    );
    final connection = ConnectionStore()..api = api;

    await tester.pumpWidget(_chatApp(api, connection));
    await tester.pumpAndSettle();

    // Real selector values are exposed through tooltips, not toolbar text.
    expect(find.byTooltip('配置档：代码专家'), findsOneWidget);
    expect(find.byTooltip('Workspace：repo'), findsOneWidget);
    expect(find.text('代码专家'), findsNothing);
    expect(find.text('repo'), findsNothing);
    expect(find.byTooltip('难度：high'), findsOneWidget);
    expect(find.text('high'), findsNothing);
    expect(find.text('1/2 工具集'), findsNothing);
    expect(find.byTooltip('工具集：1/2 已启用'), findsOneWidget);

    // Fabricated picker copy no longer exists anywhere.
    expect(find.text('研究助理'), findsNothing);
    expect(find.text('选择人格'), findsNothing);
    expect(find.text('编码工具集'), findsNothing);
    expect(find.text('文件系统工具集'), findsNothing);
    expect(find.text('Git 工具集'), findsNothing);
    expect(find.text('Medium'), findsNothing);
    expect(find.text('仓库根目录'), findsNothing);

    // Yolo menu entry reflects the real config value (checked state).
    // The AppBar also hosts a PopupMenuButton (会话菜单) — target the
    // composer tools row's 更多 menu by tooltip.
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('YOLO 模式'), findsOneWidget);
    await tester.tapAt(Offset.zero); // dismiss
    await tester.pumpAndSettle();
    connection.dispose();
  });

  testWidgets('profile chip activates the real profile via the API', (
    tester,
  ) async {
    final api = _FakeChatApi(config: const {'yolo': false});
    final connection = ConnectionStore()..api = api;

    await tester.pumpWidget(_chatApp(api, connection));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('配置档：代码专家'));
    await tester.pumpAndSettle();
    expect(find.text('写作助手'), findsOneWidget); // sheet lists real profiles
    await tester.tap(find.text('写作助手'));
    await tester.pumpAndSettle();

    expect(api.activatedProfile, '写作助手');
    expect(find.byTooltip('配置档：写作助手'), findsOneWidget);
    expect(find.text('写作助手'), findsNothing);
    connection.dispose();
  });

  testWidgets('profile picker trusts payload active over stale item flags', (
    tester,
  ) async {
    final api = _FakeChatApi(config: const {'yolo': false});
    api.activatedProfile = '写作助手';
    final connection = ConnectionStore()..api = api;

    await tester.pumpWidget(_chatApp(api, connection));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('配置档：写作助手'));
    await tester.pumpAndSettle();

    final selectedChecks = tester.widgetList<Icon>(
      find.byIcon(Icons.check_circle),
    );
    expect(selectedChecks, hasLength(1));
    expect(find.text('当前激活'), findsOneWidget);
    final selectedTile = find.ancestor(
      of: find.byIcon(Icons.check_circle),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: selectedTile, matching: find.text('写作助手')),
      findsOneWidget,
    );
    final tile = tester.widget<ListTile>(selectedTile);
    final shape = tile.shape! as RoundedRectangleBorder;
    expect(shape.side.width, 2);
    expect(tile.tileColor, isNotNull);
    final sheet = find.ancestor(
      of: find.text('选择配置档'),
      matching: find.byType(BottomSheet),
    );
    final selectedSemantics = tester
        .widgetList<Semantics>(
          find.descendant(of: sheet, matching: find.byType(Semantics)),
        )
        .where((widget) => widget.properties.selected == true);
    expect(selectedSemantics, hasLength(1));
    connection.dispose();
  });

  test(
    'profiles payload normalizes object active and camel-case item flag',
    () {
      final payload = ProfilesPayload.fromJson({
        'profiles': [
          {'name': 'default'},
          {'name': 'research', 'isActive': true},
        ],
        'active': {'name': 'research'},
      });

      expect(payload.active, 'research');
      expect(
        payload.profiles.singleWhere((p) => p.name == 'research').isActive,
        isTrue,
      );

      final fallback = ProfilesPayload.fromJson({
        'profiles': [
          {'name': 'default'},
          {'id': 'writing', 'isActive': true},
        ],
      });
      expect(fallback.active, 'writing');

      final sticky = ProfilesPayload.fromJson({
        'data': {
          'profiles': [
            {'name': 'default'},
            {'name': 'experts'},
          ],
          'active': 'experts',
          'current_profile': {'name': 'default'},
        },
      });
      expect(sticky.active, 'experts');
      expect(sticky.current, 'default');
    },
  );

  for (final width in [320.0, 390.0, 760.0, 784.0]) {
    testWidgets(
      '${width.toInt()} wide composer exposes every tool above the edit box',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = TextEditingController(text: 'hello');
        addTearDown(controller.dispose);

        const leadingKeys = [
          ValueKey('attach-action'),
          ValueKey('image-action'),
          ValueKey('link-action'),
        ];
        const footerKeys = [
          ValueKey('queue-action'),
          ValueKey('voice-action'),
          ValueKey('tts-action'),
          ValueKey('more-action'),
        ];
        const longModel =
            'provider/extraordinarily-long-model-name-that-must-be-ellipsized';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: HermesComposer(
                  controller: controller,
                  onSend: (_) {},
                  personalityLabel: 'Profile',
                  onPersonalityTap: () {},
                  workspaceLabel: 'Workspace',
                  onWorkspaceTap: () {},
                  modelLabel: longModel,
                  onModelTap: () {},
                  toolsLabel: '工具集：1/2 已启用',
                  toolsSelected: true,
                  onToolsTap: () {},
                  difficultyLabel: 'Difficulty',
                  onDifficultyTap: () {},
                  quotaLabel: r'$123.45 quota',
                  onQuotaTap: () {},
                  leadingActions: const [
                    IconButton(
                      key: ValueKey('attach-action'),
                      tooltip: '附件',
                      onPressed: null,
                      icon: Icon(Icons.attach_file),
                    ),
                    IconButton(
                      key: ValueKey('image-action'),
                      tooltip: '图片',
                      onPressed: null,
                      icon: Icon(Icons.image_outlined),
                    ),
                    IconButton(
                      key: ValueKey('link-action'),
                      tooltip: '链接',
                      onPressed: null,
                      icon: Icon(Icons.link),
                    ),
                  ],
                  footerActions: const [
                    IconButton(
                      key: ValueKey('queue-action'),
                      tooltip: '队列',
                      onPressed: null,
                      icon: Icon(Icons.queue),
                    ),
                    IconButton(
                      key: ValueKey('voice-action'),
                      tooltip: '语音',
                      onPressed: null,
                      icon: Icon(Icons.mic),
                    ),
                    IconButton(
                      key: ValueKey('tts-action'),
                      tooltip: 'TTS',
                      onPressed: null,
                      icon: Icon(Icons.volume_up_outlined),
                    ),
                    IconButton(
                      key: ValueKey('more-action'),
                      tooltip: '更多',
                      onPressed: null,
                      icon: Icon(Icons.more_horiz),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // No breakpoint-specific "+" panel any more — every tool exists
        // immediately, above the edit box, at every width. The tools row
        // scrolls horizontally (prototype `.pillrow` parity) instead of
        // wrapping, so items past the fold are reached by scrolling —
        // `ensureVisible` does that the same way a real drag would, then
        // the item must land fully inside the composer's own bounds.
        Future<void> checkReachable(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pump();
          _expectFullyInside(tester, finder, tester.getRect(_composerCard()));
        }

        for (final key in [...leadingKeys, ...footerKeys]) {
          await checkReachable(find.byKey(key));
        }
        expect(find.text('Profile'), findsNothing);
        expect(find.text('Workspace'), findsNothing);
        expect(find.text(longModel), findsNothing);
        for (final tooltip in [
          '配置档：Profile',
          'Workspace：Workspace',
          '配置模型：$longModel',
          '难度：Difficulty',
          '工具集：1/2 已启用',
        ]) {
          final button = find.byTooltip(tooltip);
          await checkReachable(button);
          expect(tester.getSize(button), const Size(44, 44));
        }
        expect(find.text('工具集：1/2 已启用'), findsNothing);
        for (final label in [r'$123.45 quota']) {
          await checkReachable(find.text(label));
        }
        await checkReachable(find.byTooltip('表情'));
        // The send button lives beside the field inside the fixed edit box,
        // not in the scrollable tools row — always fully inside, no scroll.
        _expectFullyInside(
          tester,
          find.byIcon(Icons.arrow_upward),
          tester.getRect(_composerCard()),
        );

        // Every tool sits above the text field — never inside/below it.
        final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
        for (final tooltip in [
          '配置档：Profile',
          'Workspace：Workspace',
          '配置模型：$longModel',
          '难度：Difficulty',
          '工具集：1/2 已启用',
          '表情',
        ]) {
          expect(
            tester.getTopLeft(find.byTooltip(tooltip)).dy,
            lessThan(fieldTop),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'narrow composer shows every tool above the edit box without a "+" panel',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController(text: 'hello');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HermesComposer(
              controller: controller,
              onSend: (_) {},
              onModelTap: () {},
              modelLabel: 'test-model',
              leadingActions: const [
                IconButton(onPressed: null, icon: Icon(Icons.attach_file)),
              ],
              footerActions: const [
                IconButton(onPressed: null, icon: Icon(Icons.mic)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // No "+" expand affordance exists any more — every tool renders
      // immediately, above the text field.
      expect(find.byTooltip('展开工具'), findsNothing);
      expect(
        find.byKey(const ValueKey('composer-expanded-tools-panel')),
        findsNothing,
      );
      expect(find.byTooltip('配置模型：test-model'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);

      final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      expect(
        tester.getTopLeft(find.byTooltip('配置模型：test-model')).dy,
        lessThan(fieldTop),
      );
      expect(
        tester.getTopLeft(find.byIcon(Icons.attach_file)).dy,
        lessThan(fieldTop),
      );

      // The send button stays attached beside the field inside the edit
      // box, not in a separate footer row below it.
      expect(
        tester.getRect(find.byIcon(Icons.arrow_upward)).top,
        lessThan(tester.getRect(find.byType(TextField)).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('send button vertically centers on the field content', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesComposer(
            controller: controller,
            onSend: (_) {},
            onModelTap: () {},
            modelLabel: 'test-model',
          ),
        ),
      ),
    );
    await tester.pump();

    final fieldCenter = tester.getRect(find.byType(TextField)).center.dy;
    final buttonCenter = tester
        .getRect(find.byIcon(Icons.arrow_upward))
        .center
        .dy;
    // Prototype parity (`.composerbox{align-items:flex-end}`, `.send`
    // sized to match the collapsed textarea): the send button's optical
    // center must land on the single-line field's content center, not
    // float a few pixels above or below it.
    expect(buttonCenter, closeTo(fieldCenter, 1));
  });

  testWidgets('phone attachment tray stays horizontally scrollable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final attachments = List.generate(
      8,
      (i) => ComposerAttachment(
        label: 'very-long-file-name-$i.txt',
        kind: ComposerAttachmentKind.file,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesComposer(
            controller: controller,
            onSend: (_) {},
            attachments: attachments,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '900 wide composer keeps every tool above the edit box, send beside field',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController(text: 'hello');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HermesComposer(
              controller: controller,
              onSend: (_) {},
              personalityLabel: 'Profile',
              onPersonalityTap: () {},
              workspaceLabel: 'Workspace',
              onWorkspaceTap: () {},
              modelLabel: 'Model',
              onModelTap: () {},
              toolsLabel: '工具集：1/2 已启用',
              onToolsTap: () {},
              difficultyLabel: 'Difficulty',
              onDifficultyTap: () {},
              leadingActions: const [
                IconButton(onPressed: null, icon: Icon(Icons.attach_file)),
              ],
              footerActions: const [
                IconButton(onPressed: null, icon: Icon(Icons.mic)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      for (final tooltip in [
        '配置档：Profile',
        'Workspace：Workspace',
        '配置模型：Model',
      ]) {
        expect(
          tester.getTopLeft(find.byTooltip(tooltip)).dy,
          lessThan(fieldTop),
        );
      }
      expect(
        tester.getTopLeft(find.byTooltip('工具集：1/2 已启用')).dy,
        lessThan(fieldTop),
      );
      // Send stays attached beside the field inside the edit box, not in a
      // separate footer row below it.
      expect(
        tester.getRect(find.byIcon(Icons.arrow_upward)).top,
        lessThan(tester.getRect(find.byType(TextField)).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('1200 wide composer keeps every tool above the edit box too', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesComposer(
            controller: controller,
            onSend: (_) {},
            modelLabel: 'Model',
            onModelTap: () {},
            toolsLabel: 'Tools',
            onToolsTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(
      tester.getTopLeft(find.byTooltip('配置模型：Model')).dy,
      lessThan(fieldTop),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '360 wide composer shows every tool above the field without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController(text: 'hello');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HermesComposer(
              controller: controller,
              onSend: (_) {},
              onModelTap: () {},
              modelLabel: 'test-model',
              leadingActions: const [
                IconButton(onPressed: null, icon: Icon(Icons.attach_file)),
              ],
              footerActions: const [
                IconButton(onPressed: null, icon: Icon(Icons.mic)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // No "+" expand affordance any more — every tool renders immediately.
      expect(find.byTooltip('展开工具'), findsNothing);
      expect(
        find.byKey(const ValueKey('composer-expanded-tools-panel')),
        findsNothing,
      );
      expect(find.byTooltip('配置模型：test-model'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tools sheet lists real toolsets and toggles via the API', (
    tester,
  ) async {
    final api = _FakeChatApi(config: const {'yolo': false});
    final connection = ConnectionStore()..api = api;

    await tester.pumpWidget(_chatApp(api, connection));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('工具集：1/2 已启用'));
    await tester.pumpAndSettle();
    expect(find.text('fs'), findsOneWidget);
    expect(find.text('web'), findsOneWidget);
    // No fabricated tool-name cards.
    expect(
      find.text('execute_code, read_file, write_file, terminal'),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(SwitchListTile, 'web'));
    await tester.pumpAndSettle();
    expect(api.toolsetToggles, [('web', true)]);
    connection.dispose();
  });

  testWidgets('tools sheet cannot toggle after the server changes', (
    tester,
  ) async {
    final oldApi = _FakeChatApi(config: const {'yolo': false});
    final newApi = _FakeChatApi(config: const {'yolo': false});
    final connection = ConnectionStore()..api = oldApi;
    addTearDown(connection.dispose);

    await tester.pumpWidget(_chatApp(oldApi, connection));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('工具集：1/2 已启用'));
    await tester.pumpAndSettle();

    connection.api = newApi;
    await tester.tap(find.widgetWithText(SwitchListTile, 'web'));
    await tester.pumpAndSettle();

    expect(oldApi.toolsetToggles, isEmpty);
    expect(newApi.toolsetToggles, isEmpty);
  });

  testWidgets('model picker check follows the current session model', (
    tester,
  ) async {
    final api = _FakeChatApi(config: const {'yolo': false});
    final connection = ConnectionStore()..api = api;
    final chat = ChatStore();
    final session = _ModelSwitchSessionStore(
      connection: connection,
      chat: chat,
      requests: RequestStore(),
    )..applyModelSelection('session-provider', 'session-model');

    await tester.pumpWidget(_chatApp(api, connection, session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('配置模型：session-model'));
    await tester.pumpAndSettle();

    final selectedTile = find.ancestor(
      of: find.byIcon(Icons.check),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: selectedTile, matching: find.text('session-model')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: selectedTile, matching: find.text('catalog-model')),
      findsNothing,
    );
    connection.dispose();
  });

  testWidgets('applied now updates composer from the session switch response', (
    tester,
  ) async {
    final api = _FakeChatApi(config: const {'yolo': false});
    final connection = ConnectionStore()..api = api;
    final chat = ChatStore();
    final session = _ModelSwitchSessionStore(
      connection: connection,
      chat: chat,
      requests: RequestStore(),
    )..applyModelSelection('session-provider', 'session-model');

    await tester.pumpWidget(_chatApp(api, connection, session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('配置模型：session-model'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected Provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('selected-model'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('配置模型：final-model'), findsOneWidget);
    expect(find.text('final-model'), findsNothing);
    expect(find.text('catalog-model'), findsNothing);
    expect(session.info?.provider, 'final-provider');
    expect(session.switches, [('selected-provider', 'selected-model')]);
    connection.dispose();
  });

  testWidgets(
    'deferred model selection updates next-turn model and explains it',
    (tester) async {
      final api = _FakeChatApi(config: const {'yolo': false});
      final connection = ConnectionStore()..api = api;
      final chat = ChatStore();
      final session = _ModelSwitchSessionStore(
        connection: connection,
        chat: chat,
        requests: RequestStore(),
        switchResult: const {
          'applied': 'deferred',
          'provider': 'selected-provider',
          'model': 'selected-model',
        },
      )..applyModelSelection('session-provider', 'session-model');

      await tester.pumpWidget(_chatApp(api, connection, session: session));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('配置模型：session-model'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected Provider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('selected-model'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('配置模型：selected-model'), findsOneWidget);
      expect(find.text('模型切换将在下一轮生效'), findsOneWidget);
      expect(session.info?.model, 'selected-model');
      expect(session.switches, [('selected-provider', 'selected-model')]);
      connection.dispose();
    },
  );

  testWidgets('tablet session rail expands children without opening parent', (
    tester,
  ) async {
    final connection = ConnectionStore();
    final session = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    var opened = false;
    final parent = SessionRow(id: 'parent', title: '父会话');
    final child = SessionRow(
      id: 'child',
      title: '子会话',
      parentSessionId: 'parent',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(
          home: Scaffold(
            body: TabletSessionRail(
              width: 280,
              rows: [parent, child],
              currentId: 'parent',
              onOpen: (_) async => opened = true,
              onNew: () async {},
            ),
          ),
        ),
      ),
    );

    final leading = tester.widget<Icon>(
      find.byKey(const ValueKey('tablet-session-leading-parent')),
    );
    expect(leading.icon, Icons.chat_bubble_outline);
    final titleX = tester.getTopLeft(find.text('父会话')).dx;
    final toggle = find.byKey(const ValueKey('tablet-session-toggle-parent'));
    expect(tester.getTopLeft(toggle).dx, greaterThan(titleX));
    expect(find.text('子会话'), findsNothing);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('子会话'), findsOneWidget);
    expect(opened, isFalse);
    connection.dispose();
  });

  test('scroll coordinator resets each session and gates pagination', () {
    final coordinator = ChatScrollCoordinator();

    expect(coordinator.enterSession('A'), isTrue);
    expect(coordinator.allowPagination, isFalse);
    coordinator.markInitialPositioned();
    coordinator.updateStuck(false);
    expect(coordinator.messagesChanged(3), isFalse);

    expect(coordinator.enterSession('B'), isTrue);
    expect(coordinator.stuckToBottom, isTrue);
    expect(coordinator.allowPagination, isFalse);
    expect(coordinator.messagesChanged(3), isTrue);
    coordinator.markInitialPositioned();
    expect(coordinator.allowPagination, isTrue);
    coordinator.updateStuck(false);
    expect(coordinator.messagesChanged(4), isFalse);
  });

  test('prepend anchor compensation is invalidated by a session switch', () {
    final coordinator = ChatScrollCoordinator();
    coordinator.enterSession('A');
    final epoch = coordinator.sessionEpoch;
    expect(
      coordinator.restorePrependOffset(
        beforePixels: 120,
        beforeExtent: 1000,
        afterExtent: 1600,
        minExtent: 0,
        maxExtent: 1600,
      ),
      720,
    );
    coordinator.enterSession('B');
    expect(coordinator.ownsEpoch(epoch), isFalse);
  });

  testWidgets(
    'difficulty pill and yolo entry disappear when the config lacks the fields',
    (tester) async {
      final api = _FakeChatApi(
        config: const {'model': {}},
      ); // no reasoning/yolo
      final connection = ConnectionStore()..api = api;

      await tester.pumpWidget(_chatApp(api, connection));
      await tester.pumpAndSettle();

      // No invented reasoning-effort pill.
      expect(find.text('难度'), findsNothing);
      expect(find.text('high'), findsNothing);

      // No misleading yolo switch in the more menu.
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('YOLO 模式'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      connection.dispose();
    },
  );
}
