/// CommandPaletteStore: unified search across navigation destinations, recent
/// sessions and slash commands (Batch 8 of the desktop migration).
///
/// Mirrors the desktop renderer's command palette (Cmd+K overlay): typing a
/// query filters across multiple result kinds; selecting an item navigates,
/// opens a session, or dispatches a slash command.
library;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_en.dart';
import '../models.dart';
import 'command_store.dart';
import 'session_store.dart';

enum PaletteResultKind { navigate, session, slashCommand, action }

class PaletteResult {
  final PaletteResultKind kind;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? routeName;
  final String? sessionId;
  final SlashCommand? command;

  const PaletteResult({
    required this.kind,
    required this.title,
    this.subtitle,
    this.icon,
    this.routeName,
    this.sessionId,
    this.command,
  });
}

class CommandPaletteStore extends ChangeNotifier {
  final SessionStore session;
  final CommandStore commands;

  CommandPaletteStore({required this.session, required this.commands});

  bool _open = false;
  String _query = '';
  List<PaletteResult> _results = [];
  int _selectedIndex = 0;
  AppLocalizations _localizations = AppLocalizationsEn();

  bool get isOpen => _open;
  String get query => _query;
  List<PaletteResult> get results => _results;
  int get selectedIndex => _selectedIndex;
  set selectedIndex(int v) {
    if (v < 0 || v >= _results.length || v == _selectedIndex) return;
    _selectedIndex = v;
    notifyListeners();
  }

  void open() {
    _open = true;
    _query = '';
    _results = _buildDefaults();
    _selectedIndex = 0;
    notifyListeners();
  }

  void close() {
    _open = false;
    _query = '';
    _results = const [];
    _selectedIndex = 0;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    _results = _search(q);
    _selectedIndex = 0;
    notifyListeners();
  }

  void moveSelection(int delta) {
    if (_results.isEmpty) return;
    _selectedIndex = (_selectedIndex + delta) % _results.length;
    if (_selectedIndex < 0) _selectedIndex += _results.length;
    notifyListeners();
  }

  PaletteResult? get current =>
      _results.isEmpty ? null : _results[_selectedIndex];

  void setLocalizations(AppLocalizations localizations) {
    if (_localizations.localeName == localizations.localeName) return;
    _localizations = localizations;
    if (_open) {
      _results = _search(_query);
      _selectedIndex = _results.isEmpty
          ? 0
          : _selectedIndex.clamp(0, _results.length - 1);
    }
  }

  List<PaletteResult> _buildDefaults() {
    return [
      ..._navigationEntries(),
      ..._quickActions(),
      ..._recentSessions(limit: 5),
      ..._slashCommands(limit: 10),
    ];
  }

  List<PaletteResult> _search(String q) {
    if (q.isEmpty) return _buildDefaults();
    final lower = q.toLowerCase();
    final nav = _navigationEntries()
        .where((r) => r.title.toLowerCase().contains(lower))
        .toList();
    final actions = _quickActions()
        .where((r) => r.title.toLowerCase().contains(lower))
        .toList();
    final sessions = _recentSessions(limit: 20)
        .where(
          (r) =>
              (r.title.toLowerCase().contains(lower) ||
              (r.subtitle ?? '').toLowerCase().contains(lower)),
        )
        .toList();
    final slash = _slashCommands(limit: 50)
        .where(
          (r) =>
              r.title.toLowerCase().contains(lower) ||
              (r.subtitle ?? '').toLowerCase().contains(lower),
        )
        .toList();
    return [...nav, ...actions, ...sessions, ...slash];
  }

  List<PaletteResult> _navigationEntries() {
    final l10n = _localizations;
    return [
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.navHome,
        icon: Icons.home_outlined,
        routeName: 'home',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.navSessions,
        icon: Icons.chat_bubble_outline,
        routeName: 'sessions',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featureProjects,
        icon: Icons.folder_outlined,
        routeName: 'projects',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.navTasks,
        icon: Icons.task_alt,
        routeName: 'tasks',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featureTerminal,
        icon: Icons.terminal,
        routeName: 'terminal',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featureGit,
        icon: Icons.merge,
        routeName: 'git',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featureFiles,
        icon: Icons.folder_open,
        routeName: 'files',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.homeToolKnowledge,
        icon: Icons.menu_book,
        routeName: 'knowledge',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.paletteKanban,
        icon: Icons.view_kanban,
        routeName: 'kanban',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featureSettings,
        icon: Icons.settings,
        routeName: 'settings',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featureCommandCenter,
        icon: Icons.terminal,
        routeName: 'command_center',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featurePet,
        icon: Icons.pets,
        routeName: 'pet_center',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featureSubagents,
        icon: Icons.account_tree,
        routeName: 'subagents',
      ),
      PaletteResult(
        kind: PaletteResultKind.navigate,
        title: l10n.featureArtifacts,
        icon: Icons.inventory_2,
        routeName: 'artifacts',
      ),
    ];
  }

  List<PaletteResult> _quickActions() {
    final l10n = _localizations;
    return [
      PaletteResult(
        kind: PaletteResultKind.action,
        title: l10n.sessionNew,
        subtitle: l10n.paletteNewSessionDesc,
        icon: Icons.add_circle_outline,
        routeName: 'new_session',
      ),
      PaletteResult(
        kind: PaletteResultKind.action,
        title: l10n.paletteVoiceInput,
        subtitle: l10n.paletteVoiceInputDesc,
        icon: Icons.mic,
        routeName: 'voice_input',
      ),
      PaletteResult(
        kind: PaletteResultKind.action,
        title: l10n.paletteReconnect,
        subtitle: l10n.paletteReconnectDesc,
        icon: Icons.refresh,
        routeName: 'reconnect',
      ),
    ];
  }

  List<PaletteResult> _recentSessions({int limit = 5}) {
    final sessions = session.sessions ?? const <SessionRow>[];
    return sessions.take(limit).map((s) {
      return PaletteResult(
        kind: PaletteResultKind.session,
        title: s.title?.isNotEmpty == true
            ? s.title!
            : _localizations.sessionUntitled,
        subtitle: s.preview ?? s.id,
        icon: Icons.history,
        sessionId: s.id,
      );
    }).toList();
  }

  List<PaletteResult> _slashCommands({int limit = 10}) {
    final catalog = commands.catalog;
    return catalog.take(limit).map((c) {
      return PaletteResult(
        kind: PaletteResultKind.slashCommand,
        title: '/${c.name}',
        subtitle: c.description,
        icon: Icons.terminal,
        command: c,
      );
    }).toList();
  }
}
