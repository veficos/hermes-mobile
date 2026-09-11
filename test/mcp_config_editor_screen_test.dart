import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/mcp_config_editor_screen.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    testWidgets('MCP structured draft discard and successful result $style', (
      tester,
    ) async {
      McpServerDraftResult? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesTheme(
            visualStyle: style,
            brightness: Brightness.light,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('open'),
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<McpServerDraftResult>(
                        MaterialPageRoute(
                          builder: (_) => const McpServerEditorScreen(),
                        ),
                      );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(McpServerEditorScreen)),
      );
      final name = find.byKey(const ValueKey('mcp-server-name'));
      await tester.enterText(name, 'test');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.fileEditorKeepEditing));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).controller!.text, 'test');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.fileEditorDiscard));
      await tester.pumpAndSettle();
      expect(find.byType(McpServerEditorScreen), findsNothing);
      expect(result, isNull);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(name, 'test');
      await tester.enterText(
        find.byKey(const ValueKey('mcp-server-endpoint')),
        'https://example.test/mcp',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mcp-server-save')));
      await tester.pumpAndSettle();
      expect(result?.payload, {
        'name': 'test',
        'url': 'https://example.test/mcp',
      });
      expect(find.byType(McpServerEditorScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('MCP draft back and cancel protection $style', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesTheme(
            visualStyle: style,
            brightness: Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('open'),
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const McpConfigEditorScreen(
                        title: 'MCP',
                        initialValue: '{}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(McpConfigEditorScreen));
      final l10n = AppLocalizations.of(context);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      expect(find.byType(McpConfigEditorScreen), findsNothing);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '{draft');
      await tester.pump();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.fileEditorKeepEditing));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '{draft',
      );
      await Navigator.of(
        tester.element(find.byType(McpConfigEditorScreen)),
      ).maybePop();
      await tester.pumpAndSettle();
      expect(find.text(l10n.fileEditorDiscardQuestion), findsOneWidget);
      await tester.tap(find.text(l10n.fileEditorDiscard));
      await tester.pumpAndSettle();
      expect(find.byType(McpConfigEditorScreen), findsNothing);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('MCP JSON editor uses a full page and validates before saving', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
