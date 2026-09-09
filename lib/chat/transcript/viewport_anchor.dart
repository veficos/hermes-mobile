import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A mounted message and its position immediately before a transcript edit.
class TranscriptViewportAnchor {
  const TranscriptViewportAnchor._(this.key, this.top, this.pixels);
  final GlobalKey key;
  final double top;
  final double pixels;

  static TranscriptViewportAnchor? capture(
    Iterable<GlobalKey> keys,
    ScrollPosition position,
  ) {
    TranscriptViewportAnchor? result;
    for (final key in keys) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is! RenderBox) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top + box.size.height <= 0 || top >= position.viewportDimension) {
        continue;
      }
      if (result == null || top < result.top) {
        result = TranscriptViewportAnchor._(key, top, position.pixels);
      }
    }
    return result;
  }

  double? restoredOffset(ScrollPosition position, {double? userScrollDelta}) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is! RenderBox) return null;
    final currentTop = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    // Preserve any user movement between capture and layout.
    final desiredTop = top - (userScrollDelta ?? (position.pixels - pixels));
    return (position.pixels + currentTop - desiredTop).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }
}
