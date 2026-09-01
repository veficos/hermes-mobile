library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../connections/connection_registry.dart';
import '../../l10n/runtime_l10n.dart';
import '../gateway.dart';
import 'connection_store.dart';
import 'wake_audio_capture.dart';

class WakeDetection {
  final String phrase;
  final String? profile;
  final bool startNewSession;

  const WakeDetection({
    required this.phrase,
    this.profile,
    this.startNewSession = true,
  });
}

class WakeWordStore extends ChangeNotifier with WidgetsBindingObserver {
  final ConnectionStore connection;
  final WakeAudioCapture audioCapture;
  StreamSubscription<GatewayEvent>? _events;
  StreamSubscription<void>? _reconnected;
  OwnerRoute? _ownerRoute;
  ConnectionId? _activeConnection;
  bool _wasConnected = false;
  bool _disposed = false;
  bool _syncing = false;
  bool _lifecyclePaused = false;
  bool _voicePaused = false;
  bool _available = false;
  bool _enabled = false;
  bool _listening = false;
  bool _pending = false;
  String _notice = '';
  String _phrase = '';
  String _captureMode = '';
  int _frameLength = 1280;
  int _captureGeneration = 0;
  final List<int> _pcmPending = [];
  final List<Uint8List> _frameQueue = [];
  bool _drainingFrames = false;
  WakeDetection? _detection;

  WakeWordStore({required this.connection, WakeAudioCapture? audioCapture})
    : audioCapture = audioCapture ?? RecordWakeAudioCapture() {
    _activeConnection = connection.activeConnectionId;
    connection.addListener(_onConnectionChanged);
    _events = connection.events.listen(_onEvent);
    _reconnected = connection.reconnected.listen((_) => unawaited(arm()));
    WidgetsBinding.instance.addObserver(this);
    _onConnectionChanged();
  }

  bool get available => _available;
  bool get enabled => _enabled;
  bool get listening => _listening;
  bool get pending => _pending;
  String get notice => _notice;
  String get phrase => _phrase;
  WakeDetection? get detection => _detection;

  String get statusLabel {
    if (_pending) return runtimeL10n.voiceWakeEnabling;
    // Detected-but-not-yet-consumed: the brief window between the wake
    // engine firing and the app switching into an actual capture (surfaced
    // separately from plain "listening" so the indicator has a genuine third
    // state — armed vs. triggered — matching desktop's wake-indicator).
    if (_detection != null) return runtimeL10n.voiceWakeTriggered;
    if (_enabled && _listening) {
      return _phrase.isEmpty
          ? runtimeL10n.voiceWakeListening
          : runtimeL10n.voiceWakeListeningFor(_phrase);
    }
    if (_notice.isNotEmpty) return _notice;
    return _enabled
        ? runtimeL10n.voiceWakeWaiting
        : runtimeL10n.voiceWakeDisabled;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onConnectionChanged() {
    if (_disposed) return;
    final current = connection.activeConnectionId;
    if (_activeConnection != current) {
      final oldRoute = _ownerRoute;
      _activeConnection = current;
      _ownerRoute = null;
      _wasConnected = false;
      unawaited(_stopClientCapture());
      if (oldRoute != null) {
        unawaited(
          connection
              .requestForOwner(oldRoute, 'wake.stop', const {})
              .catchError((_) => <String, dynamic>{}),
        );
      }
      _available = false;
      _listening = false;
      _notice = '';
      _notify();
    }
    final connected = connection.isConnected;
    if (connected && !_wasConnected && !_lifecyclePaused) {
      unawaited(arm());
    }
    if (!connected && _wasConnected) {
      unawaited(_stopClientCapture());
      _listening = false;
      _notify();
    }
    _wasConnected = connected;
  }

  OwnerRoute get _activeRoute =>
      OwnerRoute(connectionId: connection.activeConnectionId);

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> params, {
    OwnerRoute? route,
  }) => connection.requestForOwner(
    route ?? _activeRoute,
    method,
    params,
    timeout: method == 'wake.start'
        ? const Duration(minutes: 3)
        : const Duration(seconds: 120),
  );

  Future<Map<String, dynamic>> refreshStatus() async {
    final status = await _request('wake.status', const {
      'surface': 'gui',
      'client_capture': true,
    });
    _applyStatus(status);
    return status;
  }

  Future<void> arm() async {
    if (_disposed || _syncing || _lifecyclePaused || _voicePaused) return;
    _syncing = true;
    try {
      final status = await refreshStatus();
      if (!_available || !_enabled) return;
      if (status['listening'] == true) {
        if (_usesClientCapture(status['capture'])) {
          await _startClientCapture(
            (status['frame_length'] as num?)?.toInt() ?? _frameLength,
          );
        }
        return;
      }
      await _start(persist: false);
    } catch (_) {
      // Older gateways do not expose wake.*. The hidden/off state is correct.
    } finally {
      _syncing = false;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_pending || _disposed) return;
    _pending = true;
    _notice = value ? runtimeL10n.voiceWakeInstallNotice : '';
    _notify();
    try {
      if (value) {
        await _start(persist: true);
      } else {
        await _stopClientCapture();
        final result = await _request('wake.stop', const {'persist': true});
        _listening = false;
        if (result['disabled_persisted'] == true || result['stopped'] == true) {
          _enabled = false;
        }
        _notice = _reasonText(result);
      }
    } catch (error) {
      _notice = '$error';
    } finally {
      _pending = false;
      _notify();
    }
  }

  Future<void> toggle() => setEnabled(!_enabled);

  Future<String> command(String rawAction) async {
    final action = rawAction.trim().toLowerCase();
    if (action.isEmpty || action == 'status') {
      try {
        await refreshStatus();
      } catch (error) {
        _notice = '$error';
        _notify();
      }
      return statusLabel;
    }
    if (const {'on', 'start', 'enable'}.contains(action)) {
      await setEnabled(true);
      return statusLabel;
    }
    if (const {'off', 'stop', 'disable'}.contains(action)) {
      await setEnabled(false);
      return statusLabel;
    }
    if (action == 'toggle') {
      await toggle();
      return statusLabel;
    }
    throw ArgumentError(runtimeL10n.voiceWakeUsage);
  }

  Future<void> _start({required bool persist}) async {
    final result = await _request('wake.start', {
      'surface': 'gui',
      'client_capture': true,
      if (persist) 'persist': true,
    });
    if (result['started'] != true) {
      await _stopClientCapture();
      _listening = false;
      if (result['reason'] == 'unavailable') _available = false;
      _notice = _reasonText(result);
      _notify();
      return;
    }
    _ownerRoute = _activeRoute;
    _available = true;
    _enabled = true;
    _listening = true;
    _notice = '';
    _phrase = result['phrase']?.toString().trim() ?? _phrase;
    _captureMode = result['capture']?.toString().toLowerCase() ?? '';
    _frameLength = (result['frame_length'] as num?)?.toInt() ?? 1280;
    _notify();
    if (_usesClientCapture(_captureMode)) {
      await _startClientCapture(_frameLength);
    }
  }

  void _applyStatus(Map<String, dynamic> status) {
    _available = status['available'] == true;
    _enabled = status['enabled'] == true;
    _listening = status['listening'] == true;
    _phrase = status['phrase']?.toString().trim() ?? _phrase;
    _captureMode = status['capture']?.toString().toLowerCase() ?? '';
    _frameLength = (status['frame_length'] as num?)?.toInt() ?? _frameLength;
    _notice = _listening && status['audio_silent'] != true
        ? ''
        : _reasonText(status);
    if (_listening) _ownerRoute = _activeRoute;
    _notify();
  }

  static bool _usesClientCapture(dynamic value) => const {
    'client',
    'remote',
    'external',
  }.contains(value?.toString().toLowerCase());

  static String _reasonText(Map<String, dynamic> result) {
    final hint = result['hint']?.toString().trim();
    if (hint != null && hint.isNotEmpty) return hint;
    return switch (result['reason']?.toString()) {
      'disabled' => runtimeL10n.voiceWakeNotEnabled,
      'disabled_for_surface' => runtimeL10n.voiceWakeOtherSurface,
      'owned' || 'not_owner' => runtimeL10n.voiceWakeOwned,
      'unavailable' => runtimeL10n.voiceWakeUnavailable,
      final value? when value.isNotEmpty => value,
      _ => '',
    };
  }

  Future<void> _startClientCapture(int frameLength) async {
    if (_disposed || _lifecyclePaused || _voicePaused) return;
    final generation = ++_captureGeneration;
    await audioCapture.stop();
    _pcmPending.clear();
    _frameQueue.clear();
    try {
      final started = await audioCapture.start(
        frameLength: frameLength,
        onData: (bytes) => _onPcm(bytes, generation, frameLength),
        onError: (error) {
          if (generation != _captureGeneration) return;
          _notice = runtimeL10n.voiceWakeMicInterrupted('$error');
          _listening = false;
          _notify();
        },
      );
      if (generation != _captureGeneration) {
        await audioCapture.stop();
        return;
      }
      if (!started) {
        _notice = runtimeL10n.voiceWakeMicPermission;
        _listening = false;
        _notify();
        await _request(
          'wake.stop',
          const {},
        ).catchError((_) => <String, dynamic>{});
      }
    } catch (error) {
      if (generation != _captureGeneration) return;
      _notice = runtimeL10n.voiceWakeMicStartFailed('$error');
      _listening = false;
      _notify();
      await _request(
        'wake.stop',
        const {},
      ).catchError((_) => <String, dynamic>{});
    }
  }

  void _onPcm(Uint8List bytes, int generation, int frameLength) {
    if (generation != _captureGeneration || !audioCapture.active) return;
    _pcmPending.addAll(bytes);
    final frameBytes = frameLength.clamp(160, 32000) * 2;
    while (_pcmPending.length >= frameBytes) {
      _frameQueue.add(Uint8List.fromList(_pcmPending.sublist(0, frameBytes)));
      _pcmPending.removeRange(0, frameBytes);
    }
    while (_frameQueue.length > 24) {
      _frameQueue.removeAt(0);
    }
    unawaited(_drainFrameQueue(generation));
  }

  Future<void> _drainFrameQueue(int generation) async {
    if (_drainingFrames) return;
    _drainingFrames = true;
    try {
      while (generation == _captureGeneration &&
          audioCapture.active &&
          _frameQueue.isNotEmpty) {
        final count = _frameQueue.length.clamp(1, 4);
        final frames = _frameQueue.sublist(0, count);
        _frameQueue.removeRange(0, count);
        final total = frames.fold<int>(0, (sum, frame) => sum + frame.length);
        final merged = Uint8List(total);
        var offset = 0;
        for (final frame in frames) {
          merged.setRange(offset, offset + frame.length, frame);
          offset += frame.length;
        }
        try {
          await _request('wake.feed', {
            'pcm': base64Encode(merged),
            'sample_rate': 16000,
          }, route: _ownerRoute);
        } catch (error) {
          if (generation == _captureGeneration) {
            _notice = runtimeL10n.voiceWakeAudioUploadFailed('$error');
            _notify();
          }
        }
      }
    } finally {
      _drainingFrames = false;
      if (generation == _captureGeneration && _frameQueue.isNotEmpty) {
        unawaited(_drainFrameQueue(generation));
      }
    }
  }

  Future<void> _stopClientCapture() async {
    _captureGeneration++;
    _pcmPending.clear();
    _frameQueue.clear();
    await audioCapture.stop();
  }

  void _onEvent(GatewayEvent event) {
    if (event.type != 'wake.detected') return;
    _voicePaused = true;
    _listening = false;
    unawaited(_stopClientCapture());
    final profile = event.payload['profile']?.toString().trim();
    _detection = WakeDetection(
      phrase: event.payload['phrase']?.toString().trim() ?? _phrase,
      profile: profile == null || profile.isEmpty ? null : profile,
      startNewSession: event.payload['start_new_session'] != false,
    );
    _notify();
  }

  WakeDetection? takeDetection() {
    final value = _detection;
    if (value == null) return null;
    _detection = null;
    _notify();
    return value;
  }

  Future<void> pauseForVoice() async {
    if (!_enabled && !_listening && !audioCapture.active) return;
    _voicePaused = true;
    await _stopClientCapture();
    try {
      await _request('wake.pause', const {}, route: _ownerRoute);
    } catch (_) {}
    _listening = false;
    _notify();
  }

  Future<void> resumeAfterVoice() async {
    _voicePaused = false;
    if (_lifecyclePaused || _disposed) return;
    try {
      await _request('wake.resume', const {}, route: _ownerRoute);
    } catch (_) {
      return;
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      if (_lifecyclePaused || _voicePaused || _disposed) return;
      try {
        final status = await refreshStatus();
        if (!_enabled || !_available) return;
        if (status['listening'] == true) {
          if (_usesClientCapture(status['capture'])) {
            await _startClientCapture(_frameLength);
          }
          return;
        }
        await _start(persist: false);
        if (_listening) return;
        if (status['reason'] == 'owned') return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }

  Future<void> _pauseForLifecycle() async {
    if (_lifecyclePaused) return;
    _lifecyclePaused = true;
    await _stopClientCapture();
    try {
      await _request('wake.pause', const {}, route: _ownerRoute);
    } catch (_) {}
    _listening = false;
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final wasPaused = _lifecyclePaused;
      _lifecyclePaused = false;
      if (wasPaused && !_voicePaused) unawaited(resumeAfterVoice());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_pauseForLifecycle());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    connection.removeListener(_onConnectionChanged);
    _events?.cancel();
    _reconnected?.cancel();
    final route = _ownerRoute;
    if (route != null) {
      unawaited(
        connection
            .requestForOwner(route, 'wake.stop', const {})
            .catchError((_) => <String, dynamic>{}),
      );
    }
    unawaited(audioCapture.dispose().catchError((_) {}));
    super.dispose();
  }
}
