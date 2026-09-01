import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Collapses tall content behind a "show more" toggle with a bottom fade,
/// mirroring desktop's `components/chat/expandable-block.tsx`. Used for very
/// long markdown blocks and log-like tool output so a single message can't
/// dominate the transcript.
class ExpandableBlock extends StatefulWidget {
  final Widget child;
  final double collapsedHeight;
  final String? showMoreLabel;
  final String? showLessLabel;

  const ExpandableBlock({
    super.key,
    required this.child,
    this.collapsedHeight = 280,
    this.showMoreLabel,
    this.showLessLabel,
  });

  @override
  State<ExpandableBlock> createState() => _ExpandableBlockState();
}

class _ExpandableBlockState extends State<ExpandableBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: _expanded
              ? widget.child
              : Stack(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: widget.collapsedHeight,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        heightFactor: 1,
                        child: widget.child,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                scheme.surface.withValues(alpha: 0),
                                scheme.surface,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
            ),
            label: Text(
              _expanded
                  ? widget.showLessLabel ?? context.l10n.commonCollapse
                  : widget.showMoreLabel ?? context.l10n.commonViewAll,
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
