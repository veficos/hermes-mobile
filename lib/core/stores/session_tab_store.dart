import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../connections/connection_registry.dart';

@immutable
class SessionTab {
  final String id;
  final String title;
  final OwnerRoute owner;
  final bool readOnly;
  final bool watch;
  final bool unread;
  final bool running;
  const SessionTab({
    required this.id,
    required this.title,
    required this.owner,
    this.readOnly = false,
    this.watch = false,
    this.unread = false,
    this.running = false,
  });
  SessionTab copyWith({
    String? title,
    bool? readOnly,
    bool? watch,
    bool? unread,
    bool? running,
  }) => SessionTab(
    id: id,
    title: title ?? this.title,
    owner: owner,
    readOnly: readOnly ?? this.readOnly,
    watch: watch ?? this.watch,
    unread: unread ?? this.unread,
    running: running ?? this.running,
  );
}

/// Mobile replacement for desktop session tiles: deterministic tab/stack
/// operations, independent of Navigator and safe for background turns.
class SessionTabStore extends ChangeNotifier {
  final List<SessionTab> _tabs = [];
  String? _activeId;
  StreamSubscription<RoutedGatewayEvent>? _eventSub;
  SessionOwnerIndex? _owners;
  Stream<RoutedGatewayEvent>? _eventsSource;
  static const _prefsKey = 'hermes_mobile.session_tabs.v1';
  List<SessionTab> get tabs => List.unmodifiable(_tabs);
  String? get activeId => _activeId;
  SessionTab? get active => _tabs.where((t) => t.id == _activeId).firstOrNull;

  /// Binds background gateway events once. Events for unknown/closed tabs are
  /// ignored so an old connection can never mutate a new tab.
  void attachRoutedEvents(
    Stream<RoutedGatewayEvent> events, {
    SessionOwnerIndex? owners,
  }) {
    if (identical(_eventsSource, events) && identical(_owners, owners)) return;
    _eventSub?.cancel();
    _eventsSource = events;
    _owners = owners;
    _eventSub = events.listen(_onRoutedEvent);
  }

  Future<void> restore({Set<String>? availableSessionIds}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return;
      _tabs
        ..clear()
        ..addAll(
          list
              .whereType<Map>()
              .map((m) {
                final id = '${m['id'] ?? ''}';
                final owner = OwnerRoute(
                  connectionId: ConnectionId('${m['connection'] ?? 'primary'}'),
                  profile: (m['profile'] as String?)?.isEmpty == true
                      ? null
                      : m['profile'] as String?,
                );
                return SessionTab(
                  id: id,
                  title: '${m['title'] ?? id}',
                  owner: owner,
                  readOnly: m['readOnly'] == true,
                  watch: m['watch'] == true,
                );
              })
              .where(
                (t) =>
                    t.id.isNotEmpty &&
                    (availableSessionIds == null ||
                        availableSessionIds.contains(t.id)),
              )
              .take(24),
        );
      final active = prefs.getString('$_prefsKey.active');
      _activeId = _tabs.any((t) => t.id == active)
          ? active
          : (_tabs.isEmpty ? null : _tabs.first.id);
      notifyListeners();
    } catch (_) {
      // Corrupt preferences must not prevent the app from opening.
    }
  }

  /// Removes persisted tabs that are no longer present in the authoritative
  /// session list (for example after server-side deletion or profile change).
  /// This is intentionally explicit so restoring tabs never triggers network
  /// calls or silently resurrects stale sessions.
  void reconcile(Set<String> availableSessionIds) {
    final before = _tabs.length;
    _tabs.removeWhere((tab) => !availableSessionIds.contains(tab.id));
    if (_activeId != null && !_tabs.any((tab) => tab.id == _activeId)) {
      _activeId = _tabs.isEmpty ? null : _tabs.first.id;
    }
    if (_tabs.length != before) {
      notifyListeners();
      _persist();
    }
  }

  void _onRoutedEvent(RoutedGatewayEvent routed) {
    final event = routed.event;
    final eventSid =
        event.sessionId ??
        event.payload['session_id']?.toString() ??
        event.payload['runtime_id']?.toString();
    if (eventSid == null) return;
    final sid = _tabs.any((t) => t.id == eventSid)
        ? eventSid
        : _owners?.byRuntime(eventSid)?.durableId;
    if (sid == null) return;
    final i = _tabs.indexWhere((t) {
      if (t.id != sid || t.owner.connectionId != routed.route.connectionId) {
        return false;
      }
      final routedProfile = routed.route.profile ?? event.profile;
      return t.owner.profile == null ||
          routedProfile == null ||
          routedProfile == t.owner.profile;
    });
    if (i < 0) return;
    final start =
        event.type == 'message.start' ||
        event.type == 'turn.start' ||
        event.type == 'session.busy';
    final done =
        event.type == 'message.complete' ||
        event.type == 'turn.complete' ||
        event.type == 'error' ||
        event.type == 'session.stopped' ||
        event.type == 'session.idle';
    if (!start && !done) return;
    final isActive = _activeId == sid;
    _tabs[i] = _tabs[i].copyWith(
      running: start ? true : false,
      unread: isActive ? false : (start ? _tabs[i].unread : true),
    );
    notifyListeners();
    _persist();
  }

  void open(SessionTab tab, {bool activate = true}) {
    final i = _tabs.indexWhere((t) => t.id == tab.id);
    if (i < 0) {
      _tabs.add(tab);
    } else {
      _tabs[i] = tab;
    }
    if (activate) {
      _activeId = tab.id;
      if (_tabs[i < 0 ? _tabs.length - 1 : i].unread) {
        final activeIndex = i < 0 ? _tabs.length - 1 : i;
        _tabs[activeIndex] = _tabs[activeIndex].copyWith(unread: false);
      }
    }
    notifyListeners();
    _persist();
  }

  void activate(String id) {
    if (!_tabs.any((t) => t.id == id)) return;
    _activeId = id;
    final i = _tabs.indexWhere((t) => t.id == id);
    if (i >= 0 && _tabs[i].unread) _tabs[i] = _tabs[i].copyWith(unread: false);
    notifyListeners();
    _persist();
  }

  void markUnread(String id, bool value) {
    _patch(id, (t) => t.copyWith(unread: value));
    _persist();
  }

  void markRunning(String id, bool value) {
    _patch(id, (t) => t.copyWith(running: value));
    _persist();
  }

  void close(String id) {
    final i = _tabs.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tabs.removeAt(i);
    if (_activeId == id) {
      _activeId = _tabs.isEmpty
          ? null
          : _tabs[(i - 1).clamp(0, _tabs.length - 1)].id;
    }
    notifyListeners();
    _persist();
  }

  void closeOthers(String id) {
    final keep = _tabs.where((t) => t.id == id).toList();
    if (keep.isEmpty) return;
    _tabs
      ..clear()
      ..add(keep.single);
    _activeId = id;
    notifyListeners();
    _persist();
  }

  void closeToRight(String id) {
    final i = _tabs.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tabs.removeRange(i + 1, _tabs.length);
    notifyListeners();
    _persist();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _tabs.length) return;
    if (newIndex > oldIndex) newIndex--;
    newIndex = newIndex.clamp(0, _tabs.length - 1);
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);
    notifyListeners();
    _persist();
  }

  void _patch(String id, SessionTab Function(SessionTab) fn) {
    final i = _tabs.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tabs[i] = fn(_tabs[i]);
    notifyListeners();
  }

  void _persist() {
    unawaited(
      SharedPreferences.getInstance()
          .then<void>((prefs) async {
            final encoded = _tabs
                .map(
                  (t) => {
                    'id': t.id,
                    'title': t.title,
                    'connection': t.owner.connectionId.value,
                    'profile': t.owner.profile,
                    'readOnly': t.readOnly,
                    'watch': t.watch,
                  },
                )
                .toList(growable: false);
            await Future.wait([
              prefs.setString(_prefsKey, jsonEncode(encoded)),
              prefs.setString('$_prefsKey.active', _activeId ?? ''),
            ]);
          })
          .catchError((_) {}),
    );
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
