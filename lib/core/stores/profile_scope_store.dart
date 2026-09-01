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

  /// The user-picked override, or null to follow the active profile.
  String? get override => _override;
  List<ProfileInfo> get profiles => _profiles;
  String? get activeProfile => _activeProfile;
  bool get loaded => _loaded;

  void bindApi(ApiClient? api) {
    if (identical(_api, api)) return;
    _api = api;
    _generation++;
    _override = null;
    _profiles = const [];
    _activeProfile = null;
    _loaded = false;
    _inflight = null;
    notifyListeners();
  }

  void setOverride(String? profile) {
    if (_override == profile) return;
    _override = profile;
    notifyListeners();
  }

  /// Adopts a `ProfilesPayload` a screen already fetched itself, so other
  /// scope-aware screens get a populated profile list for free instead of
  /// each independently re-fetching it.
  void updateProfiles(ProfilesPayload payload) {
    _profiles = payload.profiles;
    _activeProfile = payload.active;
    _loaded = true;
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
      _profiles = payload.profiles;
      _activeProfile = payload.active;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Best-effort — dependent screens simply fall back to the ambient
      // active profile until a retry succeeds.
    } finally {
      if (generation == _generation && identical(api, _api)) {
        _inflight = null;
      }
    }
  }
}
