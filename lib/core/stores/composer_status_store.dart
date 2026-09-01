/// ComposerStatusStore: background process status stack parity with desktop
/// `src/store/composer-status.ts`.
///
/// Tracks per-session background processes synced from the gateway via
/// `process.list` and controlled via `process.kill`. Finished items auto-clear
/// after a short delay so the stack only shows live work, while failures linger
/// long enough for the user to read the exit code.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Status of a process or task row shown above the composer.
enum ComposerStatusState { running, done, failed }

/// The kind of work represented by a status row.
enum ComposerStatusType { goal, todo, subagent, background, preview }

@immutable
class ComposerStatusSnapshot {
  const ComposerStatusSnapshot({
    required this.sessionId,
    required this.revision,
    required this.items,
    required this.groups,
  });

  final String sessionId;
  final int revision;
  final List<ComposerStatusItem> items;
  final Map<ComposerStatusType, List<ComposerStatusItem>> groups;

  bool get isEmpty => items.isEmpty;
  bool get hasRunning =>
      items.any((item) => item.state == ComposerStatusState.running);
}

/// A single row in the composer status stack.
///
/// This intentionally mirrors the desktop `ComposerStatusItem` shape so the
/// mobile UI can evolve the same groupings and affordances.
@immutable
class ComposerStatusItem {
  const ComposerStatusItem({
    required this.id,
    required this.type,
    required this.state,
    required this.title,
    this.exitCode,
    this.output,
    this.sessionId,
    this.currentTool,
    this.goalStatus,
    this.todoStatus,
  });

  /// Background process id from the gateway registry.
  final String id;
  final ComposerStatusType type;
  final ComposerStatusState state;

  /// Command line for background processes, or a human label for other kinds.
  final String title;

  /// Non-zero exit code shown inline when a background process failed.
  final int? exitCode;

  /// Captured stdout/stderr tail for the inline viewer.
  final String? output;

  /// For subagents: the child session id the row opens.
  final String? sessionId;

  /// For subagents: the active tool label shown on the right.
  final String? currentTool;

  /// For goals: active | paused | waiting | done.
  final String? goalStatus;

  /// For todos: the full backend status driving the checkmark glyph.
  final String? todoStatus;

  ComposerStatusItem copyWith({
    ComposerStatusState? state,
    int? exitCode,
    String? output,
    String? currentTool,
    String? goalStatus,
    String? todoStatus,
  }) => ComposerStatusItem(
    id: id,
    type: type,
    state: state ?? this.state,
    title: title,
    exitCode: exitCode ?? this.exitCode,
    output: output ?? this.output,
    sessionId: sessionId,
    currentTool: currentTool ?? this.currentTool,
    goalStatus: goalStatus ?? this.goalStatus,
    todoStatus: todoStatus ?? this.todoStatus,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComposerStatusItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          state == other.state &&
          title == other.title &&
          exitCode == other.exitCode &&
          output == other.output &&
          sessionId == other.sessionId &&
          currentTool == other.currentTool &&
          goalStatus == other.goalStatus &&
          todoStatus == other.todoStatus;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    state,
    title,
    exitCode,
    output,
    sessionId,
    currentTool,
    goalStatus,
    todoStatus,
  );
}

/// Raw entry returned by the gateway `process.list` RPC.
///
/// Fields are intentionally loose because the registry payload is an
/// implementation detail of `tui_gateway`.
@immutable
class GatewayProcessEntry {
  const GatewayProcessEntry({
    this.sessionId,
    this.command,
    this.status,
    this.exitCode,
    this.outputTail,
  });

  factory GatewayProcessEntry.fromJson(Map<String, dynamic> json) {
    final exit = json['exit_code'];
    return GatewayProcessEntry(
      sessionId: json['session_id']?.toString(),
      command: json['command']?.toString(),
      status: json['status']?.toString(),
      exitCode: exit is int ? exit : (exit is num ? exit.toInt() : null),
      outputTail: json['output_tail']?.toString(),
    );
  }

  final String? sessionId;
  final String? command;
  final String? status;
  final int? exitCode;
  final String? outputTail;
}

/// RPC surface the store needs from its host (usually [SessionStore]).
abstract class ComposerStatusRpc {
  Future<List<Map<String, dynamic>>> listBackgroundProcesses(String sessionId);
  Future<void> killBackgroundProcess(String sessionId, String processId);
}

/// Background process registry and status stack for the composer.
///
/// The store is session-scoped: every runtime session id keeps its own list of
/// background items. Lists are only rebuilt when the registry actually changes,
/// so mounting the stack does not cause per-token rebuilds.
class ComposerStatusStore extends ChangeNotifier {
  static const int _successLingerMs = 4000;
  static const int _failureLingerMs = 12000;

  ComposerStatusRpc? _rpc;

  final Map<String, List<ComposerStatusItem>> _backgroundBySession = {};
  final Map<String, List<ComposerStatusItem>> _typedBySession = {};
  final Map<String, Set<String>> _dismissedBySession = {};
  final Map<String, Map<String, Timer>> _autoClearTimers = {};
  final Map<String, int> _revisionBySession = {};
  final Map<String, ComposerStatusSnapshot> _snapshotBySession = {};
  final StreamController<ComposerStatusItem> _completionController =
      StreamController<ComposerStatusItem>.broadcast();

  static String _typedTimerKey(String id) => 'typed:$id';
  static String _backgroundTimerKey(String id) => 'background:$id';

  /// Emits an item each time a background process transitions from running to
  /// done/failed. UI can listen to show a SnackBar or local notification.
  Stream<ComposerStatusItem> get completionEvents =>
      _completionController.stream;

  void bindRpc(ComposerStatusRpc rpc) {
    _rpc = rpc;
  }

  /// All background items for [sessionId], or empty if none.
  List<ComposerStatusItem> itemsFor(String? sessionId) {
    return snapshotFor(sessionId).items;
  }

  ComposerStatusSnapshot snapshotFor(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) {
      return const ComposerStatusSnapshot(
        sessionId: '',
        revision: 0,
        items: [],
        groups: {},
      );
    }
    final revision = _revisionBySession[sessionId] ?? 0;
    final cached = _snapshotBySession[sessionId];
    if (cached != null && cached.revision == revision) return cached;
    final all = <ComposerStatusItem>[
      ...?_typedBySession[sessionId],
      ...?_backgroundBySession[sessionId],
    ];
    all.sort(
      (a, b) => ComposerStatusType.values
          .indexOf(a.type)
          .compareTo(ComposerStatusType.values.indexOf(b.type)),
    );
    final items = List<ComposerStatusItem>.unmodifiable(all);
    final mutableGroups = <ComposerStatusType, List<ComposerStatusItem>>{};
    for (final item in items) {
      mutableGroups.putIfAbsent(item.type, () => []).add(item);
    }
    final groups = <ComposerStatusType, List<ComposerStatusItem>>{
      for (final entry in mutableGroups.entries)
        entry.key: List<ComposerStatusItem>.unmodifiable(entry.value),
    };
    return _snapshotBySession[sessionId] = ComposerStatusSnapshot(
      sessionId: sessionId,
      revision: revision,
      items: items,
      groups: Map.unmodifiable(groups),
    );
  }

  void _markChanged(String sessionId) {
    _revisionBySession[sessionId] = (_revisionBySession[sessionId] ?? 0) + 1;
    _snapshotBySession.remove(sessionId);
  }

  /// Insert or update a strongly typed, session-scoped status. All completed
  /// work shares Desktop's lifecycle: success lingers 4s, failure 12s.
  void upsertStatus(String? sessionId, ComposerStatusItem item) {
    if (sessionId == null || sessionId.isEmpty) return;
    final list = _typedBySession.putIfAbsent(sessionId, () => []);
    final index = list.indexWhere((old) => old.id == item.id);
    if (index < 0) {
      list.add(item);
    } else if (list[index] == item) {
      return;
    } else {
      list[index] = item;
    }
    if (item.state == ComposerStatusState.running) {
      _cancelAutoDismiss(sessionId, _typedTimerKey(item.id));
    } else {
      _scheduleTypedAutoDismiss(
        sessionId,
        item.id,
        item.state == ComposerStatusState.failed
            ? _failureLingerMs
            : _successLingerMs,
      );
    }
    _markChanged(sessionId);
    notifyListeners();
  }

  void replaceTodos(String? sessionId, List<ComposerStatusItem> todos) {
    if (sessionId == null || sessionId.isEmpty) return;
    final previousTodos = (_typedBySession[sessionId] ?? const [])
        .where((item) => item.type == ComposerStatusType.todo)
        .toList();
    final retained = (_typedBySession[sessionId] ?? const [])
        .where((item) => item.type != ComposerStatusType.todo)
        .toList();
    retained.addAll(todos);
    _typedBySession[sessionId] = retained;
    final nextIds = todos.map((item) => item.id).toSet();
    for (final old in previousTodos) {
      if (!nextIds.contains(old.id)) {
        _cancelAutoDismiss(sessionId, _typedTimerKey(old.id));
      }
    }
    for (final item in todos) {
      if (item.state == ComposerStatusState.running) {
        _cancelAutoDismiss(sessionId, _typedTimerKey(item.id));
      } else {
        _scheduleTypedAutoDismiss(sessionId, item.id, _successLingerMs);
      }
    }
    _markChanged(sessionId);
    notifyListeners();
  }

  void dismissStatus(String sessionId, String id) {
    _cancelAutoDismiss(sessionId, _typedTimerKey(id));
    final list = _typedBySession[sessionId];
    if (list == null) return;
    list.removeWhere((item) => item.id == id);
    if (list.isEmpty) _typedBySession.remove(sessionId);
    _markChanged(sessionId);
    notifyListeners();
  }

  void _scheduleTypedAutoDismiss(String sessionId, String id, int delayMs) {
    final timers = _autoClearTimers.putIfAbsent(sessionId, () => {});
    final timerKey = _typedTimerKey(id);
    if (timers.containsKey(timerKey)) return;
    timers[timerKey] = Timer(Duration(milliseconds: delayMs), () {
      _autoClearTimers[sessionId]?.remove(timerKey);
      dismissStatus(sessionId, id);
    });
  }

  /// True when [sessionId] has at least one running background process.
  bool hasRunningFor(String? sessionId) {
    return snapshotFor(sessionId).hasRunning;
  }

  /// Fetch the live process snapshot for [sessionId] and reconcile it into the
  /// registry. Errors are swallowed — the next poll or event retries.
  Future<void> refreshBackgroundProcesses(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) return;
    final rpc = _rpc;
    if (rpc == null) return;
    try {
      final raw = await rpc.listBackgroundProcesses(sessionId);
      final entries = raw
          .map(
            (e) => GatewayProcessEntry.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.sessionId != null && e.sessionId!.isNotEmpty)
          .toList();
      reconcileBackgroundProcesses(sessionId, entries);
    } catch (_) {
      // Transient socket loss — the next trigger retries.
    }
  }

  /// Sync a gateway process-list snapshot into the store.
  ///
  /// Existing rows keep their position, status flips happen in place, new rows
  /// append, dismissed ids stay gone, and unchanged rows keep their identity so
  /// mounted stack rows skip unnecessary rebuilds.
  void reconcileBackgroundProcesses(
    String sessionId,
    List<GatewayProcessEntry> procs,
  ) {
    final dismissed = _dismissedBySession.putIfAbsent(
      sessionId,
      () => <String>{},
    );

    final fresh = <String, ComposerStatusItem>{};
    for (final proc in procs) {
      final id = proc.sessionId;
      if (id == null || id.isEmpty || dismissed.contains(id)) continue;
      fresh[id] = _toBackgroundItem(proc);
    }

    final prev = _backgroundBySession[sessionId] ?? const [];
    final prevState = <String, ComposerStatusState>{
      for (final item in prev) item.id: item.state,
    };

    // Emit completion events for anything that just finished.
    for (final entry in fresh.entries) {
      final item = entry.value;
      if (item.state != ComposerStatusState.running &&
          prevState[entry.key] == ComposerStatusState.running) {
        _completionController.add(item);
      }
    }

    final kept = <ComposerStatusItem>[];
    for (final old in prev) {
      final next = fresh.remove(old.id);
      if (next == null) continue;
      kept.add(_sameBackgroundItem(old, next) ? old : next);
    }

    final next = [...kept, ...fresh.values];

    // Garbage-collect dismissed ids that are no longer reported.
    if (dismissed.isNotEmpty) {
      final reported = procs
          .map((p) => p.sessionId)
          .whereType<String>()
          .toSet();
      dismissed.removeWhere((id) => !reported.contains(id));
    }

    // Arm/cancel auto-clear timers based on the new finished set.
    final finishedDelay = <String, int>{
      for (final item in next)
        if (item.state != ComposerStatusState.running)
          item.id: item.state == ComposerStatusState.failed
              ? _failureLingerMs
              : _successLingerMs,
    };

    for (final entry in finishedDelay.entries) {
      _scheduleAutoDismiss(sessionId, entry.key, entry.value);
    }

    final timers = _autoClearTimers.putIfAbsent(sessionId, () => {});
    for (final timerKey
        in timers.keys.where((key) => key.startsWith('background:')).toList()) {
      final id = timerKey.substring('background:'.length);
      if (!finishedDelay.containsKey(id)) {
        _cancelAutoDismiss(sessionId, timerKey);
      }
    }

    if (next.isEmpty) {
      _backgroundBySession.remove(sessionId);
    } else {
      _backgroundBySession[sessionId] = next;
    }

    // Only notify if the list actually changed.
    if (!_listsEqual(prev, next)) {
      _markChanged(sessionId);
      notifyListeners();
    }
  }

  /// Dismiss a finished row now and keep it dismissed across refreshes.
  void dismissBackgroundProcess(String sessionId, String id) {
    _cancelAutoDismiss(sessionId, _backgroundTimerKey(id));
    _dismissedBySession.putIfAbsent(sessionId, () => <String>{}).add(id);
    final list = _backgroundBySession[sessionId];
    if (list == null) return;
    final next = list.where((item) => item.id != id).toList();
    if (next.length == list.length) return;
    if (next.isEmpty) {
      _backgroundBySession.remove(sessionId);
    } else {
      _backgroundBySession[sessionId] = next;
    }
    _markChanged(sessionId);
    notifyListeners();
  }

  /// Kill a running process, then dismiss the row on success.
  ///
  /// On failure the row stays so the user can retry or see that it didn't die.
  Future<void> stopBackgroundProcess(String sessionId, String id) async {
    final rpc = _rpc;
    if (rpc == null) return;
    try {
      await rpc.killBackgroundProcess(sessionId, id);
      dismissBackgroundProcess(sessionId, id);
    } catch (_) {
      rethrow;
    }
  }

  /// Rewind cleanup: kill live background processes and drop every row for the
  /// session. Ids are marked dismissed so an in-flight `process.list` poll can't
  /// resurrect them; [reconcileBackgroundProcesses] garbage-collects those once
  /// the registry stops reporting them.
  Future<void> resetSessionBackground(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) return;
    _cancelAllAutoDismiss(sessionId);
    final list = _backgroundBySession[sessionId] ?? const [];
    final dismissed = _dismissedBySession.putIfAbsent(
      sessionId,
      () => <String>{},
    );
    final rpc = _rpc;

    for (final item in list) {
      dismissed.add(item.id);
      if (item.state == ComposerStatusState.running && rpc != null) {
        // Best-effort kill; don't await or throw.
        unawaited(
          rpc.killBackgroundProcess(sessionId, item.id).catchError((_) {}),
        );
      }
    }

    _backgroundBySession.remove(sessionId);
    _typedBySession.remove(sessionId);
    _markChanged(sessionId);
    notifyListeners();
  }

  ComposerStatusItem _toBackgroundItem(GatewayProcessEntry proc) {
    final exited = proc.status == 'exited';
    final exitCode = proc.exitCode;
    final state = exited
        ? (exitCode != null && exitCode != 0
              ? ComposerStatusState.failed
              : ComposerStatusState.done)
        : ComposerStatusState.running;
    final title = (proc.command ?? '').split('\n').first.trim();
    return ComposerStatusItem(
      id: proc.sessionId!,
      type: ComposerStatusType.background,
      state: state,
      title: title.isEmpty ? 'background process' : title,
      exitCode: exitCode,
      output: proc.outputTail?.isNotEmpty == true ? proc.outputTail : null,
    );
  }

  bool _sameBackgroundItem(ComposerStatusItem a, ComposerStatusItem b) =>
      a.id == b.id &&
      a.state == b.state &&
      a.title == b.title &&
      a.output == b.output &&
      a.exitCode == b.exitCode;

  void _scheduleAutoDismiss(String sessionId, String id, int delayMs) {
    final timers = _autoClearTimers.putIfAbsent(sessionId, () => {});
    final timerKey = _backgroundTimerKey(id);
    if (timers.containsKey(timerKey)) return;
    timers[timerKey] = Timer(Duration(milliseconds: delayMs), () {
      _autoClearTimers[sessionId]?.remove(timerKey);
      dismissBackgroundProcess(sessionId, id);
    });
  }

  void _cancelAutoDismiss(String sessionId, String id) {
    final timers = _autoClearTimers[sessionId];
    if (timers == null) return;
    final timer = timers.remove(id);
    timer?.cancel();
  }

  void _cancelAllAutoDismiss(String sessionId) {
    final timers = _autoClearTimers.remove(sessionId);
    if (timers == null) return;
    for (final timer in timers.values) {
      timer.cancel();
    }
  }

  bool _listsEqual(List<ComposerStatusItem> a, List<ComposerStatusItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final timers in _autoClearTimers.values) {
      for (final timer in timers.values) {
        timer.cancel();
      }
    }
    _autoClearTimers.clear();
    _snapshotBySession.clear();
    _completionController.close();
    super.dispose();
  }
}
