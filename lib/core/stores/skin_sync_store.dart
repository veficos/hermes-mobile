/// Live-follows the backend's active `display.skin`, mirroring desktop's
/// `themes/backend-sync.ts`. Mobile's design system is a closed set of four
/// hand-tuned themes (graphite/indigo/moss/dune) rather than desktop's
/// arbitrary-palette converter — so unlike desktop, a custom skin's raw
/// colors are never derived into a new theme. Only a skin name that already
/// maps onto one of the four (directly, or through the same legacy-alias
/// table `AppearanceStore` migrates from) is ever applied.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../theme/hermes_tokens.dart';
import '../gateway.dart';
import 'appearance_store.dart';
import 'connection_store.dart';

class SkinSyncStore extends ChangeNotifier {
  SkinSyncStore({required this.connection, required AppearanceStore appearance})
    // The public named argument intentionally differs from the private field.
    // ignore: prefer_initializing_formals
    : _appearance = appearance {
    _sub = connection.events.listen(_onEvent);
  }

  final ConnectionStore connection;
  AppearanceStore _appearance;

  StreamSubscription<GatewayEvent>? _sub;

  // Last skin name synced from the backend + whether it was ever APPLIED (vs
  // merely seeded at connect). Once applied, only a name change re-applies —
  // no re-apply on a repeat event, no snap-back after a manual accent switch
  // in Appearance settings.
  String? _lastName;
  bool _lastApplied = false;

  void bind(AppearanceStore appearance) {
    _appearance = appearance;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(GatewayEvent e) {
    if (e.type == 'gateway.ready') {
      final skin = e.payload['skin'];
      if (skin is Map) {
        _ingest(skin['name']?.toString(), apply: false);
      }
    } else if (e.type == 'skin.changed') {
      _ingest(e.payload['name']?.toString(), apply: true);
    }
  }

  void _ingest(String? rawName, {required bool apply}) {
    final name = rawName?.trim().toLowerCase();
    if (name == null || name.isEmpty) return;

    if (!apply) {
      // Connect-time seed: record without painting, so a fresh connect never
      // stomps the user's persisted mobile accent.
      if (_lastName != name || !_lastApplied) {
        _lastName = name;
        _lastApplied = false;
      }
      return;
    }

    if (name == _lastName && _lastApplied) return;
    _lastName = name;
    _lastApplied = true;

    final matched = HermesAccents.matchId(name);
    if (matched != null) _appearance.setAccentId(matched);
  }
}
