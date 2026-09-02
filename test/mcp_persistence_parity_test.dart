import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/mcp_screen.dart';
import 'package:provider/provider.dart';

class _PersistentMcpApi extends ApiClient {
  _PersistentMcpApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test-key');

  bool enabled = true;
  bool persistToggle = true;
  String? lastProfile;

  @override
  Future<ProfilesPayload> listProfiles() async => const ProfilesPayload(
    profiles: [ProfileInfo(name: 'work', isActive: true)],
    active: 'work',
  );

  @override
  Future<List<Map<String, dynamic>>> mcpServers({String? profile}) async {
    lastProfile = profile;
    return [
      {
        'name': 'remote',
        'transport': 'http',
        'url': 'https://mcp.example.test',
        'enabled': enabled,
        'tools': null,
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> mcpCatalog({String? profile}) async => [];

  @override
  Future<Map<String, dynamic>> mcpTest(String name, {String? profile}) async =>
      {'ok': true, 'tools': const [], 'prompts': 0, 'resources': 0};

  @override
  Future<void> mcpSetEnabled(String name, bool value, {String? profile}) async {
    lastProfile = profile;
    if (persistToggle) enabled = value;
  }

  @override
  Future<Map<String, int>> toolCallCounts30d({String? profile}) async => {};
}

Future<void> _pump(WidgetTester tester, _PersistentMcpApi api) async {
  final connection = ConnectionStore()..api = api;
  final sessions = SessionStore(
    connection: connection,
    chat: ChatStore(),
    requests: RequestStore(),
  );
  final scope = ProfileScopeStore()..bindApi(api);
  addTearDown(() {
    scope.dispose();
    sessions.dispose();
    connection.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connection),
        ChangeNotifierProvider.value(value: sessions),
        ChangeNotifierProvider.value(value: scope),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const McpScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('toggle persists for active profile without a live gateway', (
    tester,
  ) async {
    final api = _PersistentMcpApi();
    await _pump(tester, api);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(api.enabled, isFalse);
    expect(api.lastProfile, 'work');
    expect(find.textContaining('Operation failed'), findsNothing);
  });

  testWidgets('toggle reports a server persistence mismatch', (tester) async {
    final api = _PersistentMcpApi()..persistToggle = false;
    await _pump(tester, api);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(api.enabled, isTrue);
    expect(find.textContaining('did not persist'), findsOneWidget);
  });
}
