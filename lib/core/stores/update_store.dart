library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../update_manifest_crypto.dart';
import '../update_manifest_schema.dart';
import '../../l10n/runtime_l10n.dart';

export '../update_manifest_crypto.dart'
    show canonicalJson, verifyUpdateManifestEnvelope;
export '../update_manifest_schema.dart' show compareAppVersions;

const _defaultManifestUrl = String.fromEnvironment(
  'HERMES_MOBILE_UPDATE_MANIFEST_URL',
  defaultValue:
      'https://github.com/NousResearch/hermes-agent/releases/download/mobile-channel/hermes-mobile-update.json',
);
const _defaultManifestPublicKey = String.fromEnvironment(
  'HERMES_MOBILE_UPDATE_PUBLIC_KEY',
);
const _defaultReleaseUrl =
    'https://github.com/NousResearch/hermes-agent/releases';

class MobileUpdateManifest {
  final String latestVersion;
  final String minimumSupportedVersion;
  final int? minimumBuild;
  final String updateUrl;
  final String releaseNotesUrl;
  final String? message;

  const MobileUpdateManifest({
    required this.latestVersion,
    required this.minimumSupportedVersion,
    this.minimumBuild,
    required this.updateUrl,
    required this.releaseNotesUrl,
    this.message,
  });

  factory MobileUpdateManifest.fromJson(
    Map<String, dynamic> json, {
    required TargetPlatform platform,
  }) {
    final platformKey = platform == TargetPlatform.iOS ? 'ios' : 'android';
    final platformConfig = json[platformKey] is Map
        ? (json[platformKey] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final updateUrl =
        (platformConfig['url'] ?? json['update_url'] ?? _defaultReleaseUrl)
            .toString()
            .trim();
    final releaseNotesUrl =
        (json['release_notes_url'] ?? json['release_url'] ?? _defaultReleaseUrl)
            .toString()
            .trim();
    _requireHttpsUrl(updateUrl, field: '$platformKey.url');
    _requireHttpsUrl(releaseNotesUrl, field: 'release_notes_url');
    return MobileUpdateManifest(
      latestVersion: (json['latest_version'] ?? json['latest'] ?? '')
          .toString()
          .trim(),
      minimumSupportedVersion:
          (json['minimum_supported_version'] ?? json['minimum'] ?? '0.0.0')
              .toString()
              .trim(),
      minimumBuild:
          (platformConfig['minimum_build'] ?? json['minimum_build'] as num?)
              ?.toInt(),
      updateUrl: updateUrl,
      releaseNotesUrl: releaseNotesUrl,
      message: json['message']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'latest_version': latestVersion,
    'minimum_supported_version': minimumSupportedVersion,
    'minimum_build': minimumBuild,
    'update_url': updateUrl,
    'release_notes_url': releaseNotesUrl,
    'message': message,
  };
}

Uri _requireHttpsUrl(String value, {required String field}) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw FormatException('$field must be an HTTPS URL');
  }
  return uri;
}

class UpdateStore extends ChangeNotifier {
  static const _manifestKey = 'hm_update_manifest_v1';
  static const _lastCheckKey = 'hm_update_last_check_v1';
  static const automaticInterval = Duration(hours: 24);

  factory UpdateStore({
    http.Client? client,
    Uri? manifestUri,
    String? currentVersion,
    String? currentBuild,
    TargetPlatform? platform,
    String manifestPublicKey = _defaultManifestPublicKey,
    bool? allowUnsignedManifest,
  }) => UpdateStore._(
    client ?? http.Client(),
    manifestUri ?? Uri.parse(_defaultManifestUrl),
    currentVersion,
    currentBuild,
    platform ?? defaultTargetPlatform,
    manifestPublicKey,
    allowUnsignedManifest ?? !kReleaseMode,
  );

  UpdateStore._(
    this._client,
    this.manifestUri,
    this._currentVersion,
    this._currentBuild,
    this.platform,
    this.manifestPublicKey,
    this.allowUnsignedManifest,
  );

  final http.Client _client;
  final Uri manifestUri;
  final TargetPlatform platform;
  final String manifestPublicKey;
  final bool allowUnsignedManifest;
  String? _currentVersion;
  String? _currentBuild;
  MobileUpdateManifest? _manifest;
  bool _checking = false;
  String? _error;

  String get currentVersion => _currentVersion ?? '0.0.0';
  String get currentBuild => _currentBuild ?? '0';
  MobileUpdateManifest? get manifest => _manifest;
  bool get checking => _checking;
  String? get error => _error;

  bool get updateAvailable =>
      _manifest != null &&
      compareAppVersions(currentVersion, _manifest!.latestVersion) < 0;
  bool get requiresUpdate {
    final value = _manifest;
    if (value == null) return false;
    final versionOrder = compareAppVersions(
      currentVersion,
      value.minimumSupportedVersion,
    );
    if (versionOrder < 0) return true;
    if (versionOrder > 0 || value.minimumBuild == null) return false;
    return (int.tryParse(currentBuild) ?? 0) < value.minimumBuild!;
  }

  Uri get updateUri =>
      Uri.tryParse(_manifest?.updateUrl ?? '') ?? Uri.parse(_defaultReleaseUrl);
  Uri get releaseNotesUri =>
      Uri.tryParse(_manifest?.releaseNotesUrl ?? '') ??
      Uri.parse(_defaultReleaseUrl);

  Future<void> initialize() async {
    if (_currentVersion == null || _currentBuild == null) {
      try {
        final package = await PackageInfo.fromPlatform();
        _currentVersion = package.version;
        _currentBuild = package.buildNumber;
      } catch (_) {
        _currentVersion ??= '0.0.0';
        _currentBuild ??= '0';
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_manifestKey);
    if (cached != null) {
      try {
        final decoded = (jsonDecode(cached) as Map).cast<String, dynamic>();
        final payload = await verifyUpdateManifestEnvelope(
          decoded,
          publicKey: manifestPublicKey,
          allowUnsigned: allowUnsignedManifest,
        );
        if (decoded.containsKey('signed')) {
          validateUpdateManifestPayload(payload);
        }
        _manifest = MobileUpdateManifest.fromJson(payload, platform: platform);
      } catch (_) {
        _manifest = null;
      }
    }
    notifyListeners();
    final checkedAt = DateTime.tryParse(prefs.getString(_lastCheckKey) ?? '');
    if (checkedAt == null ||
        DateTime.now().difference(checkedAt) >= automaticInterval) {
      unawaited(check());
    }
  }

  Future<bool> check({bool force = false}) async {
    if (_checking) return false;
    // Set the guard before any `await` so two near-simultaneous callers
    // (e.g. the automatic startup check racing a manual "check for
    // updates" tap) can't both slip past the `_checking` check while the
    // first call is still suspended on the awaits below.
    _checking = true;
    _error = null;
    notifyListeners();
    try {
      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        final checkedAt = DateTime.tryParse(
          prefs.getString(_lastCheckKey) ?? '',
        );
        if (checkedAt != null &&
            DateTime.now().difference(checkedAt) < automaticInterval) {
          return _manifest != null;
        }
      }
      final response = await _client
          .get(manifestUri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw StateError(runtimeL10n.updateHttpError(response.statusCode));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const FormatException('manifest must be an object');
      }
      final envelope = decoded.cast<String, dynamic>();
      final payload = await verifyUpdateManifestEnvelope(
        envelope,
        publicKey: manifestPublicKey,
        allowUnsigned: allowUnsignedManifest,
      );
      if (envelope.containsKey('signed')) {
        validateUpdateManifestPayload(payload);
      }
      final next = MobileUpdateManifest.fromJson(payload, platform: platform);
      if (!RegExp(
        r'^v?\d+(?:\.\d+){1,3}(?:[-+].*)?$',
      ).hasMatch(next.latestVersion)) {
        throw const FormatException('invalid latest version');
      }
      if (!RegExp(
        r'^v?\d+(?:\.\d+){1,3}(?:[-+].*)?$',
      ).hasMatch(next.minimumSupportedVersion)) {
        throw const FormatException('invalid minimum supported version');
      }
      if (compareAppVersions(next.minimumSupportedVersion, next.latestVersion) >
          0) {
        throw const FormatException(
          'minimum supported version cannot exceed latest version',
        );
      }
      _manifest = next;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_manifestKey, jsonEncode(envelope));
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
      return true;
    } catch (error) {
      _error = error.toString();
      return false;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
