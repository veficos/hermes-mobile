import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

abstract interface class VoicePlayerAdapter {
  Stream<void> get onComplete;
  Future<void> play(Uint8List bytes);
  Future<void> stop();
  Future<void> dispose();
}

final class DeviceVoicePlayer implements VoicePlayerAdapter {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;

  @override
  Future<void> play(Uint8List bytes) =>
      _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
