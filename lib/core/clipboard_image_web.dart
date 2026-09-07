import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'clipboard_image.dart';

Future<ClipboardImage?> readClipboardImage() async {
  final items = (await web.window.navigator.clipboard.read().toDart).toDart;
  for (final item in items) {
    final types = item.types.toDart.map((type) => type.toDart);
    for (final mime in types) {
      if (!mime.startsWith('image/')) continue;
      final blob = await item.getType(mime).toDart;
      final buffer = await blob.arrayBuffer().toDart;
      final extension = mime.split('/').last.replaceAll('jpeg', 'jpg');
      return ClipboardImage(
        bytes: Uint8List.view(buffer.toDart),
        mimeType: mime,
        filename: 'clipboard.$extension',
      );
    }
  }
  return null;
}
