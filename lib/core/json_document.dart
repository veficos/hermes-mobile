library;

import 'dart:convert';

typedef JsonPath = List<Object>;

class JsonDocument {
  const JsonDocument._(this.value);

  final Object? value;

  static JsonDocument parse(String source) =>
      JsonDocument._(jsonDecode(source) as Object?);

  String formatted({int indent = 2}) =>
      JsonEncoder.withIndent(' ' * indent).convert(value);

  Object? at(JsonPath path) {
    Object? cursor = value;
    for (final segment in path) {
      cursor = switch ((cursor, segment)) {
        (final Map<Object?, Object?> map, final String key)
            when map.containsKey(key) =>
          map[key],
        (final List<Object?> list, final int index)
            when index >= 0 && index < list.length =>
          list[index],
        _ => throw RangeError('Invalid JSON path: ${_displayPath(path)}'),
      };
    }
    return cursor;
  }

  JsonDocument set(JsonPath path, Object? next) {
    if (path.isEmpty) return JsonDocument._(_normalize(next));
    final root = _deepCopy(value);
    final parent = _parentAt(root, path);
    _write(parent, path.last, _normalize(next));
    return JsonDocument._(root);
  }

  JsonDocument remove(JsonPath path) {
    if (path.isEmpty) return const JsonDocument._(null);
    final root = _deepCopy(value);
    final parent = _parentAt(root, path);
    final segment = path.last;
    switch ((parent, segment)) {
      case (final Map<Object?, Object?> map, final String key):
        if (!map.containsKey(key)) throw RangeError('Missing key: $key');
        map.remove(key);
      case (final List<Object?> list, final int index):
        if (index < 0 || index >= list.length) throw RangeError.index(index, list);
        list.removeAt(index);
      default:
        throw RangeError('Invalid JSON path: ${_displayPath(path)}');
    }
    return JsonDocument._(root);
  }

  static Object? _parentAt(Object? root, JsonPath path) {
    Object? cursor = root;
    for (final segment in path.take(path.length - 1)) {
      cursor = switch ((cursor, segment)) {
        (final Map<Object?, Object?> map, final String key) => map[key],
        (final List<Object?> list, final int index)
            when index >= 0 && index < list.length =>
          list[index],
        _ => throw RangeError('Invalid JSON path: ${_displayPath(path)}'),
      };
    }
    return cursor;
  }

  static void _write(Object? parent, Object segment, Object? next) {
    switch ((parent, segment)) {
      case (final Map<Object?, Object?> map, final String key):
        map[key] = next;
      case (final List<Object?> list, final int index):
        if (index < 0 || index >= list.length) throw RangeError.index(index, list);
        list[index] = next;
      default:
        throw RangeError('Cannot write JSON path segment: $segment');
    }
  }

  static Object? _normalize(Object? input) {
    jsonEncode(input);
    return _deepCopy(input);
  }

  static Object? _deepCopy(Object? input) => jsonDecode(jsonEncode(input));

  static String _displayPath(JsonPath path) =>
      path.map((part) => part is int ? '[$part]' : '.$part').join();
}
