import 'package:shared_preferences/shared_preferences.dart';

/// Small bounded prompt history, separate from structured edit undo.
class ComposerInputHistory {
  final int capacity;
  final List<String> _entries = <String>[];
  int _cursor = 0;
  ComposerInputHistory({this.capacity = 50});

  Future<void> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    _entries
      ..clear()
      ..addAll(prefs.getStringList(key) ?? const <String>[]);
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
    reset();
  }

  Future<void> persist(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, _entries);
  }

  void add(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    _entries.remove(text);
    _entries.add(text);
    if (_entries.length > capacity) _entries.removeAt(0);
    reset();
  }

  String? previous() {
    if (_entries.isEmpty) return null;
    _cursor = (_cursor - 1).clamp(0, _entries.length - 1);
    return _entries[_cursor];
  }

  String? next() {
    if (_entries.isEmpty) return null;
    _cursor = (_cursor + 1).clamp(0, _entries.length);
    return _cursor == _entries.length ? '' : _entries[_cursor];
  }

  void reset() => _cursor = _entries.length;
  List<String> get entries => List.unmodifiable(_entries);
}
