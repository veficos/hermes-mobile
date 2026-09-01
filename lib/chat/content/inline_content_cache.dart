import 'dart:collection';

import 'inline_content.dart';
import 'reference_chips.dart';

class PreparedInlineContent {
  const PreparedInlineContent({
    required this.body,
    required this.nodes,
    required this.references,
  });

  final String body;
  final List<InlineContentNode> nodes;
  final List<MessageReference> references;
}

/// Bounded cache for immutable transcript preprocessing. It deliberately
/// stores data models, not widgets or BuildContexts.
class InlineContentCache {
  InlineContentCache._();
  static final InlineContentCache instance = InlineContentCache._();

  static const int maxEntries = 256;
  static const int maxSourceChars = 2000000;
  final LinkedHashMap<String, PreparedInlineContent> _entries =
      LinkedHashMap<String, PreparedInlineContent>();
  int _sourceChars = 0;

  int get entryCount => _entries.length;
  int get sourceChars => _sourceChars;

  PreparedInlineContent prepare(String text, {bool cache = true}) {
    if (cache) {
      final hit = _entries.remove(text);
      if (hit != null) {
        _entries[text] = hit;
        return hit;
      }
    }
    final references = List<MessageReference>.unmodifiable(
      extractMessageReferences(text),
    );
    final body = references.isEmpty ? text : stripMessageReferences(text);
    final prepared = PreparedInlineContent(
      body: body,
      nodes: List<InlineContentNode>.unmodifiable(parseInlineContent(body)),
      references: references,
    );
    if (cache && text.length <= maxSourceChars ~/ 2) {
      _entries[text] = prepared;
      _sourceChars += text.length;
      while (_entries.length > maxEntries || _sourceChars > maxSourceChars) {
        final oldest = _entries.keys.first;
        _sourceChars -= oldest.length;
        _entries.remove(oldest);
      }
    }
    return prepared;
  }

  void clear() {
    _entries.clear();
    _sourceChars = 0;
  }
}
