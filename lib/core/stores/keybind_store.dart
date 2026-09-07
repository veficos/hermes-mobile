/// Desktop parity: `store/keybinds.ts` + `lib/keybinds/actions.ts`. Desktop
/// exposes ~50 rebindable actions; mobile only has a handful of
/// hardware-keyboard shortcuts to begin with (desktop-platform builds only —
/// touch has no physical keyboard), so this mirrors just those: undo and
/// find in the chat composer. Escape-to-cancel and Ctrl/Cmd+S save stay
/// fixed, matching desktop's own `KEYBIND_READONLY` treatment of
/// `composer.cancel` (escape is never rebindable there either).
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KeybindAction {
  final String id;
  final List<SingleActivator> defaults;

  const KeybindAction(this.id, this.defaults);
}

class KeybindStore extends ChangeNotifier {
  static const _prefsPrefix = 'hm_keybind_';

  static final List<KeybindAction> actions = [
    KeybindAction('chat.undo', [
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
    ]),
    KeybindAction('chat.find', [
      const SingleActivator(LogicalKeyboardKey.keyF, control: true),
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
    ]),
  ];

  final Map<String, SingleActivator> _overrides = {};

  List<SingleActivator> bindingsFor(String actionId) {
    final override = _overrides[actionId];
    if (override != null) return [override];
    return actions.firstWhere((a) => a.id == actionId).defaults;
  }

  bool isCustomized(String actionId) => _overrides.containsKey(actionId);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final action in actions) {
      final raw = prefs.getString('$_prefsPrefix${action.id}');
      if (raw == null) continue;
      final combo = _decode(raw);
      if (combo != null) _overrides[action.id] = combo;
    }
    notifyListeners();
  }

  /// The id of another action already bound to [activator], if any.
  String? conflictFor(String actionId, SingleActivator activator) {
    for (final action in actions) {
      if (action.id == actionId) continue;
      final bound = bindingsFor(action.id);
      if (bound.any((b) => _sameCombo(b, activator))) return action.id;
    }
    return null;
  }

  Future<void> setBinding(String actionId, SingleActivator activator) async {
    _overrides[actionId] = activator;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsPrefix$actionId', _encode(activator));
  }

  Future<void> resetBinding(String actionId) async {
    if (!_overrides.containsKey(actionId)) return;
    _overrides.remove(actionId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsPrefix$actionId');
  }

  Future<void> resetAll() async {
    if (_overrides.isEmpty) return;
    _overrides.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    for (final action in actions) {
      await prefs.remove('$_prefsPrefix${action.id}');
    }
  }

  static bool _sameCombo(SingleActivator a, SingleActivator b) {
    return a.trigger == b.trigger &&
        a.control == b.control &&
        a.meta == b.meta &&
        a.shift == b.shift &&
        a.alt == b.alt;
  }

  static String _encode(SingleActivator a) {
    return jsonEncode({
      'key': a.trigger.keyId,
      'control': a.control,
      'meta': a.meta,
      'shift': a.shift,
      'alt': a.alt,
    });
  }

  static SingleActivator? _decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final key = LogicalKeyboardKey.findKeyByKeyId(map['key'] as int);
      if (key == null) return null;
      return SingleActivator(
        key,
        control: map['control'] as bool? ?? false,
        meta: map['meta'] as bool? ?? false,
        shift: map['shift'] as bool? ?? false,
        alt: map['alt'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}
