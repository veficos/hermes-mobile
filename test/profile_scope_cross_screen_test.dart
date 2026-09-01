import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/screens/config_center_screen.dart';
import 'package:hermes_mobile/screens/mcp_screen.dart';
import 'package:provider/provider.dart';

/// Desktop's Capabilities scope (apps/desktop/src/app/skills/index.tsx) lets
/// one profile pick made in the MCP tab carry over to every other capability
/// surface without switching the app's active profile. This proves the
/// mobile port's shared [ProfileScopeStore] does the same across two
/// independently-reachable screens (McpScreen, ConfigCenterScreen) — picking
/// a profile in one is reflected, and re-fetches with the right `profile:`,
/// in the other.
class _CapabilitiesApi extends ApiClient {
  _CapabilitiesApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final List<String?> mcpServersProfiles = [];
  final List<String?> skillsProfiles = [];

  @override
  Future<ProfilesPayload> listProfiles() async => const ProfilesPayload(
    profiles: [
      ProfileInfo(name: 'default', isActive: true),
      ProfileInfo(name: 'work'),
    ],
    active: 'default',
  );

  @override
  Future<List<Map<String, dynamic>>> mcpServers({String? profile}) async {
    mcpServersProfiles.add(profile);
    return [
      {
        'name': profile == 'work' ? 'work-server' : 'default-server',
        'transport': 'stdio',
        'command': 'npx',
        'args': const <String>[],
        'enabled': true,
        'tools': null,
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> mcpCatalog({String? profile}) async => [];

  @override
  Future<List<SkillInfo>> skills({String? profile}) async {
    skillsProfiles.add(profile);
    return [];
  }

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [];

  @override
  Future<List<Map<String, dynamic>>> plugins({String? profile}) async => [];

  @override
  Future<Map<String, dynamic>> knowledgeGraph() async => {'nodes': <dynamic>[]};
}

void main() {
  testWidgets(
    'picking a profile in the MCP screen carries over to ConfigCenterScreen',
    (tester) async {
      final api = _CapabilitiesApi();
      final connection = ConnectionStore()..api = api;
      final sessions = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );
      final scopeStore = ProfileScopeStore()..bindApi(api);
      addTearDown(() {
        sessions.dispose();
        connection.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: connection),
            ChangeNotifierProvider.value(value: sessions),
            ChangeNotifierProvider.value(value: scopeStore),
          ],
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (settings) =>
                  MaterialPageRoute(builder: (_) => const McpScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('default-server'), findsOneWidget);
      // Two profiles known -> the "配置对象" dropdown must be visible.
      expect(find.text('配置对象'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('work').last);
      await tester.pumpAndSettle();

      expect(scopeStore.override, 'work');
      expect(find.text('work-server'), findsOneWidget);

      // Now open ConfigCenterScreen, sharing the SAME store — it must load
      // already scoped to "work", with no extra profile picking required.
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: connection),
            ChangeNotifierProvider.value(value: sessions),
            ChangeNotifierProvider.value(value: scopeStore),
          ],
          child: const MaterialApp(home: ConfigCenterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('work-server'), findsOneWidget);
      expect(api.mcpServersProfiles.last, 'work');
      expect(api.skillsProfiles.last, 'work');
    },
  );
}
