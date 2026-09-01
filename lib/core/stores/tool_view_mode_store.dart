import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global "technical vs friendly" tool-row view mode (desktop `$toolViewMode`).
/// `technical` shows raw args / result JSON for every tool row; `friendly`
/// (default) shows the readable presentation. Session-independent, persisted.
class ToolViewModeStore {
  ToolViewModeStore._();
  static final ToolViewModeStore instance = ToolViewModeStore._();

  static const _key = 'hm_tool_view_technical';

  /// True == technical (raw payload) view.
  final ValueNotifier<bool> technical = ValueNotifier<bool>(false);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      technical.value = prefs.getBool(_key) ?? false;
    } catch (_) {
      // Defaults are fine when preferences are unavailable.
    }
  }

  Future<void> toggle() async {
    technical.value = !technical.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, technical.value);
    } catch (_) {}
  }

  /// Round-trippable JSON of a tool payload for the technical view.
  static String prettyJson(Object? value) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return const JsonEncoder.withIndent(
            '  ',
          ).convert(jsonDecode(trimmed));
        } catch (_) {
          return value;
        }
      }
      return value;
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}
