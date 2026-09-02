/// Shared cross-screen "which profile's config am I viewing/editing" scope
/// override — desktop parity for `SettingsProfileScope`
/// (apps/desktop/src/store/settings-scope.ts) and the Capabilities scope
/// selector (apps/desktop/src/app/skills/index.tsx).
///
/// `override == null` means "follow the active profile" — the same ambient
/// default every profile-aware `ApiClient` call already falls back to when
/// its own `profile:` argument is omitted. A non-null value pins every
/// scope-aware screen (Model/对话, Providers, MCP, Skills, Toolsets) to that
/// profile until cleared or the active connection changes, without touching
/// which profile is actually active for the running session.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api_client.dart';
import '../models.dart';

class ProfileScopeStore extends ChangeNotifier {
  ApiClient? _api;
  String? _override;
  List<ProfileInfo> _profiles = const [];
  String? _activeProfile;
  bool _loaded = false;
  Future<void>? _inflight;
  int _generation = 0;
  int _updateGeneration = 0;
  Timer? _refreshTimer;
  bool _autoRefreshEnabled = false;
  bool _foreground = true;
  FutureOr<void> Function(ProfilesPayload payload, ApiClient api)?
  _backendSnapshotSink;

  /// The user-picked override, or null to follow the active profile.
  String? get override => _override;
  List<ProfileInfo> get profiles => _profiles;
  String? get activeProfile => _activeProfile;
  bool get loaded => _loaded;

  void bindApi(ApiClient? api) {
    if (identical(_api, api)) return;
    _api = api;
    _generation++;
    _updateGeneration++;
    _override = null;
    _profiles = const [];
    _activeProfile = null;
    _loaded = false;
    _inflight = null;
    _restartRefreshTimer();
    notifyListeners();
  }

  void startAutoRefresh() {
    if (_autoRefreshEnabled) return;
    _autoRefreshEnabled = true;
    _restartRefreshTimer();
  }

  void bindBackendSnapshotSink(
    FutureOr<void> Function(ProfilesPayload payload, ApiClient api)? sink,
  ) {
    _backendSnapshotSink = sink;
  }

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = !_autoRefreshEnabled || _api == null || !_foreground
        ? null
        : Timer.periodic(
            const Duration(seconds: 30),
            (_) => unawaited(refresh()),
          );
  }

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _restartRefreshTimer();
    if (value && _api != null) unawaited(refresh());
  }

  void setOverride(String? profile) {
    if (_override == profile) return;
    _override = profile;
    notifyListeners();
  }

  /// Adopts a `ProfilesPayload` a screen already fetched itself, so other
  /// scope-aware screens get a populated profile list for free instead of
  /// each independently re-fetching it.
  Future<void> updateProfiles(ProfilesPayload payload) async {
    final api = _api;
    final sink = _backendSnapshotSink;
    final generation = _generation;
    final updateGeneration = ++_updateGeneration;
    if (api != null && sink != null) {
      await sink(payload, api);
    }
    if (generation != _generation ||
        updateGeneration != _updateGeneration ||
        !identical(api, _api)) {
      return;
    }
    updateSnapshot(payload.profiles, payload.active, markLoaded: true);
  }

  void syncFromSession(List<ProfileInfo> profiles, String? active) {
    final changed =
        active != _activeProfile ||
        profiles.length != _profiles.length ||
        List.generate(
          profiles.length,
          (index) =>
              profiles[index].name != _profiles[index].name ||
              profiles[index].isActive != _profiles[index].isActive,
        ).any((different) => different);
    if (changed) {
      _generation++;
      _updateGeneration++;
      _inflight = null;
    }
    updateSnapshot(profiles, active);
  }

  void updateSnapshot(
    List<ProfileInfo> profiles,
    String? active, {
    bool markLoaded = false,
  }) {
    if (profiles.isEmpty && active == null && !markLoaded) return;
    final unchanged =
        active == _activeProfile &&
        profiles.length == _profiles.length &&
        List.generate(
          profiles.length,
          (index) =>
              profiles[index].name == _profiles[index].name &&
              profiles[index].isActive == _profiles[index].isActive,
        ).every((same) => same);
    if (unchanged && (!markLoaded || _loaded)) return;
    _profiles = List.unmodifiable(profiles);
    _activeProfile = active;
    _loaded = markLoaded || profiles.isNotEmpty || active != null;
    if (_override != null &&
        !profiles.any((profile) => profile.name == _override)) {
      _override = null;
    }
    notifyListeners();
  }

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return refresh();
  }

  Future<void> refresh() {
    final api = _api;
    if (api == null) return Future.value();
    final existing = _inflight;
    if (existing != null) return existing;
    final future = _refresh(api, _generation);
    _inflight = future;
    return future;
  }

  Future<void> _refresh(ApiClient api, int generation) async {
    try {
      final payload = await api.listProfiles();
      if (generation != _generation || !identical(api, _api)) return;
      updateSnapshot(payload.profiles, payload.active, markLoaded: true);
      await _backendSnapshotSink?.call(payload, api);
    } catch (_) {
      // Best-effort — dependent screens simply fall back to the ambient
      // active profile until a retry succeeds.
    } finally {
      if (generation == _generation && identical(api, _api)) {
        _inflight = null;
      }
    }
  }

  // ignore: annotate_overrides
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
