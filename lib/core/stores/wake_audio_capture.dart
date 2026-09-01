library;

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

abstract interface class WakeAudioCapture {
  bool get active;

  Future<bool> start({
    required int frameLength,
    required void Function(Uint8List bytes) onData,
    required void Function(Object error) onError,
  });

  Future<void> stop();
  Future<void> dispose();
}

class RecordWakeAudioCapture implements WakeAudioCapture {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  bool _active = false;

  @override
  bool get active => _active;

  @override
  Future<bool> start({
    required int frameLength,
    required void Function(Uint8List bytes) onData,
    required void Function(Object error) onError,
  }) async {
    await stop();
    if (!await _recorder.hasPermission()) return false;
    try {
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          streamBufferSize: frameLength * 2,
        ),
      );
      _active = true;
      _subscription = stream.listen(
        onData,
        onError: (Object error) {
          _active = false;
          onError(error);
        },
        onDone: () {
          final endedUnexpectedly = _active;
          _active = false;
          if (endedUnexpectedly) {
            onError(StateError('wake microphone stream ended'));
          }
        },
      );
      return true;
    } catch (_) {
      _active = false;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _active = false;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await stop();
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}
