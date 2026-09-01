import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';

import '../../l10n/runtime_l10n.dart';
import '../api_client.dart';
import '../models.dart';
import '../terminal_gateway.dart';
import '../terminal_interactions.dart';
import 'connection_store.dart';
import 'session_store.dart';

enum TerminalColorPreset {
  system,
  professionalDark,
  highContrastDark,
  softLight,
}

enum TerminalCursorPreset { bar, block, underline }

class SshTerminalTarget {
  final String host;
  final String user;
  final int? port;
  final String identityFile;
  final String cwd;

  const SshTerminalTarget({
    required this.host,
    this.user = '',
    this.port,
    this.identityFile = '',
    this.cwd = '',
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    if (user.isNotEmpty) 'user': user,
    if (port != null) 'port': port,
    if (identityFile.isNotEmpty) 'identity_file': identityFile,
    if (cwd.isNotEmpty) 'cwd': cwd,
  };
}

bool isSensitiveTerminalCommand(String command) {
  final normalized = command.trim().toLowerCase();
  return RegExp(
        r'''(?:password|passwd|token|api[_-]?key|secret|private[_-]?key|authorization)\s*(?:=|:)''',
      ).hasMatch(normalized) ||
      RegExp(
        r'''^(?:export|set|setx|\$env:)\s*[^\s]*(?:token|key|secret|password)''',
      ).hasMatch(normalized);
}

class TerminalStore extends ChangeNotifier {
  ConnectionStore connection;
  SessionStore? sessionStore;
  final String storageScope;

  TerminalStore({
    required this.connection,
    this.sessionStore,
    this.storageScope = '',
  });

  static const _maxSessions = 5;
  static const _prefsKey = 'hm_terminal_tabs_v2';
  static const _historyKey = 'hm_terminal_cmd_history_v1';
  static const _snapshotLines = 200;
  static const _maxHistory = 200;
  static const _persistHistoryKey = 'hm_terminal_persist_history_v1';
  static const _persistSnapshotsKey = 'hm_terminal_persist_snapshots_v1';
  static const _fontSizeKey = 'hm_terminal_font_size_v1';
  static const _lineHeightKey = 'hm_terminal_line_height_v1';
  static const _colorPresetKey = 'hm_terminal_color_preset_v1';
  static const _cursorPresetKey = 'hm_terminal_cursor_preset_v1';
  static const _contentPaddingKey = 'hm_terminal_content_padding_v1';

  String _scopedKey(String base) => storageScope.isEmpty
      ? base
      : '$base:${Uri.encodeComponent(storageScope)}';

  final List<TerminalSession> _sessions = [];
  final Map<String, Terminal> _terminals = {};
  final Map<String, Timer> _snapshotTimers = {};
  final Map<String, OscCwdTracker> _cwdTrackers = {};
  final List<String> _commandHistory = [];
  final Set<String> _recoveringSessionIds = {};
  final Set<String> _failedRecoverySessionIds = {};
  final Map<String, SshTerminalTarget> _sshTargets = {};
  TerminalGatewayClient? _client;
  StreamSubscription? _eventSub;
  StreamSubscription? _disconnectSub;
  String? _activeId;
  String? _defaultCwd;
  bool _initialized = false;
  bool _reconnecting = false;
  String? _reconnectNotice;
  String _fontFamily = '';
  bool _persistHistory = false;
  bool _persistSnapshots = false;
  double _fontSize = 15;
  double _lineHeight = 1.42;
  TerminalColorPreset _colorPreset = TerminalColorPreset.system;
  TerminalCursorPreset _cursorPreset = TerminalCursorPreset.bar;
  bool _contentPadding = true;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  String? get activeId => _activeId;
  String? get cwd => _defaultCwd;
  String? get reconnectNotice => _reconnectNotice;
  List<String> get commandHistory => List.unmodifiable(_commandHistory);
  String get configuredFontFamily => _fontFamily;
  String get fontFamily => _fontStack.first;
  List<String> get fontFamilyFallback => _fontStack.skip(1).toList();
  int get maxSessions => _maxSessions;
  bool get persistHistory => _persistHistory;
  bool get persistSnapshots => _persistSnapshots;
  double get terminalFontSize => _fontSize;
  double get terminalLineHeight => _lineHeight;
  TerminalColorPreset get terminalColorPreset => _colorPreset;
  TerminalCursorPreset get terminalCursorPreset => _cursorPreset;
  bool get terminalContentPadding => _contentPadding;
  bool isRecovering(String id) => _recoveringSessionIds.contains(id);
  bool recoveryFailed(String id) => _failedRecoverySessionIds.contains(id);

  List<String> get _fontStack {
    final configured = _fontFamily
        .split(',')
        .map((item) => item.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), ''))
        .where((item) => item.isNotEmpty)
        .toList();
    return <String>{
      ...configured,
      'HermesJetBrainsMono',
      'JetBrains Mono',
      'Cascadia Code',
      'SF Mono',
      'Fira Code',
      'Roboto Mono',
      'Noto Sans Mono',
      'Noto Sans Mono CJK SC',
      'Consolas',
      'DejaVu Sans Mono',
      'Liberation Mono',
      'Menlo',
      'monospace',
    }.toList();
  }

  void bindStores({
    required ConnectionStore connection,
    SessionStore? sessionStore,
  }) {
    this.connection = connection;
    this.sessionStore = sessionStore;
  }

  Terminal? terminal(String id) => _terminals[id];
  Terminal? get activeTerminal =>
      _activeId == null ? null : _terminals[_activeId];
  bool isRunning(String id) =>
      _sessions.any((session) => session.id == id && session.isAlive);

  TerminalSession? get activeSession {
    final id = _activeId;
    if (id == null) return null;
    return _sessions.where((session) => session.id == id).firstOrNull;
  }

  /// Prefer the open chat session cwd, then server default cwd.
  String? get preferredLaunchCwd {
    final sessionCwd = sessionStore?.info?.cwd?.trim();
    if (sessionCwd != null && sessionCwd.isNotEmpty) return sessionCwd;
    final fallback = _defaultCwd?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _defaultCwd = await connection.api?.fsDefaultCwd();
    } catch (_) {}
    await _loadPrivacySettings();
    await _loadDisplayPreferences();
    await _loadTerminalConfig();
    await _loadCommandHistory();
    await _connectClient();
    await _restoreTabs();
    if (_sessions.isEmpty) await newSession();
  }

  Future<void> _connectClient() async {
    if (!connection.settings.isConfigured) {
      throw StateError(runtimeL10n.terminalServerNotConfigured);
    }
    await _eventSub?.cancel();
    await _disconnectSub?.cancel();
    final old = _client;
    final client = TerminalGatewayClient(
      serverBaseUrl: connection.settings.baseUrl,
      apiKey: connection.settings.apiKey,
      extraHeaders: connection.settings.normalizedHeaders,
    );
    _client = client;
    _eventSub = client.events.listen(_onEvent);
    _disconnectSub = client.disconnects.listen((_) => _recoverConnection());
    await old?.close();
    await client.connect();
  }

  Future<void> newSession({
    String? cwd,
    String? reviveBuffer,
    String? reattachId,
  }) async {
    if (_sessions.length >= _maxSessions) {
      throw StateError(runtimeL10n.terminalLimitReached(_maxSessions));
    }
    if (_client == null || !_client!.isConnected) await _connectClient();
    final localId = 'term_${DateTime.now().microsecondsSinceEpoch}';
    final terminal = Terminal(maxLines: 1000);
    final launchCwd = (cwd != null && cwd.trim().isNotEmpty)
        ? cwd.trim()
        : preferredLaunchCwd;
    final session = TerminalSession(
      id: localId,
      title: runtimeL10n.terminalNumbered(_sessions.length + 1),
      cwd: launchCwd ?? '',
      createdAt: DateTime.now(),
    );
    _sessions.add(session);
    _terminals[localId] = terminal;
    _cwdTrackers[localId] = OscCwdTracker();
    _activeId = localId;
    if (reviveBuffer?.isNotEmpty == true) {
      terminal.write(
        '${runtimeL10n.terminalSnapshotStart}\r\n'
        '$reviveBuffer\r\n'
        '${runtimeL10n.terminalSnapshotEnd}\r\n',
      );
    }
    terminal.onOutput = (data) {
      final runtimeId = _session(localId)?.runtimeSessionId;
      if (runtimeId != null) _sendOrRecover(_client?.write(runtimeId, data));
    };
    terminal.onResize = (cols, rows, _, _) {
      final runtimeId = _session(localId)?.runtimeSessionId;
      if (runtimeId != null) {
        _sendOrRecover(_client?.resize(runtimeId, cols, rows));
      }
    };
    notifyListeners();
    try {
      await _startRuntime(localId, reattachId: reattachId);
      await _persistTabs();
    } catch (error) {
      terminal.write('\r\nTerminal failed to start: $error\r\n');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> newSshSession(SshTerminalTarget target) async {
    if (target.host.trim().isEmpty) {
      throw ArgumentError(runtimeL10n.terminalSshHostRequired);
    }
    if (_sessions.length >= _maxSessions) {
      throw StateError(runtimeL10n.terminalLimitReached(_maxSessions));
    }
    if (_client == null || !_client!.isConnected) await _connectClient();
    final localId = 'ssh_${DateTime.now().microsecondsSinceEpoch}';
    final terminal = Terminal(maxLines: 1000);
    final session = TerminalSession(
      id: localId,
      title: runtimeL10n.terminalSshNamed(target.host),
      cwd: target.cwd,
      createdAt: DateTime.now(),
    );
    _sessions.add(session);
    _terminals[localId] = terminal;
    _cwdTrackers[localId] = OscCwdTracker();
    _sshTargets[localId] = target;
    _activeId = localId;
    terminal.onOutput = (data) {
      final runtimeId = _session(localId)?.runtimeSessionId;
      if (runtimeId != null) _sendOrRecover(_client?.write(runtimeId, data));
    };
    terminal.onResize = (cols, rows, _, _) {
      final runtimeId = _session(localId)?.runtimeSessionId;
      if (runtimeId != null) {
        _sendOrRecover(_client?.resize(runtimeId, cols, rows));
      }
    };
    notifyListeners();
    try {
      await _startRuntime(localId);
      await _persistTabs();
    } catch (error) {
      terminal.write('\r\nSSH terminal failed to start: $error\r\n');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restartSession(String localId) async {
    final session = _session(localId);
    final terminal = _terminals[localId];
    if (session == null || terminal == null) return;
    if (session.runtimeSessionId != null) {
      await _client?.disposeSession(session.runtimeSessionId!);
    }
    final index = _sessions.indexWhere((item) => item.id == localId);
    if (index >= 0) {
      _sessions[index] = session.copyWith(
        clearRuntime: true,
        exited: false,
        clearExitCode: true,
      );
    }
    terminal.write('\r\n${runtimeL10n.terminalRestartingShell}\r\n');
    notifyListeners();
    try {
      await _startRuntime(localId);
      _failedRecoverySessionIds.remove(localId);
    } catch (_) {
      _failedRecoverySessionIds.add(localId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _startRuntime(String localId, {String? reattachId}) async {
    final session = _session(localId);
    final terminal = _terminals[localId];
    if (session == null || terminal == null) return;
    final cols = terminal.viewWidth > 0 ? terminal.viewWidth : 80;
    final rows = terminal.viewHeight > 0 ? terminal.viewHeight : 24;
    Map<String, dynamic> result;
    if (reattachId != null && reattachId.isNotEmpty) {
      try {
        result = await _client!.request('reattach', {'id': reattachId});
      } catch (error) {
        developer.log(
          'reattach failed for $reattachId; starting a new shell',
          name: 'hermes.terminal',
          error: error,
        );
        result = await _client!.request('start', {
          'cwd': session.cwd,
          'cols': cols,
          'rows': rows,
        });
        terminal.write('\r\n${runtimeL10n.terminalOpenedNewShell}\r\n');
      }
    } else {
      final ssh = _sshTargets[localId];
      result = await _client!.request(ssh == null ? 'start' : 'ssh.start', {
        'cwd': session.cwd,
        'cols': cols,
        'rows': rows,
        if (ssh != null) ...ssh.toJson(),
      });
    }
    final runtimeId = result['id']?.toString() ?? '';
    if (runtimeId.isEmpty) {
      throw StateError(runtimeL10n.terminalPtyIdMissing);
    }
    final index = _sessions.indexWhere((item) => item.id == localId);
    if (index < 0) {
      await _client!.disposeSession(runtimeId);
      return;
    }
    _sessions[index] = _sessions[index].copyWith(
      runtimeSessionId: runtimeId,
      cwd: result['cwd']?.toString() ?? session.cwd,
      title: result['shell']?.toString() ?? session.title,
      exited: false,
      clearExitCode: true,
    );
    notifyListeners();
  }

  void _onEvent(TerminalGatewayEvent event) {
    final runtimeId = event.data['id']?.toString();
    if (runtimeId == null) return;
    final session = _sessions
        .where((item) => item.runtimeSessionId == runtimeId)
        .firstOrNull;
    if (session == null) return;
    if (event.type == 'data') {
      final data = event.data['data']?.toString() ?? '';
      _terminals[session.id]?.write(data);
      final observedCwd = _cwdTrackers[session.id]?.add(data);
      if (observedCwd != null && observedCwd != session.cwd) {
        final index = _sessions.indexWhere((item) => item.id == session.id);
        if (index >= 0) {
          _sessions[index] = _sessions[index].copyWith(cwd: observedCwd);
          notifyListeners();
        }
      }
      _scheduleSnapshot(session.id);
    } else if (event.type == 'error') {
      _terminals[session.id]?.write(
        '\r\nTerminal error: ${event.data['message'] ?? 'unknown'}\r\n',
      );
    } else if (event.type == 'exit') {
      final code = (event.data['code'] as num?)?.toInt();
      final index = _sessions.indexWhere((item) => item.id == session.id);
      if (index < 0) return;
      _sessions[index] = _sessions[index].copyWith(
        clearRuntime: true,
        exited: true,
        exitCode: code,
      );
      _terminals[session.id]?.write(
        '\r\n${runtimeL10n.terminalShellExited(code?.toString() ?? '')}\r\n',
      );
      unawaited(_persistTabs());
      notifyListeners();
    }
  }

  void sendControlC(String id) => sendRaw(id, '\x03');

  void sendRaw(String id, String data) {
    final session = _session(id);
    if (session == null || !session.isAlive) return;
    _client?.write(session.runtimeSessionId!, data);
  }

  void sendPaths(String id, Iterable<String> paths) {
    final session = _session(id);
    if (session == null || !session.isAlive) return;
    final input = quoteTerminalPaths(paths, session.title);
    if (input.isNotEmpty) _client?.write(session.runtimeSessionId!, input);
  }

  void clear(String id) {
    _terminals[id]?.write('\x1b[2J\x1b[H');
    _scheduleSnapshot(id);
  }

  Future<void> refreshCwd(String id) async {
    final session = _session(id);
    final runtimeId = session?.runtimeSessionId;
    if (session == null || runtimeId == null || _client == null) return;
    try {
      final result = await _client!.request('cwd', {'id': runtimeId});
      final next = result['cwd']?.toString();
      if (next == null || next.isEmpty || next == session.cwd) return;
      final index = _sessions.indexWhere((item) => item.id == id);
      if (index < 0) return;
      _sessions[index] = _sessions[index].copyWith(cwd: next);
      notifyListeners();
    } catch (error) {
      developer.log(
        'cwd refresh failed for terminal $id',
        name: 'hermes.terminal',
        error: error,
      );
    }
  }

  void recordCommand(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (isSensitiveTerminalCommand(trimmed)) return;
    if (_commandHistory.isNotEmpty && _commandHistory.last == trimmed) return;
    _commandHistory.add(trimmed);
    while (_commandHistory.length > _maxHistory) {
      _commandHistory.removeAt(0);
    }
    unawaited(_persistCommandHistory());
  }

  void clearReconnectNotice() {
    if (_reconnectNotice == null) return;
    _reconnectNotice = null;
    notifyListeners();
  }

  Future<void> closeSession(String id, {bool disposeRemote = true}) async {
    final session = _session(id);
    _snapshotTimers.remove(id)?.cancel();
    if (disposeRemote && session?.runtimeSessionId != null) {
      await _client?.disposeSession(session!.runtimeSessionId!);
    }
    _sessions.removeWhere((item) => item.id == id);
    _terminals.remove(id);
    _sshTargets.remove(id);
    _cwdTrackers.remove(id);
    _recoveringSessionIds.remove(id);
    _failedRecoverySessionIds.remove(id);
    if (_activeId == id) _activeId = _sessions.lastOrNull?.id;
    await _persistTabs();
    notifyListeners();
  }

  void select(String id) {
    if (!_terminals.containsKey(id)) return;
    _activeId = id;
    notifyListeners();
    unawaited(refreshCwd(id));
  }

  String selectedText(String id, TerminalController controller) {
    final range = controller.selection;
    final terminal = _terminals[id];
    return range == null || terminal == null
        ? ''
        : terminal.buffer.getText(range);
  }

  void _scheduleSnapshot(String id) {
    if (!_persistSnapshots) return;
    _snapshotTimers.remove(id)?.cancel();
    _snapshotTimers[id] = Timer(const Duration(seconds: 2), () {
      _snapshotTimers.remove(id);
      unawaited(_persistTabs());
    });
  }

  String _snapshot(Terminal terminal) {
    final lines = terminal.buffer.lines;
    final start = (lines.length - _snapshotLines).clamp(0, lines.length);
    return [
      for (var i = start; i < lines.length; i++) lines[i].toString(),
    ].join('\r\n').trimRight();
  }

  Future<void> _persistTabs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_prefsKey),
      jsonEncode({
        'active': _activeId,
        'tabs': [
          for (final session in _sessions)
            {
              'cwd': session.cwd,
              'title': session.title,
              'runtime_id': session.runtimeSessionId,
              if (_persistSnapshots)
                'buffer': _snapshot(_terminals[session.id]!),
            },
        ],
      }),
    );
  }

  Future<void> _restoreTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(_prefsKey));
    if (raw == null || raw.isEmpty) return;
    List<dynamic> tabs;
    try {
      final decoded = jsonDecode(raw) as Map;
      tabs = (decoded['tabs'] as List? ?? const []).take(_maxSessions).toList();
    } catch (_) {
      return;
    }
    for (final value in tabs) {
      try {
        final tab = (value as Map).cast<String, dynamic>();
        await newSession(
          cwd: tab['cwd']?.toString(),
          reviveBuffer: _persistSnapshots ? tab['buffer']?.toString() : null,
          reattachId: tab['runtime_id']?.toString(),
        );
      } catch (_) {
        // One tab failing to reattach shouldn't block the rest from
        // restoring — newSession already surfaces the failure inline in
        // that tab's own terminal buffer.
      }
    }
  }

  Future<void> _loadCommandHistory() async {
    if (!_persistHistory) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(_historyKey));
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _commandHistory
        ..clear()
        ..addAll(
          decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .take(_maxHistory),
        );
    } catch (_) {}
  }

  Future<void> _persistCommandHistory() async {
    if (!_persistHistory) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_historyKey), jsonEncode(_commandHistory));
  }

  Future<void> _loadPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    _persistHistory = prefs.getBool(_scopedKey(_persistHistoryKey)) ?? false;
    _persistSnapshots =
        prefs.getBool(_scopedKey(_persistSnapshotsKey)) ?? false;
    if (!_persistHistory) await prefs.remove(_scopedKey(_historyKey));
  }

  Future<void> setPersistHistory(bool value) async {
    _persistHistory = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_persistHistoryKey), value);
    if (!value) {
      _commandHistory.clear();
      await prefs.remove(_scopedKey(_historyKey));
    }
    notifyListeners();
  }

  Future<void> setPersistSnapshots(bool value) async {
    _persistSnapshots = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_persistSnapshotsKey), value);
    await _persistTabs();
    notifyListeners();
  }

  Future<void> clearPrivateData() async {
    _commandHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey(_historyKey));
    await prefs.remove(_scopedKey(_prefsKey));
    notifyListeners();
  }

  /// `TerminalGatewayClient.write`/`resize` return false (dropping the
  /// keystroke/resize) when the socket is down — kick off the same recovery
  /// flow a detected disconnect uses instead of leaving the input silently
  /// lost with no visible signal.
  void _sendOrRecover(bool? sent) {
    if (sent == false && !_reconnecting) unawaited(_recoverConnection());
  }

  Future<void> _recoverConnection() async {
    if (_reconnecting) return;
    _reconnecting = true;
    _reconnectNotice = runtimeL10n.terminalReconnecting;
    notifyListeners();
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      try {
        await _connectClient();
        for (final session in List<TerminalSession>.from(_sessions)) {
          if (session.exited) continue;
          _recoveringSessionIds.add(session.id);
          _failedRecoverySessionIds.remove(session.id);
          notifyListeners();
          final previousRuntime = session.runtimeSessionId;
          final terminal = _terminals[session.id];
          terminal?.write('\r\n${runtimeL10n.terminalRestoringShell}\r\n');
          final index = _sessions.indexWhere((item) => item.id == session.id);
          if (index >= 0) {
            _sessions[index] = _sessions[index].copyWith(clearRuntime: true);
          }
          try {
            await _startRuntime(session.id, reattachId: previousRuntime);
            terminal?.write(
              '\r\n${runtimeL10n.terminalConnectionRestored}\r\n',
            );
          } catch (_) {
            _failedRecoverySessionIds.add(session.id);
            terminal?.write(
              '\r\n${runtimeL10n.terminalConnectionRestoreFailed}\r\n',
            );
          } finally {
            _recoveringSessionIds.remove(session.id);
            notifyListeners();
          }
        }
        _reconnectNotice = runtimeL10n.terminalReconnected;
        _reconnecting = false;
        notifyListeners();
        return;
      } catch (_) {}
    }
    _reconnectNotice = runtimeL10n.terminalReconnectFailed;
    _reconnecting = false;
    notifyListeners();
  }

  TerminalSession? _session(String id) =>
      _sessions.where((item) => item.id == id).firstOrNull;

  Future<void> _loadTerminalConfig() async {
    final api = connection.api;
    if (api == null) return;
    try {
      final result = await api.get('/api/v1/config');
      final config = (result as Map)['config'] as Map?;
      final terminal = config?['terminal'] as Map?;
      _fontFamily = terminal?['font_family']?.toString().trim() ?? '';
      notifyListeners();
    } catch (_) {
      // Terminal startup remains available when config discovery fails.
    }
  }

  Future<void> setFontFamily(String value, {ApiClient? expectedApi}) async {
    final normalized = value.trim();
    final previous = _fontFamily;
    _fontFamily = normalized;
    notifyListeners();
    try {
      final api = expectedApi ?? connection.api;
      if (api == null || !identical(connection.api, api)) {
        throw StateError(runtimeL10n.backendDisconnected);
      }
      await api.put(
        '/api/v1/config',
        body: {
          'config': {
            'terminal': {'font_family': normalized},
          },
        },
      );
    } catch (_) {
      _fontFamily = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadDisplayPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = (prefs.getDouble(_fontSizeKey) ?? 15).clamp(12, 22).toDouble();
    _lineHeight = (prefs.getDouble(_lineHeightKey) ?? 1.42)
        .clamp(1.2, 1.7)
        .toDouble();
    _colorPreset = TerminalColorPreset.values.firstWhere(
      (value) => value.name == prefs.getString(_colorPresetKey),
      orElse: () => TerminalColorPreset.system,
    );
    _cursorPreset = TerminalCursorPreset.values.firstWhere(
      (value) => value.name == prefs.getString(_cursorPresetKey),
      orElse: () => TerminalCursorPreset.bar,
    );
    _contentPadding = prefs.getBool(_contentPaddingKey) ?? true;
    notifyListeners();
  }

  Future<void> setDisplayPreferences({
    double? fontSize,
    double? lineHeight,
    TerminalColorPreset? colorPreset,
    TerminalCursorPreset? cursorPreset,
    bool? contentPadding,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (fontSize != null) {
      _fontSize = fontSize.clamp(12, 22).toDouble();
      await prefs.setDouble(_fontSizeKey, _fontSize);
    }
    if (lineHeight != null) {
      _lineHeight = lineHeight.clamp(1.2, 1.7).toDouble();
      await prefs.setDouble(_lineHeightKey, _lineHeight);
    }
    if (colorPreset != null) {
      _colorPreset = colorPreset;
      await prefs.setString(_colorPresetKey, colorPreset.name);
    }
    if (cursorPreset != null) {
      _cursorPreset = cursorPreset;
      await prefs.setString(_cursorPresetKey, cursorPreset.name);
    }
    if (contentPadding != null) {
      _contentPadding = contentPadding;
      await prefs.setBool(_contentPaddingKey, contentPadding);
    }
    notifyListeners();
  }

  Future<void> resetDisplayPreferences() => setDisplayPreferences(
    fontSize: 15,
    lineHeight: 1.42,
    colorPreset: TerminalColorPreset.system,
    cursorPreset: TerminalCursorPreset.bar,
    contentPadding: true,
  );

  @override
  void dispose() {
    for (final timer in _snapshotTimers.values) {
      timer.cancel();
    }
    _eventSub?.cancel();
    _disconnectSub?.cancel();
    unawaited(_client?.close());
    super.dispose();
  }
}

String? parseOscCwd(int code, String payload) {
  if (code == 9) {
    if (!payload.startsWith('9;')) return null;
    final raw = payload
        .substring(2)
        .trim()
        .replaceAll(RegExp(r'''^"|"$'''), '');
    return raw.isEmpty ? null : raw;
  }
  if (code != 7) return null;
  final match = RegExp(r'^file://[^/]*(/.*)$').firstMatch(payload.trim());
  if (match == null) return null;
  var raw = match.group(1)!;
  try {
    raw = Uri.decodeComponent(raw);
  } catch (_) {}
  if (RegExp(r'^/[A-Za-z]:[\\/]').hasMatch(raw)) raw = raw.substring(1);
  return raw.isEmpty ? null : raw;
}

/// Stateful observer because a PTY can split one OSC sequence across frames.
class OscCwdTracker {
  String _tail = '';

  String? add(String chunk) {
    final data = _tail + chunk;
    _tail = '';
    String? latest;
    var cursor = 0;
    while (true) {
      final start = data.indexOf('\x1b]', cursor);
      if (start < 0) break;
      final bel = data.indexOf('\x07', start + 2);
      final st = data.indexOf('\x1b\\', start + 2);
      final end = bel < 0 ? st : (st < 0 ? bel : (bel < st ? bel : st));
      if (end < 0) {
        _tail = data.substring(start);
        if (_tail.length > 4096) _tail = _tail.substring(_tail.length - 4096);
        break;
      }
      final body = data.substring(start + 2, end);
      final separator = body.indexOf(';');
      if (separator > 0) {
        final code = int.tryParse(body.substring(0, separator));
        if (code == 7 || code == 9) {
          latest = parseOscCwd(code!, body.substring(separator + 1)) ?? latest;
        }
      }
      cursor = end + (end == st ? 2 : 1);
    }
    return latest;
  }
}
