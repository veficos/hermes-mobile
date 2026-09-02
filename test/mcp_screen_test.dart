import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/screens/mcp_screen.dart';
import 'package:provider/provider.dart';

class _McpContractApi extends ApiClient {
  _McpContractApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int testCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> mcpServers({String? profile}) async => [
    {
      'name': 'filesystem',
      'transport': 'stdio',
      'command': 'npx',
      'args': ['server-filesystem'],
      'enabled': true,
      // Real backend shape: null (no filter) or {"include"/"exclude": [...]}
      // — never a bare list. See _mcp_server_summary in web_server.py.
      'tools': null,
    },
  ];

  @override
  Future<Map<String, dynamic>> mcpTest(String name, {String? profile}) async {
    testCalls++;
    return {
      'ok': true,
      'tools': [
        {'name': 'read_file', 'description': 'Read a file'},
      ],
      'prompts': 0,
      'resources': 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> mcpCatalog({String? profile}) async => [
    {
      'name': 'github',
      'description': 'GitHub MCP server',
      'transport': 'http',
      'url': 'https://mcp.github.example',
      'required_env': [
        {'name': 'GITHUB_TOKEN', 'prompt': 'GitHub token', 'required': true},
      ],
      'installed': false,
      'enabled': false,
    },
  ];
}

void main() {
  testWidgets(
    'MCP screen renders canonical server state and credential install form',
    (tester) async {
      final api = _McpContractApi();
      final connection = ConnectionStore()..api = api;
      final sessions = SessionStore(
        connection: connection,
        chat: ChatStore(),
        requests: RequestStore(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: connection),
            ChangeNotifierProvider.value(value: sessions),
            ChangeNotifierProvider(
              create: (_) => ProfileScopeStore()..bindApi(connection.api),
            ),
          ],
          child: const MaterialApp(home: McpScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('filesystem'), findsOneWidget);
      expect(find.text('github'), findsOneWidget);

      // Enabled servers are probed automatically on load, so connection
      // health and discovered tools represent runtime truth rather than the
      // configured `enabled` flag alone.
      expect(api.testCalls, 1);
      expect(find.textContaining('stdio · 1 个工具'), findsOneWidget);
      expect(find.text('read_file'), findsOneWidget);

      // The explicit test action remains available as a forced re-probe.
      await tester.tap(find.byTooltip('测试连接'));
      await tester.pumpAndSettle();
      expect(api.testCalls, 2);
      expect(find.textContaining('stdio · 1 个工具'), findsOneWidget);
      expect(find.text('read_file'), findsOneWidget);

      final install = find.widgetWithText(FilledButton, '安装');
      await tester.ensureVisible(install);
      await tester.tap(install);
      await tester.pumpAndSettle();

      expect(find.text('安装 github'), findsOneWidget);
      expect(find.text('GitHub token'), findsOneWidget);
      expect(find.text('必填'), findsOneWidget);

      sessions.dispose();
      connection.dispose();
    },
  );
}
