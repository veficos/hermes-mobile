import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/pane_tree.dart';

void main() {
  test('pane tree inserts tabs and edge splits then normalizes on close', () {
    PaneNode tree = const PaneGroup(
      id: 'group-root',
      panes: ['session:a'],
      active: 'session:a',
    );
    tree = insertPaneInTree(
      tree,
      targetGroupId: 'group-root',
      paneId: 'session:b',
      newGroupId: 'unused',
      newSplitId: 'unused',
    );
    expect(paneIds(tree), ['session:a', 'session:b']);
    expect(paneGroupFor(tree, 'session:b')!.active, 'session:b');

    tree = insertPaneInTree(
      tree,
      targetGroupId: 'group-root',
      paneId: 'plugin:tasks',
      newGroupId: 'group-right',
      newSplitId: 'split-root',
      position: PaneDropPosition.right,
    );
    expect(tree, isA<PaneSplit>());
    expect(paneIds(tree), ['session:a', 'session:b', 'plugin:tasks']);

    tree = removePaneFromTree(tree, 'plugin:tasks')!;
    expect(tree, isA<PaneGroup>());
    expect(paneIds(tree), ['session:a', 'session:b']);

    tree = removePaneFromTree(tree, 'session:b')!;
    expect((tree as PaneGroup).active, 'session:a');
  });

  test('moving a pane preserves every pane exactly once', () {
    final root = PaneSplit(
      id: 'root',
      axis: PaneSplitAxis.horizontal,
      children: const [
        PaneGroup(id: 'left', panes: ['a', 'b'], active: 'a'),
        PaneGroup(id: 'right', panes: ['c'], active: 'c'),
      ],
      weights: const [2, 1],
    );
    final moved = movePaneInTree(
      root,
      paneId: 'b',
      targetGroupId: 'right',
      newGroupId: 'bottom',
      newSplitId: 'right-split',
      position: PaneDropPosition.bottom,
    );
    expect(paneIds(moved).toSet(), {'a', 'b', 'c'});
    expect(paneIds(moved).length, 3);
    expect(paneGroupFor(moved, 'b')!.id, 'bottom');
  });

  test('deserialization rejects empty and bounded hostile trees', () {
    expect(
      PaneNode.fromJson({
        'type': 'group',
        'id': '../bad',
        'panes': ['a'],
      }),
      isNull,
    );
    expect(
      PaneNode.fromJson({
        'type': 'group',
        'id': 'valid',
        'panes': List.filled(40, 'same'),
        'active': 'missing',
      }),
      isA<PaneGroup>()
          .having((group) => group.panes, 'unique panes', ['same'])
          .having((group) => group.active, 'fallback active', 'same'),
    );
    final restored = PaneNode.fromJson({
      'type': 'split',
      'id': 'root',
      'axis': 'horizontal',
      'children': [
        {
          'type': 'group',
          'id': 'one',
          'panes': ['a'],
          'active': 'a',
        },
        {
          'type': 'group',
          'id': 'two',
          'panes': ['b'],
          'active': 'b',
        },
      ],
      'weights': ['not-a-number', -4],
    });
    expect((restored as PaneSplit).weights, [1, 1]);
  });
}
