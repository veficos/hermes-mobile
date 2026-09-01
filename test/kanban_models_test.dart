import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/kanban/models.dart';

void main() {
  test('parses all canonical columns and task metadata', () {
    final board = KanbanBoard.fromJson({
      'latest_event_id': 7,
      'tenants': ['a'],
      'assignees': ['worker'],
      'columns': [
        for (final status in const [
          'triage',
          'todo',
          'scheduled',
          'ready',
          'running',
          'blocked',
          'review',
          'done',
          'archived',
        ])
          {
            'name': status,
            'tasks': [
              {
                'id': status,
                'title': status,
                'status': status,
                'warnings': {'count': 1},
              },
            ],
          },
      ],
    });
    expect(board.columns, hasLength(9));
    expect(board.tasks, hasLength(9));
    expect(
      board.tasks.singleWhere((t) => t.status == 'running').running,
      isTrue,
    );
    expect(board.tasks.first.warnings?['count'], 1);
  });

  test('parses detail sibling collections', () {
    final detail = KanbanTaskDetail.fromJson({
      'task': {
        'id': 't1',
        'title': 'Task',
        'status': 'blocked',
        'diagnostics': [
          {
            'kind': 'x',
            'severity': 'critical',
            'title': 'Bad',
            'detail': 'retry',
            'actions': [],
          },
        ],
      },
      'comments': [
        {'id': 1, 'author': 'a', 'body': 'hi', 'created_at': 1},
      ],
      'events': [
        {'id': 2, 'kind': 'blocked', 'payload': {}, 'created_at': 2},
      ],
      'attachments': [
        {'id': 3, 'filename': 'a.txt', 'size': 4},
      ],
      'runs': [
        {'id': 4, 'status': 'failed', 'error': 'no'},
      ],
      'links': {
        'parents': ['p'],
        'children': ['c'],
      },
    });
    expect(detail.comments.single.body, 'hi');
    expect(detail.events.single.kind, 'blocked');
    expect(detail.attachments.single.filename, 'a.txt');
    expect(detail.runs.single.error, 'no');
    expect(detail.diagnostics.single.severity, 'critical');
    expect(detail.parents, ['p']);
    expect(detail.children, ['c']);
  });
}
