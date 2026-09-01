import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/coding_status_store.dart';

class _GitApi extends ApiClient {
  _GitApi() : super(baseUrl: 'http://example.invalid', apiKey: 'test');

  int calls = 0;

  @override
  Future<Map<String, dynamic>> gitStatus(String path) async {
    calls++;
    return {
      'current': 'feature/status',
      'added': 12,
      'removed': 3,
      'untracked': 2,
      'ahead': 1,
      'behind': 4,
    };
  }
}

class _DelayedGitApi extends ApiClient {
  _DelayedGitApi(this.branch)
    : super(baseUrl: 'http://example.invalid', apiKey: 'test');

  final String branch;
  final Completer<void> gate = Completer<void>();

  @override
  Future<Map<String, dynamic>> gitStatus(String path) async {
    await gate.future;
    return {'current': branch};
  }
}

void main() {
  test(
    'coding status is scoped by cwd and coalesces concurrent refreshes',
    () async {
      final api = _GitApi();
      final store = CodingStatusStore()..bindApi(api);

      await Future.wait([store.refresh('/repo'), store.refresh('/repo')]);
      final status = store.forCwd('/repo');

      expect(api.calls, 1);
      expect(status?.branch, 'feature/status');
      expect(status?.changed, 17);
      expect(status?.ahead, 1);
      expect(status?.behind, 4);
    },
  );

  test('coding mutations fail while disconnected', () async {
    final store = CodingStatusStore();

    await expectLater(store.switchBranch('/repo', 'main'), throwsStateError);
    await expectLater(
      store.addWorktree('/repo', name: 'feature'),
      throwsStateError,
    );
  });

  test('old connection status cannot overwrite the newly bound API', () async {
    final oldApi = _DelayedGitApi('old');
    final newApi = _DelayedGitApi('new');
    final store = CodingStatusStore()..bindApi(oldApi);
    final oldRefresh = store.refresh('/repo');

    store.bindApi(newApi);
    final newRefresh = store.refresh('/repo');
    newApi.gate.complete();
    await newRefresh;
    expect(store.forCwd('/repo')?.branch, 'new');

    oldApi.gate.complete();
    await oldRefresh;
    expect(store.forCwd('/repo')?.branch, 'new');
  });
}
