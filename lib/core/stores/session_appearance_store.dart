import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable per-session color overrides, matching Desktop's
/// `$sessionColorOverrides` behavior.
class SessionAppearanceStore extends ChangeNotifier {
  static const _storageKey = 'hm_session_color_overrides_v1';

  static final List<Color> swatches = List<Color>.unmodifiable(
    List.generate(
      12,
      (index) => HSLColor.fromAHSL(1, index * 30, 0.68, 0.58).toColor(),
    ),
  );

  final Map<String, Color> _overrides = {};
  int _revision = 0;
  int get revision => _revision;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  Color? colorFor(String sessionId) => _overrides[sessionId];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _overrides
        ..clear()
        ..addEntries(
          decoded.entries
              .where((entry) => entry.value is int)
              .map((entry) => MapEntry(entry.key, Color(entry.value as int))),
        );
      notifyListeners();
    } catch (_) {
      // A corrupt local preference must not prevent the session list loading.
    }
  }

  Future<void> setColor(String sessionId, Color? color) async {
    if (color == null) {
      _overrides.remove(sessionId);
    } else {
      _overrides[sessionId] = color;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        for (final entry in _overrides.entries)
          entry.key: entry.value.toARGB32(),
      }),
    );
  }
}
