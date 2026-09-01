/// Persisted connection settings and credential storage.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _headerNamePattern = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");

bool isValidConnectionHeaderName(String name) {
  final value = name.trim();
  return value.isNotEmpty && _headerNamePattern.hasMatch(value);
}

bool isReservedConnectionHeaderName(String name) =>
    _reservedConnectionHeaders.contains(name.trim().toLowerCase());

enum ConnectionKind { remote, cloud, ssh }

enum ConnectionTransport { companion, directGateway, sshTunnel }

enum ConnectionAuthMode { token, oauth }

enum CleartextTransportPolicy { unrestricted, localHosts, namedLocalHosts }

CleartextTransportPolicy get currentCleartextTransportPolicy {
  if (!kReleaseMode) return CleartextTransportPolicy.unrestricted;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => CleartextTransportPolicy.namedLocalHosts,
    TargetPlatform.iOS => CleartextTransportPolicy.localHosts,
    _ => CleartextTransportPolicy.unrestricted,
  };
}

bool isLocalConnectionHost(String host) {
  final value = host.trim().toLowerCase();
  if (value == 'localhost' || value == '::1' || value.endsWith('.local')) {
    return true;
  }
  final parts = value.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((part) => part == null || part < 0 || part > 255)) {
    return false;
  }
  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      first == 127 ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}

bool nativeCleartextHostSupported(
  String host, {
  CleartextTransportPolicy? policy,
}) {
  final effective = policy ?? currentCleartextTransportPolicy;
  if (effective == CleartextTransportPolicy.unrestricted) return true;
  if (effective == CleartextTransportPolicy.localHosts) {
    return isLocalConnectionHost(host);
  }
  final value = host.trim().toLowerCase();
  return value == 'localhost' ||
      value == '127.0.0.1' ||
      value == '10.0.2.2' ||
      value.endsWith('.local');
}

bool connectionTransportAllowed(
  String rawUrl, {
  bool allowInsecure = false,
  CleartextTransportPolicy? policy,
}) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || uri.host.isEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return true;
  if (scheme != 'http') return false;
  final effective = policy ?? currentCleartextTransportPolicy;
  if (effective == CleartextTransportPolicy.unrestricted) {
    return isLocalConnectionHost(uri.host) || allowInsecure;
  }
  return nativeCleartextHostSupported(uri.host, policy: effective);
}

T _enumValue<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}

class ConnectionSettings {
  final String serverUrl;
  final String apiKey;
  final ConnectionKind kind;
  final ConnectionTransport transport;
  final ConnectionAuthMode authMode;
  final String label;
  final String org;
  final String refreshToken;
  final String oauthProvider;
  final String oauthUserId;
  final int oauthExpiresAt;
  final bool allowInsecureTransport;
  final String sshHost;
  final String sshUser;
  final int sshPort;
  final String sshPrivateKey;
  final String sshPrivateKeyPassphrase;
  final String sshPassword;
  final String sshRemoteHermesPath;
  final String sshRemoteProfile;

  /// Extra headers used by REST and native WebSocket requests. This supports
  /// access proxies without letting callers replace Hermes' own auth headers.
  final Map<String, String> headers;

  const ConnectionSettings({
    this.serverUrl = '',
    this.apiKey = '',
    this.headers = const {},
    this.kind = ConnectionKind.remote,
    this.transport = ConnectionTransport.companion,
    this.authMode = ConnectionAuthMode.token,
    this.label = '',
    this.org = '',
    this.refreshToken = '',
    this.oauthProvider = '',
    this.oauthUserId = '',
    this.oauthExpiresAt = 0,
    this.allowInsecureTransport = false,
    this.sshHost = '',
    this.sshUser = '',
    this.sshPort = 22,
    this.sshPrivateKey = '',
    this.sshPrivateKeyPassphrase = '',
    this.sshPassword = '',
    this.sshRemoteHermesPath = '',
    this.sshRemoteProfile = '',
  });

  bool get isConfigured => transport == ConnectionTransport.sshTunnel
      ? sshHost.trim().isNotEmpty && sshUser.trim().isNotEmpty
      : serverUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  String get baseUrl => serverUrl.trim().replaceAll(RegExp(r'/+$'), '');

  Map<String, String> get normalizedHeaders {
    final result = <String, String>{};
    for (final entry in headers.entries) {
      final name = entry.key.trim();
      final value = entry.value.trim();
      if (!isValidConnectionHeaderName(name) || value.isEmpty) continue;
      final lower = name.toLowerCase();
      if (isReservedConnectionHeaderName(lower)) continue;
      result[name] = value;
    }
    return Map.unmodifiable(result);
  }

  bool hasSameIdentity(ConnectionSettings other) =>
      baseUrl == other.baseUrl &&
      kind == other.kind &&
      transport == other.transport &&
      authMode == other.authMode &&
      allowInsecureTransport == other.allowInsecureTransport &&
      (transport == ConnectionTransport.sshTunnel
          ? sshHost == other.sshHost &&
                sshUser == other.sshUser &&
                sshPort == other.sshPort &&
                sshRemoteProfile == other.sshRemoteProfile
          : authMode == ConnectionAuthMode.oauth
          ? oauthProvider == other.oauthProvider &&
                oauthUserId == other.oauthUserId
          : apiKey == other.apiKey) &&
      _mapsEqual(normalizedHeaders, other.normalizedHeaders);

  ConnectionSettings copyWith({
    String? serverUrl,
    String? apiKey,
    Map<String, String>? headers,
    ConnectionKind? kind,
    ConnectionTransport? transport,
    ConnectionAuthMode? authMode,
    String? label,
    String? org,
    String? refreshToken,
    String? oauthProvider,
    String? oauthUserId,
    int? oauthExpiresAt,
    bool? allowInsecureTransport,
    String? sshHost,
    String? sshUser,
    int? sshPort,
    String? sshPrivateKey,
    String? sshPrivateKeyPassphrase,
    String? sshPassword,
    String? sshRemoteHermesPath,
    String? sshRemoteProfile,
  }) => ConnectionSettings(
    serverUrl: serverUrl ?? this.serverUrl,
    apiKey: apiKey ?? this.apiKey,
    headers: headers ?? this.headers,
    kind: kind ?? this.kind,
    transport: transport ?? this.transport,
    authMode: authMode ?? this.authMode,
    label: label ?? this.label,
    org: org ?? this.org,
    refreshToken: refreshToken ?? this.refreshToken,
    oauthProvider: oauthProvider ?? this.oauthProvider,
    oauthUserId: oauthUserId ?? this.oauthUserId,
    oauthExpiresAt: oauthExpiresAt ?? this.oauthExpiresAt,
    allowInsecureTransport:
        allowInsecureTransport ?? this.allowInsecureTransport,
    sshHost: sshHost ?? this.sshHost,
    sshUser: sshUser ?? this.sshUser,
    sshPort: sshPort ?? this.sshPort,
    sshPrivateKey: sshPrivateKey ?? this.sshPrivateKey,
    sshPrivateKeyPassphrase:
        sshPrivateKeyPassphrase ?? this.sshPrivateKeyPassphrase,
    sshPassword: sshPassword ?? this.sshPassword,
    sshRemoteHermesPath: sshRemoteHermesPath ?? this.sshRemoteHermesPath,
    sshRemoteProfile: sshRemoteProfile ?? this.sshRemoteProfile,
  );

  /// Runtime serialization. Persistence must use [toMetadataJson].
  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'apiKey': apiKey,
    'headers': normalizedHeaders,
    'kind': kind.name,
    'transport': transport.name,
    'authMode': authMode.name,
    'label': label,
    'org': org,
    'refreshToken': refreshToken,
    'oauthProvider': oauthProvider,
    'oauthUserId': oauthUserId,
    'oauthExpiresAt': oauthExpiresAt,
    'allowInsecureTransport': allowInsecureTransport,
    'sshHost': sshHost,
    'sshUser': sshUser,
    'sshPort': sshPort,
    'sshPrivateKey': sshPrivateKey,
    'sshPrivateKeyPassphrase': sshPrivateKeyPassphrase,
    'sshPassword': sshPassword,
    'sshRemoteHermesPath': sshRemoteHermesPath,
    'sshRemoteProfile': sshRemoteProfile,
  };

  Map<String, dynamic> toMetadataJson() => {
    'serverUrl': serverUrl,
    'apiKeySet': apiKey.trim().isNotEmpty,
    'headerNames': normalizedHeaders.keys.toList()..sort(),
    'kind': kind.name,
    'transport': transport.name,
    'authMode': authMode.name,
    if (label.trim().isNotEmpty) 'label': label.trim(),
    if (org.trim().isNotEmpty) 'org': org.trim(),
    if (oauthProvider.trim().isNotEmpty) 'oauthProvider': oauthProvider.trim(),
    if (oauthUserId.trim().isNotEmpty) 'oauthUserId': oauthUserId.trim(),
    if (oauthExpiresAt > 0) 'oauthExpiresAt': oauthExpiresAt,
    if (allowInsecureTransport) 'allowInsecureTransport': true,
    if (sshHost.trim().isNotEmpty) 'sshHost': sshHost.trim(),
    if (sshUser.trim().isNotEmpty) 'sshUser': sshUser.trim(),
    if (sshPort != 22) 'sshPort': sshPort,
    if (sshRemoteHermesPath.trim().isNotEmpty)
      'sshRemoteHermesPath': sshRemoteHermesPath.trim(),
    if (sshRemoteProfile.trim().isNotEmpty)
      'sshRemoteProfile': sshRemoteProfile.trim(),
  };

  factory ConnectionSettings.fromJson(Map<String, dynamic> json) =>
      ConnectionSettings(
        serverUrl: json['serverUrl'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        headers:
            (json['headers'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
        kind: _enumValue(
          ConnectionKind.values,
          json['kind'],
          ConnectionKind.remote,
        ),
        transport: _enumValue(
          ConnectionTransport.values,
          json['transport'],
          ConnectionTransport.companion,
        ),
        authMode: _enumValue(
          ConnectionAuthMode.values,
          json['authMode'],
          ConnectionAuthMode.token,
        ),
        label: json['label']?.toString() ?? '',
        org: json['org']?.toString() ?? '',
        refreshToken: json['refreshToken']?.toString() ?? '',
        oauthProvider: json['oauthProvider']?.toString() ?? '',
        oauthUserId: json['oauthUserId']?.toString() ?? '',
        oauthExpiresAt: (json['oauthExpiresAt'] as num?)?.toInt() ?? 0,
        allowInsecureTransport: json['allowInsecureTransport'] == true,
        sshHost: json['sshHost']?.toString() ?? '',
        sshUser: json['sshUser']?.toString() ?? '',
        sshPort: (json['sshPort'] as num?)?.toInt() ?? 22,
        sshPrivateKey: json['sshPrivateKey']?.toString() ?? '',
        sshPrivateKeyPassphrase:
            json['sshPrivateKeyPassphrase']?.toString() ?? '',
        sshPassword: json['sshPassword']?.toString() ?? '',
        sshRemoteHermesPath: json['sshRemoteHermesPath']?.toString() ?? '',
        sshRemoteProfile: json['sshRemoteProfile']?.toString() ?? '',
      );
}

const _reservedConnectionHeaders = {
  'authorization',
  'connection',
  'content-length',
  'content-type',
  'cookie',
  'host',
  'origin',
  'referer',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'x-hermes-session-token',
};

bool _mapsEqual(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

abstract class ConnectionSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// OS-backed credential store. The memory fallback only keeps tests and
/// unsupported embedders usable; it never writes secrets to ordinary prefs.
class PlatformConnectionSecretStore implements ConnectionSecretStore {
  final FlutterSecureStorage _storage;
  final Map<String, String> _fallback = {};

  PlatformConnectionSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key) ?? _fallback[key];
    } on MissingPluginException {
      return _fallback[key];
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _fallback[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      // No insecure persistence fallback.
    }
  }

  @override
  Future<void> delete(String key) async {
    _fallback.remove(key);
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      // The in-memory copy is already gone.
    }
  }
}

class SettingsStore {
  static const _key = 'hermes_mobile_connection';
  static const _profilesKey = 'hermes_mobile_server_profiles';
  static const _activeProfileKey = 'hermes_mobile_active_profile';
  static const _primarySecretKey = 'hermes.connection.primary.credentials.v1';

  final ConnectionSecretStore secrets;

  SettingsStore({ConnectionSecretStore? secrets})
    : secrets = secrets ?? PlatformConnectionSecretStore();

  Future<ConnectionSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const ConnectionSettings();
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final metadata = ConnectionSettings.fromJson(json);
      final legacyHasSecrets =
          metadata.apiKey.isNotEmpty ||
          metadata.refreshToken.isNotEmpty ||
          metadata.normalizedHeaders.isNotEmpty ||
          metadata.sshPrivateKey.isNotEmpty ||
          metadata.sshPrivateKeyPassphrase.isNotEmpty ||
          metadata.sshPassword.isNotEmpty;
      final stored = legacyHasSecrets
          ? const ConnectionSettings()
          : await _readSecret(_primarySecretKey);
      final settings = metadata.copyWith(
        apiKey: legacyHasSecrets ? metadata.apiKey : stored.apiKey,
        headers: legacyHasSecrets ? metadata.normalizedHeaders : stored.headers,
        refreshToken: legacyHasSecrets
            ? metadata.refreshToken
            : stored.refreshToken,
        sshPrivateKey: legacyHasSecrets
            ? metadata.sshPrivateKey
            : stored.sshPrivateKey,
        sshPrivateKeyPassphrase: legacyHasSecrets
            ? metadata.sshPrivateKeyPassphrase
            : stored.sshPrivateKeyPassphrase,
        sshPassword: legacyHasSecrets
            ? metadata.sshPassword
            : stored.sshPassword,
      );
      try {
        if (legacyHasSecrets) await _writeSecret(_primarySecretKey, settings);
        await prefs.setString(_key, jsonEncode(settings.toMetadataJson()));
      } catch (_) {
        // Keep readable legacy credentials until secure persistence succeeds.
      }
      return settings;
    } catch (_) {
      return const ConnectionSettings();
    }
  }

  Future<void> save(ConnectionSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeSecret(_primarySecretKey, settings);
    await prefs.setString(_key, jsonEncode(settings.toMetadataJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await secrets.delete(_primarySecretKey);
    await prefs.remove(_key);
  }

  Future<List<ServerProfile>> profiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final profiles = <ServerProfile>[];
      var migrationSafe = true;
      for (final item in list) {
        final json = (item as Map).cast<String, dynamic>();
        final name = (json['name'] ?? '').toString();
        if (name.trim().isEmpty) continue;
        final metadata = ConnectionSettings.fromJson(json);
        final legacyHasSecrets =
            metadata.apiKey.isNotEmpty ||
            metadata.refreshToken.isNotEmpty ||
            metadata.normalizedHeaders.isNotEmpty ||
            metadata.sshPrivateKey.isNotEmpty ||
            metadata.sshPrivateKeyPassphrase.isNotEmpty ||
            metadata.sshPassword.isNotEmpty;
        final stored = legacyHasSecrets
            ? const ConnectionSettings()
            : await _readSecret(_profileSecretKey(name));
        final settings = metadata.copyWith(
          apiKey: legacyHasSecrets ? metadata.apiKey : stored.apiKey,
          headers: legacyHasSecrets
              ? metadata.normalizedHeaders
              : stored.headers,
          refreshToken: legacyHasSecrets
              ? metadata.refreshToken
              : stored.refreshToken,
          sshPrivateKey: legacyHasSecrets
              ? metadata.sshPrivateKey
              : stored.sshPrivateKey,
          sshPrivateKeyPassphrase: legacyHasSecrets
              ? metadata.sshPrivateKeyPassphrase
              : stored.sshPrivateKeyPassphrase,
          sshPassword: legacyHasSecrets
              ? metadata.sshPassword
              : stored.sshPassword,
        );
        if (legacyHasSecrets) {
          try {
            await _writeSecret(_profileSecretKey(name), settings);
          } catch (_) {
            migrationSafe = false;
          }
        }
        profiles.add(ServerProfile(name: name, settings: settings));
      }
      if (migrationSafe) await _writeProfileMetadata(prefs, profiles);
      return profiles;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfile(String name, ConnectionSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await profiles();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final next = <ServerProfile>[
      for (final profile in existing)
        if (profile.name != trimmed) profile,
      ServerProfile(name: trimmed, settings: settings.copyWith()),
    ];
    await _writeSecret(_profileSecretKey(trimmed), settings);
    await _writeProfileMetadata(prefs, next);
  }

  Future<void> deleteProfile(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final next = (await profiles()).where((p) => p.name != name).toList();
    await secrets.delete(_profileSecretKey(name));
    await _writeProfileMetadata(prefs, next);
    final active = prefs.getString(_activeProfileKey);
    if (active == name) await prefs.remove(_activeProfileKey);
  }

  Future<void> activateProfile(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, name);
  }

  Future<String?> activeProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey);
  }

  Future<void> _writeProfileMetadata(
    SharedPreferences prefs,
    List<ServerProfile> profiles,
  ) async {
    await prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  Future<ConnectionSettings> _readSecret(String key) async {
    final raw = await secrets.read(key);
    if (raw == null || raw.isEmpty) return const ConnectionSettings();
    try {
      return ConnectionSettings.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return const ConnectionSettings();
    }
  }

  Future<void> _writeSecret(String key, ConnectionSettings settings) =>
      secrets.write(
        key,
        jsonEncode({
          'apiKey': settings.apiKey,
          'headers': settings.normalizedHeaders,
          'refreshToken': settings.refreshToken,
          'sshPrivateKey': settings.sshPrivateKey,
          'sshPrivateKeyPassphrase': settings.sshPrivateKeyPassphrase,
          'sshPassword': settings.sshPassword,
        }),
      );

  static String _profileSecretKey(String name) {
    final encoded = base64Url
        .encode(utf8.encode(name.trim()))
        .replaceAll('=', '');
    return 'hermes.connection.profile.$encoded.credentials.v1';
  }
}

class ServerProfile {
  final String name;
  final ConnectionSettings settings;

  const ServerProfile({required this.name, required this.settings});

  Map<String, dynamic> toJson() => {'name': name, ...settings.toMetadataJson()};

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
    name: (json['name'] ?? '').toString(),
    settings: ConnectionSettings.fromJson(json),
  );
}
