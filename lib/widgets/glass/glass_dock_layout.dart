import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lets scrollable content sample beneath a dock while exposing its measured
/// height as trailing scroll padding. The dock itself owns its materials.
class GlassDockLayout extends StatefulWidget {
  const GlassDockLayout({
    super.key,
    required this.enabled,
    required this.bodyBuilder,
    required this.dock,
    this.onInsetChanged,
  });
  final bool enabled;
  final Widget Function(BuildContext context, double bottomInset) bodyBuilder;
  final Widget dock;
  final VoidCallback? onInsetChanged;

  @override
  State<GlassDockLayout> createState() => _GlassDockLayoutState();
}

class _GlassDockLayoutState extends State<GlassDockLayout> {
  double _height = 0;
  double? _viewport;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                if (notification.depth != 0 ||
                    notification.metrics.axis != Axis.vertical) {
                  return false;
                }
                final next = notification.metrics.viewportDimension;
                final previous = _viewport;
                _viewport = next;
                if (previous != null && previous != next) {
                  widget.onInsetChanged?.call();
                }
                return false;
              },
              child: widget.bodyBuilder(context, 0),
            ),
          ),
          widget.dock,
        ],
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.depth != 0 ||
                  notification.metrics.axis != Axis.vertical) {
                return false;
              }
              final next = notification.metrics.viewportDimension;
              final previous = _viewport;
              _viewport = next;
              if (previous != null && previous != next) {
                widget.onInsetChanged?.call();
              }
              return false;
            },
            child: widget.bodyBuilder(context, _height),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _MeasureDock(
            onHeight: (height) {
              if (mounted && height != _height) {
                setState(() => _height = height);
                widget.onInsetChanged?.call();
              }
            },
            child: widget.dock,
          ),
        ),
      ],
    );
  }
}

class _MeasureDock extends SingleChildRenderObjectWidget {
  const _MeasureDock({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) => _DockSize(onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _DockSize renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _DockSize extends RenderProxyBox {
  _DockSize(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reportedHeight;
  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reportedHeight) return;
    _reportedHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
