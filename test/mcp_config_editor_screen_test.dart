import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/screens/mcp_config_editor_screen.dart';

void main() {
  testWidgets('MCP JSON editor uses a full page and validates before saving', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const McpConfigEditorScreen(
                      title: 'mcp.json',
                      initialValue: '{}',
                      documentEditor: true,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(McpConfigEditorScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    final editor = find.byKey(const ValueKey('mcp-document-editor'));
    await tester.enterText(editor, '{broken');
    await tester.tap(find.byKey(const ValueKey('mcp-config-save')));
    await tester.pump();
    expect(find.text('JSON 语法无效'), findsOneWidget);

    await tester.enterText(editor, '{"mcpServers": {}}');
    await tester.tap(find.byKey(const ValueKey('mcp-config-save')));
    await tester.pumpAndSettle();
    expect(result, '{"mcpServers": {}}');
  });
}
