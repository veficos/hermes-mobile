import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/tool_card_models.dart';

void main() {
  group('DelegateRunModel.listFrom', () {
    test('falls back to a single row when args has no tasks array', () {
      final rows = DelegateRunModel.listFrom({
        'tool_id': 'call-1',
        'task': 'refactor the auth module',
        'running': true,
      });
      expect(rows, hasLength(1));
      expect(rows.first.task, 'refactor the auth module');
      expect(rows.first.status, 'running');
    });

    test('fans out one row per dispatched task', () {
      final rows = DelegateRunModel.listFrom({
        'tool_id': 'call-1',
        'running': true,
        'args': {
          'tasks': [
            {'goal': 'write tests'},
            {'goal': 'update docs'},
          ],
        },
      });
      expect(rows, hasLength(2));
      expect(rows[0].id, 'call-1:0');
      expect(rows[0].task, 'write tests');
      expect(rows[0].status, 'running');
      expect(rows[1].id, 'call-1:1');
      expect(rows[1].task, 'update docs');
    });

    test('marks a row completed once its result settles', () {
      final rows = DelegateRunModel.listFrom({
        'tool_id': 'call-1',
        'running': false,
        'args': {
          'tasks': [
            {'goal': 'write tests'},
            {'goal': 'update docs'},
          ],
        },
        'result': {
          'results': [
            {'status': 'ok', 'model': 'gpt-5', 'duration_seconds': 12},
          ],
        },
      });
      expect(rows[0].status, 'completed');
      expect(rows[0].model, 'gpt-5');
      expect(rows[0].durationMs, 12000);
      // No result row yet for the second task, and the call as a whole is
      // no longer marked running (a background dispatch) — parked, not
      // failed.
      expect(rows[1].status, 'dispatched');
    });

    test('marks a settled row failed on a non-ok status', () {
      final rows = DelegateRunModel.listFrom({
        'tool_id': 'call-1',
        'args': {
          'tasks': [
            {'goal': 'flaky task'},
          ],
        },
        'result': {
          'results': [
            {'status': 'timeout'},
          ],
        },
      });
      expect(rows.single.status, 'failed');
    });
  });
}
