import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/provider_config_screen.dart';
import 'package:provider/provider.dart';

class _ProviderConfigApi extends ApiClient {
  _ProviderConfigApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<ProfilesPayload> listProfiles() async => const ProfilesPayload(
    profiles: [ProfileInfo(name: 'default', isActive: true)],
    active: 'default',
  );

  @override
  Future<Map<String, dynamic>> providerEnvVars({String? profile}) async => {
    'OPENAI_API_KEY': {'description': 'OpenAI API key', 'is_set': false},
  };

  @override
  Future<Map<String, dynamic>> customEndpoints({String? profile}) async => {
    'endpoints': [
      {'id': 'local', 'name': 'Local', 'base_url': 'https://example.test/v1'},
    ],
  };

  @override
  Future<Map<String, dynamic>> oauthProviders({String? profile}) async => {
    'providers': [
      {'id': 'openai', 'name': 'OpenAI', 'connected': false},
    ],
  };

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [
    ToolsetInfo(name: 'vision', enabled: true, toolCount: 3),
  ];
}

class _RejectingEndpointApi extends _ProviderConfigApi {
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>> validateCustomEndpoint(
    Map<String, dynamic> value, {
    String? profile,
  }) async => {'ok': false, 'message': 'endpoint unreachable'};

  @override
  Future<Map<String, dynamic>> saveCustomEndpoint(
    Map<String, dynamic> value, {
    String? profile,
  }) async {
    saveCalls++;
    return {'ok': true};
  }
}

void main() {
  testWidgets('provider configuration renders all sections in Arabic RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final connection = ConnectionStore()..api = _ProviderConfigApi();
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<ConnectionStore>.value(value: connection),
              ChangeNotifierProvider(create: (_) => ProfileScopeStore()),
            ],
            child: const ProviderConfigScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('متغيرات البيئة', skipOffstage: false), findsOneWidget);
    expect(
      find.text('نقاط النهاية المخصصة', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('OAuth للموفر', skipOffstage: false), findsOneWidget);
    expect(
      find.text('موفرو مجموعات الأدوات', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('تفويض', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed endpoint validation never saves the endpoint', (
    tester,
  ) async {
    final api = _RejectingEndpointApi();
    final connection = ConnectionStore()..api = api;
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            ChangeNotifierProvider(create: (_) => ProfileScopeStore()),
          ],
          child: const ProviderConfigScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Broken endpoint');
    await tester.enterText(
      find.byType(TextField).at(1),
      'https://invalid.test/v1',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.saveCalls, 0);
    expect(find.textContaining('endpoint unreachable'), findsOneWidget);
  });

  testWidgets('endpoint action reports a connection lost after rendering', (
    tester,
  ) async {
    final connection = ConnectionStore()..api = _ProviderConfigApi();
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            ChangeNotifierProvider(create: (_) => ProfileScopeStore()),
          ],
          child: const ProviderConfigScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    connection.api = null;
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set active'));
    await tester.pumpAndSettle();

    expect(find.text('Backend disconnected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
