import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/session_tree.dart';

void main() {
  final rows = [
    SessionRow(id: 'root', title: 'Root'),
    SessionRow(id: 'child', title: 'Child', parentSessionId: 'root'),
    SessionRow(id: 'grandchild', title: 'Grandchild', parentSessionId: 'child'),
    SessionRow(id: 'other-root', title: 'Other root'),
  ];

  test('visible session tree defaults to roots only', () {
    final visible = buildVisibleSessionTree(rows, const {});

    expect(visible.map((item) => item.row.id), ['root', 'other-root']);
    expect(visible.map((item) => item.depth), [0, 0]);
  });

  test('visible session tree expands one level at a time', () {
    final parentExpanded = buildVisibleSessionTree(rows, const {'root'});
    final childExpanded = buildVisibleSessionTree(rows, const {
      'root',
      'child',
    });

    expect(parentExpanded.map((item) => item.row.id), [
      'root',
      'child',
      'other-root',
    ]);
    expect(childExpanded.map((item) => item.row.id), [
      'root',
      'child',
      'grandchild',
      'other-root',
    ]);
    expect(childExpanded.map((item) => item.depth), [0, 1, 2, 0]);
  });

  test('collapsing a parent hides all descendants', () {
    final visible = buildVisibleSessionTree(rows, const {'child'});

    expect(visible.map((item) => item.row.id), ['root', 'other-root']);
  });
}
