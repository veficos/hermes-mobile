library;

import 'package:flutter/foundation.dart';

enum PaneSplitAxis { horizontal, vertical }

enum PaneDropPosition { center, left, right, top, bottom }

@immutable
sealed class PaneNode {
  const PaneNode({required this.id});

  final String id;

  Map<String, dynamic> toJson();

  static PaneNode? fromJson(Object? raw, {int depth = 0}) {
    if (raw is! Map || depth > 8) return null;
    final json = raw.cast<Object?, Object?>();
    final id = json['id']?.toString().trim() ?? '';
    if (!_validId(id)) return null;
    switch (json['type']) {
      case 'group':
        final panes = (json['panes'] as List? ?? const [])
            .map((value) => value.toString().trim())
            .where(_validPaneId)
            .take(32)
            .toSet()
            .toList(growable: false);
        if (panes.isEmpty) return null;
        final requestedActive = json['active']?.toString() ?? '';
        return PaneGroup(
          id: id,
          panes: panes,
          active: panes.contains(requestedActive)
              ? requestedActive
              : panes.first,
        );
      case 'split':
        final axis = PaneSplitAxis.values.firstWhere(
          (value) => value.name == json['axis']?.toString(),
          orElse: () => PaneSplitAxis.horizontal,
        );
        final children = (json['children'] as List? ?? const [])
            .map((value) => PaneNode.fromJson(value, depth: depth + 1))
            .whereType<PaneNode>()
            .take(8)
            .toList(growable: false);
        if (children.isEmpty) return null;
        final rawWeights = json['weights'] as List? ?? const [];
        final weights = List<double>.generate(children.length, (index) {
          final rawValue = index < rawWeights.length ? rawWeights[index] : null;
          final value = rawValue is num ? rawValue : null;
          return _validWeight(value?.toDouble()) ? value!.toDouble() : 1;
        });
        return normalizePaneTree(
          PaneSplit(id: id, axis: axis, children: children, weights: weights),
        );
      default:
        return null;
    }
  }
}

@immutable
class PaneGroup extends PaneNode {
  const PaneGroup({
    required super.id,
    required this.panes,
    required this.active,
  });

  final List<String> panes;
  final String active;

  PaneGroup copyWith({List<String>? panes, String? active}) => PaneGroup(
    id: id,
    panes: panes ?? this.panes,
    active: active ?? this.active,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'group',
    'id': id,
    'panes': panes,
    'active': active,
  };
}

@immutable
class PaneSplit extends PaneNode {
  const PaneSplit({
    required super.id,
    required this.axis,
    required this.children,
    required this.weights,
  });

  final PaneSplitAxis axis;
  final List<PaneNode> children;
  final List<double> weights;

  PaneSplit copyWith({List<PaneNode>? children, List<double>? weights}) =>
      PaneSplit(
        id: id,
        axis: axis,
        children: children ?? this.children,
        weights: weights ?? this.weights,
      );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'split',
    'id': id,
    'axis': axis.name,
    'children': children.map((child) => child.toJson()).toList(),
    'weights': weights,
  };
}

bool _validId(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$').hasMatch(value);

bool _validPaneId(String value) =>
    value.length <= 512 && value.isNotEmpty && !value.contains('\u0000');

bool _validWeight(double? value) =>
    value != null && value.isFinite && value > 0;

List<String> paneIds(PaneNode? node) {
  if (node == null) return const [];
  return switch (node) {
    PaneGroup() => [...node.panes],
    PaneSplit() => [for (final child in node.children) ...paneIds(child)],
  };
}

PaneGroup? paneGroupFor(PaneNode? node, String paneId) {
  if (node == null) return null;
  if (node is PaneGroup) return node.panes.contains(paneId) ? node : null;
  for (final child in (node as PaneSplit).children) {
    final found = paneGroupFor(child, paneId);
    if (found != null) return found;
  }
  return null;
}

PaneNode? normalizePaneTree(PaneNode? node) {
  if (node == null) return null;
  if (node is PaneGroup) {
    final panes = node.panes.where(_validPaneId).toSet().toList();
    if (panes.isEmpty) return null;
    return node.copyWith(
      panes: List.unmodifiable(panes),
      active: panes.contains(node.active) ? node.active : panes.first,
    );
  }

  final split = node as PaneSplit;
  final children = <PaneNode>[];
  final weights = <double>[];
  for (var index = 0; index < split.children.length; index++) {
    final child = normalizePaneTree(split.children[index]);
    if (child == null) continue;
    final weight =
        index < split.weights.length && _validWeight(split.weights[index])
        ? split.weights[index]
        : 1.0;
    if (child is PaneSplit && child.axis == split.axis) {
      final total = child.weights.fold<double>(0, (sum, item) => sum + item);
      for (
        var childIndex = 0;
        childIndex < child.children.length;
        childIndex++
      ) {
        children.add(child.children[childIndex]);
        weights.add(
          weight * (total > 0 ? child.weights[childIndex] / total : 1),
        );
      }
    } else {
      children.add(child);
      weights.add(weight);
    }
  }
  if (children.isEmpty) return null;
  if (children.length == 1) return children.first;
  return PaneSplit(
    id: split.id,
    axis: split.axis,
    children: List.unmodifiable(children),
    weights: List.unmodifiable(weights),
  );
}

PaneNode? removePaneFromTree(PaneNode? node, String paneId) {
  if (node == null) return null;
  PaneNode walk(PaneNode current) {
    if (current is PaneGroup) {
      final at = current.panes.indexOf(paneId);
      if (at < 0) return current;
      final panes = current.panes.where((id) => id != paneId).toList();
      final active = current.active == paneId && panes.isNotEmpty
          ? panes[at.clamp(0, panes.length - 1)]
          : current.active;
      return current.copyWith(panes: panes, active: active);
    }
    final split = current as PaneSplit;
    return split.copyWith(children: split.children.map(walk).toList());
  }

  return normalizePaneTree(walk(node));
}

PaneNode activatePaneInTree(PaneNode node, String paneId) {
  if (node is PaneGroup) {
    return node.panes.contains(paneId) ? node.copyWith(active: paneId) : node;
  }
  final split = node as PaneSplit;
  return split.copyWith(
    children: split.children
        .map((child) => activatePaneInTree(child, paneId))
        .toList(),
  );
}

PaneNode insertPaneInTree(
  PaneNode node, {
  required String targetGroupId,
  required String paneId,
  required String newGroupId,
  required String newSplitId,
  PaneDropPosition position = PaneDropPosition.center,
}) {
  PaneNode walk(PaneNode current) {
    if (current is PaneGroup) {
      if (current.id != targetGroupId) return current;
      if (position == PaneDropPosition.center) {
        final panes = [...current.panes.where((id) => id != paneId), paneId];
        return current.copyWith(panes: panes, active: paneId);
      }
      final axis = switch (position) {
        PaneDropPosition.left ||
        PaneDropPosition.right => PaneSplitAxis.horizontal,
        PaneDropPosition.top ||
        PaneDropPosition.bottom => PaneSplitAxis.vertical,
        PaneDropPosition.center => throw StateError('unreachable'),
      };
      final before =
          position == PaneDropPosition.left || position == PaneDropPosition.top;
      final added = PaneGroup(id: newGroupId, panes: [paneId], active: paneId);
      return PaneSplit(
        id: newSplitId,
        axis: axis,
        children: before ? [added, current] : [current, added],
        weights: const [1, 1],
      );
    }
    final split = current as PaneSplit;
    return split.copyWith(children: split.children.map(walk).toList());
  }

  return normalizePaneTree(walk(node))!;
}

PaneNode movePaneInTree(
  PaneNode node, {
  required String paneId,
  required String targetGroupId,
  required String newGroupId,
  required String newSplitId,
  PaneDropPosition position = PaneDropPosition.center,
}) {
  final removed = removePaneFromTree(node, paneId);
  if (removed == null) {
    return PaneGroup(id: newGroupId, panes: [paneId], active: paneId);
  }
  final target = paneGroupFor(removed, targetGroupId);
  final fallback = target ?? paneGroupFor(removed, paneIds(removed).first);
  if (fallback == null) return removed;
  return insertPaneInTree(
    removed,
    targetGroupId: fallback.id,
    paneId: paneId,
    newGroupId: newGroupId,
    newSplitId: newSplitId,
    position: position,
  );
}

PaneNode updateSplitWeights(
  PaneNode node,
  String splitId,
  List<double> weights,
) {
  if (node is PaneGroup) return node;
  final split = node as PaneSplit;
  if (split.id == splitId &&
      weights.length == split.children.length &&
      weights.every(_validWeight)) {
    return split.copyWith(weights: List.unmodifiable(weights));
  }
  return split.copyWith(
    children: split.children
        .map((child) => updateSplitWeights(child, splitId, weights))
        .toList(),
  );
}
