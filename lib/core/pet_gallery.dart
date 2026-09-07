library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// One entry from the gateway's `pet.gallery` RPC — the petdex is 4500+
/// pets served remotely, never bundled into the app (mirrors desktop's
/// `PetTab`, which fetches the same way instead of shipping pet art).
class PetGalleryEntry {
  final String slug;
  final String displayName;
  final String spritesheetUrl;
  final bool installed;
  final bool curated;

  const PetGalleryEntry({
    required this.slug,
    required this.displayName,
    required this.spritesheetUrl,
    required this.installed,
    required this.curated,
  });

  factory PetGalleryEntry.fromJson(Map<String, dynamic> json) => PetGalleryEntry(
    slug: json['slug']?.toString() ?? '',
    displayName:
        json['displayName']?.toString() ?? json['slug']?.toString() ?? '',
    spritesheetUrl: json['spritesheetUrl']?.toString() ?? '',
    installed: json['installed'] == true,
    curated: json['curated'] == true,
  );
}

const _petFrameWidth = 192;
const _petFrameHeight = 208;
const _petIconWidth = 96;
const _petIconHeight = 104;

final Map<String, Future<String?>> _petFrameCache = {};

/// Fetches [spriteUrl]'s spritesheet and crops frame 0 (the top-left cell)
/// into a small PNG data URL — mirrors desktop's `petFrameIcon`. Cached per
/// URL so scrolling/reopening the gallery doesn't refetch.
Future<String?> petFrameIcon(String spriteUrl) {
  if (spriteUrl.isEmpty) return Future.value(null);
  return _petFrameCache.putIfAbsent(spriteUrl, () => _fetchPetFrame(spriteUrl));
}

Future<String?> _fetchPetFrame(String spriteUrl) async {
  try {
    final response = await http
        .get(Uri.parse(spriteUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode >= 400) {
      _petFrameCache.remove(spriteUrl);
      return null;
    }
    final codec = await ui.instantiateImageCodec(response.bodyBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final cropW = math.min(_petFrameWidth, image.width).toDouble();
    final cropH = math.min(_petFrameHeight, image.height).toDouble();
    final recorder = ui.PictureRecorder();
    final dstRect = Rect.fromLTWH(
      0,
      0,
      _petIconWidth.toDouble(),
      _petIconHeight.toDouble(),
    );
    final canvas = Canvas(recorder, dstRect);
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, cropW, cropH), dstRect, Paint());
    final picture = recorder.endRecording();
    final output = await picture.toImage(_petIconWidth, _petIconHeight);
    final pngData = await output.toByteData(format: ui.ImageByteFormat.png);
    if (pngData == null) {
      _petFrameCache.remove(spriteUrl);
      return null;
    }
    return 'data:image/png;base64,${base64Encode(pngData.buffer.asUint8List())}';
  } catch (_) {
    _petFrameCache.remove(spriteUrl);
    return null;
  }
}
