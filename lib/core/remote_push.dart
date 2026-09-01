library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'notifications_service.dart';
import 'settings_store.dart';
import 'stores/connection_store.dart';
import 'stores/locale_store.dart';
import 'stores/session_store.dart';

class RemotePushToken {
  final String platform;
  final String value;

  const RemotePushToken({required this.platform, required this.value});

  factory RemotePushToken.fromMap(Map<String, dynamic> map) => RemotePushToken(
    platform: map['platform']?.toString().trim().toLowerCase() ?? '',
    value: map['token']?.toString().trim() ?? '',
  );

  bool get isValid =>
      const {'android', 'ios'}.contains(platform) && value.length >= 16;
}

abstract class RemotePushPlatformAdapter {
  ValueChanged<RemotePushToken>? onToken;
  ValueChanged<Map<String, dynamic>>? onMessage;
  ValueChanged<Map<String, dynamic>>? onTap;

  Future<void> initialize();
  Future<RemotePushToken?> getToken();
  Future<void> deleteToken();
  void dispose();
}

class MethodChannelRemotePushPlatform implements RemotePushPlatformAdapter {
  static const _channel = MethodChannel('hermes.push');

  @override
  ValueChanged<RemotePushToken>? onToken;
  @override
  ValueChanged<Map<String, dynamic>>? onMessage;
  @override
  ValueChanged<Map<String, dynamic>>? onTap;

  @override
  Future<void> initialize() async {
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      final raw = call.arguments;
      final payload = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      switch (call.method) {
        case 'token':
          final token = RemotePushToken.fromMap(payload);
          if (token.isValid) onToken?.call(token);
        case 'message':
          onMessage?.call(payload);
        case 'tap':
          onTap?.call(payload);
      }
    });
  }

  @override
  Future<RemotePushToken?> getToken() async {
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getToken');
      if (raw == null) return null;
      final token = RemotePushToken.fromMap(raw);
      return token.isValid ? token : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('deleteToken');
    } on PlatformException {
      // Registration cleanup on the Hermes server remains authoritative.
    } on MissingPluginException {
      // Unsupported host platform.
    }
  }

  @override
  void dispose() {
    onToken = null;
    onMessage = null;
    onTap = null;
    _channel.setMethodCallHandler(null);
  }
}

class RemotePushService extends ChangeNotifier {
  static const _deviceIdKey = 'hm_push_device_id_v1';
  static const _enabledKey = 'hm_push_enabled_v1';

  final ConnectionStore connection;
  final SessionStore session;
  final LocaleStore locale;
  final NotificationsService notifications;
  final RemotePushPlatformAdapter platform;
  final Future<PackageInfo> Function() packageInfoLoader;

  RemotePushService({
    required this.connection,
    required this.session,
    required this.locale,
    required this.notifications,
    RemotePushPlatformAdapter? platform,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : platform = platform ?? MethodChannelRemotePushPlatform(),
       packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  String _deviceId = '';
  String _appVersion = '';
  RemotePushToken? _token;
  String? _lastFingerprint;
  bool _syncScheduled = false;
  bool _started = false;
  bool enabled = true;
  bool registered = false;
  String? lastError;
  List<String> configuredPlatforms = const [];
  int serverDeviceCount = 0;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    platform.onToken = _onToken;
    platform.onMessage = (payload) {
      notifications.handleRemotePayload(payload, tapped: false);
    };
    platform.onTap = (payload) {
      notifications.handleRemotePayload(payload, tapped: true);
    };
    connection
      ..addListener(_scheduleSync)
      ..addBeforeDisconnectHook(_unregisterBeforeDisconnect);
    session.addListener(_scheduleSync);
    locale.addListener(_scheduleSync);
    await platform.initialize();
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? true;
    _deviceId = prefs.getString(_deviceIdKey) ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = _newDeviceId();
      await prefs.setString(_deviceIdKey, _deviceId);
    }
    try {
      final info = await packageInfoLoader();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = '';
    }
    if (enabled) _token = await platform.getToken();
    await _sync();
    await refreshStatus();
  }

  void _onToken(RemotePushToken token) {
    if (!token.isValid) return;
    _token = token;
    _lastFingerprint = null;
    _scheduleSync();
    _notify();
  }

  void _scheduleSync() {
    if (_syncScheduled || !_started) return;
    _syncScheduled = true;
    scheduleMicrotask(() async {
      _syncScheduled = false;
      if (!_started) return;
      await _sync();
    });
  }

  Future<void> _sync() async {
    final token = _token;
    final api = connection.api;
    if (token == null ||
        !enabled ||
        _deviceId.isEmpty ||
        api == null ||
        connection.settings.transport != ConnectionTransport.companion) {
      registered = false;
      _notify();
      return;
    }
    final connectionId = connection.activeConnectionId.value;
    final profile = session.activeProfile ?? session.sessionListProfile;
    final registration = <String, dynamic>{
      'device_id': _deviceId,
      'platform': token.platform,
      'token': token.value,
      'connection_id': connectionId,
      'profile': profile,
      'locale': locale.tag == 'system'
          ? PlatformDispatcher.instance.locale.toLanguageTag()
          : locale.tag,
      'app_version': _appVersion,
    };
    final fingerprint = jsonEncode([api.baseUrl, registration]);
    if (_lastFingerprint == fingerprint) return;
    try {
      await api.registerPushDevice(registration);
      _lastFingerprint = fingerprint;
      registered = true;
      lastError = null;
      _notify();
    } catch (error) {
      registered = false;
      lastError = '$error';
      _notify();
    }
  }

  Future<void> _unregisterBeforeDisconnect(ApiClient api) async {
    if (_deviceId.isEmpty || api.directGateway) return;
    await api.unregisterPushDevice(_deviceId);
    if (identical(api, connection.api)) {
      _lastFingerprint = null;
      registered = false;
      _notify();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (enabled == value) return;
    enabled = value;
    _notify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) {
      await unregister();
      return;
    }
    _token ??= await platform.getToken();
    _lastFingerprint = null;
    await _sync();
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    final api = connection.api;
    if (api == null || api.directGateway) {
      configuredPlatforms = const [];
      serverDeviceCount = 0;
      _notify();
      return;
    }
    try {
      final status = await api.pushStatus();
      configuredPlatforms =
          (status['configured_platforms'] as List? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false);
      serverDeviceCount = (status['device_count'] as num?)?.toInt() ?? 0;
      lastError = null;
    } catch (error) {
      lastError = '$error';
    }
    _notify();
  }

  Future<Map<String, dynamic>> sendTest() async {
    final api = connection.api;
    if (api == null || api.directGateway || _deviceId.isEmpty) {
      throw StateError('Remote push is unavailable for this connection');
    }
    return api.testPushDevice(_deviceId);
  }

  Future<void> unregister({bool deletePlatformToken = false}) async {
    final api = connection.api;
    if (api != null && !api.directGateway && _deviceId.isNotEmpty) {
      try {
        await api.unregisterPushDevice(_deviceId);
      } catch (_) {
        // The server can also expire invalid tokens after a failed delivery.
      }
    }
    if (deletePlatformToken) {
      await platform.deleteToken();
      _token = null;
    }
    _lastFingerprint = null;
    registered = false;
    _notify();
  }

  String _newDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return 'mobile-${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  void _notify() {
    if (_started) notifyListeners();
  }

  @override
  void dispose() {
    _started = false;
    connection
      ..removeListener(_scheduleSync)
      ..removeBeforeDisconnectHook(_unregisterBeforeDisconnect);
    session.removeListener(_scheduleSync);
    locale.removeListener(_scheduleSync);
    platform.dispose();
    super.dispose();
  }
}
