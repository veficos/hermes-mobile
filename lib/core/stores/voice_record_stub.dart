import 'dart:typed_data';

const bool isSupported = false;
const String mimeType = 'audio/wav';

class VoiceRecorder {
  Future<bool> start() async => false;

  Future<Uint8List?> stop() async => null;
  Future<void> waitForSpeechEnd() async {}

  void dispose() {}
}
