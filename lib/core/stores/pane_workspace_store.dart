library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../connections/connection_registry.dart';
import '../pane_tree.dart';
import 'plugin_contribution_store.dart';
import '../../l10n/runtime_l10n.dart';

enum WorkspacePaneKind {
  session,
  plugin,
  terminal,
  files,
  review,
  logs,
  preview,
}

enum WorkspaceLayoutPreset { defaultLayout, focus, terminalDeck, quad }

@immutable
class WorkspacePane {
  const WorkspacePane({
    required this.id,
    required this.kind,
    required this.referenceId,
    required this.title,
    required this.owner,
    this.readOnly = false,
  });

  final String id;
  final WorkspacePaneKind kind;
  final String referenceId;
  final String title;
  final OwnerRoute owner;
  final bool readOnly;

  WorkspacePane copyWith({String? title}) => WorkspacePane(
    id: id,
    kind: kind,
    referenceId: referenceId,
    title: title ?? this.title,
    owner: owner,
    readOnly: readOnly,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'reference_id': referenceId,
    'title': title,
    'connection_id': owner.connectionId.value,
    if (owner.profile?.isNotEmpty == true) 'profile': owner.profile,
    if (readOnly) 'read_only': true,
  };

  static WorkspacePane? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<Object?, Object?>();
    final id = json['id']?.toString().trim() ?? '';
    final referenceId = json['reference_id']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final connectionId = json['connection_id']?.toString().trim() ?? '';
    final kind = WorkspacePaneKind.values
        .where((value) => value.name == json['kind']?.toString())
        .firstOrNull;
    if (id.isEmpty ||
        id.length > 512 ||
        referenceId.isEmpty ||
        referenceId.length > 512 ||
        title.isEmpty ||
        title.length > 240 ||
        connectionId.isEmpty ||
        kind == null) {
      return null;
    }
    return WorkspacePane(
      id: id,
      kind: kind,
      referenceId: referenceId,
      title: title,
      owner: OwnerRoute(
        connectionId: ConnectionId(connectionId),
        profile: json['profile']?.toString(),
      ),
      readOnly: json['read_only'] == true,
    );
  }
}

class PaneWorkspaceStore extends ChangeNotifier {
  static const storageKey = 'hm_pane_workspace_v1';
  static const maxPanes = 16;

  PaneNode? _tree;
  Map<String, WorkspacePane> _panes = const {};
  String? _focusedPaneId;
  bool _loaded = false;
  int _sequence = 0;
  Future<void> _writeTail = Future.value();

  PaneNode? get tree => _tree;
  Map<String, WorkspacePane> get panes => Map.unmodifiable(_panes);
  String? get focusedPaneId => _focusedPaneId;
  bool get loaded => _loaded;
  bool get isEmpty => _panes.isEmpty;

  List<WorkspacePane> get orderedPanes => [
    for (final id in paneIds(_tree)) ?_panes[id],
  ];

  String _nextId(String prefix) {
    _sequence++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_sequence.toRadixString(36)}';
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final json = decoded.cast<Object?, Object?>();
          final descriptors = <String, WorkspacePane>{};
          for (final rawPane in (json['panes'] as List? ?? const []).take(
            maxPanes,
          )) {
            final pane = WorkspacePane.fromJson(rawPane);
            if (pane != null) descriptors[pane.id] = pane;
          }
          var restoredTree = PaneNode.fromJson(json['tree']);
          restoredTree = _pruneTree(restoredTree, descriptors.keys.toSet());
          final ids = paneIds(restoredTree).toSet();
          _panes = Map.unmodifiable({
            for (final entry in descriptors.entries)
              if (ids.contains(entry.key)) entry.key: entry.value,
          });
          _tree = restoredTree;
          final requested = json['focused']?.toString();
          _focusedPaneId = ids.contains(requested)
              ? requested
              : ids.firstOrNull;
        }
      }
    } catch (_) {
      _tree = null;
      _panes = const {};
      _focusedPaneId = null;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  PaneNode? _pruneTree(PaneNode? node, Set<String> allowed) {
    var next = node;
    for (final id in paneIds(node)) {
      if (!allowed.contains(id)) next = removePaneFromTree(next, id);
    }
    return next;
  }

  String _sessionPaneId(String durableId, OwnerRoute owner) =>
      'session:${Uri.encodeComponent(owner.connectionId.value)}:'
      '${Uri.encodeComponent(owner.profile ?? '')}:'
      '${Uri.encodeComponent(durableId)}';

  String _pluginPaneId(MobilePluginContribution contribution) =>
      'plugin:${Uri.encodeComponent(contribution.owner.connectionId.value)}:'
      '${Uri.encodeComponent(contribution.owner.profile ?? '')}:'
      '${Uri.encodeComponent(contribution.namespacedId)}';

  String _corePaneId(
    WorkspacePaneKind kind,
    String referenceId,
    OwnerRoute owner,
  ) =>
      '${kind.name}:${Uri.encodeComponent(owner.connectionId.value)}:'
      '${Uri.encodeComponent(owner.profile ?? '')}:'
      '${Uri.encodeComponent(referenceId)}';

  Future<String> openSession({
    required String durableId,
    required String title,
    required OwnerRoute owner,
    bool readOnly = false,
    PaneDropPosition position = PaneDropPosition.right,
    String? targetPaneId,
  }) async {
    final paneId = _sessionPaneId(durableId, owner);
    await _open(
      WorkspacePane(
        id: paneId,
        kind: WorkspacePaneKind.session,
        referenceId: durableId,
        title: title.trim().isEmpty
            ? runtimeL10n.sessionUntitled
            : title.trim(),
        owner: owner,
        readOnly: readOnly,
      ),
      position: position,
      targetPaneId: targetPaneId,
    );
    return paneId;
  }

  Future<String> openPlugin(
    MobilePluginContribution contribution, {
    PaneDropPosition position = PaneDropPosition.right,
    String? targetPaneId,
  }) async {
    final paneId = _pluginPaneId(contribution);
    await _open(
      WorkspacePane(
        id: paneId,
        kind: WorkspacePaneKind.plugin,
        referenceId: contribution.namespacedId,
        title: contribution.title,
        owner: contribution.owner,
      ),
      position: position,
      targetPaneId: targetPaneId,
    );
    return paneId;
  }

  Future<String> openCorePane({
    required WorkspacePaneKind kind,
    required String title,
    required OwnerRoute owner,
    String referenceId = 'default',
    PaneDropPosition position = PaneDropPosition.right,
    String? targetPaneId,
  }) async {
    if (kind == WorkspacePaneKind.session || kind == WorkspacePaneKind.plugin) {
      throw ArgumentError.value(kind, 'kind', 'Expected a core pane kind');
    }
    final normalizedReference = referenceId.trim().isEmpty
        ? 'default'
        : referenceId.trim();
    final paneId = _corePaneId(kind, normalizedReference, owner);
    await _open(
      WorkspacePane(
        id: paneId,
        kind: kind,
        referenceId: normalizedReference,
        title: title.trim().isEmpty ? kind.name : title.trim(),
        owner: owner,
      ),
      position: position,
      targetPaneId: targetPaneId,
    );
    return paneId;
  }

  Future<void> _open(
    WorkspacePane pane, {
    required PaneDropPosition position,
    String? targetPaneId,
  }) async {
    if (!_loaded) await load();
    if (_panes.containsKey(pane.id)) {
      _panes = Map.unmodifiable({..._panes, pane.id: pane});
      activate(pane.id);
      return;
    }
    if (_panes.length >= maxPanes) {
      throw StateError(runtimeL10n.workspacePaneLimit(maxPanes));
    }
    _panes = Map.unmodifiable({..._panes, pane.id: pane});
    if (_tree == null) {
      _tree = PaneGroup(
        id: _nextId('group'),
        panes: [pane.id],
        active: pane.id,
      );
    } else {
      final target = targetPaneId ?? _focusedPaneId ?? paneIds(_tree).first;
      final group =
          paneGroupFor(_tree, target) ??
          paneGroupFor(_tree, paneIds(_tree).first)!;
      _tree = insertPaneInTree(
        _tree!,
        targetGroupId: group.id,
        paneId: pane.id,
        newGroupId: _nextId('group'),
        newSplitId: _nextId('split'),
        position: position,
      );
    }
    _focusedPaneId = pane.id;
    notifyListeners();
    await _persist();
  }

  void activate(String paneId) {
    if (_tree == null || !_panes.containsKey(paneId)) return;
    _tree = activatePaneInTree(_tree!, paneId);
    _focusedPaneId = paneId;
    notifyListeners();
    unawaited(_persist());
  }

  void close(String paneId) {
    if (!_panes.containsKey(paneId)) return;
    _tree = removePaneFromTree(_tree, paneId);
    _panes = Map.unmodifiable({..._panes}..remove(paneId));
    if (_focusedPaneId == paneId) {
      _focusedPaneId = paneIds(_tree).lastOrNull;
    }
    notifyListeners();
    unawaited(_persist());
  }

  void move(String paneId, String targetPaneId, PaneDropPosition position) {
    final current = _tree;
    final target = paneGroupFor(current, targetPaneId);
    if (current == null ||
        target == null ||
        !_panes.containsKey(paneId) ||
        paneId == targetPaneId && position == PaneDropPosition.center) {
      return;
    }
    _tree = movePaneInTree(
      current,
      paneId: paneId,
      targetGroupId: target.id,
      newGroupId: _nextId('group'),
      newSplitId: _nextId('split'),
      position: position,
    );
    _focusedPaneId = paneId;
    notifyListeners();
    unawaited(_persist());
  }

  void resize(String splitId, List<double> weights) {
    final current = _tree;
    if (current == null) return;
    _tree = updateSplitWeights(current, splitId, weights);
    notifyListeners();
    unawaited(_persist());
  }

  void applyLayoutPreset(WorkspaceLayoutPreset preset) {
    final ids = paneIds(_tree).where(_panes.containsKey).toList();
    if (ids.isEmpty) return;
    final active = ids.contains(_focusedPaneId) ? _focusedPaneId! : ids.first;
    final next = switch (preset) {
      WorkspaceLayoutPreset.focus => _presetGroup('preset-focus', ids, active),
      WorkspaceLayoutPreset.defaultLayout => _defaultPreset(ids, active),
      WorkspaceLayoutPreset.terminalDeck => _terminalDeckPreset(ids, active),
      WorkspaceLayoutPreset.quad => _quadPreset(ids, active),
    };
    _tree = normalizePaneTree(next);
    _focusedPaneId = active;
    notifyListeners();
    unawaited(_persist());
  }

  PaneNode _defaultPreset(List<String> ids, String active) {
    final main = _idsOfKinds(ids, const {
      WorkspacePaneKind.session,
      WorkspacePaneKind.plugin,
      WorkspacePaneKind.preview,
    });
    final upperTools = _idsOfKinds(ids, const {
      WorkspacePaneKind.files,
      WorkspacePaneKind.review,
    });
    final lowerTools = _idsOfKinds(ids, const {
      WorkspacePaneKind.terminal,
      WorkspacePaneKind.logs,
    });
    return _presetSplit(
          'preset-default-root',
          PaneSplitAxis.horizontal,
          [
            _presetGroupOrNull('preset-default-main', main, active),
            _presetSplitOrNull(
              'preset-default-tools',
              PaneSplitAxis.vertical,
              [
                _presetGroupOrNull('preset-default-upper', upperTools, active),
                _presetGroupOrNull('preset-default-lower', lowerTools, active),
              ],
              const [1.6, 1],
            ),
          ],
          const [3.4, 1.25],
        ) ??
        _presetGroup('preset-default-fallback', ids, active);
  }

  PaneNode _terminalDeckPreset(List<String> ids, String active) {
    final terminal = _idsOfKinds(ids, const {
      WorkspacePaneKind.terminal,
      WorkspacePaneKind.logs,
    });
    final top = ids.where((id) => !terminal.contains(id)).toList();
    return _presetSplit(
          'preset-terminal-root',
          PaneSplitAxis.vertical,
          [
            _presetGroupOrNull('preset-terminal-main', top, active),
            _presetGroupOrNull('preset-terminal-deck', terminal, active),
          ],
          const [3, 1],
        ) ??
        _presetGroup('preset-terminal-fallback', ids, active);
  }

  PaneNode _quadPreset(List<String> ids, String active) {
    final main = _idsOfKinds(ids, const {
      WorkspacePaneKind.session,
      WorkspacePaneKind.plugin,
    });
    final files = _idsOfKinds(ids, const {WorkspacePaneKind.files});
    final terminal = _idsOfKinds(ids, const {
      WorkspacePaneKind.terminal,
      WorkspacePaneKind.logs,
    });
    final review = _idsOfKinds(ids, const {
      WorkspacePaneKind.review,
      WorkspacePaneKind.preview,
    });
    final assigned = {...main, ...files, ...terminal, ...review};
    main.addAll(ids.where((id) => !assigned.contains(id)));
    return _presetSplit(
          'preset-quad-root',
          PaneSplitAxis.vertical,
          [
            _presetSplitOrNull(
              'preset-quad-top',
              PaneSplitAxis.horizontal,
              [
                _presetGroupOrNull('preset-quad-main', main, active),
                _presetGroupOrNull('preset-quad-files', files, active),
              ],
              const [3, 1],
            ),
            _presetSplitOrNull(
              'preset-quad-bottom',
              PaneSplitAxis.horizontal,
              [
                _presetGroupOrNull('preset-quad-terminal', terminal, active),
                _presetGroupOrNull('preset-quad-review', review, active),
              ],
              const [1.4, 1],
            ),
          ],
          const [3, 1],
        ) ??
        _presetGroup('preset-quad-fallback', ids, active);
  }

  List<String> _idsOfKinds(List<String> ids, Set<WorkspacePaneKind> kinds) => [
    for (final id in ids)
      if (kinds.contains(_panes[id]?.kind)) id,
  ];

  PaneGroup _presetGroup(String id, List<String> ids, String active) =>
      PaneGroup(
        id: id,
        panes: List.unmodifiable(ids),
        active: ids.contains(active) ? active : ids.first,
      );

  PaneGroup? _presetGroupOrNull(String id, List<String> ids, String active) =>
      ids.isEmpty ? null : _presetGroup(id, ids, active);

  PaneNode? _presetSplitOrNull(
    String id,
    PaneSplitAxis axis,
    List<PaneNode?> candidates,
    List<double> candidateWeights,
  ) {
    final children = <PaneNode>[];
    final weights = <double>[];
    for (var index = 0; index < candidates.length; index++) {
      final child = candidates[index];
      if (child == null) continue;
      children.add(child);
      weights.add(
        index < candidateWeights.length ? candidateWeights[index] : 1,
      );
    }
    if (children.isEmpty) return null;
    if (children.length == 1) return children.first;
    return PaneSplit(
      id: id,
      axis: axis,
      children: List.unmodifiable(children),
      weights: List.unmodifiable(weights),
    );
  }

  PaneNode? _presetSplit(
    String id,
    PaneSplitAxis axis,
    List<PaneNode?> candidates,
    List<double> candidateWeights,
  ) => _presetSplitOrNull(id, axis, candidates, candidateWeights);

  void rename(String paneId, String title) {
    final pane = _panes[paneId];
    final normalized = title.trim();
    if (pane == null || normalized.isEmpty || pane.title == normalized) return;
    _panes = Map.unmodifiable({
      ..._panes,
      paneId: pane.copyWith(title: normalized),
    });
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> clear() async {
    _tree = null;
    _panes = const {};
    _focusedPaneId = null;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    final payload = jsonEncode({
      'tree': _tree?.toJson(),
      'panes': _panes.values.map((pane) => pane.toJson()).toList(),
      'focused': _focusedPaneId,
    });
    final write = _writeTail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, payload);
    });
    _writeTail = write.catchError((_) {});
    return write;
  }

  Future<void> flush() => _writeTail;
}
