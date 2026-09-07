import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../voice_activity.dart';
import '../voice_recorder.dart';

const bool isSupported = true;
const String mimeType = 'audio/webm';

final class VoiceRecorder extends VoiceRecorderBase {
  @override
  bool get supported => isSupported;
  @override
  String get mimeType => VoiceRecorderMime.mimeType;
  final AudioRecorder _recorder = AudioRecorder();
  final List<int> _bytes = [];
  StreamSubscription<List<int>>? _streamSubscription;

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    _bytes.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(encoder: AudioEncoder.opus),
    );
    _streamSubscription = stream.listen(_bytes.addAll);
    return true;
  }

  @override
  Future<Uint8List?> stop() async {
    await _recorder.stop();
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    return _bytes.isEmpty ? null : Uint8List.fromList(_bytes);
  }

  @override
  Future<void> waitForSpeechEnd({void Function(double level)? onLevel}) async {
    final activity = VoiceActivityDetector();
    var heardSpeech = false;
    DateTime? silentSince;
    final startedAt = DateTime.now();
    await for (final amplitude in _recorder.onAmplitudeChanged(
      const Duration(milliseconds: 120),
    )) {
      final now = DateTime.now();
      final level = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
      onLevel?.call(level);
      activity.add(amplitude.current, now);
      if (amplitude.current > activity.endThresholdDb) {
        heardSpeech = true;
        silentSince = null;
      } else if (heardSpeech) {
        silentSince ??= now;
        if (now.difference(silentSince) > const Duration(milliseconds: 900)) {
          return;
        }
      }
      if (now.difference(startedAt) > const Duration(seconds: 60) ||
          (!heardSpeech &&
              now.difference(startedAt) > const Duration(seconds: 10))) {
        return;
      }
    }
  }

  @override
  Future<bool> waitForSpeechStart({
    void Function(double level)? onLevel,
  }) async {
    final startedAt = DateTime.now();
    final activity = VoiceActivityDetector();
    await for (final amplitude in _recorder.onAmplitudeChanged(
      const Duration(milliseconds: 80),
    )) {
      final now = DateTime.now();
      final level = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
      onLevel?.call(level);
      if (activity.add(amplitude.current, now)) return true;
      if (now.difference(startedAt) >= const Duration(seconds: 60)) {
        return false;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _recorder.dispose();
  }
}

abstract final class VoiceRecorderMime {
  static const mimeType = 'audio/webm';
}
