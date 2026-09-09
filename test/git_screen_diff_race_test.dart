import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/git_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tablet inline diff: `_showDiff` used to guard its write-back with the
/// shared `_loadGeneration`, which only changes on a full reload. A slow diff
/// for file A could therefore overwrite the panel after the user had already
/// selected file B. A dedicated `_diffGeneration` now invalidates stale
/// responses.
class _RaceGitApi extends ApiClient {
  _RaceGitApi() : super(baseUrl: 'http://race.invalid', apiKey: 'test');

  final Map<String, Completer<String>> diffCompleters = {};

  @override
  Future<Map<String, dynamic>> gitStatus(String path) async =>
      {'branch': 'main', 'staged': 0, 'unstaged': 2, 'untracked': 0};

  @override
  Future<List<Map<String, dynamic>>> gitReviewList(
    String path, {
    String scope = 'uncommitted',
    String? base,
  }) async => [
    {'path': 'a.txt', 'status': 'M', 'staged': false, 'added': 1, 'removed': 0},
    {'path': 'b.txt', 'status': 'M', 'staged': false, 'added': 1, 'removed': 0},
  ];

  @override
  Future<List<Map<String, dynamic>>> gitBranches(String path) async => const [];

  @override
  Future<List<Map<String, dynamic>>> gitRemotes(String path) async => const [];

  @override
  Future<List<Map<String, dynamic>>> gitStashes(String path) async => const [];

  @override
  Future<String> gitReviewDiff(
    String path,
    String file, {
    String scope = 'uncommitted',
    String? base,
    bool staged = false,
  }) {
    final completer = Completer<String>();
    diffCompleters[file] = completer;
    return completer.future;
  }
}

void main() {
  testWidgets('late diff response cannot overwrite a newer selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final api = _RaceGitApi();
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GitScreen(initialPath: '/repo'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select a.txt: its diff request hangs.
    await tester.tap(find.text('a.txt'));
    await tester.pump();
    expect(api.diffCompleters.containsKey('a.txt'), isTrue);

    // Select b.txt while a.txt is still in flight.
    await tester.tap(find.text('b.txt'));
    await tester.pump();
    expect(api.diffCompleters.containsKey('b.txt'), isTrue);

    // b.txt resolves first and is shown.
    api.diffCompleters['b.txt']!.complete('diff-b-content');
    await tester.pumpAndSettle();
    expect(find.text('diff-b-content'), findsOneWidget);

    // The stale a.txt response must not clobber the b.txt panel.
    api.diffCompleters['a.txt']!.complete('diff-a-content');
    await tester.pumpAndSettle();
    expect(find.text('diff-b-content'), findsOneWidget);
    expect(find.text('diff-a-content'), findsNothing);
  });
}
