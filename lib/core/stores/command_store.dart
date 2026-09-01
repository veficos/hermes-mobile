/// CommandStore: slash-command catalog, slash/path autocomplete and command
/// dispatch over the gateway (Batch 3.2 of the desktop migration).
///
/// Socket-bound (needs a live gateway). The ChatScreen uses it to render the
/// autocomplete overlay above the composer and to forward slash-command taps.
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../connections/connection_registry.dart';
import 'connection_store.dart';

const slashGroupSkills = 'Skills';
const slashGroupCommands = 'Commands';

class CommandStore extends ChangeNotifier {
  final ConnectionStore connection;
  CommandStore({required this.connection})
    : _connectionId = connection.activeConnectionId,
      _gateway = connection.gateway {
    connection.addListener(_onConnectionChanged);
  }

  ConnectionId _connectionId;
  Object? _gateway;
  String? _profile;
  int _generation = 0;

  List<SlashCommand> _catalog = [];
  List<SlashCommand> get catalog => _catalog;
  List<SlashSuggestion> _catalogSuggestions = [];
  List<SlashSuggestion> get catalogSuggestions =>
      List.unmodifiable(_catalogSuggestions);
  final Map<String, ({DateTime at, SlashCompletionResult result})>
  _completionCache = {};
  final Map<String, num> _skillUsage = {};
  static const _completionTtl = Duration(minutes: 60);
  static const _completionCacheLimit = 100;

  /// True right after a slash/path completion request actually failed (as
  /// opposed to genuinely returning zero matches) — lets the composer show
  /// "autocomplete unavailable" instead of silently looking like "no
  /// results" when the gateway request itself errored.
  bool _lastCompletionFailed = false;
  bool get lastCompletionFailed => _lastCompletionFailed;

  void bindProfile(String? profile) {
    if (_profile == profile) return;
    _profile = profile;
    _invalidateScope();
  }

  void _onConnectionChanged() {
    final id = connection.activeConnectionId;
    final gateway = connection.gateway;
    if (id == _connectionId && identical(gateway, _gateway)) return;
    _connectionId = id;
    _gateway = gateway;
    _invalidateScope();
    if (connection.isConnected) unawaited(loadCatalog());
  }

  void _invalidateScope() {
    _generation++;
    _completionCache.clear();
    _catalogSuggestions = [];
    _catalog = [];
    _skillUsage.clear();
    _lastCompletionFailed = false;
    notifyListeners();
  }

  /// Load the slash-command catalog (called once after connect).
  Future<void> loadCatalog() async {
    final generation = _generation;
    await connection.ensureConnected();
    try {
      final gateway = connection.gateway;
      if (gateway == null) return;
      final result = await gateway.request('commands.catalog', {});
      if (generation != _generation ||
          !identical(gateway, connection.gateway)) {
        return;
      }
      final suggestions = <SlashSuggestion>[];
      final categorized = <String>{};
      final categories = (result['categories'] as List?) ?? const [];
      for (final rawCategory in categories.whereType<Map>()) {
        final category = rawCategory.cast<String, dynamic>();
        final group = category['name']?.toString();
        for (final rawPair in (category['pairs'] as List?) ?? const []) {
          final suggestion = _pairSuggestion(rawPair, group: group);
          if (suggestion != null) {
            suggestions.add(suggestion);
            categorized.add(suggestion.text.toLowerCase());
          }
        }
      }

      final skills = (result['skills'] as Map?)?.cast<dynamic, dynamic>();
      _skillUsage.clear();
      if (skills != null) {
        for (final entry in skills.entries) {
          final metadata = entry.value;
          if (metadata is Map && metadata['usage'] is num) {
            _skillUsage[entry.key.toString().toLowerCase()] =
                metadata['usage'] as num;
          }
        }
      }
      for (final rawPair in (result['pairs'] as List?) ?? const []) {
        final suggestion = _pairSuggestion(rawPair);
        if (suggestion == null ||
            categorized.contains(suggestion.text.toLowerCase())) {
          continue;
        }
        suggestions.add(
          SlashSuggestion(
            text: suggestion.text,
            display: suggestion.display,
            meta: suggestion.meta,
            group: skills?.containsKey(suggestion.text) == true
                ? slashGroupSkills
                : slashGroupCommands,
          ),
        );
      }

      final legacy =
          (result['commands'] as List?) ??
          (result['items'] as List?) ??
          const [];
      for (final raw in legacy.whereType<Map>()) {
        final json = raw.cast<String, dynamic>();
        final suggestion = SlashSuggestion.fromJson(json);
        if (suggestion.text.trim().isEmpty) continue;
        suggestions.add(
          SlashSuggestion(
            text: suggestion.text,
            display: suggestion.display,
            meta: suggestion.meta,
            group:
                suggestion.group ??
                json['category']?.toString() ??
                slashGroupCommands,
            action: suggestion.action,
          ),
        );
      }

      suggestions.sort(_compareSuggestions);
      _catalogSuggestions = suggestions;
      _catalog = suggestions
          .map(
            (s) => SlashCommand(
              name: s.text,
              description: s.meta,
              category: s.group,
            ),
          )
          .toList(growable: false);
      notifyListeners();
    } catch (_) {
      // Catalog is best-effort; the autocomplete endpoint still works.
    }
  }

  SlashSuggestion? _pairSuggestion(dynamic raw, {String? group}) {
    if (raw is! List || raw.isEmpty) return null;
    final text = raw.first?.toString() ?? '';
    if (text.trim().isEmpty) return null;
    return SlashSuggestion(
      text: text,
      display: text,
      meta: raw.length > 1 ? raw[1]?.toString() : null,
      group: group,
    );
  }

  /// Slash-command completion (`/comm…` → `/commands`, `/commit`, …).
  /// Returns an empty list when [text] is not a bare slash token.
  Future<SlashCompletionResult> completeSlashResult(String text) async {
    if (!text.startsWith('/')) {
      return const SlashCompletionResult(items: []);
    }
    final cacheKey = text.toLowerCase();
    final cached = _completionCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.at) < _completionTtl) {
      return cached.result;
    }
    final generation = _generation;
    try {
      await connection.ensureConnected();
      final gateway = connection.gateway;
      if (gateway == null) return const SlashCompletionResult(items: []);
      final result = await gateway.request('complete.slash', {'text': text});
      if (generation != _generation ||
          !identical(gateway, connection.gateway)) {
        return const SlashCompletionResult(items: []);
      }
      final items = (result['items'] as List?) ?? [];
      final suggestions = items
          .whereType<Map>()
          .map((e) => SlashSuggestion.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.text.trim().isNotEmpty)
          .toList();
      suggestions.sort(_compareSuggestions);
      final replaceFrom = (result['replace_from'] as num?)?.toInt() ?? 1;
      final completion = SlashCompletionResult(
        items: suggestions,
        replaceFrom: replaceFrom.clamp(1, text.length),
      );
      if (_completionCache.length >= _completionCacheLimit) {
        _completionCache.remove(_completionCache.keys.first);
      }
      _completionCache[cacheKey] = (at: DateTime.now(), result: completion);
      if (_lastCompletionFailed) {
        _lastCompletionFailed = false;
        notifyListeners();
      }
      return completion;
    } catch (_) {
      if (generation != _generation) {
        return const SlashCompletionResult(items: []);
      }
      if (!_lastCompletionFailed) {
        _lastCompletionFailed = true;
        notifyListeners();
      }
      return const SlashCompletionResult(items: []);
    }
  }

  Future<List<SlashSuggestion>> completeSlash(String text) async =>
      (await completeSlashResult(text)).items;

  void invalidateSlashCompletions() {
    _completionCache.clear();
    _catalogSuggestions = [];
    _catalog = [];
    notifyListeners();
  }

  int _compareSuggestions(SlashSuggestion left, SlashSuggestion right) {
    final leftSkill = left.group == slashGroupSkills;
    final rightSkill = right.group == slashGroupSkills;
    if (leftSkill != rightSkill) return leftSkill ? 1 : -1;
    if (!leftSkill) return 0;
    final leftUsage = _skillUsage[left.text.toLowerCase()] ?? 0;
    final rightUsage = _skillUsage[right.text.toLowerCase()] ?? 0;
    return rightUsage.compareTo(leftUsage);
  }

  /// Path completion for `@mentions` (file / dir paths on the server cwd).
  Future<List<PathSuggestion>> completePath(String word) async {
    final generation = _generation;
    try {
      await connection.ensureConnected();
      final gateway = connection.gateway;
      if (gateway == null) return const [];
      final result = await gateway.request('complete.path', {'word': word});
      if (generation != _generation ||
          !identical(gateway, connection.gateway)) {
        return const [];
      }
      final items = (result['items'] as List?) ?? [];
      if (_lastCompletionFailed) {
        _lastCompletionFailed = false;
        notifyListeners();
      }
      return items
          .map(
            (e) => PathSuggestion.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      if (generation != _generation) return const [];
      if (!_lastCompletionFailed) {
        _lastCompletionFailed = true;
        notifyListeners();
      }
      return const [];
    }
  }

  /// Execute a full slash invocation using the Desktop gateway contract.
  Future<Map<String, dynamic>> executeSlash(
    String command, {
    required String sessionId,
  }) async {
    await connection.ensureConnected();
    final gateway = connection.gateway;
    if (gateway == null) return const {};
    final invocation = command.replaceFirst(RegExp(r'^/+'), '').trim();
    try {
      return await gateway.request('slash.exec', {
        'session_id': sessionId,
        'command': invocation,
      });
    } catch (error) {
      if (!identical(gateway, connection.gateway)) rethrow;
      developer.log(
        'slash.exec failed for /$invocation; falling back to command.dispatch',
        name: 'hermes.command',
        error: error,
      );
      final parts = invocation.split(RegExp(r'\s+'));
      final name = parts.first;
      final arg = invocation.substring(name.length).trim();
      try {
        return await gateway.request('command.dispatch', {
          'session_id': sessionId,
          'name': name,
          'arg': arg,
        });
      } catch (fallbackError) {
        if (fallbackError.toString().toLowerCase().contains(
          'not a quick/plugin/skill command',
        )) {
          Error.throwWithStackTrace(error, StackTrace.current);
        }
        rethrow;
      }
    }
  }

  /// Dispatch a slash command by name; returns the raw gateway result.
  Future<Map<String, dynamic>> dispatch(
    String command, {
    String? sessionId,
    String arg = '',
  }) async {
    await connection.ensureConnected();
    final gateway = connection.gateway;
    if (gateway == null) return const {};
    final result = await gateway.request('command.dispatch', {
      'name': command,
      'arg': arg,
      'session_id': ?sessionId,
    });
    if (!identical(gateway, connection.gateway)) return const {};
    return result;
  }

  @override
  void dispose() {
    connection.removeListener(_onConnectionChanged);
    super.dispose();
  }
}
