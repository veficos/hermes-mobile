/// NotificationsService: bridges [NotificationStore] items to system-level
/// notifications via `flutter_local_notifications` (Batch 8 of the desktop
/// migration). Mirrors the desktop renderer's `notification.show` → system
/// toast behaviour.
///
/// On platforms where the native plugin is unavailable the service degrades
/// gracefully — in-app notifications from [NotificationStore] still work, only
/// the system toast is skipped.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/runtime_l10n.dart';
import 'stores/notification_store.dart';

class NotificationTarget {
  final String notificationId;
  final String? sessionId;
  final String? connectionId;
  final String? profile;
  final String? requestId;
  final bool approval;

  const NotificationTarget({
    required this.notificationId,
    this.sessionId,
    this.connectionId,
    this.profile,
    this.requestId,
    this.approval = false,
  });

  factory NotificationTarget.fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const NotificationTarget(notificationId: '');
    }
    try {
      final json = jsonDecode(payload);
      if (json is Map) {
        return NotificationTarget.fromMap(json.cast<String, dynamic>());
      }
    } catch (_) {
      // Pre-structured payloads contained only the session id.
    }
    return NotificationTarget(notificationId: '', sessionId: payload);
  }

  factory NotificationTarget.fromMap(Map<String, dynamic> json) {
    // Push providers may wrap custom values in data/payload, and older
    // gateways used camelCase or stored_session_id. Normalize all supported
    // forms so foreground, background, and cold-start taps behave alike.
    final values = <String, dynamic>{...json};
    for (final key in const ['data', 'payload']) {
      final nested = json[key];
      if (nested is Map) {
        for (final entry in nested.entries) {
          values.putIfAbsent(entry.key.toString(), () => entry.value);
        }
      } else if (nested is String && nested.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(nested);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              values.putIfAbsent(entry.key.toString(), () => entry.value);
            }
          }
        } catch (_) {
          // Top-level fields may still contain a valid target.
        }
      }
    }
    Object? first(Iterable<String> keys) {
      for (final key in keys) {
        final value = values[key];
        if (_nonEmpty(value) != null) return value;
      }
      return null;
    }

    final eventType = _nonEmpty(first(const ['event_type', 'eventType']));
    final approvalValue = first(const [
      'approval',
      'is_approval',
      'isApproval',
    ]);
    return NotificationTarget(
      notificationId:
          _nonEmpty(first(const ['notification_id', 'notificationId'])) ?? '',
      sessionId: _nonEmpty(
        first(const [
          'session_id',
          'sessionId',
          'stored_session_id',
          'storedSessionId',
          'durable_session_id',
          'durableSessionId',
        ]),
      ),
      connectionId: _nonEmpty(first(const ['connection_id', 'connectionId'])),
      profile: _nonEmpty(first(const ['profile', 'profile_id', 'profileId'])),
      requestId: _nonEmpty(first(const ['request_id', 'requestId'])),
      approval:
          approvalValue == true ||
          approvalValue?.toString().toLowerCase() == 'true' ||
          eventType == 'approval.request',
    );
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String toPayload() => jsonEncode({
    'notification_id': notificationId,
    'session_id': sessionId,
    'connection_id': connectionId,
    'profile': profile,
    'request_id': requestId,
    'approval': approval,
  });
}

class NotificationsService {
  final NotificationStore store;

  NotificationsService({required this.store}) {
    store.addListener(_onStoreChanged);
    initialized = _init();
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 1;
  final Map<String, int> _keyToId = {};
  final Set<String> _showingIds = {};
  NotificationTarget? _pendingTarget;
  ValueChanged<NotificationTarget>? _onTapTarget;
  late final Future<void> initialized;

  set onTapTarget(ValueChanged<NotificationTarget>? callback) {
    _onTapTarget = callback;
    final pending = _pendingTarget;
    if (callback != null && pending != null) {
      _pendingTarget = null;
      callback(pending);
    }
  }

  Future<void> _init() async {
    // dart:io Platform is unavailable on Flutter web.
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      // Windows/Linux: the plugin has no native backend; skip silently.
      return;
    }
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    try {
      final ok = await _plugin.initialize(
        init,
        onDidReceiveNotificationResponse: _onTap,
      );
      _ready = ok == true;
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      await store.initialized;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _dispatchTarget(
          NotificationTarget.fromPayload(launch?.notificationResponse?.payload),
        );
      }
      _onStoreChanged();
    } catch (_) {
      _ready = false;
    }
  }

  void _onStoreChanged() {
    if (!_ready) return;
    for (final item in store.items) {
      if (item.read || item.systemShown || !_showingIds.add(item.id)) continue;
      unawaited(_deliver(item));
    }
  }

  Future<void> _deliver(NotificationItem item) async {
    try {
      if (await _show(item)) store.markSystemShown(item.id);
    } finally {
      _showingIds.remove(item.id);
    }
  }

  Future<bool> _show(NotificationItem item) async {
    if (!_ready) return false;
    final channelId = switch (item.kind) {
      NotificationKind.error => 'hermes-error',
      NotificationKind.warning => 'hermes-warning',
      NotificationKind.success => 'hermes-success',
      NotificationKind.approval => 'hermes-approval',
      NotificationKind.info => 'hermes-info',
    };
    final channelName = switch (item.kind) {
      NotificationKind.error => runtimeL10n.notificationChannelErrors,
      NotificationKind.warning => runtimeL10n.notificationChannelWarnings,
      NotificationKind.success => runtimeL10n.notificationChannelSuccess,
      NotificationKind.approval => runtimeL10n.notificationChannelApprovals,
      NotificationKind.info => runtimeL10n.notificationChannelInfo,
    };
    final importance = switch (item.kind) {
      NotificationKind.error || NotificationKind.approval => Importance.high,
      _ => Importance.defaultImportance,
    };
    final priority = switch (item.kind) {
      NotificationKind.error || NotificationKind.approval => Priority.high,
      _ => Priority.defaultPriority,
    };
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
    );
    const ios = DarwinNotificationDetails();
    try {
      final id = _keyToId.putIfAbsent(item.id, () => _nextId++);
      await _plugin.show(
        id,
        item.title,
        item.message,
        NotificationDetails(android: android, iOS: ios),
        payload: NotificationTarget(
          notificationId: item.id,
          sessionId: item.sessionId,
          connectionId: item.connectionId,
          profile: item.profile,
          requestId: item.requestId,
          approval: item.kind == NotificationKind.approval,
        ).toPayload(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onTap(NotificationResponse resp) {
    _dispatchTarget(NotificationTarget.fromPayload(resp.payload));
  }

  /// The real OS-level notification permission state, independent of any
  /// locally-persisted "enabled" preference or server registration status.
  /// Returns `null` when the platform has no meaningful permission concept
  /// (web/desktop) or the check itself failed.
  Future<bool?> osNotificationsEnabled() async {
    if (kIsWeb) return null;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled();
        case TargetPlatform.iOS:
          final options = await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions();
          return options?.isEnabled;
        case TargetPlatform.macOS:
          final options = await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions();
          return options?.isEnabled;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  void _dispatchTarget(NotificationTarget target) {
    final callback = _onTapTarget;
    if (callback == null) {
      _pendingTarget = target;
    } else {
      callback(target);
    }
  }

  void handleRemotePayload(
    Map<String, dynamic> payload, {
    required bool tapped,
  }) {
    final target = NotificationTarget.fromMap(payload);
    final eventType = payload['event_type']?.toString() ?? '';
    final title = payload['title']?.toString().trim();
    final body =
        (payload['body'] ?? payload['message'] ?? payload['text'])
            ?.toString()
            .trim() ??
        '';
    final kind = target.approval
        ? NotificationKind.approval
        : eventType == 'error'
        ? NotificationKind.error
        : eventType == 'message.complete' || eventType == 'background.complete'
        ? NotificationKind.success
        : NotificationKind.info;
    final key = target.notificationId.isNotEmpty
        ? target.notificationId
        : 'remote:${target.sessionId ?? eventType}:${body.hashCode}';
    store.addExternal(
      key: key,
      kind: kind,
      title: title?.isNotEmpty == true ? title! : 'Hermes',
      message: body,
      sessionId: target.sessionId,
      connectionId: target.connectionId,
      profile: target.profile,
      requestId: target.requestId,
    );
    if (tapped) _dispatchTarget(target);
  }

  void dispose() {
    _onTapTarget = null;
    store.removeListener(_onStoreChanged);
  }
}
