/// Rewrite bare long URLs into `[host/short…](url)` so the transcript shows a
/// readable label instead of a full query-string wall (desktop `PrettyLink`).
///
/// Deliberately conservative: skips anything already inside a `[label](url)`
/// or an autolink `<url>`, skips fenced/inline code, and only shortens URLs
/// past a length threshold.
library;

const _shortenOver = 48;

final _fence = RegExp(r'```[\s\S]*?```', multiLine: true);
final _inlineCode = RegExp(r'`[^`]*`');
final _bareUrl = RegExp(r'(?<![\(\<\]])\bhttps?://[^\s<>()\[\]]+');
final _imageLink = RegExp(
  r'(?<!!)\[([^\]]*)\]\((https?://[^\s()]+\.(?:png|jpe?g|gif|webp|bmp)(?:\?[^\s()]*)?)\)',
  caseSensitive: false,
);

String _label(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host.replaceFirst('www.', '');
  var path = uri.path;
  if (path.length > 24) path = '${path.substring(0, 23)}…';
  final tail = uri.hasQuery ? '?…' : '';
  return '$host$path$tail';
}

/// Runs [transform] over [text] with fenced/inline code spans swapped out
/// first (and restored after), so neither pass ever touches a literal
/// markdown example inside a code block.
String _withCodeProtected(String text, String Function(String) transform) {
  final protected = <String>[];
  String stash(Match m) {
    protected.add(m.group(0)!);
    return '\u0000${protected.length - 1}\u0000';
  }

  var out = transform(
    text.replaceAllMapped(_fence, stash).replaceAllMapped(_inlineCode, stash),
  );

  for (var i = 0; i < protected.length; i++) {
    out = out.replaceFirst('\u0000$i\u0000', protected[i]);
  }
  return out;
}

String prettifyBareLinks(String text) {
  if (!text.contains('http')) return text;
  return _withCodeProtected(
    text,
    (body) => body.replaceAllMapped(_bareUrl, (m) {
      final url = m.group(0)!;
      // Trailing punctuation shouldn't be swallowed into the link.
      final trailing = RegExp(r'[.,;:!?)]+$').firstMatch(url)?.group(0) ?? '';
      final clean = url.substring(0, url.length - trailing.length);
      if (clean.length <= _shortenOver) return url;
      return '[${_label(clean)}]($clean)$trailing';
    }),
  );
}

/// A plain `[label](url)` link whose URL points straight at an image file
/// renders as an inline picture instead — models frequently write link
/// syntax instead of `![label](url)` for a generated/attached image, and a
/// tappable text link is a poor substitute for actually seeing the picture.
/// Already-real image syntax (`![...]`) is left untouched.
String upgradeImageLinks(String text) {
  if (!text.contains('](')) return text;
  return _withCodeProtected(
    text,
    (body) => body.replaceAllMapped(
      _imageLink,
      (m) => '![${m.group(1)}](${m.group(2)})',
    ),
  );
}
