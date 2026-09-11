import 'package:flutter/widgets.dart';

/// Content edits change coordinates without cancelling an active finger drag.
class TranscriptScrollController extends ScrollController {
  bool _correctingContent = false;
  bool get correctingContent => _correctingContent;

  /// Motion from drag/ballistic updates, excluding layout and anchor corrections.
  double get motionPixels =>
      hasClients ? (position as _TranscriptScrollPosition).motionPixels : 0;
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _TranscriptScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
  );

  void correctContentOffset(double target) {
    if (!hasClients) return;
    _correctingContent = true;
    try {
      (position as _TranscriptScrollPosition).correctContentOffset(target);
    } finally {
      _correctingContent = false;
    }
  }
}

class _TranscriptScrollPosition extends ScrollPositionWithSingleContext {
  double motionPixels = 0;

  @override
  double setPixels(double newPixels) {
    final before = pixels;
    final overscroll = super.setPixels(newPixels);
    motionPixels += pixels - before;
    return overscroll;
  }

  _TranscriptScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
  });

  void correctContentOffset(double target) {
    if (!target.isFinite || (target - pixels).abs() < .5) return;
    final current = activity;
    final velocity = current?.velocity ?? 0;
    final dragging = current is DragScrollActivity;
    if (!dragging) goIdle();
    forcePixels(target);
    // A ballistic simulation owns absolute coordinates: recreate it from
    // the corrected origin, retaining velocity. Drag activities use deltas.
    if (!dragging) goBallistic(velocity);
  }
}
