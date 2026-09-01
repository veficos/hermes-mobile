library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleStore extends ChangeNotifier {
  static const _preferenceKey = 'hm_display_locale_v1';
  static const supportedTags = {'en', 'zh', 'zh_Hant', 'ja', 'ar'};

  Locale? _locale;
  bool _loaded = false;

  Locale? get locale => _locale;
  bool get loaded => _loaded;
  String get tag => localeTag(_locale);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = localeFromTag(prefs.getString(_preferenceKey));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale? value) async {
    final normalized = localeFromTag(localeTag(value));
    if (_loaded && normalized == _locale) return;
    _locale = normalized;
    _loaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_preferenceKey);
    } else {
      await prefs.setString(_preferenceKey, localeTag(normalized));
    }
  }

  static Locale? localeFromTag(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == 'system') return null;
    final tag = raw.trim().replaceAll('-', '_');
    if (!supportedTags.contains(tag)) return null;
    if (tag == 'zh_Hant') {
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    }
    return Locale(tag);
  }

  static String localeTag(Locale? locale) {
    if (locale == null) return 'system';
    if (locale.languageCode == 'zh' && locale.scriptCode == 'Hant') {
      return 'zh_Hant';
    }
    return locale.languageCode;
  }
}
