import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../voice_activity.dart';
import '../voice_recorder.dart';

const bool isSupported = true;
const String mimeType = 'audio/wav';

final class VoiceRecorder extends VoiceRecorderBase {
  @override
  bool get supported => isSupported;
  @override
  String get mimeType => VoiceRecorderMime.mimeType;
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> start() async {
    final ok = await _recorder.hasPermission();
    if (!ok) return false;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/hermes_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: path,
    );
    return true;
  }

  @override
  Future<Uint8List?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    try {
      return await file.readAsBytes();
    } finally {
      // Best-effort cleanup: the temp recording has been read into memory
      // (or failed to), so don't leave it on disk indefinitely.
      unawaited(file.delete().catchError((_) => file));
    }
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
    _recorder.dispose();
  }
}

abstract final class VoiceRecorderMime {
  static const mimeType = 'audio/wav';
}
