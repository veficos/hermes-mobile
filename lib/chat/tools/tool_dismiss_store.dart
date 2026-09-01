import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session-scoped dismissal state for low-value settled tool rows.
class ToolDismissStore extends ChangeNotifier {
  static const _storageKey = 'hm_tool_dismiss_v2';
  final Map<String, Set<String>> _dismissedBySession = <String, Set<String>>{};
  String _sessionId = '';
  bool _loaded = false;

  String get sessionId => _sessionId;
  bool get loaded => _loaded;

  Future<void> bindSession(String? sessionId) async {
    final next = (sessionId ?? '').trim();
    if (next == _sessionId && _loaded) return;
    _sessionId = next;
    await _load();
    notifyListeners();
  }

  bool isDismissed(String id, {String? sessionId}) {
    final scope = (sessionId ?? _sessionId).trim();
    return (_dismissedBySession[scope] ?? const <String>{}).contains(id);
  }

  void dismiss(String id, {bool running = false, bool interactive = false}) {
    if (id.isEmpty || running || interactive) return;
    final set = _dismissedBySession.putIfAbsent(_sessionId, () => <String>{});
    if (set.add(id)) {
      notifyListeners();
      _persist();
    }
  }

  void restore(String id) {
    final set = _dismissedBySession[_sessionId];
    if (set != null && set.remove(id)) {
      notifyListeners();
      _persist();
    }
  }

  void clear({String? sessionId}) {
    final scope = (sessionId ?? _sessionId).trim();
    if ((_dismissedBySession[scope] ?? const <String>{}).isEmpty) return;
    _dismissedBySession.remove(scope);
    notifyListeners();
    _persist();
  }

  Future<void> _load() async {
    _loaded = false;
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _loaded = true;
      return;
    }
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _dismissedBySession
            ..clear()
            ..addAll(
              decoded.map(
                (key, value) => MapEntry(
                  key.toString(),
                  (value is List ? value : const <dynamic>[])
                      .map((item) => item.toString())
                      .toSet(),
                ),
              ),
            );
        }
      } catch (_) {
        // Corrupt local UI state must never block chat rendering.
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(
          _dismissedBySession.map(
            (key, value) => MapEntry(key, value.toList()),
          ),
        ),
      );
    } catch (_) {
      // Persistence is best effort when platform preferences are unavailable.
    }
  }
}
