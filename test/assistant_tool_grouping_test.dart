import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/widgets/message_bubble.dart';
import 'package:provider/provider.dart';

/// Every consecutive run of tool calls — exploratory (read_file,
/// list_files, …) and dedicated (patch, generate_image, delegate_task, …)
/// alike — collapses into one categorized run-summary rollup card (e.g.
/// "编辑了 1 个文件，浏览了 3 个文件，运行了 1 个命令") instead of the dedicated
/// call breaking out as its own separate sibling card. A lone tool call
/// still renders standalone (no one-item rollup).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ChatMessage assistantWith(List<ChatPart> parts) => ChatMessage(
    id: 'a1',
    role: 'assistant',
    parts: parts,
    model: 'openai/gpt-4o',
    timestamp: DateTime(2026, 8, 16, 10),
  );

  Future<void> pump(WidgetTester tester, ChatMessage message) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ToolDismissStore(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(message: message, showFooter: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'exploratory and dedicated calls in the same run merge into one rollup',
    (tester) async {
      await pump(
        tester,
        assistantWith([
          ChatPart.text('已阅读相关文件并跑通测试：'),
          ChatPart.toolCall({
            'name': 'read_file',
            'args': {'path': 'lib/a.dart'},
            'result_text': 'a',
          }),
          ChatPart.toolCall({
            'name': 'list_files',
            'args': {'path': 'lib/'},
            'result_text': 'b',
          }),
          ChatPart.toolCall({
            'name': 'patch',
            'args': {'patch': '*** Begin Patch\n*** End Patch'},
            'result_text': 'applied',
          }),
          ChatPart.toolCall({
            'name': 'terminal',
            'args': {'command': 'flutter test'},
            'result_text': 'All tests passed!',
          }),
          ChatPart.toolCall({
            'name': 'web_search',
            'args': {'query': 'usage display'},
            'result_text': '{"hits": 2}',
          }),
        ]),
      );

      // One rollup for all five calls — the dedicated `patch` call no
      // longer breaks out into its own standalone card. The header reads as
      // a categorized run summary (edit/explore/run) rather than a bare
      // "used N tools" count.
      const summary = '编辑了 1 个文件，浏览了 3 个文件，运行了 1 个命令';
      expect(find.text(summary), findsOneWidget);
      expect(find.text('使用了 2 个工具'), findsNothing);
      // Expanding the (collapsed-by-default, settled) group reveals the
      // `patch` row as a summary line, not its own full diff card —
      // tapping it would open that detail in a sheet instead.
      await tester.tap(find.text(summary));
      await tester.pumpAndSettle();
      expect(find.text('patch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a lone dedicated tool call between two others still merges', (
    tester,
  ) async {
    await pump(
      tester,
      assistantWith([
        ChatPart.toolCall({
          'name': 'patch',
          'args': {'patch': '*** Begin Patch\n*** End Patch'},
          'result_text': 'applied',
        }),
        ChatPart.toolCall({
          'name': 'terminal',
          'args': {'command': 'echo hi'},
          'result_text': 'hi',
        }),
        ChatPart.toolCall({
          'name': 'write_file',
          'args': {'path': 'lib/b.dart'},
          'result_text': 'written',
        }),
      ]),
    );

    // All three consecutive calls merge into one rollup, regardless of
    // classification.
    const summary = '编辑了 2 个文件，运行了 1 个命令';
    expect(find.text(summary), findsOneWidget);
    await tester.tap(find.text(summary));
    await tester.pumpAndSettle();
    expect(find.text('patch'), findsOneWidget);
    expect(find.text('terminal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a run of length 1 never collapses into a rollup', (
    tester,
  ) async {
    await pump(
      tester,
      assistantWith([
        ChatPart.text('已应用修改：'),
        ChatPart.toolCall({
          'name': 'patch',
          'args': {'patch': '*** Begin Patch\n*** End Patch'},
          'result_text': 'applied',
        }),
      ]),
    );

    expect(find.text('使用了 1 个工具'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
