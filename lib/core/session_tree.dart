import 'models.dart';

/// A session row together with its depth in the durable parent/child tree.
class SessionTreeItem {
  final SessionRow row;
  final int depth;

  const SessionTreeItem(this.row, this.depth);
}

/// Projects a flat API response into a stable, cycle-safe session tree.
///
/// Child sessions (any source) are only visible beneath a parent present in
/// the same authoritative response. The backend owns cross-page parent
/// lineage and already collapses compression continuations.
List<SessionTreeItem> buildSessionTree(List<SessionRow> rows) {
  return buildVisibleSessionTree(rows, {for (final row in rows) row.id});
}

/// Projects the rows visible under the currently expanded parents.
///
/// Roots are always visible. A child is visited only when every ancestor on
/// its path is expanded, so collapsing a parent hides its complete subtree.
List<SessionTreeItem> buildVisibleSessionTree(
  List<SessionRow> rows,
  Set<String> expandedIds,
) {
  final byId = <String, SessionRow>{
    for (final row in rows)
      if (row.id.isNotEmpty) row.id: row,
  };
  final children = <String, List<SessionRow>>{};
  final roots = <SessionRow>[];
  for (final row in rows) {
    final parentId = row.parentSessionId;
    if (parentId != null && parentId.isNotEmpty && byId.containsKey(parentId)) {
      (children[parentId] ??= <SessionRow>[]).add(row);
    } else if (row.isChildSession) {
      // Do not promote a child session without its parent context.
    } else {
      roots.add(row);
    }
  }

  final result = <SessionTreeItem>[];
  final seen = <String>{};
  void visit(SessionRow row, int depth) {
    if (row.id.isEmpty || !seen.add(row.id)) return;
    result.add(SessionTreeItem(row, depth));
    if (expandedIds.contains(row.id)) {
      for (final child in children[row.id] ?? const <SessionRow>[]) {
        visit(child, depth + 1);
      }
    }
  }

  for (final root in roots) {
    visit(root, 0);
  }
  // Keep malformed non-child cycles accessible.
  for (final row in rows) {
    if (!row.isChildSession) visit(row, 0);
  }
  return result;
}
