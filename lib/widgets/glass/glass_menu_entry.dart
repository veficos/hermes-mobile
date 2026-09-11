import 'package:flutter/material.dart';
import '../../theme/hermes_glass_theme.dart';
import 'glass_surface.dart';
import 'glass_selection_row.dart';

/// One material around a complete menu; nested entries retain their actions.
class GlassMenuEntry<T> extends PopupMenuEntry<T> {
  const GlassMenuEntry({
    super.key,
    required this.entries,
    this.initialValue,
    this.padding = EdgeInsets.zero,
    this.maxHeight,
  });
  final List<PopupMenuEntry<T>> entries;
  final T? initialValue;
  final EdgeInsetsGeometry padding;
  final double? maxHeight;

  /// Capture before opening the route: Flutter removes safe-area padding
  /// from the popup's descendant MediaQuery after positioning its viewport.
  static double availableHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    return (media.size.height -
            media.padding.vertical -
            media.viewInsets.vertical -
            16)
        .clamp(0.0, double.infinity);
  }

  @override
  double get height => entries.fold(0, (sum, entry) => sum + entry.height);
  @override
  bool represents(T? value) => entries.any((entry) => entry.represents(value));
  @override
  State<GlassMenuEntry<T>> createState() => _GlassMenuEntryState<T>();
}

class _GlassMenuEntryState<T> extends State<GlassMenuEntry<T>> {
  @override
  Widget build(BuildContext context) {
    // The native popup has an outer scroll view. Bound our material to its
    // usable viewport so only entries scroll, never the rounded glass edge.
    final maxHeight =
        widget.maxHeight ?? GlassMenuEntry.availableHeight(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: GlassSurface(
        role: HermesGlassRole.overlay,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: widget.padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in widget.entries)
                  if (entry is PopupMenuItem<T>)
                    GlassSelectionRow(
                      selected:
                          widget.initialValue != null &&
                          entry.represents(widget.initialValue),
                      child: entry,
                    )
                  else
                    entry,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
