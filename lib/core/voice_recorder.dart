import 'dart:typed_data';

abstract interface class VoiceRecorderAdapter {
  bool get supported;
  String get mimeType;
  Future<bool> start();
  Future<Uint8List?> stop();
  Future<void> waitForSpeechEnd({void Function(double level)? onLevel});
  Future<bool> waitForSpeechStart({void Function(double level)? onLevel});
  void dispose();
}

abstract base class VoiceRecorderBase implements VoiceRecorderAdapter {
  const VoiceRecorderBase();
}
