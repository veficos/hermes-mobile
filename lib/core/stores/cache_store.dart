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

  String _scopedKey(String base, String scope) =>
      '$base:${Uri.encodeComponent(scope)}';

  Future<void> cacheSessions(
    List<Map<String, dynamic>> sessions, {
    required String scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_sessionsKey, scope),
      jsonEncode(sessions),
    );
  }

  Future<List<Map<String, dynamic>>> cachedSessions({
    required String scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(_sessionsKey, scope));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheCwd(String cwd, {required String scope}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_cwdKey, scope), cwd);
  }

  Future<String> cachedCwd({required String scope}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_cwdKey, scope)) ?? '';
  }

  /// Cache a transcript page: messages + the offset of the oldest loaded
  /// message + whether more history exists.
  Future<void> cacheTranscript(
    String sessionId,
    List<Map<String, dynamic>> messages, {
    int startOffset = 0,
    bool hasMore = false,
    required String scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'offset': startOffset,
      'hasMore': hasMore,
      'messages': messages,
    });
    await prefs.setString(
      _scopedKey('$_transcriptPrefix$sessionId', scope),
      payload,
    );
  }

  Future<Map<String, dynamic>?> cachedTranscript(
    String sessionId, {
    required String scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _scopedKey('$_transcriptPrefix$sessionId', scope),
    );
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTranscript(
    String sessionId, {
    required String scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey('$_transcriptPrefix$sessionId', scope));
  }
}
