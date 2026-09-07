library;

import 'dart:typed_data';

import 'clipboard_image_stub.dart'
    if (dart.library.io) 'clipboard_image_io.dart'
    if (dart.library.js_interop) 'clipboard_image_web.dart'
    as impl;

class ClipboardImage {
  const ClipboardImage({
    required this.bytes,
    required this.mimeType,
    required this.filename,
  });
  final Uint8List bytes;
  final String mimeType;
  final String filename;
}

Future<ClipboardImage?> readClipboardImage() => impl.readClipboardImage();
