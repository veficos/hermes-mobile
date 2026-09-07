library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

class SessionViewState {
  final String? anchorMessageId;
  final double scrollOffset;
  final int composerSelection;
  final String? previewTabId;
  final bool consoleOpen;
  final Set<String> expandedItems;

  const SessionViewState({
    this.anchorMessageId,
    this.scrollOffset = 0,
    this.composerSelection = 0,
    this.previewTabId,
    this.consoleOpen = false,
    this.expandedItems = const {},
  });

  int get estimatedBytes =>
      96 +
      (anchorMessageId?.length ?? 0) * 2 +
      (previewTabId?.length ?? 0) * 2 +
      expandedItems.fold(0, (sum, value) => sum + value.length * 2);
}

/// Count-and-byte bounded per-session UI state cache. Transcript data remains
/// authoritative in ChatStore; this cache only makes rapid session switches
/// feel warm and cannot bleed one session's visual state into another.
class SessionViewStateStore extends ChangeNotifier {
  final int maxCount;
  final int maxBytes;
  final LinkedHashMap<String, SessionViewState> _states = LinkedHashMap();
  final Set<String> _protected = {};

  SessionViewStateStore({this.maxCount = 24, this.maxBytes = 512 * 1024});

  SessionViewState? get(String sessionId) {
    final value = _states.remove(sessionId);
    if (value != null) _states[sessionId] = value;
    return value;
  }

  void put(String sessionId, SessionViewState state) {
    if (sessionId.isEmpty) return;
    _states.remove(sessionId);
    _states[sessionId] = state;
    _prune();
  }

  void protect(Iterable<String> sessionIds) {
    _protected
      ..clear()
      ..addAll(sessionIds.where((id) => id.isNotEmpty));
    _prune();
  }

  int get count => _states.length;
  int get estimatedBytes =>
      _states.values.fold(0, (sum, value) => sum + value.estimatedBytes);

  void _prune() {
    var bytes = estimatedBytes;
    while ((_states.length > maxCount || bytes > maxBytes) &&
        _states.keys.any((id) => !_protected.contains(id))) {
      final victim = _states.keys.firstWhere((id) => !_protected.contains(id));
      bytes -= _states.remove(victim)!.estimatedBytes;
    }
  }
}
