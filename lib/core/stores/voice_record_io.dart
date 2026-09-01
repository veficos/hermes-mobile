import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const bool isSupported = true;
const String mimeType = 'audio/wav';

class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();

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

  Future<Uint8List?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    return File(path).readAsBytes();
  }

  Future<void> waitForSpeechEnd() async {
    var heardSpeech = false;
    DateTime? silentSince;
    final startedAt = DateTime.now();
    await for (final amplitude in _recorder.onAmplitudeChanged(
      const Duration(milliseconds: 120),
    )) {
      final now = DateTime.now();
      if (amplitude.current > -38) {
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

  void dispose() {
    _recorder.dispose();
  }
}
