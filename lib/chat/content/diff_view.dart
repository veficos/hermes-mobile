import 'package:flutter/material.dart';

import 'code_highlighter.dart';

/// Unified-diff renderer with add/remove tint + a 2px gutter accent, optional
/// old/new line-number columns, and per-line syntax highlighting of the change
/// content. Desktop parity: `components/chat/diff-lines.tsx` (`SyntaxDiff` /
/// `DiffLines`).
class FileDiffView extends StatelessWidget {
  final String diff;

  /// File path — drives the syntax-highlight language.
  final String? path;
  final bool showLineNumbers;
  final double maxHeight;

  const FileDiffView({
    super.key,
    required this.diff,
    this.path,
    this.showLineNumbers = false,
    this.maxHeight = 360,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lines = _parseDiff(diff);
    final language = _languageForPath(path);
    final base = const TextStyle(fontFamily: 'monospace', fontSize: 12);

    final addBg = (isDark ? const Color(0xFF2EA043) : const Color(0xFF2DA44E))
        .withValues(alpha: isDark ? 0.16 : 0.12);
    final removeBg =
        (isDark ? const Color(0xFFF85149) : const Color(0xFFCF222E)).withValues(
          alpha: isDark ? 0.16 : 0.12,
        );
    final addBar = isDark ? const Color(0xFF3FB950) : const Color(0xFF2DA44E);
    final removeBar = isDark
        ? const Color(0xFFF85149)
        : const Color(0xFFCF222E);

    final gutterStyle = base.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      fontSize: 11,
    );

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      color: scheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in lines)
                if (line.kind == _DiffKind.hunk)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    color: scheme.surfaceContainerHigh,
                    child: Text(
                      line.text,
                      style: base.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 10.5,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: line.kind == _DiffKind.add
                          ? addBg
                          : line.kind == _DiffKind.remove
                          ? removeBg
                          : null,
                      border: Border(
                        left: BorderSide(
                          width: 2,
                          color: line.kind == _DiffKind.add
                              ? addBar
                              : line.kind == _DiffKind.remove
                              ? removeBar
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showLineNumbers) ...[
                          SizedBox(
                            width: 34,
                            child: Text(
                              line.oldNo?.toString() ?? '',
                              textAlign: TextAlign.right,
                              style: gutterStyle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 34,
                            child: Text(
                              line.newNo?.toString() ?? '',
                              textAlign: TextAlign.right,
                              style: gutterStyle,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        _DiffLineText(
                          text: line.text,
                          language: language,
                          isDark: isDark,
                          base: base.copyWith(color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiffLineText extends StatelessWidget {
  final String text;
  final String? language;
  final bool isDark;
  final TextStyle base;

  const _DiffLineText({
    required this.text,
    required this.language,
    required this.isDark,
    required this.base,
  });

  @override
  Widget build(BuildContext context) {
    if (language != null && text.trim().isNotEmpty) {
      final span = CodeHighlighter.instance.highlight(text, language!, isDark);
      if (span != null) {
        return Text.rich(TextSpan(style: base, children: [span]));
      }
    }
    return Text(text, style: base);
  }
}

enum _DiffKind { add, remove, context, hunk }

class _DiffLine {
  final _DiffKind kind;
  final String text;
  final int? oldNo;
  final int? newNo;
  const _DiffLine(this.kind, this.text, {this.oldNo, this.newNo});
}

final _hunkHeader = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');

List<_DiffLine> _parseDiff(String diff) {
  final out = <_DiffLine>[];
  var oldNo = 0;
  var newNo = 0;
  for (final raw in diff.split('\n')) {
    // Drop git file-header noise.
    if (raw.startsWith('diff --git ') ||
        raw.startsWith('index ') ||
        raw.startsWith('--- ') ||
        raw.startsWith('+++ ') ||
        raw.startsWith('new file mode') ||
        raw.startsWith('deleted file mode') ||
        raw.startsWith('similarity index') ||
        raw.startsWith('rename ') ||
        raw.startsWith('\\ No newline at end of file')) {
      continue;
    }
    final hunk = _hunkHeader.firstMatch(raw);
    if (hunk != null) {
      oldNo = int.parse(hunk.group(1)!);
      newNo = int.parse(hunk.group(2)!);
      out.add(_DiffLine(_DiffKind.hunk, raw.trim()));
      continue;
    }
    if (raw.startsWith('+')) {
      out.add(_DiffLine(_DiffKind.add, raw.substring(1), newNo: newNo++));
    } else if (raw.startsWith('-')) {
      out.add(_DiffLine(_DiffKind.remove, raw.substring(1), oldNo: oldNo++));
    } else {
      final text = raw.startsWith(' ') ? raw.substring(1) : raw;
      out.add(
        _DiffLine(_DiffKind.context, text, oldNo: oldNo++, newNo: newNo++),
      );
    }
  }
  return out;
}

String? _languageForPath(String? path) {
  if (path == null) return null;
  final dot = path.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = path.substring(dot + 1).toLowerCase();
  return CodeHighlighter.instance.supports(ext) ? ext : null;
}

/// `+N −M` line-stat counts for a unified diff (excludes `+++` / `---`).
({int added, int removed}) diffLineStats(String diff) {
  var added = 0;
  var removed = 0;
  for (final line in diff.split('\n')) {
    if (line.startsWith('+') && !line.startsWith('+++')) added++;
    if (line.startsWith('-') && !line.startsWith('---')) removed++;
  }
  return (added: added, removed: removed);
}
