/// SubagentStore: durable child-session projection plus live runtime trees.
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../l10n/runtime_l10n.dart';
import '../gateway.dart';
import '../models.dart';
import 'connection_store.dart';

// Stream-entry bookkeeping — mirrors desktop's store/subagents.ts constants
// exactly so the same event payloads render the same lines.
const _maxStream = 24;
const _previewMax = 220;
const _toolPreviewMax = 96;
const _terminalSubagentStatuses = {'completed', 'failed', 'interrupted'};

String _compactLine(String text, [int max = _previewMax]) {
  final line = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (line.isEmpty) return '';
  return line.length > max ? '${line.substring(0, max - 1)}…' : line;
}

String _toolLabel(String name) {
  final words = name
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1));
  final label = words.join(' ');
  return label.isEmpty ? name : label;
}

String _formatToolLine(String name, [String preview = '']) {
  final snippet = _compactLine(preview, _toolPreviewMax);
  return snippet.isNotEmpty
      ? '${_toolLabel(name)}("$snippet")'
      : _toolLabel(name);
}

/// Port of desktop's `streamFromPayload` (store/subagents.ts) — builds the
/// new stream lines a single event contributes (tool tail entries, the
/// active tool, progress/thinking text, and a terminal summary), to be
/// appended to the node's existing stream.
List<SubagentStreamEntry> _streamEntriesFromPayload(
  Map<String, dynamic> payload,
  String status,
  String eventType,
  int at,
) {
  final out = <SubagentStreamEntry>[];
  final tool = payload['tool_name']?.toString() ?? '';
  final preview =
      (payload['tool_preview'] ?? payload['text'])?.toString() ?? '';
  final text = _compactLine((payload['text'] ?? preview).toString());

  final tail = payload['output_tail'];
  if (tail is List) {
    for (final raw in tail) {
      if (raw is! Map) continue;
      final tailTool = raw['tool']?.toString() ?? '';
      final tailPreview = raw['preview']?.toString() ?? '';
      final isError = raw['is_error'] == true;
      final line = tailTool.isNotEmpty
          ? _formatToolLine(tailTool, tailPreview)
          : _compactLine(tailPreview);
      if (line.isNotEmpty) {
        out.add(
          SubagentStreamEntry(
            at: at,
            isError: isError,
            kind: tailTool.isNotEmpty ? 'tool' : 'progress',
            text: line,
          ),
        );
      }
    }
  }

  if (tool.isNotEmpty) {
    out.add(
      SubagentStreamEntry(
        at: at,
        isError: payload['error'] != null,
        kind: 'tool',
        text: _formatToolLine(tool, preview),
      ),
    );
  }

  if (eventType == 'subagent.progress' && text.isNotEmpty) {
    out.add(
      SubagentStreamEntry(
        at: at,
        isError: payload['error'] != null,
        kind: 'progress',
        text: text,
      ),
    );
  }

  if (eventType == 'subagent.thinking' && text.isNotEmpty) {
    out.add(SubagentStreamEntry(at: at, kind: 'thinking', text: text));
  }

  // The backend sends no summary on a hard child timeout (only a preview
  // like "Timed out after 612.3s" + duration_seconds) — synthesize one so
  // the terminal row explains why it failed.
  final durationSeconds = payload['duration_seconds'];
  final timeoutSummary = payload['status'] == 'timeout'
      ? 'Timed out after ${durationSeconds ?? '?'}s'
      : '';
  final summary = _compactLine(
    (payload['summary'] ?? payload['text'] ?? timeoutSummary).toString(),
  );
  if (_terminalSubagentStatuses.contains(status) && summary.isNotEmpty) {
    out.add(
      SubagentStreamEntry(
        at: at,
        isError: status == 'failed',
        kind: 'summary',
        text: summary,
      ),
    );
  }

  return out;
}

/// Append [entries] to [stream], deduping an exact repeat of the last line
/// and capping at [_maxStream] — matches desktop's `appendStream`.
List<SubagentStreamEntry> _appendStream(
  List<SubagentStreamEntry> stream,
  List<SubagentStreamEntry> entries,
) {
  var next = stream;
  for (final entry in entries) {
    final last = next.isEmpty ? null : next.last;
    if (last != null &&
        last.kind == entry.kind &&
        last.text == entry.text &&
        last.isError == entry.isError) {
      continue;
    }
    next = [...next, entry];
    if (next.length > _maxStream) {
      next = next.sublist(next.length - _maxStream);
    }
  }
  return next;
}

class SubagentStore extends ChangeNotifier {
  static const _logName = 'hermes.subagent';

  final ConnectionStore connection;
  SubagentStore({required this.connection}) {
    _eventSub = connection.events.listen(_onEvent);
    _reconnectSub = connection.reconnected.listen((_) {
      unawaited(refreshProjection());
    });
  }

  final Map<String, SessionRow> _childrenById = {};
  final Map<String, Map<String, SubagentNode>> _runtimeByParent = {};
  final Map<String, List<SubagentNode>> _bySession = {};
  StreamSubscription<GatewayEvent>? _eventSub;
  StreamSubscription<void>? _reconnectSub;
  bool _loading = false;
  bool _refreshPending = false;
  Object? _error;

  bool get loading => _loading;
  Object? get error => _error;
  List<SessionRow> get childSessions => List.unmodifiable(_childrenById.values);
  Iterable<String> get sessionIds => {..._bySession.keys, ..._durableParentIds};

  Iterable<String> get _durableParentIds => _childrenById.values
      .map((row) => row.parentSessionId)
      .whereType<String>()
      .where((id) => id.isNotEmpty);

  List<SubagentNode> forSession(String? sid) =>
      sid == null ? const [] : (_bySession[sid] ?? const []);

  List<SessionRow> childrenForParent(String parentId) {
    final rows = _childrenById.values
        .where((row) => row.parentSessionId == parentId)
        .toList();
    rows.sort((a, b) => (b.lastMessageAt ?? 0).compareTo(a.lastMessageAt ?? 0));
    return rows;
  }

  SubagentNode? runtimeForChild(String childSessionId) {
    for (final nodes in _runtimeByParent.values) {
      for (final node in nodes.values) {
        if (node.sessionId == childSessionId) return node;
      }
    }
    return null;
  }

  int runtimeDescendantCount(String parentSessionId) {
    final seen = <String>{};
    void visit(SubagentNode node) {
      if (!seen.add(node.id)) return;
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final node in forSession(parentSessionId)) {
      visit(node);
    }
    return seen.length;
  }

  int descendantCount(String parentSessionId) {
    final seenSessions = <String>{};
    final seenRuntime = <String>{};

    void visitRuntime(SubagentNode node) {
      if (!seenRuntime.add(node.id)) return;
      for (final child in node.children) {
        visitRuntime(child);
      }
    }

    void visitDurable(String parentId) {
      for (final child in childrenForParent(parentId)) {
        if (seenSessions.add(child.id)) visitDurable(child.id);
      }
      for (final node in forSession(parentId)) {
        visitRuntime(node);
      }
    }

    visitDurable(parentSessionId);
    for (final node in forSession(parentSessionId)) {
      visitRuntime(node);
    }
    return seenSessions.length + seenRuntime.length;
  }

  bool get hasRunning => _runtimeByParent.values.any(
    (nodes) => nodes.values.any(
      (node) => node.status == 'running' || node.status == 'queued',
    ),
  );

  void _log(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _logName,
      error: error,
      stackTrace: stackTrace,
    );
  }

  String? _parentSessionId(GatewayEvent event) {
    String? value(dynamic raw) {
      final text = raw?.toString();
      return text == null || text.isEmpty ? null : text;
    }

    final childId = _childSessionId(event.payload);
    final explicit =
        value(event.payload['parent_session_id']) ??
        value(event.payload['parent_id']);
    if (explicit != null) return explicit;
    final fallback =
        value(event.payload['session_id']) ?? value(event.sessionId);
    return fallback == childId ? null : fallback;
  }

  String? _childSessionId(Map<String, dynamic> payload) {
    final value = payload['child_session_id']?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  void _onEvent(GatewayEvent event) {
    if (event.type == 'sessions.changed') {
      unawaited(refreshProjection());
      return;
    }
    if (!event.type.startsWith('subagent.')) return;
    final sid = _parentSessionId(event);
    final childId = _childSessionId(event.payload);
    _log(
      'event type=${event.type} session=${sid ?? '<missing>'} '
      'subagent=${event.payload['subagent_id'] ?? event.payload['id'] ?? '<missing>'} '
      'childSession=${childId ?? '<missing>'}',
    );
    if (sid == null) {
      _log('event ignored: missing parent session id type=${event.type}');
      return;
    }

    final flat = _runtimeByParent.putIfAbsent(sid, () => {});
    final payload = Map<String, dynamic>.from(event.payload);
    if (childId != null) payload['child_session_id'] = childId;
    final id = (payload['subagent_id'] ?? payload['id'] ?? '').toString();
    switch (event.type) {
      case 'subagent.start':
      case 'subagent.spawn_requested':
        final node = SubagentNode.fromJson({
          ...payload,
          'status': payload['status']?.toString() ?? 'running',
        });
        if (node.id.isNotEmpty) {
          flat[node.id] = _enrichFromPayload(node, payload, event.type);
        }
      case 'subagent.complete':
        if (id.isNotEmpty && flat[id] != null) {
          final updated = _copyWith(
            flat[id]!,
            status: (payload['status'] ?? 'completed').toString(),
            summary: payload['summary']?.toString(),
            updatedAt: DateTime.now(),
          );
          flat[id] = _enrichFromPayload(updated, payload, event.type);
        }
      case 'subagent.text':
      case 'subagent.thinking':
      case 'subagent.tool':
      case 'subagent.progress':
        if (id.isNotEmpty && flat[id] != null) {
          final updated = _copyWith(
            flat[id]!,
            currentTool:
                payload['tool_name']?.toString() ??
                payload['name']?.toString() ??
                payload['tool']?.toString(),
            updatedAt: DateTime.now(),
          );
          flat[id] = _enrichFromPayload(updated, payload, event.type);
        }
    }
    _rebuildTrees();
    notifyListeners();
  }

  Future<void> refreshProjection() async {
    final api = connection.api;
    if (api == null) return;
    if (_loading) {
      _refreshPending = true;
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    _log('projection refresh start');
    try {
      final projection = await api.subagentProjection();
      _childrenById
        ..clear()
        ..addEntries(
          projection.sessions
              .where((row) => row.id.isNotEmpty)
              .map((row) => MapEntry(row.id, row)),
        );
      _runtimeByParent
        ..clear()
        ..addEntries(
          projection.bySession.entries.map(
            (entry) => MapEntry(entry.key, _flatten(entry.value)),
          ),
        );
      _rebuildTrees();
      _log(
        'projection refresh complete children=${_childrenById.length} '
        'groups=${_runtimeByParent.length} total=${projection.total}',
      );
    } catch (error, stackTrace) {
      _error = error;
      _log('projection refresh failed', error, stackTrace);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
      if (_refreshPending) {
        _refreshPending = false;
        unawaited(refreshProjection());
      }
    }
  }

  Map<String, SubagentNode> _flatten(List<SubagentNode> roots) {
    final result = <String, SubagentNode>{};
    void visit(SubagentNode node) {
      if (node.id.isEmpty) return;
      result[node.id] = _copyWith(node, children: const []);
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final root in roots) {
      visit(root);
    }
    return result;
  }

  void _rebuildTrees() {
    _bySession.clear();
    final durableChildIds = _childrenById.values
        .where((row) => row.isDelegatedChild)
        .map((row) => row.id)
        .toSet();
    for (final entry in _runtimeByParent.entries) {
      final nodes = entry.value.values
          .where(
            (node) =>
                node.sessionId == null ||
                !durableChildIds.contains(node.sessionId),
          )
          .toList();
      final childIds = <String>{};
      final childrenByParent = <String, List<SubagentNode>>{};
      for (final node in nodes) {
        final parentId = node.parentId;
        if (parentId != null && parentId.isNotEmpty && parentId != node.id) {
          childIds.add(node.id);
          (childrenByParent[parentId] ??= []).add(node);
        }
      }
      final building = <String>{};
      SubagentNode build(SubagentNode node) {
        if (!building.add(node.id)) return _copyWith(node, children: const []);
        final children = <SubagentNode>[];
        final seenChildren = <String>{};
        for (final child in childrenByParent[node.id] ?? const []) {
          if (seenChildren.add(child.id)) children.add(build(child));
        }
        building.remove(node.id);
        return _copyWith(node, children: children);
      }

      final roots = <SubagentNode>[];
      final seenRoots = <String>{};
      for (final node in nodes) {
        if (!childIds.contains(node.id) && seenRoots.add(node.id)) {
          roots.add(build(node));
        }
      }
      for (final node in nodes) {
        if (seenRoots.add(node.id)) roots.add(build(node));
      }
      _bySession[entry.key] = roots;
    }
  }

  /// Legacy batch query remains available for older call sites/backends.
  Future<void> refreshSessions(Iterable<String> sessionIds) async {
    final ids = sessionIds.toList();
    final api = connection.api;
    if (api == null) {
      throw StateError(runtimeL10n.backendDisconnected);
    }
    _loading = true;
    _error = null;
    notifyListeners();
    _log('refresh start parents=${ids.length} ids=$ids');
    try {
      final entries = await api.subagentsForSessions(ids);
      for (final entry in entries.entries) {
        _runtimeByParent[entry.key] = _flatten(entry.value);
      }
      _rebuildTrees();
    } catch (error, stackTrace) {
      _error = error;
      _log('refresh failed parents=${ids.length}', error, stackTrace);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshTree(String sessionId) async {
    final api = connection.api;
    if (api == null) {
      throw StateError(runtimeL10n.backendDisconnected);
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final entries = await api.subagents(sessionId);
      _runtimeByParent[sessionId] = _flatten(entries);
      _rebuildTrees();
    } catch (error, stackTrace) {
      _error = error;
      _log('refresh tree failed parent=$sessionId', error, stackTrace);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> interrupt(String subagentId) async {
    final api = connection.api;
    if (api == null) {
      throw StateError(runtimeL10n.backendDisconnected);
    }
    await api.interruptSubagent(subagentId);
  }

  SubagentNode _copyWith(
    SubagentNode node, {
    String? status,
    String? summary,
    String? currentTool,
    DateTime? updatedAt,
    List<SubagentNode>? children,
    double? costUsd,
    int? inputTokens,
    int? outputTokens,
    int? toolCount,
    List<String>? filesRead,
    List<String>? filesWritten,
    List<SubagentStreamEntry>? stream,
  }) {
    return SubagentNode(
      id: node.id,
      parentId: node.parentId,
      goal: node.goal,
      sessionId: node.sessionId,
      model: node.model,
      status: status ?? node.status,
      taskCount: node.taskCount,
      taskIndex: node.taskIndex,
      startedAt: node.startedAt,
      updatedAt: updatedAt ?? node.updatedAt,
      summary: summary ?? node.summary,
      currentTool: currentTool ?? node.currentTool,
      children: children ?? node.children,
      costUsd: costUsd ?? node.costUsd,
      inputTokens: inputTokens ?? node.inputTokens,
      outputTokens: outputTokens ?? node.outputTokens,
      toolCount: toolCount ?? node.toolCount,
      filesRead: filesRead ?? node.filesRead,
      filesWritten: filesWritten ?? node.filesWritten,
      stream: stream ?? node.stream,
    );
  }

  /// Merge one event payload's stream/files/token/cost signal into [node] —
  /// the enrichment every `subagent.*` event contributes, regardless of
  /// which case in [_onEvent] handled its status/tool-name update. Mirrors
  /// desktop's `toProgress` (store/subagents.ts).
  SubagentNode _enrichFromPayload(
    SubagentNode node,
    Map<String, dynamic> payload,
    String eventType,
  ) {
    final at = DateTime.now().millisecondsSinceEpoch;
    final newEntries = _streamEntriesFromPayload(
      payload,
      node.status,
      eventType,
      at,
    );
    final filesRead = (payload['files_read'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final filesWritten = (payload['files_written'] as List?)
        ?.map((e) => e.toString())
        .toList();
    return _copyWith(
      node,
      stream: newEntries.isEmpty
          ? node.stream
          : _appendStream(node.stream, newEntries),
      filesRead: (filesRead?.isNotEmpty ?? false) ? filesRead : null,
      filesWritten: (filesWritten?.isNotEmpty ?? false) ? filesWritten : null,
      costUsd: (payload['cost_usd'] as num?)?.toDouble(),
      inputTokens: (payload['input_tokens'] as num?)?.toInt(),
      outputTokens: (payload['output_tokens'] as num?)?.toInt(),
      toolCount: (payload['tool_count'] as num?)?.toInt(),
    );
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }
}
