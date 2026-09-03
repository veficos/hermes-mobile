/// NotificationStore: in-app notification center (Q9 decision).
///
/// Subscribes to gateway broadcast events and turns `notification.show`,
/// `background.complete` into a local, read-flagged list. Notifications carry
/// an optional session id so tapping one deep-links back to the Session
/// (spec §181–182). Items and delivery state survive process restarts.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gateway.dart';
import '../connections/connection_registry.dart';
import '../../l10n/runtime_l10n.dart';
import 'connection_store.dart';

enum NotificationKind { info, success, warning, error, approval }

class NotificationItem {
  final String id;
  final NotificationKind kind;
  final String title;
  final String message;
  final String? sessionId;
  final String? connectionId;
  final String? profile;
  final String? requestId;

  /// Optional feature destination for notifications without a session.
  final String? target;
  final DateTime time;
  bool read;
  bool systemShown;

  NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    this.sessionId,
    this.connectionId,
    this.profile,
    this.requestId,
    this.target,
    required this.time,
    this.read = false,
    this.systemShown = false,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind']?.toString();
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      kind:
          NotificationKind.values
              .where((value) => value.name == kindName)
              .firstOrNull ??
          NotificationKind.info,
      title: json['title']?.toString() ?? 'Hermes',
      message: json['message']?.toString() ?? '',
      sessionId: json['session_id']?.toString(),
      connectionId: json['connection_id']?.toString(),
      profile: json['profile']?.toString(),
      requestId: json['request_id']?.toString(),
      target: json['target']?.toString(),
      time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
      read: json['read'] == true,
      systemShown: json['system_shown'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'message': message,
    'session_id': sessionId,
    'connection_id': connectionId,
    'profile': profile,
    'request_id': requestId,
    'target': target,
    'time': time.toIso8601String(),
    'read': read,
    'system_shown': systemShown,
  };
}

class NotificationStore extends ChangeNotifier {
  static const _storageKey = 'hm_notifications_v2';
  final ConnectionStore connection;
  late final StreamSubscription _sub;
  final List<NotificationItem> _items = [];
  final Set<String> _seenKeys = {};
  late final Future<void> initialized;
  Future<void> _persistTail = Future.value();

  NotificationStore({required this.connection}) {
    _sub = connection.routedEvents.listen(_onEvent);
    initialized = _load();
  }

  List<NotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  void addExternal({
    required String key,
    required NotificationKind kind,
    required String title,
    required String message,
    String? sessionId,
    String? connectionId,
    String? profile,
    String? requestId,
    String? target,
  }) => _add(
    kind: kind,
    title: title,
    message: message,
    sessionId: sessionId,
    connectionId: connectionId,
    profile: profile,
    requestId: requestId,
    target: target,
    key: key,
  );

  void _onEvent(RoutedGatewayEvent routed) {
    final e = routed.event;
    final connectionId = routed.route.connectionId.value;
    switch (e.type) {
      case 'notification.show':
        _fromNotice(e, connectionId, routed.route.profile);
      case 'notification.clear':
        final key = e.payload['key']?.toString();
        if (key != null && key.isNotEmpty) {
          _removeGatewayKey(connectionId, key);
        }
      case 'background.complete':
        _add(
          kind: NotificationKind.success,
          title: runtimeL10n.notificationBackgroundCompleted,
          message: runtimeL10n.notificationBackgroundCompletedBody,
          sessionId: e.sessionId,
          connectionId: connectionId,
          profile: e.profile ?? routed.route.profile,
          key: _gatewayKey(
            connectionId,
            'background.complete:${e.sessionId ?? e.payload['id'] ?? DateTime.now().millisecondsSinceEpoch}',
          ),
        );
      case 'approval.request':
        final payload = e.payload;
        final title = payload['title']?.toString();
        _add(
          kind: NotificationKind.approval,
          title: title ?? runtimeL10n.notificationApprovalRequired,
          message: runtimeL10n.notificationApprovalRequiredBody,
          sessionId: e.sessionId,
          connectionId: connectionId,
          profile: e.profile ?? routed.route.profile,
          requestId: payload['request_id']?.toString(),
          key: _gatewayKey(
            connectionId,
            'approval.request:${payload['request_id'] ?? e.sessionId ?? DateTime.now().millisecondsSinceEpoch}',
          ),
        );
    }
  }

  /// `notification.show` payload: {text, level, kind, ttl_ms, key, id}.
  void _fromNotice(GatewayEvent e, String connectionId, String? routeProfile) {
    final p = e.payload;
    final text = (p['text']?.toString() ?? '').replaceFirst(
      RegExp(r'^[•⚠✕✗✓]\uFE0F?\s*'),
      '',
    );
    if (text.isEmpty) return;
    final level = p['level']?.toString() ?? 'info';
    final kind = switch (level) {
      'error' => NotificationKind.error,
      'warn' => NotificationKind.warning,
      'success' => NotificationKind.success,
      _ => NotificationKind.info,
    };
    // The policy prefixes a short label before the message ("Credits: …").
    final sep = text.indexOf(': ');
    final title =
        p['title']?.toString() ?? (sep > 0 ? text.substring(0, sep) : 'Hermes');
    final message = sep > 0 ? text.substring(sep + 2) : text;
    _add(
      kind: kind,
      title: title,
      message: message,
      sessionId: e.sessionId,
      connectionId: connectionId,
      profile: e.profile ?? routeProfile,
      key: _gatewayKey(
        connectionId,
        p['key']?.toString() ?? 'notification.show',
      ),
    );
  }

  String _gatewayKey(String connectionId, String key) =>
      '$connectionId\u0000$key';

  void _removeGatewayKey(String connectionId, String key) {
    final scoped = _gatewayKey(connectionId, key);
    final removed = _items
        .where(
          (item) =>
              item.id == scoped ||
              (item.id == key && item.connectionId == connectionId),
        )
        .map((item) => item.id)
        .toSet();
    if (removed.isEmpty) return;
    _items.removeWhere((item) => removed.contains(item.id));
    _seenKeys.removeAll(removed);
    notifyListeners();
    unawaited(_persist());
  }

  void _add({
    required NotificationKind kind,
    required String title,
    required String message,
    String? sessionId,
    String? connectionId,
    String? profile,
    String? requestId,
    String? target,
    required String key,
  }) {
    // Dedupe: a repeated key replaces the earlier entry instead of stacking.
    if (_seenKeys.contains(key)) {
      final idx = _items.indexWhere((n) => n.id == key);
      if (idx >= 0) {
        final existing = _items[idx];
        _items.removeAt(idx);
        _items.insert(
          0,
          NotificationItem(
            id: key,
            kind: kind,
            title: title,
            message: message,
            sessionId: sessionId ?? existing.sessionId,
            connectionId:
                connectionId ??
                existing.connectionId ??
                connection.activeConnectionId.value,
            profile: profile ?? existing.profile,
            requestId: requestId ?? existing.requestId,
            target: target ?? existing.target,
            time: DateTime.now(),
            read: false,
            systemShown: false,
          ),
        );
        notifyListeners();
        unawaited(_persist());
        return;
      }
    }
    _seenKeys.add(key);
    _items.insert(
      0,
      NotificationItem(
        id: key,
        kind: kind,
        title: title,
        message: message,
        sessionId: sessionId,
        connectionId: connectionId ?? connection.activeConnectionId.value,
        profile: profile,
        requestId: requestId,
        time: DateTime.now(),
      ),
    );
    if (_items.length > 100) _items.removeLast();
    notifyListeners();
    unawaited(_persist());
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0 || _items[idx].read) return;
    _items[idx].read = true;
    notifyListeners();
    unawaited(_persist());
  }

  void markSystemShown(String id) {
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx < 0 || _items[idx].systemShown) return;
    _items[idx].systemShown = true;
    notifyListeners();
    unawaited(_persist());
  }

  void markAllRead() {
    var changed = false;
    for (final n in _items) {
      if (!n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      unawaited(_persist());
    }
  }

  void remove(String id) {
    _items.removeWhere((n) => n.id == id);
    _seenKeys.remove(id);
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    _seenKeys.clear();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = decoded
          .whereType<Map>()
          .map((row) => NotificationItem.fromJson(row.cast<String, dynamic>()))
          .where((item) => item.id.isNotEmpty)
          .toList();
      final liveIds = _items.map((item) => item.id).toSet();
      for (final item in loaded) {
        if (liveIds.add(item.id)) _items.add(item);
      }
      _items.sort((a, b) => b.time.compareTo(a.time));
      if (_items.length > 100) _items.removeRange(100, _items.length);
      _seenKeys.addAll(_items.map((item) => item.id));
      notifyListeners();
    } catch (_) {
      // Corrupt local state must not prevent the notification stream starting.
    }
  }

  Future<void> _persist() async {
    final snapshot = jsonEncode(_items.map((item) => item.toJson()).toList());
    final write = _persistTail.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, snapshot);
      } catch (_) {
        // Notification persistence is best-effort.
      }
    });
    _persistTail = write;
    await write;
  }

  Future<void> flushPersistence() => _persistTail;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
