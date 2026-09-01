import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'inline_content.dart';

/// Standalone display equation. Desktop KaTeX (`$$…$$`) parity. Falls back to
/// the raw TeX source (monospace) when the expression can't be parsed.
class MathBlockView extends StatelessWidget {
  final String tex;
  const MathBlockView({super.key, required this.tex});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          tex,
          textStyle: TextStyle(fontSize: 16, color: color),
          onErrorFallback: (_) => SelectableText(
            '\$\$$tex\$\$',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ),
    );
  }
}

/// A prose line that flows plain text and inline `$…$` equations together.
class MathInlineRun extends StatelessWidget {
  final List<InlineRichSegment> segments;
  final bool selectable;
  const MathInlineRun({
    super.key,
    required this.segments,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6) ??
        const TextStyle(height: 1.6);
    final spans = <InlineSpan>[
      for (final segment in segments)
        if (segment.isMath)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              segment.value,
              textStyle: base,
              onErrorFallback: (_) => Text(
                '\$${segment.value}\$',
                style: base.copyWith(fontFamily: 'monospace'),
              ),
            ),
          )
        else
          TextSpan(text: segment.value, style: base),
    ];
    final textSpan = TextSpan(children: spans);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: selectable ? SelectableText.rich(textSpan) : Text.rich(textSpan),
    );
  }
}
