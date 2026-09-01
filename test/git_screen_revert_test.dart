import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/git_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `gitRevert` (`POST /api/v1/git/review/revert`) already existed server-side
/// but no Dart caller ever used it — the working tree had no in-app "discard
/// changes" action. This covers the new per-file and "revert all" buttons.
class _GitApi extends ApiClient {
  _GitApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final List<(String, String?)> revertCalls = [];
  List<Map<String, dynamic>> files = [
    {'path': 'a.txt', 'status': 'M', 'staged': false, 'added': 1, 'removed': 0},
    {'path': 'b.txt', 'status': 'M', 'staged': false, 'added': 2, 'removed': 1},
  ];

  @override
  Future<Map<String, dynamic>> gitStatus(String path) async => {
    'branch': 'main',
    'staged': 0,
    'unstaged': files.length,
    'untracked': 0,
  };

  @override
  Future<List<Map<String, dynamic>>> gitReviewList(
    String path, {
    String scope = 'uncommitted',
    String? base,
  }) async => files;

  @override
  Future<List<Map<String, dynamic>>> gitBranches(String path) async => const [];

  @override
  Future<List<Map<String, dynamic>>> gitRemotes(String path) async => const [];

  @override
  Future<List<Map<String, dynamic>>> gitStashes(String path) async => const [];

  @override
  Future<void> gitRevert(String path, String? file) async {
    revertCalls.add((path, file));
    if (file == null) {
      files = [];
    } else {
      files = files.where((f) => f['path'] != file).toList();
    }
  }
}

class _DeferredGitApi extends _GitApi {
  final revert = Completer<void>();

  @override
  Future<void> gitRevert(String path, String? file) async {
    revertCalls.add((path, file));
    await revert.future;
    files = [];
  }
}

class _NotifyingConnection extends ConnectionStore {
  void expose(ApiClient api) {
    this.api = api;
    notifyListeners();
  }
}

Future<_GitApi> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final api = _GitApi();
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
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GitScreen(initialPath: '/repo'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('English Git UI and revert dialog do not leak Chinese', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('en'));
    expect(find.text('Changes'), findsOneWidget);
    expect(find.text('Changed files'), findsOneWidget);
    _expectNoHanText(tester);

    await tester.tap(find.byTooltip('Revert this file').first);
    await tester.pumpAndSettle();
    expect(find.text('Revert this file?'), findsOneWidget);
    _expectNoHanText(tester);
  });

  testWidgets(
    'reverting a single file calls gitRevert with that file and reloads',
    (tester) async {
      final api = await _pump(tester);
      expect(find.text('a.txt'), findsOneWidget);
      expect(find.text('b.txt'), findsOneWidget);

      await tester.tap(find.byTooltip('还原此文件').first);
      await tester.pumpAndSettle();
      // Confirm dialog names the specific file.
      expect(find.text('还原此文件？'), findsOneWidget);
      expect(find.textContaining('a.txt'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, '还原'));
      await tester.pumpAndSettle();

      expect(api.revertCalls, [('/repo', 'a.txt')]);
      expect(find.text('a.txt'), findsNothing);
      expect(find.text('b.txt'), findsOneWidget);
    },
  );

  testWidgets('"全部还原" reverts every file after confirmation', (tester) async {
    final api = await _pump(tester);
    await tester.tap(find.text('全部还原'));
    await tester.pumpAndSettle();
    expect(find.text('还原全部更改？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '还原'));
    await tester.pumpAndSettle();

    expect(api.revertCalls, [('/repo', null)]);
    expect(find.text('工作区干净，没有更改'), findsOneWidget);
  });

  testWidgets('cancelling the confirm dialog does not revert anything', (
    tester,
  ) async {
    final api = await _pump(tester);
    await tester.tap(find.byTooltip('还原此文件').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(api.revertCalls, isEmpty);
    expect(find.text('a.txt'), findsOneWidget);
  });

  testWidgets('late revert cannot clear a reconnected repository', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final stale = _DeferredGitApi();
    final current = _GitApi()
      ..files = [
        {
          'path': 'current.txt',
          'status': 'M',
          'staged': false,
          'added': 1,
          'removed': 0,
        },
      ];
    final connection = _NotifyingConnection()..expose(stale);
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

    await tester.tap(find.byTooltip('还原此文件').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '还原'));
    await tester.pump();
    expect(stale.revertCalls, [('/repo', 'a.txt')]);

    connection.expose(current);
    await tester.pumpAndSettle();
    expect(find.text('current.txt'), findsOneWidget);

    stale.revert.complete();
    await tester.pumpAndSettle();
    expect(find.text('current.txt'), findsOneWidget);
    expect(find.text('工作区干净，没有更改'), findsNothing);
  });
}

void _expectNoHanText(WidgetTester tester) {
  final han = RegExp(r'[\u3400-\u9fff]');
  final leaked = find
      .byType(Text)
      .evaluate()
      .map((element) => element.widget as Text)
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .where(han.hasMatch)
      .toList();
  expect(leaked, isEmpty);
}
