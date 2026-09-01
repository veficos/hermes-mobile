import '../../core/message_preview_targets.dart';
import '../../core/preview_bridge.dart';

sealed class InlineContentNode {
  const InlineContentNode();
}

class InlineTextNode extends InlineContentNode {
  final String text;
  const InlineTextNode(this.text);
}

class InlineCodeNode extends InlineContentNode {
  final String code;
  final String language;
  const InlineCodeNode(this.code, this.language);
}

class InlineDirectiveNode extends InlineContentNode {
  final String name;
  final String value;
  const InlineDirectiveNode(this.name, this.value);
}

class InlinePreviewNode extends InlineContentNode {
  final MessagePreviewTarget target;
  const InlinePreviewNode(this.target);
}

/// GitHub-flavored alert / admonition block (`> [!NOTE]` … `> [!CAUTION]`).
/// Desktop parity: `embeds/alert.tsx`. [type] is lower-case
/// (note | tip | important | warning | caution); [body] is the remaining
/// markdown source with the `>` quote markers stripped.
class InlineAlertNode extends InlineContentNode {
  final String type;
  final String body;
  const InlineAlertNode(this.type, this.body);
}

/// A standalone display equation (`$$ … $$` or `\[ … \]`). Desktop KaTeX
/// parity.
class InlineMathNode extends InlineContentNode {
  final String tex;
  const InlineMathNode(this.tex);
}

/// A `::preview{file="…"}` directive — a workspace file the agent wants shown
/// inline. Desktop renders it as a live sandboxed iframe; mobile renders a
/// card that opens the file in the WebView preview page.
class InlinePreviewFileNode extends InlineContentNode {
  final String file;
  final double? initialHeight;
  const InlinePreviewFileNode(this.file, {this.initialHeight});
}

/// A generic plugin-owned transcript directive: `::name{key="value"}`.
class InlinePluginDirectiveNode extends InlineContentNode {
  final String name;
  final Map<String, String> attributes;
  final String source;
  const InlinePluginDirectiveNode(this.name, this.attributes, this.source);
}

/// A run of prose that carries inline math (`$ … $` / `\( … \)`). Rendered as
/// one flowing line: plain-text spans interleaved with `Math.tex` widget
/// spans. Markdown emphasis inside such a run is not re-applied (rare in
/// practice — inline-math sentences are plain prose).
class InlineRichNode extends InlineContentNode {
  final List<InlineRichSegment> segments;
  const InlineRichNode(this.segments);
}

class InlineRichSegment {
  final String value;
  final bool isMath;
  const InlineRichSegment(this.value, {required this.isMath});
}

const _alertTypes = {'note', 'tip', 'important', 'warning', 'caution'};
final _alertMarker = RegExp(
  r'^ {0,3}>\s?\[!(note|tip|important|warning|caution)\]\s*$',
  caseSensitive: false,
);
final _quoteStrip = RegExp(r'^ {0,3}>\s?');

// $$ … $$  or  \[ … \]  — display math.
final _blockMath = RegExp(r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]');
// $ … $  (not $$)  or  \( … \)  — inline math.
final _inlineMath = RegExp(
  r'(?<![\$\\])\$(?!\$)([^\$\n]+?)(?<!\\)\$(?!\$)|\\\(([\s\S]+?)\\\)',
);

List<InlineContentNode> parseInlineContent(String text) {
  final nodes = <InlineContentNode>[];
  final fence = RegExp(r'```([\w+-]*)\n([\s\S]*?)```', multiLine: true);
  var cursor = 0;
  for (final match in fence.allMatches(text)) {
    if (match.start > cursor) {
      nodes.addAll(_blocks(text.substring(cursor, match.start)));
    }
    nodes.add(InlineCodeNode(match.group(2) ?? '', match.group(1) ?? ''));
    cursor = match.end;
  }
  if (cursor < text.length) nodes.addAll(_blocks(text.substring(cursor)));
  return nodes;
}

/// Split a non-fenced chunk into GitHub alert blocks and plain runs, then hand
/// each plain run to [_mathAndText].
List<InlineContentNode> _blocks(String text) {
  final nodes = <InlineContentNode>[];
  final lines = text.split('\n');
  final plain = StringBuffer();

  void flushPlain() {
    if (plain.isEmpty) return;
    nodes.addAll(_mathAndText(plain.toString()));
    plain.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final marker = _alertMarker.firstMatch(lines[i]);
    if (marker == null) {
      plain.write(lines[i]);
      if (i != lines.length - 1) plain.write('\n');
      continue;
    }
    final bodyLines = <String>[];
    var j = i + 1;
    while (j < lines.length && lines[j].trimLeft().startsWith('>')) {
      bodyLines.add(lines[j].replaceFirst(_quoteStrip, ''));
      j++;
    }
    final type = marker.group(1)!.toLowerCase();
    if (_alertTypes.contains(type)) {
      flushPlain();
      nodes.add(InlineAlertNode(type, bodyLines.join('\n').trim()));
      i = j - 1;
    } else {
      plain.write(lines[i]);
      if (i != lines.length - 1) plain.write('\n');
    }
  }
  flushPlain();
  return nodes;
}

/// Split display equations into [InlineMathNode]s; hand the prose between them
/// to [_inlineMathRun].
List<InlineContentNode> _mathAndText(String text) {
  final nodes = <InlineContentNode>[];
  var cursor = 0;
  for (final match in _blockMath.allMatches(text)) {
    if (match.start > cursor) {
      nodes.addAll(_inlineMathRun(text.substring(cursor, match.start)));
    }
    final tex = (match.group(1) ?? match.group(2) ?? '').trim();
    if (tex.isNotEmpty) nodes.add(InlineMathNode(tex));
    cursor = match.end;
  }
  if (cursor < text.length) {
    nodes.addAll(_inlineMathRun(text.substring(cursor)));
  }
  return nodes;
}

/// A prose run: plain [InlineTextNode] when it has no inline math, otherwise a
/// single [InlineRichNode] that flows text + `Math.tex` on one line.
List<InlineContentNode> _inlineMathRun(String text) {
  if (text.isEmpty) return const [];
  if (!_inlineMath.hasMatch(text)) return _textAndTargets(text);

  final segments = <InlineRichSegment>[];
  var cursor = 0;
  for (final match in _inlineMath.allMatches(text)) {
    if (match.start > cursor) {
      segments.add(
        InlineRichSegment(text.substring(cursor, match.start), isMath: false),
      );
    }
    final tex = (match.group(1) ?? match.group(2) ?? '').trim();
    if (tex.isNotEmpty) segments.add(InlineRichSegment(tex, isMath: true));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(InlineRichSegment(text.substring(cursor), isMath: false));
  }
  return [InlineRichNode(segments)];
}

final _previewDirective = RegExp(r'::preview\{([^}\n]*)\}');
final _previewAttr = RegExp(
  r'''([a-zA-Z][\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s}]+))''',
);

List<InlineContentNode> _textAndTargets(String text) {
  final nodes = <InlineContentNode>[];
  // `::preview{file="…"}` first — it can sit mid-line among prose.
  var cursor = 0;
  for (final match in _previewDirective.allMatches(text)) {
    if (match.start > cursor) {
      nodes.addAll(_bracketDirectives(text.substring(cursor, match.start)));
    }
    final attributes = <String, String>{};
    for (final attr in _previewAttr.allMatches(match.group(1) ?? '')) {
      attributes[attr.group(1)!.toLowerCase()] =
          attr.group(2) ?? attr.group(3) ?? attr.group(4) ?? '';
    }
    final file = (attributes['file'] ?? '').trim();
    if (file.isNotEmpty) {
      nodes.add(
        InlinePreviewFileNode(
          file,
          initialHeight: parsePreviewHeight(attributes['height']),
        ),
      );
    } else {
      nodes.add(InlineTextNode(match.group(0)!));
    }
    cursor = match.end;
  }
  nodes.addAll(_pluginDirectives(cursor == 0 ? text : text.substring(cursor)));
  return nodes;
}

final _pluginDirectiveLine = RegExp(
  r'^\s*::([a-zA-Z][\w-]*)(?:\{([^}\n]*)\})?\s*$',
);
final _pluginDirectiveAttr = RegExp(
  r'''([a-zA-Z][\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')''',
);

List<InlineContentNode> _pluginDirectives(String text) {
  if (text.isEmpty) return const [];
  final nodes = <InlineContentNode>[];
  final plain = StringBuffer();
  void flush() {
    if (plain.isEmpty) return;
    nodes.addAll(_bracketDirectives(plain.toString()));
    plain.clear();
  }

  final lines = text.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final match = _pluginDirectiveLine.firstMatch(line);
    if (match == null || match.group(1) == 'preview') {
      plain.write(line);
      if (index != lines.length - 1) plain.write('\n');
      continue;
    }
    flush();
    final attrs = <String, String>{};
    for (final attr in _pluginDirectiveAttr.allMatches(match.group(2) ?? '')) {
      attrs[attr.group(1)!.toLowerCase()] =
          attr.group(2) ?? attr.group(3) ?? '';
    }
    nodes.add(InlinePluginDirectiveNode(match.group(1)!, attrs, line.trim()));
  }
  flush();
  return nodes;
}

List<InlineContentNode> _bracketDirectives(String text) {
  if (text.isEmpty) return const [];
  final nodes = <InlineContentNode>[];
  final directive = RegExp(r'\[\[([a-zA-Z][\w-]*):([^\]]+)\]\]');
  var cursor = 0;
  for (final match in directive.allMatches(text)) {
    if (match.start > cursor) {
      nodes.add(InlineTextNode(text.substring(cursor, match.start)));
    }
    nodes.add(InlineDirectiveNode(match.group(1)!, match.group(2)!));
    cursor = match.end;
  }
  final remainder = cursor < text.length ? text.substring(cursor) : '';
  if (remainder.isNotEmpty) {
    final targets = extractMessagePreviewTargets(remainder);
    nodes.add(InlineTextNode(remainder));
    nodes.addAll(targets.map(InlinePreviewNode.new));
  }
  return nodes;
}
