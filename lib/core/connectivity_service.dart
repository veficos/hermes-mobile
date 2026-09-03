/// Thin wrapper around `connectivity_plus` — turns the raw platform signal
/// into a single "do we have some network at all" boolean stream.
///
/// This is deliberately dumber than a real reachability check: it can't
/// tell "on Wi-Fi but the Wi-Fi has no internet" from "on Wi-Fi with
/// internet" — only the OS's own connectivity status. That's still useful
/// for two things `ConnectionRuntime`'s reactive (timeout/close-based)
/// retry loop can't do on its own: (1) retry the instant the OS reports
/// connectivity back, instead of waiting out whatever's left of the
/// current backoff delay, and (2) let polling timers skip a cycle
/// entirely while there is provably no network, rather than firing on
/// schedule into a request that can only time out.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

class ConnectivityService {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  /// Last known state. `true` until the first real reading arrives (an
  /// optimistic default — most consumers only care about the *negative*
  /// case, and this avoids spuriously suppressing everything at startup
  /// before the platform channel has responded).
  bool hasNetwork = true;
  bool _started = false;

  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  /// Fires on every transition (not on every platform event — duplicates
  /// with the same boolean outcome are collapsed).
  Stream<bool> get onChange => _changes.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      hasNetwork = _hasNetwork(await _connectivity.checkConnectivity());
    } catch (_) {
      // Platform channel unavailable (e.g. some desktop/CI targets) — stay
      // optimistic rather than permanently suppressing reconnect nudges
      // and polling on a platform this can't actually observe.
    }
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final next = _hasNetwork(results);
      if (next == hasNetwork) return;
      hasNetwork = next;
      if (!_changes.isClosed) _changes.add(next);
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _changes.close();
  }
}
