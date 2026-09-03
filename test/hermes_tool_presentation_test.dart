import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/h/hermes_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('terminal tool shows command and stdout instead of raw JSON', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesToolCard(
            data: {
              'name': 'terminal',
              'args_text': jsonEncode({'command': 'pwd'}),
              'result_text': jsonEncode({
                'stdout': r'D:\projects\hermes-mobile',
                'stderr': '',
                'exit_code': 0,
              }),
            },
          ),
        ),
      ),
    );

    // Completed cards start collapsed; tap the header to expand.
    await tester.tap(find.text('terminal'));
    await tester.pump();

    expect(find.text('命令'), findsOneWidget);
    expect(find.text('pwd'), findsOneWidget);
    expect(find.text('输出'), findsOneWidget);
    expect(find.textContaining(r'D:\projects\hermes-mobile'), findsOneWidget);
    expect(find.textContaining('"stdout"'), findsNothing);
  });

  testWidgets('web_search tool renders result cards from JSON payload', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesToolCard(
            data: {
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
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('web_search'));
    await tester.pump();

    expect(find.text('搜索词'), findsOneWidget);
    expect(find.text('Flutter desktop'), findsOneWidget);
    expect(find.text('Flutter documentation'), findsOneWidget);
    expect(find.text('https://docs.flutter.dev'), findsOneWidget);
    expect(find.textContaining('"results"'), findsNothing);
  });

  testWidgets('completed tool card starts collapsed and expands on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesToolCard(
            data: {
              'name': 'terminal',
              'args_text': jsonEncode({'command': 'pwd'}),
              'result_text': jsonEncode({
                'stdout': '/home/user',
                'stderr': '',
                'exit_code': 0,
              }),
            },
          ),
        ),
      ),
    );

    // Collapsed: body hidden, one-line summary visible in the header.
    expect(find.text('命令'), findsNothing);
    expect(find.text('输出'), findsNothing);
    expect(find.text('pwd'), findsOneWidget);

    await tester.tap(find.text('terminal'));
    await tester.pump();

    expect(find.text('命令'), findsOneWidget);
    expect(find.text('输出'), findsOneWidget);
    expect(find.textContaining('/home/user'), findsOneWidget);
  });

  testWidgets('running tool card also starts collapsed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesToolCard(
            data: {
              'name': 'terminal',
              'running': true,
              'args_text': jsonEncode({'command': 'pwd'}),
            },
          ),
        ),
      ),
    );

    // Collapsed even while running: body hidden, one-line summary visible.
    // The header shows an ellipsis suffix ("terminal…") while running.
    expect(find.text('命令'), findsNothing);
    expect(find.text('pwd'), findsOneWidget);

    await tester.tap(find.text('terminal…'));
    await tester.pump();

    expect(find.text('命令'), findsOneWidget);
    expect(find.text('pwd'), findsOneWidget);
  });

  testWidgets('technical view is scoped to one tool card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HermesToolCard(
                data: {
                  'name': 'terminal',
                  'args': {'command': 'pwd'},
                  'result_text': 'first',
                },
              ),
              HermesToolCard(
                data: {
                  'name': 'read_file',
                  'args': {'path': 'README.md'},
                  'result_text': 'second',
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('terminal'));
    await tester.tap(find.text('read_file'));
    await tester.pump();
    expect(find.byTooltip('原始 JSON 视图'), findsNWidgets(2));

    await tester.tap(find.byTooltip('原始 JSON 视图').first);
    await tester.pump();
    expect(find.byTooltip('可读视图'), findsOneWidget);
    expect(find.byTooltip('原始 JSON 视图'), findsOneWidget);
  });

  testWidgets('oversized result is clamped with a 查看完整 affordance', (
    tester,
  ) async {
    final big = 'x' * 25000;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HermesToolCard(
              data: {'name': 'some_tool', 'result_text': big},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('some_tool'));
    await tester.pump();

    // Inline output is clamped at the 20000-char limit with an expand affordance.
    expect(find.text('x' * 20000), findsOneWidget);
    expect(find.textContaining('内容过长'), findsOneWidget);
    expect(find.text('查看完整'), findsOneWidget);
  });
}
