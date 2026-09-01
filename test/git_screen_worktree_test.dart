import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/screens/git_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `gitWorktrees`/`gitWorktreeAdd` previously hit `/api/git/worktrees` and
/// `/api/git/worktree/add` (missing the `/v1` prefix every other ApiClient
/// call uses) — routes the mobile server never registered, so the existing
/// "新建 Worktree" action in chat_screen.dart's coding-status sheet always
/// 404'd. This covers the fixed `/api/v1/git/...` contract plus the new
/// list/create/delete UI added to the Branches tab.
class _WorktreeApi extends ApiClient {
  _WorktreeApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  List<Map<String, dynamic>> worktrees = [
    {
      'path': '/repo',
      'branch': 'main',
      'isMain': true,
      'detached': false,
      'locked': false,
    },
    {
      'path': '/repo/.worktrees/feature-x',
      'branch': 'hermes/feature-x',
      'isMain': false,
      'detached': false,
      'locked': false,
    },
  ];
  (String, Map<String, dynamic>)? lastAdd;
  (String, bool)? lastRemove;
  bool failFirstRemove = false;

  @override
  Future<Map<String, dynamic>> gitStatus(String path) async => {
    'branch': 'main',
    'staged': 0,
    'unstaged': 0,
    'untracked': 0,
  };

  @override
  Future<List<Map<String, dynamic>>> gitReviewList(
    String path, {
    String scope = 'uncommitted',
    String? base,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> gitBranches(String path) async => const [];

  @override
  Future<List<Map<String, dynamic>>> gitRemotes(String path) async => const [];

  @override
  Future<List<Map<String, dynamic>>> gitStashes(String path) async => const [];

  @override
  Future<List<Map<String, dynamic>>> gitWorktrees(String path) async =>
      worktrees;

  @override
  Future<List<Map<String, dynamic>>> gitBaseBranches(String path) async =>
      const [
        {'name': 'main', 'isRemote': false, 'isDefault': true},
        {'name': 'origin/develop', 'isRemote': true, 'isDefault': false},
      ];

  @override
  Future<Map<String, dynamic>> gitWorktreeAdd(
    String path, {
    String? name,
    String? branch,
    String? base,
    String? existingBranch,
  }) async {
    lastAdd = (path, {'name': name, 'branch': branch, 'base': base});
    final newPath = '/repo/.worktrees/$name';
    worktrees = [
      ...worktrees,
      {
        'path': newPath,
        'branch': 'hermes/$name',
        'isMain': false,
        'detached': false,
        'locked': false,
      },
    ];
    return {'path': newPath, 'branch': 'hermes/$name'};
  }

  @override
  Future<Map<String, dynamic>> gitWorktreeRemove(
    String path,
    String worktreePath, {
    bool force = false,
  }) async {
    lastRemove = (worktreePath, force);
    if (failFirstRemove && !force) {
      throw Exception(
        'fatal: \'$worktreePath\' contains modified or untracked files',
      );
    }
    worktrees = worktrees.where((w) => w['path'] != worktreePath).toList();
    return {'removed': worktreePath};
  }
}

Future<_WorktreeApi> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final api = _WorktreeApi();
  final connection = ConnectionStore()..api = api;
  final session = SessionStore(
    connection: connection,
    chat: ChatStore(),
    requests: RequestStore(),
  );
  addTearDown(() {
    session.dispose();
    connection.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider<SessionStore>.value(value: session),
      ],
      child: const MaterialApp(home: GitScreen(initialPath: '/repo')),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('分支'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('lists worktrees with the main one marked and un-deletable', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('main'), findsOneWidget);
    expect(find.text('hermes/feature-x'), findsOneWidget);
    expect(find.text('主'), findsOneWidget);
    // Only the non-main worktree gets a delete action.
    expect(find.byTooltip('删除'), findsOneWidget);
    expect(find.byTooltip('在新会话中打开'), findsNWidgets(2));
  });

  testWidgets('creating a worktree submits the picked name and base branch', (
    tester,
  ) async {
    final api = await _pump(tester);

    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();

    expect(find.text('新建 Worktree'), findsOneWidget);
    // gitBaseBranches' default ("main") is preselected.
    expect(find.text('main'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, '名称'), 'feature-y');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(api.lastAdd?.$1, '/repo');
    expect(api.lastAdd?.$2, {
      'name': 'feature-y',
      'branch': null,
      'base': 'main',
    });
    expect(find.text('hermes/feature-y'), findsOneWidget);
  });

  testWidgets('deleting a worktree confirms, then calls gitWorktreeRemove', (
    tester,
  ) async {
    final api = await _pump(tester);

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除 worktree？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(api.lastRemove, ('/repo/.worktrees/feature-x', false));
    expect(find.text('hermes/feature-x'), findsNothing);
  });

  testWidgets(
    'a dirty-worktree removal failure offers a force-delete follow-up',
    (tester) async {
      final api = await _pump(tester);
      api.failFirstRemove = true;

      await tester.tap(find.byTooltip('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(find.text('worktree 中有未提交的更改'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '强制删除'));
      await tester.pumpAndSettle();

      expect(api.lastRemove, ('/repo/.worktrees/feature-x', true));
      expect(find.text('hermes/feature-x'), findsNothing);
    },
  );
}
