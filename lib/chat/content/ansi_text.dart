import 'package:flutter/material.dart';

/// Renders text that may contain ANSI SGR escape sequences (`\x1B[…m`) as
/// coloured spans. Desktop parity: `components/assistant-ui/ansi-text.tsx`.
/// Unsupported / malformed sequences are dropped so raw `\x1B[` noise never
/// reaches the reader.
class AnsiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool selectable;

  const AnsiText({
    super.key,
    required this.text,
    this.style,
    this.selectable = true,
  });

  /// True when [text] carries at least one ANSI escape — callers use this to
  /// decide whether to route through here at all.
  static bool contains(String text) => text.contains('\x1B[');

  @override
  Widget build(BuildContext context) {
    final base = (style ?? const TextStyle()).copyWith(fontFamily: 'monospace');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final span = TextSpan(children: parseAnsi(text, base, isDark));
    return selectable ? SelectableText.rich(span) : Text.rich(span);
  }
}

/// The 16 standard terminal colours (normal 30–37 / bright 90–97), tuned for
/// legibility on both themes.
const _dark16 = <Color>[
  Color(0xFF3B4048),
  Color(0xFFE06C75),
  Color(0xFF98C379),
  Color(0xFFE5C07B),
  Color(0xFF61AFEF),
  Color(0xFFC678DD),
  Color(0xFF56B6C2),
  Color(0xFFABB2BF),
  Color(0xFF5C6370),
  Color(0xFFE06C75),
  Color(0xFF98C379),
  Color(0xFFE5C07B),
  Color(0xFF61AFEF),
  Color(0xFFC678DD),
  Color(0xFF56B6C2),
  Color(0xFFFFFFFF),
];
const _light16 = <Color>[
  Color(0xFF383A42),
  Color(0xFFD41D1D),
  Color(0xFF1D7A28),
  Color(0xFF9A6700),
  Color(0xFF1D6FD4),
  Color(0xFF8B2FB8),
  Color(0xFF0B7A85),
  Color(0xFF383A42),
  Color(0xFF8A8F98),
  Color(0xFFD41D1D),
  Color(0xFF1D7A28),
  Color(0xFF9A6700),
  Color(0xFF1D6FD4),
  Color(0xFF8B2FB8),
  Color(0xFF0B7A85),
  Color(0xFF000000),
];

Color _cube(int n) {
  // xterm 256: 16..231 = 6×6×6 cube, 232..255 = greyscale ramp.
  if (n < 16) return const Color(0xFF808080);
  if (n >= 232) {
    final v = 8 + (n - 232) * 10;
    return Color.fromARGB(255, v, v, v);
  }
  final c = n - 16;
  int comp(int x) => x == 0 ? 0 : 55 + x * 40;
  return Color.fromARGB(
    255,
    comp((c ~/ 36) % 6),
    comp((c ~/ 6) % 6),
    comp(c % 6),
  );
}

final _sgr = RegExp(r'\x1B\[([0-9;]*)m');

List<InlineSpan> parseAnsi(String text, TextStyle base, bool isDark) {
  final palette = isDark ? _dark16 : _light16;
  final spans = <InlineSpan>[];
  var current = base;
  var cursor = 0;

  void emit(String chunk) {
    if (chunk.isEmpty) return;
    // Strip any non-SGR escape (cursor moves, clears, OSC …) so they don't
    // print as garbage.
    final clean = chunk
        .replaceAll(RegExp(r'\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)'), '')
        .replaceAll(RegExp(r'\x1B[\[\]()][0-9;?]*[A-Za-z]'), '')
        // A dangling CSI sequence with no final byte yet — e.g. tool output
        // hard-truncated mid `\x1B[38;5;123m` for display, or streamed text
        // cut off before the terminator arrives. None of the complete-form
        // regexes above match it, so without this it would otherwise print
        // as raw "[38;5;123" noise; drop it wholesale instead.
        .replaceAll(RegExp(r'\x1B\[[0-9;?]*$'), '')
        .replaceAll('\x1B', '');
    if (clean.isNotEmpty) spans.add(TextSpan(text: clean, style: current));
  }

  for (final match in _sgr.allMatches(text)) {
    emit(text.substring(cursor, match.start));
    cursor = match.end;
    final raw = match.group(1) ?? '';
    final codes = raw.isEmpty
        ? [0]
        : raw.split(';').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];
      if (code == 0) {
        current = base;
      } else if (code == 1) {
        current = current.copyWith(fontWeight: FontWeight.bold);
      } else if (code == 2) {
        current = current.copyWith(
          color: (current.color ?? base.color ?? Colors.grey).withValues(
            alpha: 0.6,
          ),
        );
      } else if (code == 3) {
        current = current.copyWith(fontStyle: FontStyle.italic);
      } else if (code == 4) {
        current = current.copyWith(decoration: TextDecoration.underline);
      } else if (code == 22) {
        current = current.copyWith(fontWeight: FontWeight.normal);
      } else if (code == 23) {
        current = current.copyWith(fontStyle: FontStyle.normal);
      } else if (code == 24) {
        current = current.copyWith(decoration: TextDecoration.none);
      } else if (code == 39) {
        current = current.copyWith(color: base.color);
      } else if (code >= 30 && code <= 37) {
        current = current.copyWith(color: palette[code - 30]);
      } else if (code >= 90 && code <= 97) {
        current = current.copyWith(color: palette[code - 90 + 8]);
      } else if (code == 38 && i + 2 < codes.length && codes[i + 1] == 5) {
        current = current.copyWith(color: _cube(codes[i + 2]));
        i += 2;
      } else if (code == 38 && i + 4 < codes.length && codes[i + 1] == 2) {
        current = current.copyWith(
          color: Color.fromARGB(255, codes[i + 2], codes[i + 3], codes[i + 4]),
        );
        i += 4;
      } else if (code == 48 && i + 2 < codes.length && codes[i + 1] == 5) {
        current = current.copyWith(backgroundColor: _cube(codes[i + 2]));
        i += 2;
      }
      // 40–47 / 49 (background) mostly hurt legibility on a chat surface — skip.
    }
  }
  emit(text.substring(cursor));
  return spans.isEmpty ? [TextSpan(text: '', style: base)] : spans;
}
