import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/session_tree.dart';

void main() {
  test('large session tree projects in bounded time and preserves depth', () {
    final rows = <SessionRow>[];
    for (var i = 0; i < 5000; i++) {
      rows.add(SessionRow(id: 'root-$i', title: 'Root $i'));
      rows.add(
        SessionRow(
          id: 'child-$i',
          title: 'Child $i',
          parentSessionId: 'root-$i',
        ),
      );
    }
    final watch = Stopwatch()..start();
    final visible = buildSessionTree(rows);
    watch.stop();
    expect(visible.length, 10000);
    expect(visible.take(2).map((item) => item.depth), [0, 1]);
    expect(watch.elapsedMilliseconds, lessThan(500));

    final expanded = buildVisibleSessionTree(rows, {'root-0', 'root-1'});
    expect(expanded.length, 5002);
    expect(expanded[1].depth, 1);
    expect(expanded[3].depth, 1);
  });
}
