import 'dart:collection';

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../../theme/hermes_glass_theme.dart';
import 'code_highlighter.dart';

/// Unified-diff renderer with add/remove tint + a 2px gutter accent, optional
/// old/new line-number columns, and per-line syntax highlighting of the change
/// content. Desktop parity: `components/chat/diff-lines.tsx` (`SyntaxDiff` /
/// `DiffLines`).
class FileDiffView extends StatefulWidget {
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
  State<FileDiffView> createState() => _FileDiffViewState();
}

class _FileDiffViewState extends State<FileDiffView> {
  /// Shared across every row's horizontal [SingleChildScrollView] so
  /// scrolling one line moves them all together, matching the old
  /// single-outer-scroll-view behavior even though rows are now lazily
  /// built by [ListView.builder]. Created once and disposed with the state.
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.diff;
    final path = widget.path;
    final showLineNumbers = widget.showLineNumbers;
    final maxHeight = widget.maxHeight;
    final scheme = Theme.of(context).colorScheme;
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lines = _parseDiffCached(diff);
    final language = _languageForPath(path);
    final base = HermesType.code.copyWith(fontSize: 12);

    final add = hermesSemantic(
      context,
      HermesSemantic.green,
      HermesSemanticDark.green,
    );
    final remove = hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    );
    // 语义色透明底惯例：亮色 10% / 暗色 18%。
    final addBg = add.withValues(alpha: isDark ? 0.18 : 0.10);
    final removeBg = remove.withValues(alpha: isDark ? 0.18 : 0.10);
    final addBar = add;
    final removeBar = remove;

    final gutterStyle = base.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      fontSize: 11,
    );

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      color: HermesGlassTheme.of(context).allowsTransparency(context)
          ? palette.codeBg.withValues(alpha: .88)
          : palette.codeBg,
      child: ListView.builder(
        primary: false,
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          if (line.kind == _DiffKind.hunk) {
            return Semantics(
              container: true,
              label: 'Diff hunk ${line.text}',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                color: palette.border,
                child: Text(
                  line.text,
                  style: base.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 10.5,
                  ),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: Semantics(
              container: true,
              label:
                  '${line.kind == _DiffKind.add
                      ? 'Added'
                      : line.kind == _DiffKind.remove
                      ? 'Removed'
                      : 'Unchanged'} line ${line.newNo ?? line.oldNo ?? ''}: ${line.text}',
              child: Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
            ),
          );
        },
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

// Diff content can be rebuilt frequently while a tool result streams. Keep a
// small LRU so parent rebuilds do not rescan multi-megabyte patches. The
// source budget is intentionally bounded to avoid pinning transcript memory.
const int _maxDiffCacheEntries = 32;
const int _maxDiffCacheChars = 2 * 1000 * 1000;
final LinkedHashMap<String, List<_DiffLine>> _diffCache =
    LinkedHashMap<String, List<_DiffLine>>();
int _diffCacheChars = 0;

/// Clears parsed Diff snapshots (used by profile mode and memory diagnostics).
void clearDiffParseCache() {
  _diffCache.clear();
  _diffCacheChars = 0;
}

/// Profile hook returning the number of parsed rows while exercising the same
/// cached path used by [FileDiffView].
int diffParsedLineCount(String diff) => _parseDiffCached(diff).length;

List<_DiffLine> _parseDiffCached(String diff) {
  final cached = _diffCache.remove(diff);
  if (cached != null) {
    _diffCache[diff] = cached;
    return cached;
  }
  final parsed = List<_DiffLine>.unmodifiable(_parseDiff(diff));
  if (diff.length <= _maxDiffCacheChars ~/ 2) {
    _diffCache[diff] = parsed;
    _diffCacheChars += diff.length;
    while (_diffCache.length > _maxDiffCacheEntries ||
        _diffCacheChars > _maxDiffCacheChars) {
      final oldest = _diffCache.keys.first;
      _diffCacheChars -= oldest.length;
      _diffCache.remove(oldest);
    }
  }
  return parsed;
}

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
