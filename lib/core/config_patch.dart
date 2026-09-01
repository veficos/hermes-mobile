/// Nested get/set helpers for Hermes config maps.
///
/// Paths use dotted keys such as `memory.memory_enabled`. PUT payloads only
/// contain the top-level key so the backend deep-merge keeps sibling fields.
library;

/// Return the value at [path], or null if any segment is missing.
dynamic configValueAt(Map<String, dynamic>? root, String path) {
  if (root == null) return null;
  dynamic current = root;
  for (final segment in path.split('.')) {
    if (current is! Map) return null;
    if (!current.containsKey(segment)) return null;
    current = current[segment];
  }
  return current;
}

/// True when every segment of [path] exists (value may still be null).
bool configHasPath(Map<String, dynamic>? root, String path) {
  if (root == null) return false;
  dynamic current = root;
  for (final segment in path.split('.')) {
    if (current is! Map || !current.containsKey(segment)) return false;
    current = current[segment];
  }
  return true;
}

/// Build a PUT patch for [path] = [value], merging nested maps from [current].
Map<String, dynamic> configPatchAt(
  Map<String, dynamic> current,
  String path,
  dynamic value,
) {
  final parts = path.split('.');
  if (parts.length == 1) {
    return {parts.first: value};
  }
  final top = parts.first;
  final rest = parts.sublist(1);
  final existing = current[top];
  final merged = existing is Map
      ? Map<String, dynamic>.from(existing)
      : <String, dynamic>{};
  _putNested(merged, rest, value);
  return {top: merged};
}

void _putNested(
  Map<String, dynamic> target,
  List<String> parts,
  dynamic value,
) {
  if (parts.length == 1) {
    target[parts.first] = value;
    return;
  }
  final key = parts.first;
  final child = target[key];
  final next = child is Map
      ? Map<String, dynamic>.from(child)
      : <String, dynamic>{};
  _putNested(next, parts.sublist(1), value);
  target[key] = next;
}

/// Return a deep copy with [path] removed. Empty parent maps are pruned.
Map<String, dynamic> configWithoutPath(
  Map<String, dynamic> current,
  String path,
) {
  final copy = _deepCopy(current);
  _removeNested(copy, path.split('.'));
  return copy;
}

bool _removeNested(Map<String, dynamic> target, List<String> parts) {
  if (parts.length == 1) {
    target.remove(parts.first);
    return target.isEmpty;
  }
  final child = target[parts.first];
  if (child is Map) {
    final next = Map<String, dynamic>.from(child);
    if (_removeNested(next, parts.sublist(1))) {
      target.remove(parts.first);
    } else {
      target[parts.first] = next;
    }
  }
  return target.isEmpty;
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) => value.map(
  (key, item) => MapEntry(
    key,
    item is Map
        ? _deepCopy(Map<String, dynamic>.from(item))
        : item is List
        ? item
              .map(
                (entry) => entry is Map
                    ? _deepCopy(Map<String, dynamic>.from(entry))
                    : entry,
              )
              .toList()
        : item,
  ),
);
