/// CacheStore: offline-first disk cache (spec §148–150, §195).
///
/// Sessions list, active transcript pages and the default cwd are persisted
/// to SharedPreferences so the app can show cached (read-only) data when the
/// server is unreachable. All payloads are compact JSON; transcript pages are
/// keyed by session id.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheStore {
  static const _sessionsKey = 'hm_cache_sessions';
  static const _cwdKey = 'hm_cache_cwd';
  static const _transcriptPrefix = 'hm_cache_tr_';

  Future<void> cacheSessions(List<Map<String, dynamic>> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionsKey, jsonEncode(sessions));
  }

  Future<List<Map<String, dynamic>>> cachedSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheCwd(String cwd) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cwdKey, cwd);
  }

  Future<String> cachedCwd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cwdKey) ?? '';
  }

  /// Cache a transcript page: messages + the offset of the oldest loaded
  /// message + whether more history exists.
  Future<void> cacheTranscript(
    String sessionId,
    List<Map<String, dynamic>> messages, {
    int startOffset = 0,
    bool hasMore = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'offset': startOffset,
      'hasMore': hasMore,
      'messages': messages,
    });
    await prefs.setString('$_transcriptPrefix$sessionId', payload);
  }

  Future<Map<String, dynamic>?> cachedTranscript(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_transcriptPrefix$sessionId');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTranscript(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_transcriptPrefix$sessionId');
  }
}
