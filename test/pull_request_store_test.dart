import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/pull_request_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/widgets/session/session_list_meta.dart';
import 'package:provider/provider.dart';

class _PrApi extends ApiClient {
  _PrApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int scanCalls = 0;
  int listCalls = 0;
  bool scanMissing = false;
  Completer<void>? scanGate;
  Completer<void>? listGate;
  Map<String, dynamic> scanResult = const {
    'pull_requests': <String, dynamic>{},
    'scanned': <String>[],
  };
  List<Map<String, dynamic>> prs = [];
  List<String> lastBranches = [];
  List<int> lastNumbers = [];

  @override
  Future<Map<String, dynamic>> scanSessionPullRequests(
    List<String> sessionIds,
  ) async {
    scanCalls++;
    if (scanMissing) throw ApiException(404, 'missing');
    await scanGate?.future;
    return scanResult;
  }

  @override
  Future<List<Map<String, dynamic>>> gitPullRequests(
    String path, {
    List<String> branches = const [],
    List<int> numbers = const [],
  }) async {
    listCalls++;
    lastBranches = List.of(branches);
    lastNumbers = List.of(numbers);
    await listGate?.future;
    return List.of(prs);
  }
}

SessionRow _row({
  String id = 's1',
  String branch = 'feature/mobile',
  String profile = 'default',
}) => SessionRow(
  id: id,
  gitRepoRoot: '/repo',
  gitBranch: branch,
  profile: profile,
);

Map<String, dynamic> _pr({
  String branch = 'feature/mobile',
  int number = 12,
  String state = 'open',
  bool draft = false,
}) => {
  'branch': branch,
  'draft': draft,
  'number': number,
  'state': state,
  'title': 'Mobile parity',
  'url': 'https://github.com/o/r/pull/$number',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('SessionRow preserves git_repo_root through JSON and copyWith', () {
    final row = SessionRow.fromJson({
      'id': 's1',
      'git_repo_root': '/repo',
      'git_branch': 'feature/mobile',
    });

    expect(row.gitRepoRoot, '/repo');
    expect(row.toJson()['git_repo_root'], '/repo');
    expect(row.copyWith(profile: 'work').gitRepoRoot, '/repo');
  });

  test('trunk branch is never joined to a pull request', () async {
    final api = _PrApi()
      ..scanResult = const {
        'pull_requests': {},
        'scanned': ['s1'],
      };
    final store = PullRequestStore(api: api, profile: 'default');

    await store.refreshForSessions([_row(branch: 'main')]);

    expect(store.sessionLookupKey(_row(branch: 'main')), isNull);
    expect(api.listCalls, 0);
    expect(api.scanCalls, 1);
  });

  test('ordinary branch joins PR and reports open bucket', () async {
    final api = _PrApi()..prs = [_pr()];
    final store = PullRequestStore(api: api, profile: 'default');
    final row = _row();

    await store.refreshForSessions([row]);

    expect(api.lastBranches, ['feature/mobile']);
    expect(store.forSession(row)?.number, 12);
    expect(store.bucketFor(row), PullRequestBucket.open);
  });

  test(
    'transcript recovery requests PR by number and is scanned once',
    () async {
      final api = _PrApi()
        ..scanResult = {
          'pull_requests': {
            's1': {'number': 77, 'url': 'https://github.com/o/r/pull/77'},
          },
          'scanned': ['s1'],
        }
        ..prs = [_pr(branch: 'worktree-branch', number: 77)];
      final store = PullRequestStore(api: api, profile: 'default');
      final row = _row(branch: 'main');

      await store.refreshForSessions([row]);
      await store.refreshForSessions([row], force: true);

      expect(api.scanCalls, 1);
      expect(api.lastNumbers, [77]);
      expect(store.forSession(row)?.number, 77);
    },
  );

  test(
    '60 second cache and in-flight map deduplicate repo refreshes',
    () async {
      var now = DateTime(2026, 1, 1);
      final api = _PrApi()
        ..prs = [_pr()]
        ..listGate = Completer<void>();
      final store = PullRequestStore(
        api: api,
        profile: 'default',
        now: () => now,
      );
      final row = _row();

      final first = store.refreshForSessions([row]);
      final second = store.refreshForSessions([row]);
      await Future<void>.delayed(Duration.zero);
      expect(api.listCalls, 1);
      api.listGate!.complete();
      await Future.wait([first, second]);
      await store.refreshForSessions([row]);
      expect(api.listCalls, 1);

      now = now.add(const Duration(seconds: 61));
      api.listGate = null;
      await store.refreshForSessions([row]);
      expect(api.listCalls, 2);
    },
  );

  test('bucket mapping covers draft merged closed and none', () async {
    final api = _PrApi();
    final store = PullRequestStore(api: api, profile: 'default');
    final row = _row();

    for (final value in [
      (_pr(draft: true), PullRequestBucket.draft),
      (_pr(state: 'merged'), PullRequestBucket.merged),
      (_pr(state: 'closed'), PullRequestBucket.closed),
    ]) {
      api.prs = [value.$1];
      await store.refreshForSessions([row], force: true);
      expect(store.bucketFor(row), value.$2);
    }
    api.prs = [];
    await store.refreshForSessions([row], force: true);
    expect(store.bucketFor(row), PullRequestBucket.none);
  });

  test('connection and profile scopes isolate stamps and filters', () async {
    final api = _PrApi()..prs = [_pr()];
    final store = PullRequestStore(
      api: api,
      connectionId: 'one',
      profile: 'default',
    );
    final row = _row(branch: 'main');
    await store.stampSessionPrBranch(
      sessionId: row.id,
      repoRoot: '/repo',
      branch: 'feature/mobile',
    );
    await store.setFilter({PullRequestBucket.open});
    expect(store.sessionLookupKey(row), '/repo\nfeature/mobile');

    store.bind(api: api, connectionId: 'two', profile: 'default');
    expect(store.sessionLookupKey(row), isNull);
    expect(store.filter, isEmpty);

    store.bind(api: api, connectionId: 'one', profile: 'work');
    expect(
      store.sessionLookupKey(_row(branch: 'main', profile: 'work')),
      isNull,
    );
  });

  test(
    'an old connection transcript scan cannot stamp the new scope',
    () async {
      final oldApi = _PrApi()
        ..scanGate = Completer<void>()
        ..scanResult = {
          'pull_requests': {
            's1': {'number': 77},
          },
          'scanned': ['s1'],
        };
      final newApi = _PrApi();
      final store = PullRequestStore(
        api: oldApi,
        connectionId: 'old',
        profile: 'default',
      );
      final row = _row(branch: 'main');
      final oldRefresh = store.refreshForSessions([row]);
      await Future<void>.delayed(Duration.zero);

      store.bind(api: newApi, connectionId: 'new', profile: 'default');
      oldApi.scanGate!.complete();
      await oldRefresh;

      expect(store.sessionLookupKey(row), isNull);
      await store.refreshForSessions([row]);
      expect(newApi.scanCalls, 1);
    },
  );

  test('repo refresh replaces old slice instead of leaving stale PR', () async {
    final api = _PrApi()..prs = [_pr()];
    final store = PullRequestStore(api: api, profile: 'default');
    final row = _row();
    await store.refreshForSessions([row]);
    expect(store.forSession(row), isNotNull);

    api.prs = [];
    await store.refreshForSessions([row], force: true);
    expect(store.forSession(row), isNull);
  });

  test('missing transcript endpoint falls back to branch joins', () async {
    final api = _PrApi()
      ..scanMissing = true
      ..prs = [_pr()];
    final store = PullRequestStore(api: api, profile: 'default');

    await store.refreshForSessions([_row(branch: 'main')]);
    await store.refreshForSessions([_row(id: 's2', branch: 'main')]);
    expect(api.scanCalls, 1);

    final branchRow = _row(id: 's3');
    await store.refreshForSessions([branchRow]);
    expect(store.forSession(branchRow)?.number, 12);
  });

  testWidgets('session metadata renders the resolved PR badge', (tester) async {
    final api = _PrApi()..prs = [_pr()];
    final store = PullRequestStore(api: api, profile: 'default');
    final row = _row();
    await store.refreshForSessions([row]);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SessionMetaBadges(row: row)),
        ),
      ),
    );

    expect(find.byTooltip('PR #12 · Open'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.call_made));
    expect(icon.color, isNotNull);
  });
}
