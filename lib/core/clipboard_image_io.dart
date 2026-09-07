import 'package:flutter/services.dart';

import 'clipboard_image.dart';

const _channel = MethodChannel('hermes.clipboard');

Future<ClipboardImage?> readClipboardImage() async {
  final raw = await _channel.invokeMapMethod<String, dynamic>('readImage');
  if (raw == null || raw['bytes'] is! Uint8List) return null;
  return ClipboardImage(
    bytes: raw['bytes'] as Uint8List,
    mimeType: raw['mime']?.toString() ?? 'image/png',
    filename: raw['filename']?.toString() ?? 'clipboard.png',
  );
}
