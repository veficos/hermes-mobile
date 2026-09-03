import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/model_catalog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/screens/config_screen.dart';
import 'package:provider/provider.dart';

class _ModelConfigApi extends ApiClient {
  _ModelConfigApi()
    : super(baseUrl: 'http://model-settings.invalid', apiKey: 'test');

  final assignments = <Map<String, dynamic>>[];
  final configPatches = <Map<String, dynamic>>[];
  Map<String, dynamic>? savedMoa;

  @override
  Future<ModelCatalog> modelCatalog({bool refresh = false}) async =>
      const ModelCatalog(
        currentProvider: 'nous',
        currentModel: 'hermes-4',
        providers: [
          ModelInfo(
            slug: 'nous',
            name: 'Nous',
            isCurrent: true,
            models: ['hermes-4', 'hermes-4-fast'],
          ),
          ModelInfo(
            slug: 'openrouter',
            name: 'OpenRouter',
            isCurrent: false,
            models: ['anthropic/claude-sonnet-4'],
          ),
          ModelInfo(
            slug: 'moa',
            name: 'Mixture of Agents',
            isCurrent: false,
            models: ['default'],
          ),
        ],
      );

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => {
    'display': {
      'personality': 'Helpful',
      'show_reasoning': true,
      'message_reactions': true,
    },
    'timezone': 'Asia/Shanghai',
    'approvals': {'mode': 'smart'},
    'yolo': false,
  };

  @override
  Future<Map<String, dynamic>> auxiliaryModels({String? profile}) async => {
    'main': {'provider': 'nous', 'model': 'hermes-4'},
    'tasks': [
      {
        'task': 'vision',
        'provider': 'openrouter',
        'model': 'anthropic/claude-sonnet-4',
        'base_url': '',
      },
      {'task': 'compression', 'provider': 'auto', 'model': '', 'base_url': ''},
    ],
  };

  @override
  Future<Map<String, dynamic>> moaModels({String? profile}) async => {
    'default_preset': 'default',
    'active_preset': 'default',
    'presets': {
      'default': {
        'enabled': true,
        'reference_models': [
          {'provider': 'nous', 'model': 'hermes-4'},
        ],
        'aggregator': {
          'provider': 'openrouter',
          'model': 'anthropic/claude-sonnet-4',
        },
        'reference_temperature': 0.3,
        'aggregator_temperature': 0.2,
        'reference_timeout': 60,
        'degraded_reference_policy': 'loud',
        'max_tokens': 4096,
      },
    },
  };

  @override
  Future<Map<String, dynamic>> recommendedDefaultModel(
    String provider, {
    String? profile,
  }) async => {'provider': provider, 'model': 'hermes-4-fast'};

  @override
  Future<Map<String, dynamic>> setModelAssignment(
    Map<String, dynamic> assignment, {
    String? profile,
  }) async {
    assignments.add(assignment);
    return {'ok': true, ...assignment};
  }

  @override
  Future<void> putConfig(Map<String, dynamic> patch, {String? profile}) async {
    configPatches.add(patch);
  }

  @override
  Future<Map<String, dynamic>> saveMoaModels(
    Map<String, dynamic> config, {
    String? profile,
  }) async {
    savedMoa = config;
    return {'ok': true, ...config};
  }

  @override
  Future<List<CredentialProvider>> credentialProviders() async => const [];
}

Future<_ModelConfigApi> _pump(WidgetTester tester) async {
  final api = _ModelConfigApi();
  final connection = ConnectionStore()..api = api;
  final session = SessionStore(
    connection: connection,
    chat: ChatStore(),
    requests: RequestStore(),
  );
  addTearDown(() {
    session.dispose();
    connection.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider<SessionStore>.value(value: session),
      ],
      child: const MaterialApp(home: ConfigScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('main model uses one tap-friendly provider and model picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = await _pump(tester);

    expect(
      find.byKey(const ValueKey('main-model-setting-row')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('main-model-setting-row')),
        matching: find.byType(DropdownButtonFormField<String>),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('main-model-setting-row')));
    await tester.pumpAndSettle();
    expect(find.text('选择模型'), findsOneWidget);
    expect(find.text('Nous'), findsWidgets);
    expect(find.text('OpenRouter'), findsOneWidget);

    await tester.tap(find.text('OpenRouter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('anthropic/claude-sonnet-4'));
    await tester.pumpAndSettle();

    expect(api.assignments.single, {
      'scope': 'main',
      'provider': 'openrouter',
      'model': 'anthropic/claude-sonnet-4',
    });
    expect(find.text('anthropic/claude-sonnet-4'), findsOneWidget);
  });

  testWidgets('chat text setting opens a mobile editor with explicit save', (
    tester,
  ) async {
    final api = await _pump(tester);

    await tester.tap(find.text('对话'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('setting-row-display.personality')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('setting-row-display.personality')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('setting-editor-display.personality')),
      findsOneWidget,
    );
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('setting-editor-display.personality')),
      'Concise',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(
      api.configPatches.single['display'],
      containsPair('personality', 'Concise'),
    );
  });

  testWidgets('shows recommended, auxiliary, and editable MoA sections', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('推荐: hermes-4-fast'), findsOneWidget);
    expect(find.text('辅助模型'), findsOneWidget);
    expect(find.text('视觉理解'), findsOneWidget);
    expect(find.text('上下文压缩'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('model-moa-section')).first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('model-moa-section')), findsWidgets);
    expect(find.text('1 个参考模型'), findsOneWidget);

    await tester.tap(find.text('编辑配置'));
    await tester.pumpAndSettle();
    expect(find.text('编辑 default'), findsOneWidget);
    expect(find.text('参考 1'), findsOneWidget);
    expect(find.text('聚合模型'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('参考温度'), findsOneWidget);
    expect(find.text('聚合温度'), findsOneWidget);
  });

  testWidgets('auxiliary task can reset to following the main model', (
    tester,
  ) async {
    final api = await _pump(tester);

    await tester.tap(find.text('视觉理解'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随主模型').last);
    await tester.pumpAndSettle();

    expect(api.assignments.single, {
      'scope': 'auxiliary',
      'task': 'vision',
      'provider': 'auto',
      'model': '',
    });
    expect(find.text('跟随主模型'), findsWidgets);
  });
}
