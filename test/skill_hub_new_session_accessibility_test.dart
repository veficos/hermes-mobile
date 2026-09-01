import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/model_catalog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/new_session_screen.dart';
import 'package:hermes_mobile/screens/skill_hub_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('initial cwd survives default-cwd failure in Arabic at 320px', (
    tester,
  ) async {
    _setNarrowView(tester);
    final api = _SessionOptionsApi();
    final connection = ConnectionStore()..api = api;
    final chat = ChatStore();
    final requests = RequestStore();
    final sessions = SessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
    );
    addTearDown(() {
      sessions.dispose();
      requests.dispose();
      chat.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: sessions,
        child: _arabicApp(
          const NewSessionScreen(initialCwd: '/chosen/workspace'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('/chosen/workspace'), findsOneWidget);
    expect(api.defaultCwdCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skill preview is scrollable in Arabic at 320px and 2x', (
    tester,
  ) async {
    _setNarrowView(tester);
    final connection = ConnectionStore()..api = _SkillHubApi();
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: _arabicApp(const SkillHubScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Example skill'));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Example skill'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

void _setNarrowView(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _arabicApp(Widget home) => MaterialApp(
  locale: const Locale('ar'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  ),
  home: home,
);

class _SessionOptionsApi extends ApiClient {
  _SessionOptionsApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int defaultCwdCalls = 0;

  @override
  Future<String> fsDefaultCwd() async {
    defaultCwdCalls++;
    throw StateError('default cwd unavailable');
  }

  @override
  Future<ModelCatalog> modelCatalog({bool refresh = false}) async =>
      const ModelCatalog(
        currentProvider: null,
        currentModel: null,
        providers: [],
      );
}

class _SkillHubApi extends ApiClient {
  _SkillHubApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  SkillHubResult get result => SkillHubResult(
    name: 'Example skill',
    description: 'A long description for narrow layout coverage',
    source: 'community-source',
    identifier: 'owner/example-skill',
    trustLevel: 'community',
    tags: const ['testing', 'mobile'],
  );

  @override
  Future<SkillHubSources> skillHubSources() async => SkillHubSources(
    sources: const [],
    indexAvailable: true,
    featured: [result],
    installed: const {},
  );

  @override
  Future<SkillHubPreview> previewSkillHub(String identifier) async =>
      SkillHubPreview(
        name: result.name,
        description: result.description,
        source: result.source,
        identifier: result.identifier,
        trustLevel: result.trustLevel,
        skillMd: List.filled(30, '# Long preview content').join('\n'),
      );
}
