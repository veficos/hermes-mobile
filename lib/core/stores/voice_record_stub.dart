import 'dart:typed_data';

import '../voice_recorder.dart';

const bool isSupported = false;
const String mimeType = 'audio/wav';

final class VoiceRecorder extends VoiceRecorderBase {
  @override
  bool get supported => isSupported;
  @override
  String get mimeType => VoiceRecorderMime.mimeType;
  @override
  Future<bool> start() async => false;

  @override
  Future<Uint8List?> stop() async => null;
  @override
  Future<void> waitForSpeechEnd({void Function(double level)? onLevel}) async {}
  @override
  Future<bool> waitForSpeechStart({
    void Function(double level)? onLevel,
  }) async => false;

  @override
  void dispose() {}
}

abstract final class VoiceRecorderMime {
  static const mimeType = 'audio/wav';
}
