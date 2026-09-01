library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connection-scoped persistence for unsent composer drafts. Desktop keeps
/// the same state client-side; direct Gateways intentionally expose no draft
/// REST resource.
class ComposerDraftStore {
  static const _maxTextLength = 50000;
  static const _maxFiles = 50;
  static const _maxDrafts = 200;

  final String _key;

  ComposerDraftStore(String connectionIdentity)
    : _key =
          'hermes.composer.drafts.${sha256.convert(utf8.encode(connectionIdentity)).toString().substring(0, 24)}.v1';

  Future<Map<String, dynamic>> load(String sessionId) async {
    final all = await _read();
    final raw = all[sessionId];
    if (raw is! Map) return const {'text': '', 'files': <dynamic>[]};
    return {
      'text': raw['text']?.toString() ?? '',
      'files': raw['files'] is List
          ? List<dynamic>.from(raw['files'] as List)
          : <dynamic>[],
    };
  }

  Future<Map<String, dynamic>> save(
    String sessionId, {
    String? text,
    List<dynamic>? files,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _read(prefs);
    final previous = all[sessionId] is Map
        ? (all[sessionId] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final nextText = (text ?? previous['text']?.toString() ?? '');
    final boundedText = nextText.length > _maxTextLength
        ? nextText.substring(0, _maxTextLength)
        : nextText;
    final nextFiles = files == null
        ? List<dynamic>.from(previous['files'] as List? ?? const [])
        : List<dynamic>.from(files.take(_maxFiles));

    if (boundedText.isEmpty && nextFiles.isEmpty) {
      all.remove(sessionId);
    } else {
      all[sessionId] = {
        'text': boundedText,
        'files': nextFiles,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
    }
    if (all.length > _maxDrafts) {
      final oldest = all.entries.toList()
        ..sort((a, b) {
          final left = (a.value as Map?)?['updated_at'] as num? ?? 0;
          final right = (b.value as Map?)?['updated_at'] as num? ?? 0;
          return left.compareTo(right);
        });
      for (final entry in oldest.take(all.length - _maxDrafts)) {
        all.remove(entry.key);
      }
    }
    await prefs.setString(_key, jsonEncode(all));
    return {'text': boundedText, 'files': nextFiles};
  }

  Future<Map<String, dynamic>> _read([SharedPreferences? existing]) async {
    final prefs = existing ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
