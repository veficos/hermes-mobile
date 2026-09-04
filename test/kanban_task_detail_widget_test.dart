import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/kanban/models.dart';
import 'package:hermes_mobile/kanban/store.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/screens/kanban_task_detail_screen.dart';

void main() {
  testWidgets('detail sheet renders mobile sections', (tester) async {
    final api = KanbanApi(_NoopClient());
    final store = KanbanStore(api);
    final detail = KanbanTaskDetail.fromJson({
      'task': {'id': 't', 'title': 'Mobile task', 'status': 'running'},
      'comments': [],
      'events': [],
      'attachments': [],
      'runs': [
        {'id': 1, 'status': 'running'},
      ],
      'links': {
        'parents': [],
        'children': ['child'],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanTaskDetailScreen(initial: detail, store: store),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Mobile task'), findsOneWidget);
    expect(find.textContaining('依赖'), findsOneWidget);
    expect(find.textContaining('运行'), findsOneWidget);
  });

  testWidgets('detail sheet respects keyboard inset and remains dismissible', (
    tester,
  ) async {
    final store = KanbanStore(KanbanApi(_NoopClient()));
    final detail = KanbanTaskDetail.fromJson({
      'task': {'id': 't', 'title': 'Keyboard task', 'status': 'todo'},
      'comments': [],
      'events': [],
      'attachments': [],
      'runs': [],
      'links': {'parents': [], 'children': []},
    });
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
        child: MaterialApp(
          home: Scaffold(
            body: KanbanTaskDetailScreen(initial: detail, store: store),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Keyboard task'), findsOneWidget);
    expect(tester.takeException(), isNull);
    store.dispose();
  });

  testWidgets('home channel failure is visible and retryable', (tester) async {
    final client = _RetryHomeClient();
    final store = KanbanStore(KanbanApi(client));
    final detail = _detail();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanTaskDetailScreen(initial: detail, store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The home-channels section sits at the bottom of a now much taller
    // page (proper section cards instead of a flat ListTile stack) — it's
    // genuinely below the fold in the test's fixed viewport, so scroll it
    // into view before asserting (find.text defaults to skipOffstage:true).
    await tester.scrollUntilVisible(
      find.text('无法加载 Home channel'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('无法加载 Home channel'), findsOneWidget);
    expect(find.textContaining('home unavailable'), findsOneWidget);

    await tester.tap(find.byTooltip('重试'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('telegram'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('telegram'), findsOneWidget);
    expect(find.text('chat-1'), findsOneWidget);
    store.dispose();
  });

  testWidgets('unknown diagnostic action explains why it is disabled', (
    tester,
  ) async {
    final store = KanbanStore(KanbanApi(_NoopClient()));
    final detail = KanbanTaskDetail.fromJson({
      'task': {
        'id': 't',
        'title': 'Diagnostic task',
        'status': 'blocked',
        'diagnostics': [
          {
            'kind': 'custom',
            'severity': 'warning',
            'title': 'Needs action',
            'detail': 'Unsupported by mobile',
            'actions': [
              {'kind': 'future_action', 'label': 'Fix it'},
            ],
          },
        ],
      },
      'comments': [],
      'events': [],
      'attachments': [],
      'runs': [],
      'links': {'parents': [], 'children': []},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanTaskDetailScreen(initial: detail, store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tooltip = tester.widget<Tooltip>(
      find.ancestor(of: find.text('Fix it'), matching: find.byType(Tooltip)),
    );
    expect(tooltip.message, contains('future_action'));
    store.dispose();
  });
}

KanbanTaskDetail _detail() => KanbanTaskDetail.fromJson({
  'task': {'id': 't', 'title': 'Home task', 'status': 'todo'},
  'comments': [],
  'events': [],
  'attachments': [],
  'runs': [],
  'links': {'parents': [], 'children': []},
});

class _NoopClient extends ApiClient {
  _NoopClient() : super(baseUrl: 'http://invalid', apiKey: 'key');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async =>
      path.endsWith('/home-channels') ? {'home_channels': <dynamic>[]} : {};
}

class _RetryHomeClient extends _NoopClient {
  var calls = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (!path.endsWith('/home-channels')) return {};
    calls++;
    if (calls == 1) throw StateError('home unavailable');
    return {
      'home_channels': [
        {'platform': 'telegram', 'chat_id': 'chat-1', 'subscribed': false},
      ],
    };
  }
}
