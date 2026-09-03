/// AppearanceStore: persisted theme mode (system/light/dark) + 主题配色 +
/// 高对比（设计系统规范 v2.0 §8：4 套精选主题，各含明/暗变体）。
///
/// 旧 8 accent id 在读取时经 [HermesAccents.byId] 一次性映射到新 themeId
/// （webui→dune、ocean/sky→graphite、violet→indigo、forest→moss 等）。
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/hermes_tokens.dart';
import '../haptics.dart';

class AppearanceStore extends ChangeNotifier {
  static const _modeKey = 'hm_appearance_mode';
  static const _accentKey = 'hm_appearance_accent';
  static const _highContrastKey = 'hm_appearance_high_contrast';
  static const _hapticsKey = 'hm_appearance_haptics';
  static const _keepAwakeKey = 'hm_appearance_keep_awake';

  ThemeMode _mode = ThemeMode.dark;
  String _accentId = HermesAccents.graphite.id;
  bool _highContrast = false;
  bool _hapticsEnabled = true;
  bool _keepAwake = false;

  ThemeMode get themeMode => _mode;
  String get accentId => _accentId;
  HermesAccent get accent => HermesAccents.byId(_accentId);
  bool get highContrast => _highContrast;
  bool get hapticsEnabled => _hapticsEnabled;

  /// Desktop parity: `store/keep-awake.ts` — off by default, a device-local
  /// preference. Desktop blocks the machine from sleeping during long
  /// unattended runs; mobile's analog is keeping the *screen* on while
  /// [ChatScreen] is in the foreground (there is no mobile equivalent of
  /// "prevent the whole device from sleeping" — background execution is the
  /// OS's call, not the app's).
  bool get keepAwake => _keepAwake;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_modeKey);
    _mode = switch (mode) {
      'system' => ThemeMode.system,
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
    // 旧 accent id → 新 themeId 迁移：byId 内置映射，读取后即规范化写回。
    final stored = prefs.getString(_accentKey);
    final migrated = HermesAccents.byId(stored).id;
    _accentId = migrated;
    if (stored != null && stored != migrated) {
      await prefs.setString(_accentKey, migrated);
    }
    _highContrast = prefs.getBool(_highContrastKey) ?? false;
    _hapticsEnabled = prefs.getBool(_hapticsKey) ?? true;
    HermesHaptics.enabled = _hapticsEnabled;
    _keepAwake = prefs.getBool(_keepAwakeKey) ?? false;
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (value == _hapticsEnabled) return;
    _hapticsEnabled = value;
    HermesHaptics.enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, value);
  }

  Future<void> setKeepAwake(bool value) async {
    if (value == _keepAwake) return;
    _keepAwake = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepAwakeKey, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setAccentId(String id) async {
    if (id == _accentId) return;
    _accentId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, id);
  }

  Future<void> setHighContrast(bool value) async {
    if (value == _highContrast) return;
    _highContrast = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, value);
  }
}
