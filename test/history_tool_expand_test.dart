import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/widgets/message_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixtures =
      <({String name, String result, List<Map<String, dynamic>> transcript})>[
        (
          name: 'terminal',
          result: r'D:\projects\hermes-mobile',
          transcript: [
            {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'id': 'call-terminal',
                  'type': 'function',
                  'function': {
                    'name': 'terminal',
                    'arguments': '{"command":"pwd"}',
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'call-terminal',
              'content': r'D:\projects\hermes-mobile',
            },
          ],
        ),
        (
          name: 'execute_code',
          result: 'execution finished: 42',
          transcript: [
            {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'id': 'call-code',
                  'function': {
                    'name': 'execute_code',
                    'arguments': '{"code":"print(6 * 7)"}',
                  },
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'call-code',
              'content': 'execution finished: 42',
            },
          ],
        ),
        (
          name: 'patch',
          result: 'Done!',
          transcript: [
            {
              'role': 'assistant',
              'content': [
                {
                  'type': 'tool_use',
                  'id': 'toolu-patch',
                  'name': 'patch',
                  'input': {'patch': '*** Begin Patch\n*** End Patch'},
                },
              ],
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'tool_result',
                  'tool_use_id': 'toolu-patch',
                  'content': 'Done!',
                },
              ],
            },
          ],
        ),
        (
          name: 'tool',
          result: 'generic tool result',
          transcript: [
            {
              'role': 'tool',
              'name': 'tool',
              'args': {'input': 'hello'},
              'content': 'generic tool result',
            },
          ],
        ),
      ];

  for (final fixture in fixtures) {
    testWidgets('history ${fixture.name} card expands to show its result', (
      tester,
    ) async {
      final messages = ChatStore().fromSessionMessages(fixture.transcript);
      final message = messages.singleWhere(
        (candidate) => candidate.parts.any(
          (part) =>
              part.kind == 'tool' &&
              part.tool?['name']?.toString() == fixture.name,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(message: message, showFooter: false),
            ),
          ),
        ),
      );

      // Tool cards start collapsed; tap the header to expand.
      await tester.tap(find.text(fixture.name));
      await tester.pump();

      expect(find.textContaining(fixture.result), findsOneWidget);
    });
  }

  testWidgets('terminal call uses a readable command and output view', (
    tester,
  ) async {
    final message = ChatStore()
        .fromSessionMessages(fixtures.first.transcript)
        .single;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message, showFooter: false),
        ),
      ),
    );

    await tester.tap(find.text('terminal'));
    await tester.pump();

    expect(find.text('命令'), findsOneWidget);
    expect(find.text('输出'), findsOneWidget);
    expect(find.textContaining('"command"'), findsNothing);
  });

  testWidgets('web search renders result cards instead of raw JSON', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'search-message',
      role: 'assistant',
      parts: [
        ChatPart.toolCall({
          'tool_id': 'search-1',
          'name': 'web_search',
          'args': {'query': 'Flutter desktop'},
          'result_text': jsonEncode({
            'results': [
              {
                'title': 'Flutter documentation',
                'url': 'https://docs.flutter.dev',
                'snippet': 'Build applications for every screen.',
              },
            ],
          }),
        }),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message, showFooter: false),
        ),
      ),
    );

    await tester.tap(find.text('web_search'));
    await tester.pump();

    expect(find.text('搜索词'), findsOneWidget);
    expect(find.text('Flutter documentation'), findsOneWidget);
    expect(find.text('https://docs.flutter.dev'), findsOneWidget);
    expect(find.textContaining('"results"'), findsNothing);
  });

  testWidgets('subagent activity displays task status and expanded summary', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'subagent-message',
      role: 'assistant',
      parts: [
        ChatPart.subagentActivity({
          'subagent_id': 'researcher',
          'name': '资料研究员',
          'goal': '整理 Flutter Windows 构建问题的处理方案',
          'status': 'completed',
          'task_index': 2,
          'task_count': 2,
          'model': 'gpt-5',
          'current_tool': 'web_search',
          'summary': '已完成资料整理并返回结论。',
        }),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message, showFooter: false),
        ),
      ),
    );

    expect(find.text('子代理 · 资料研究员'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('任务'), findsOneWidget);
    expect(find.text('任务进度'), findsOneWidget);
    expect(find.text('执行摘要'), findsOneWidget);
    expect(find.text('已完成资料整理并返回结论。'), findsOneWidget);
  });
}
