import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

const bool isSupported = true;
const String mimeType = 'audio/webm';

class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  final List<int> _bytes = [];
  StreamSubscription<List<int>>? _streamSubscription;

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    _bytes.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(encoder: AudioEncoder.opus),
    );
    _streamSubscription = stream.listen(_bytes.addAll);
    return true;
  }

  Future<Uint8List?> stop() async {
    await _recorder.stop();
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    return _bytes.isEmpty ? null : Uint8List.fromList(_bytes);
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
    _streamSubscription?.cancel();
    _recorder.dispose();
  }
}
