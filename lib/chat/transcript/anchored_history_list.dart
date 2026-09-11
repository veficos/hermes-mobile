import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Keeps an existing row at the same scroll origin while history grows above it.
class AnchoredHistoryList extends StatefulWidget {
  const AnchoredHistoryList({
    super.key,
    required this.controller,
    required this.keys,
    required this.itemBuilder,
    required this.padding,
  });
  final ScrollController controller;
  final List<Key> keys;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;

  @override
  State<AnchoredHistoryList> createState() => _AnchoredHistoryListState();
}

class _AnchoredHistoryListState extends State<AnchoredHistoryList> {
  static const _center = ValueKey('history-layout-origin');
  Key? _origin;
  Set<Key> _beforeOrigin = {};

  @override
  void didUpdateWidget(covariant AnchoredHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final delta = widget.padding.top - oldWidget.padding.top;
    if (delta != 0 && widget.controller.hasClients) {
      final position = widget.controller.position;
      if ((position.pixels - position.minScrollExtent).abs() < 1) {
        // Reverse-side padding moves the leading boundary, not the origin.
        // Keep a reader at that boundary when the search/header inset changes.
        position.correctBy(-delta);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.keys.isEmpty) {
      _origin = null;
      _beforeOrigin = {};
    } else {
      _origin ??= widget.keys.length > 1 ? widget.keys[1] : widget.keys.first;
    }
    var pivot = _origin == null ? 0 : widget.keys.indexOf(_origin!);
    if (pivot < 0) {
      // Trimming the newer window can remove the zero-point row. Keep the
      // boundary after surviving older rows, including when no forward rows
      // remain. Moving it to the oldest row would change every coordinate.
      pivot = widget.keys.lastIndexWhere(_beforeOrigin.contains) + 1;
    }
    _beforeOrigin = widget.keys.take(pivot).toSet();
    final indices = {
      for (var i = 0; i < widget.keys.length; i++) widget.keys[i]: i,
    };
    return _HistoryScrollView(
      controller: widget.controller,
      center: _center,
      scrollCacheExtent: const ScrollCacheExtent.pixels(640),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: widget.padding.top),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  widget.itemBuilder(context, pivot - index - 1),
              childCount: pivot,
              findChildIndexCallback: (key) {
                final index = indices[key];
                return index != null && index < pivot
                    ? pivot - index - 1
                    : null;
              },
            ),
          ),
        ),
        SliverPadding(
          key: _center,
          padding: EdgeInsets.only(bottom: widget.padding.bottom),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => widget.itemBuilder(context, pivot + index),
              childCount: widget.keys.length - pivot,
              findChildIndexCallback: (key) {
                final index = indices[key];
                return index != null && index >= pivot ? index - pivot : null;
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryScrollView extends CustomScrollView {
  const _HistoryScrollView({
    required super.controller,
    required super.center,
    required super.slivers,
    required super.scrollCacheExtent,
  });

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) => _HistoryViewport(
    offset: offset,
    center: center,
    slivers: slivers,
    axisDirection: axisDirection,
    crossAxisDirection: Directionality.of(context) == TextDirection.rtl
        ? AxisDirection.left
        : AxisDirection.right,
    scrollCacheExtent: scrollCacheExtent,
  );
}

class _HistoryViewport extends Viewport {
  _HistoryViewport({
    required super.offset,
    required super.center,
    required super.slivers,
    required super.axisDirection,
    required super.crossAxisDirection,
    required super.scrollCacheExtent,
  });

  @override
  RenderViewport createRenderObject(BuildContext context) =>
      _HistoryRenderViewport(
        offset: offset,
        axisDirection: axisDirection,
        crossAxisDirection: crossAxisDirection!,
        scrollCacheExtent: scrollCacheExtent,
      );
}

class _HistoryRenderViewport extends RenderViewport {
  _HistoryRenderViewport({
    required super.offset,
    required super.axisDirection,
    required super.crossAxisDirection,
    required super.scrollCacheExtent,
  });
  bool _initial = true;
  RenderBox? _anchor;
  double? _anchorY;
  double? _pixels;
  Size? _viewportSize;

  // Read sliver layout offsets, never a descendant box's size during layout.
  Map<RenderBox, double> _rowPositions() {
    final result = <RenderBox, double>{};
    void visit(RenderObject object) {
      if (object is RenderSliverMultiBoxAdaptor) {
        final reverse =
            object.constraints.growthDirection == GrowthDirection.reverse;
        final origin = MatrixUtils.transformPoint(
          object.getTransformTo(this),
          Offset.zero,
        ).dy;
        var row = object.firstChild;
        while (row != null) {
          final layout = object.childScrollOffset(row);
          final next = object.childAfter(row);
          if (layout != null) {
            if (!reverse) {
              result[row] = origin + layout - object.constraints.scrollOffset;
            } else if (next != null) {
              // Reverse paint positions use the row's far layout boundary.
              // SliverList places the next row at that boundary, allowing us
              // to measure without an illegal descendant size read. Do not
              // substitute estimated scrollExtent for an unmounted neighbor.
              final end = object.childScrollOffset(next);
              if (end != null) {
                result[row] =
                    origin +
                    object.geometry!.paintExtent -
                    end +
                    object.constraints.scrollOffset;
              }
            }
          }
          row = next;
        }
      } else {
        object.visitChildren(visit);
      }
    }

    visit(this);
    return result;
  }

  @override
  void performLayout() {
    final position = offset;
    final userScrolling =
        position is ScrollPosition &&
        position.userScrollDirection != ScrollDirection.idle;
    final movement = _pixels == null ? 0.0 : offset.pixels - _pixels!;
    final preserve =
        !_initial &&
        _anchor?.attached == true &&
        (movement == 0 || userScrolling) &&
        position is ScrollPosition &&
        (!position.isScrollingNotifier.value || userScrolling) &&
        position.maxScrollExtent - position.pixels > 1;
    super.performLayout();
    if (preserve && _viewportSize == size) {
      final current = _rowPositions()[_anchor];
      if (current != null) {
        // User travel should move the row; only layout-induced travel is
        // compensated. Idle-direction programmatic scrolling retains ownership.
        final delta = current - (_anchorY! - movement);
        if (delta.isFinite && delta.abs() > .1) {
          offset.correctBy(delta);
          super.performLayout();
        }
      }
    }
    if (_initial &&
        position is ScrollPosition &&
        position.hasContentDimensions &&
        position.maxScrollExtent == 0 &&
        position.minScrollExtent < 0) {
      position.correctBy(position.minScrollExtent - position.pixels);
      super.performLayout();
    }
    _initial = false;
    _anchor = null;
    _anchorY = null;
    final rows = _rowPositions();
    for (final entry in rows.entries) {
      if (entry.value >= 0 &&
          entry.value < size.height &&
          (_anchorY == null || entry.value < _anchorY!)) {
        _anchor = entry.key;
        _anchorY = entry.value;
      }
    }
    _pixels = offset.pixels;
    _viewportSize = size;
    // An empty list is a new initialization boundary. The next short history
    // must expose its reverse-side header just as an initially populated one.
    if (rows.isEmpty) _initial = true;
  }
}
