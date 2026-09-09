/// Tail-bounded markdown "remend" for the live streaming row.
///
/// Desktop parity: `@assistant-ui/react-streamdown`'s `tailBoundedRemend`.
/// While a turn streams, the trailing bytes routinely hold a half-typed
/// construct — an unclosed ``` fence, a lone `**`, a `[label](` with no URL
/// yet. Rendering that raw makes the tail of the message flicker between
/// "code block" / "bold" / "broken link" every few tokens and then snap when
/// the closing token finally lands. Closing the open constructs with a
/// synthetic tail keeps the rendered shape stable, so the only thing that
/// visibly changes per frame is new text appended at the end.
library;

class StreamingMarkdownSplit {
  final String stablePrefix;
  final String mutableTail;

  const StreamingMarkdownSplit(this.stablePrefix, this.mutableTail);
}

/// Incrementally identifies complete Markdown blocks. Each source character
/// is scanned once; completed blocks are emitted only after they are farther
/// than [tailChars] from the live edge. The active tail therefore stays
/// bounded without rescanning or masking the full response every frame.
class IncrementalStreamingMarkdownScanner {
  IncrementalStreamingMarkdownScanner({this.tailChars = 6144});

  final int tailChars;
  String _source = '';
  int _scanned = 0;
  int _lineSearch = 0;
  int _stableEnd = 0;
  // Fence state: the opening run's character (96 = backtick, 126 = tilde) and
  // length; `_fenceChar == 0` means no fence is open. A fence only closes on
  // the same character with a run at least as long (CommonMark), so ``` and
  // ~~~ never close each other.
  int _fenceChar = 0;
  int _fenceLength = 0;
  int _inlineCodeLength = 0;
  bool get _inlineCode => _inlineCodeLength != 0;
  bool _bold = false;
  bool _strike = false;
  int _brackets = 0;
  final List<int> _safeBoundaries = <int>[];

  int get stableEnd => _stableEnd;
  String get source => _source;

  /// [appendOnly] is for callers that own the source revision and explicitly
  /// reset on replacement. It avoids comparing the entire old prefix again.
  List<String> update(String source, {bool appendOnly = false}) {
    if (source.length < _source.length ||
        (!appendOnly && !source.startsWith(_source))) {
      _reset();
    }
    _source = source;
    _scanNewText();
    final target = source.length - tailChars;
    var nextEnd = _stableEnd;
    var consumed = 0;
    for (final boundary in _safeBoundaries) {
      if (boundary > target) break;
      if (boundary > nextEnd) nextEnd = boundary;
      consumed++;
    }
    if (consumed > 0) _safeBoundaries.removeRange(0, consumed);
    if (nextEnd <= _stableEnd) return const <String>[];
    final block = source.substring(_stableEnd, nextEnd);
    _stableEnd = nextEnd;
    return <String>[block];
  }

  String tail(String source) => source.substring(_stableEnd);

  void reset() => _reset();

  void _reset() {
    _source = '';
    _scanned = 0;
    _lineSearch = 0;
    _stableEnd = 0;
    _fenceChar = 0;
    _fenceLength = 0;
    _inlineCodeLength = 0;
    _bold = false;
    _strike = false;
    _brackets = 0;
    _safeBoundaries.clear();
  }

  void _scanNewText() {
    // Only commit syntax after a complete line arrives. A fence or inline
    // delimiter can be split at any byte boundary between provider events.
    // Remember the newline search cursor so a long unfinished line is not
    // searched from its beginning on every update.
    while (true) {
      final end = _source.indexOf('\n', _lineSearch);
      if (end < 0) {
        _lineSearch = _source.length;
        return;
      }
      final line = _source.substring(_scanned, end);
      _scanned = end + 1;
      _lineSearch = _scanned;
      final fence = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$').firstMatch(line);
      if (fence != null) {
        final run = fence.group(1)!;
        final char = run.codeUnitAt(0);
        final suffix = fence.group(2)!;
        if (_fenceChar == 0 && (char != 96 || !suffix.contains('`'))) {
          _fenceChar = char;
          _fenceLength = run.length;
          continue;
        }
        if (_fenceChar == char &&
            run.length >= _fenceLength &&
            suffix.trim().isEmpty) {
          _fenceChar = 0;
          _fenceLength = 0;
          continue;
        }
        // Inside a fence this is ordinary content; outside it the line only
        // looked like a fence (e.g. a backtick in the info string), so fall
        // through and scan it inline.
        if (_fenceChar != 0) continue;
      }
      if (_fenceChar != 0) continue;
      var index = 0;
      while (index < line.length) {
        if (!_inlineCode && line.codeUnitAt(index) == 92) {
          index += 2;
          continue;
        }
        if (!_inlineCode && line.startsWith('**', index)) {
          _bold = !_bold;
          index += 2;
          continue;
        }
        if (!_inlineCode && line.startsWith('~~', index)) {
          // Only an exact `~~` run toggles strikethrough. Longer tilde runs
          // (`~~~` and up) mid-line are literal text, never a strike marker.
          var runEnd = index + 2;
          while (runEnd < line.length && line.codeUnitAt(runEnd) == 126) {
            runEnd++;
          }
          if (runEnd == index + 2) _strike = !_strike;
          index = runEnd;
          continue;
        }
        final unit = line.codeUnitAt(index);
        if (unit == 96) {
          var end = index + 1;
          while (end < line.length && line.codeUnitAt(end) == 96) {
            end++;
          }
          final length = end - index;
          if (_inlineCodeLength == 0) {
            _inlineCodeLength = length;
          } else if (_inlineCodeLength == length) {
            _inlineCodeLength = 0;
          }
          index = end;
          continue;
        }
        if (!_inlineCode) {
          if (unit == 91) _brackets++;
          if (unit == 93 && _brackets > 0) _brackets--;
        }
        index++;
      }
      if (line.trim().isEmpty &&
          !_inlineCode &&
          !_bold &&
          !_strike &&
          _brackets == 0) {
        _safeBoundaries.add(_scanned);
      }
    }
  }
}

/// Keeps only a bounded tail mutable. A blank-line boundary is accepted only
/// when all fenced and inline constructs before it are balanced, so Markdown
/// syntax can never straddle the two independently rendered regions.
StreamingMarkdownSplit splitStableStreamingMarkdown(
  String text, {
  int tailChars = 6144,
}) {
  if (text.length <= tailChars) return StreamingMarkdownSplit('', text);
  final target = text.length - tailChars;
  var boundary = text.indexOf('\n\n', target);
  while (boundary > 0) {
    final prefix = text.substring(0, boundary + 2);
    final fences = _maskCodeFences(prefix);
    // Drop leftover tilde runs of 3+ so a stray `~~~` is never miscounted
    // as a `~~` strike delimiter below.
    final masked = fences.masked.replaceAll(RegExp(r'~{3,}'), ' ');
    final balancedInline = const ['**', '~~', '`'].every(
      (marker) =>
          RegExp(RegExp.escape(marker)).allMatches(masked).length.isEven,
    );
    final lastOpenBracket = masked.lastIndexOf('[');
    final lastCloseBracket = masked.lastIndexOf(']');
    if (fences.openFence == null &&
        balancedInline &&
        lastOpenBracket <= lastCloseBracket) {
      return StreamingMarkdownSplit(prefix, text.substring(boundary + 2));
    }
    boundary = text.indexOf('\n\n', boundary + 2);
  }
  return StreamingMarkdownSplit('', text);
}

/// Return [text] with any dangling markdown construct in its tail closed off,
/// so it renders as stable, well-formed markdown mid-stream.
String remendStreamingMarkdown(String text) {
  if (text.isEmpty) return text;
  var out = text;

  // 1. Fenced code block: an unclosed ``` or ~~~ fence (up to 3 spaces of
  //    indent, per CommonMark) means everything after it is raw code. Close
  //    it with the matching run and stop — inline rules don't apply inside.
  final fences = _maskCodeFences(out);
  if (fences.openFence != null) {
    if (!out.endsWith('\n')) out += '\n';
    return '$out${fences.openFence}';
  }

  // Fences are balanced at this point (step 1 already handled the odd case),
  // so the pair-scanning below must not be thrown off by literal `[`, `**`,
  // `~~` or `` ` `` characters that live *inside* a completed code block —
  // Python's `a ** b`, a shell `` `date` `` substitution, or a truncated
  // `arr[` mid-index are all extremely common in tool/code output. Mask
  // fenced content out (same length, so indices into `out` stay valid) for
  // the scans below; actual trimming/appending still happens on `out`.
  final masked = fences.masked;

  // 2. A link/image whose target hasn't streamed in yet: `[label](…` or a lone
  //    `[label` with no closing bracket. Trim back to before the `[` so it
  //    doesn't render as a broken link that repairs itself a frame later.
  final lastOpen = masked.lastIndexOf('[');
  if (lastOpen != -1) {
    final rest = out.substring(lastOpen);
    final fullyClosed = RegExp(r'^!?\[[^\]]*\]\([^)]*\)').hasMatch(rest);
    final bareClosed = RegExp(r'^!?\[[^\]]*\](?!\()').hasMatch(rest);
    if (!fullyClosed && !bareClosed) {
      // `![` is an image marker: cut the adjacent `!` too so it isn't left
      // behind as a stray literal bang in the stable prefix.
      final cut =
          lastOpen > 0 && out.codeUnitAt(lastOpen - 1) == 33 // '!'
              ? lastOpen - 1
              : lastOpen;
      out = out.substring(0, cut).trimRight();
    }
  }

  // 3. Balance the paired inline markers that cause the worst flicker.
  //    Longer markers first so `**` isn't mistaken for two `*`. Re-mask:
  //    step 2 may have shortened `out`, so the step-2 mask (sized for the
  //    pre-trim string) can no longer be trusted here. Tilde runs of 3+ are
  //    literal text (or fence markers), never `~~` strike delimiters — drop
  //    them so they can't fake an odd `~~` count.
  final maskedForMarkers = _maskCodeFences(
    out,
  ).masked.replaceAll(RegExp(r'~{3,}'), ' ');
  for (final marker in const ['**', '~~', '`']) {
    final count = RegExp(
      RegExp.escape(marker),
    ).allMatches(maskedForMarkers).length;
    if (count.isOdd) out += marker;
  }

  return out;
}

({String masked, String? openFence}) _maskCodeFences(String text) {
  final buffer = StringBuffer();
  String? open;
  final pattern = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
  var start = 0;
  while (start < text.length) {
    final newline = text.indexOf('\n', start);
    final end = newline < 0 ? text.length : newline;
    final line = text.substring(start, end);
    final match = pattern.firstMatch(line);
    var masked = open != null;
    if (match != null) {
      final run = match.group(1)!;
      final suffix = match.group(2)!;
      if (open == null && (run[0] != '`' || !suffix.contains('`'))) {
        open = run;
        masked = true;
      } else if (open != null &&
          run[0] == open[0] &&
          run.length >= open.length &&
          suffix.trim().isEmpty) {
        open = null;
      }
    }
    buffer.write(masked ? ' ' * line.length : line);
    if (newline >= 0) buffer.write('\n');
    start = end + 1;
  }
  return (masked: buffer.toString(), openFence: open);
}
