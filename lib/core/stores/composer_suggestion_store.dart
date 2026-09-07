library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api_client.dart';
import '../composer_suggestions.dart';
import '../connections/connection_registry.dart';
import 'command_store.dart';
import 'connection_store.dart';
import 'plugin_contribution_store.dart';
import 'session_store.dart';

enum ComposerSuggestionKind { skill, github, mcpDiscovery, mcpRepair, plugin }

@immutable
class ActiveComposerSuggestion {
  const ActiveComposerSuggestion({
    required this.kind,
    required this.id,
    required this.trigger,
    this.title,
    this.description,
    this.insertText,
  });

  final ComposerSuggestionKind kind;
  final String id;
  final String trigger;
  final String? title;
  final String? description;
  final String? insertText;
  String get key => '${kind.name}:$id';
}

/// Session-scoped suggestion provider bus. Draft sampling is generation
/// guarded and cached; event offers (MCP repair) outrank draft guesses.
class ComposerSuggestionStore extends ChangeNotifier {
  ComposerSuggestionStore(this._connection, this._session, this._commands) {
    _events = _connection.routedEvents.listen(_onEvent);
  }

  ConnectionStore _connection;
  SessionStore _session;
  CommandStore _commands;
  PluginContributionStore? _plugins;
  StreamSubscription<RoutedGatewayEvent>? _events;
  Timer? _timer;
  int _generation = 0;
  final Map<String, Set<String>> _repairBySession = {};
  List<ActiveComposerSuggestion> _suggestions = const [];
  List<ActiveComposerSuggestion> get suggestions => _suggestions;

  ApiClient? _cachedApi;
  String? _cachedProfile;
  DateTime? _catalogAt;
  List<Map<String, dynamic>> _mcpCatalog = const [];
  Set<String> _configuredMcp = const {};
  bool? _githubNeedsSetup;

  void bind(
    ConnectionStore connection,
    SessionStore session,
    CommandStore commands,
  ) {
    if (!identical(_connection, connection)) {
      unawaited(_events?.cancel());
      _connection = connection;
      _events = connection.routedEvents.listen(_onEvent);
      _invalidateCatalog();
    }
    _session = session;
    _commands = commands;
  }

  void bindPluginContributions(PluginContributionStore? plugins) {
    _plugins = plugins;
  }

  void sample(String text) {
    _timer?.cancel();
    final generation = ++_generation;
    if (text.trim().length < 3 || text.trimLeft().startsWith('/')) {
      _publish(const []);
      return;
    }
    _timer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_sampleNow(text, generation));
    });
  }

  Future<void> _sampleNow(String text, int generation) async {
    final sessionId = _session.durableId ?? '';
    final draft = <ActiveComposerSuggestion>[];
    if (_commands.catalogSuggestions.isEmpty) {
      await _commands.loadCatalog();
    }
    for (final entry in _commands.catalogSuggestions) {
      if (entry.group != slashGroupSkills) continue;
      final name = entry.text.replaceFirst(RegExp(r'^/'), '');
      if (composerSkillHit(text, name) &&
          !composerSkillCollidesWithWorkspace(name, _session.info?.cwd ?? '')) {
        draft.add(
          ActiveComposerSuggestion(
            kind: ComposerSuggestionKind.skill,
            id: name,
            trigger: name,
          ),
        );
      }
    }

    final api = _connection.api;
    final profile = _session.profile ?? _session.activeProfile;
    if (api != null) {
      await _ensureCatalog(api, profile);
      if (composerGithubHit(text) && _githubNeedsSetup == true) {
        draft.add(
          const ActiveComposerSuggestion(
            kind: ComposerSuggestionKind.github,
            id: 'github-auth',
            trigger: 'GitHub',
          ),
        );
      }
      for (final match in composerMcpMatches(text, _mcpCatalog)) {
        if (!_configuredMcp.contains(match.server)) {
          draft.add(
            ActiveComposerSuggestion(
              kind: ComposerSuggestionKind.mcpDiscovery,
              id: match.server,
              trigger: match.trigger,
            ),
          );
        }
      }
    }
    final plugins = _plugins;
    final owner = _session.owner?.route;
    if (plugins != null && owner != null) {
      for (final result in await plugins.completeComposer(
        text: text,
        sessionId: sessionId,
        owner: owner,
      )) {
        draft.add(
          ActiveComposerSuggestion(
            kind: ComposerSuggestionKind.plugin,
            id: result.id,
            trigger: result.trigger,
            title: result.title,
            description: result.description,
            insertText: result.insertText,
          ),
        );
      }
    }
    if (generation != _generation || sessionId != (_session.durableId ?? '')) {
      return;
    }
    _publish(draft);
  }

  Future<void> _ensureCatalog(ApiClient api, String? profile) async {
    final fresh =
        identical(api, _cachedApi) &&
        profile == _cachedProfile &&
        _catalogAt != null &&
        DateTime.now().difference(_catalogAt!) < const Duration(minutes: 5);
    if (fresh) return;
    try {
      final values = await Future.wait<Object>([
        api.mcpCatalog(profile: profile),
        api.mcpServers(profile: profile),
        api.ghAuthStatus(profile: profile),
      ]);
      _mcpCatalog = values[0] as List<Map<String, dynamic>>;
      _configuredMcp = {
        for (final server in values[1] as List<Map<String, dynamic>>)
          if (server['name'] != null) server['name'].toString(),
      };
      _githubNeedsSetup =
          (values[2] as Map<String, dynamic>)['authenticated'] != true;
      _cachedApi = api;
      _cachedProfile = profile;
      _catalogAt = DateTime.now();
    } catch (_) {
      // Discovery failures stay quiet; stale or guessed onboarding is worse.
      _mcpCatalog = const [];
      _configuredMcp = const {};
      _githubNeedsSetup = null;
    }
  }

  bool _isCurrentEvent(RoutedGatewayEvent routed) {
    final owner = _session.owner;
    if (owner == null ||
        owner.route.connectionId != routed.route.connectionId) {
      return false;
    }
    final id = routed.event.sessionId;
    return id == null || id == _session.runtimeId || id == _session.durableId;
  }

  void _onEvent(RoutedGatewayEvent routed) {
    if (routed.event.type != 'tool.complete' || !_isCurrentEvent(routed)) {
      return;
    }
    final payload = routed.event.payload;
    final tool = payload['name']?.toString() ?? '';
    final server = composerMcpServerFromTool(tool);
    if (server == null) return;
    final result =
        (payload['result_text'] ?? payload['result'] ?? payload['error'] ?? '')
            .toString();
    final failed = payload['error'] != null || payload['is_error'] == true;
    final key = _session.durableId ?? _session.runtimeId ?? '';
    final repairs = _repairBySession.putIfAbsent(key, () => <String>{});
    if (failed && composerMcpRepairError.hasMatch(result)) {
      repairs.add(server);
    } else if (!failed) {
      repairs.remove(server);
    } else {
      return;
    }
    _publish(
      _suggestions
          .where((s) => s.kind != ComposerSuggestionKind.mcpRepair)
          .toList(),
    );
  }

  void markHandled(ActiveComposerSuggestion suggestion) {
    if (suggestion.kind == ComposerSuggestionKind.mcpRepair) {
      final key = _session.durableId ?? _session.runtimeId ?? '';
      _repairBySession[key]?.remove(suggestion.id);
    }
    _suggestions = _suggestions
        .where((item) => item.key != suggestion.key)
        .toList(growable: false);
    notifyListeners();
  }

  void _publish(List<ActiveComposerSuggestion> draft) {
    final key = _session.durableId ?? _session.runtimeId ?? '';
    final repairs = <ActiveComposerSuggestion>[
      for (final server in _repairBySession[key] ?? const <String>{})
        ActiveComposerSuggestion(
          kind: ComposerSuggestionKind.mcpRepair,
          id: server,
          trigger: server,
        ),
    ];
    final seen = <String>{};
    final next = <ActiveComposerSuggestion>[];
    for (final item in [...repairs, ...draft]) {
      if (seen.add(item.key)) next.add(item);
      if (next.length == 2) break;
    }
    if (listEquals(
      next.map((e) => e.key).toList(),
      _suggestions.map((e) => e.key).toList(),
    )) {
      return;
    }
    _suggestions = List.unmodifiable(next);
    notifyListeners();
  }

  void _invalidateCatalog() {
    _cachedApi = null;
    _catalogAt = null;
    _mcpCatalog = const [];
    _configuredMcp = const {};
    _githubNeedsSetup = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }
}
