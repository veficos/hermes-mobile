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

/// Regression coverage for the redaction hazard: `GET /api/v1/mcp/servers`
/// masks `env` values for display (`_redact_mcp_env` on the backend), so
/// editing/toggling MUST read the unredacted config via `getConfig()`
/// (`/api/v1/config` → `/api/config`, unmasked) and never round-trip the
/// masked summary back through `mcpReplaceServers` — that would permanently
/// overwrite a real secret with the redacted placeholder string.
class _RedactionApi extends ApiClient {
  _RedactionApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  Map<String, Map<String, dynamic>>? lastReplacedServers;
  Map<String, Map<String, dynamic>> rawServers = {
    'filesystem': {
      'command': 'npx',
      'args': ['server-filesystem'],
      'env': {'API_KEY': 'real-secret-123'},
      'enabled': true,
    },
  };

  @override
  Future<List<Map<String, dynamic>>> mcpServers({String? profile}) async => [
    {
      'name': 'filesystem',
      'transport': 'stdio',
      'command': 'npx',
      'args': ['server-filesystem'],
      'env': {'API_KEY': '***'}, // redacted, as the real backend returns it
      'enabled': true,
      'tools': null,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> mcpCatalog({String? profile}) async => [];

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => {
    'mcp_servers': rawServers,
  };

  @override
  Future<Map<String, dynamic>> mcpTest(String name, {String? profile}) async =>
      {
        'ok': true,
        'tools': [
          {'name': 'read_file', 'description': 'Read a file'},
        ],
        'prompts': 0,
        'resources': 0,
      };

  @override
  Future<void> mcpReplaceServers(
    Map<String, Map<String, dynamic>> servers, {
    String? profile,
  }) async {
    lastReplacedServers = servers;
    rawServers = {
      for (final entry in servers.entries)
        entry.key: Map<String, dynamic>.from(entry.value),
    };
  }
}

Future<_RedactionApi> _pump(WidgetTester tester) async {
  final api = _RedactionApi();
  final connection = ConnectionStore()..api = api;
  final sessions = SessionStore(
    connection: connection,
    chat: ChatStore(),
    requests: RequestStore(),
  );
  addTearDown(() {
    sessions.dispose();
    connection.dispose();
  });

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
  return api;
}

void main() {
  testWidgets(
    'editing a server prefills the unredacted secret, not the masked one',
    (tester) async {
      final api = await _pump(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑配置'));
      await tester.pumpAndSettle();

      expect(find.textContaining('real-secret-123'), findsOneWidget);
      expect(find.textContaining('***'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      final saved = api.lastReplacedServers?['filesystem'];
      expect(saved, isNotNull);
      expect((saved!['env'] as Map)['API_KEY'], 'real-secret-123');

      // Let the success toast's auto-dismiss timer fire before teardown.
      await tester.pump(const Duration(milliseconds: 2500));
    },
  );

  testWidgets(
    'toggling a tool filter preserves the real secret in the saved config',
    (tester) async {
      final api = await _pump(tester);

      await tester.tap(find.byTooltip('测试连接'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('read_file'));
      await tester.pumpAndSettle();

      final saved = api.lastReplacedServers?['filesystem'];
      expect(saved, isNotNull);
      expect((saved!['env'] as Map)['API_KEY'], 'real-secret-123');
      expect((saved['tools'] as Map)['exclude'], ['read_file']);
    },
  );

  testWidgets('full mcp.json editor replaces and renames server keys', (
    tester,
  ) async {
    final api = await _pump(tester);

    await tester.tap(find.byTooltip('编辑配置').first);
    await tester.pumpAndSettle();
    final editor = find.byKey(const ValueKey('mcp-document-editor'));
    expect(editor, findsOneWidget);
    await tester.enterText(editor, '''
      {"mcpServers": {
        "renamed": {
          "url": "https://mcp.example.test",
          "headers": {"X-Key": "secret"},
          "tools": {"include": ["read"]}
        }
      }}
    ''');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(api.lastReplacedServers?.containsKey('filesystem'), isFalse);
    final renamed = api.lastReplacedServers?['renamed'];
    expect(renamed?['url'], 'https://mcp.example.test');
    expect(renamed?['headers'], {'X-Key': 'secret'});
  });
}
