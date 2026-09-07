import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local privacy policy for transcript embeds. Merely viewing a
/// transcript must not contact a third party until this policy permits it.
enum EmbedMode { ask, always, off }

class EmbedConsentStore extends ChangeNotifier {
  static const _modeKey = 'hm_embed_mode_v1';
  static const _allowedKey = 'hm_embed_allowed_v1';

  EmbedMode _mode = EmbedMode.ask;
  Set<String> _allowedProviders = const <String>{};

  EmbedMode get mode => _mode;
  Set<String> get allowedProviders => Set.unmodifiable(_allowedProviders);

  bool allows(String provider) =>
      _mode == EmbedMode.always ||
      (_mode == EmbedMode.ask && _allowedProviders.contains(_key(provider)));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = switch (prefs.getString(_modeKey)) {
      'always' => EmbedMode.always,
      'off' => EmbedMode.off,
      _ => EmbedMode.ask,
    };
    _allowedProviders =
        prefs
            .getStringList(_allowedKey)
            ?.map(_key)
            .where((item) => item.isNotEmpty)
            .toSet() ??
        <String>{};
    notifyListeners();
  }

  Future<void> setMode(EmbedMode value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, value.name);
  }

  Future<void> allowProvider(String provider) async {
    final key = _key(provider);
    if (key.isEmpty || _allowedProviders.contains(key)) return;
    _allowedProviders = {..._allowedProviders, key};
    notifyListeners();
    await _persistAllowed();
  }

  Future<void> revokeProvider(String provider) async {
    final key = _key(provider);
    if (!_allowedProviders.contains(key)) return;
    _allowedProviders = {..._allowedProviders}..remove(key);
    notifyListeners();
    await _persistAllowed();
  }

  Future<void> clearAllowedProviders() async {
    if (_allowedProviders.isEmpty) return;
    _allowedProviders = <String>{};
    notifyListeners();
    await _persistAllowed();
  }

  Future<void> _persistAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = _allowedProviders.toList()..sort();
    await prefs.setStringList(_allowedKey, sorted);
  }

  static String _key(String value) => value.trim().toLowerCase();
}
