library;

import 'models.dart';

enum ComposerReferenceKind {
  file,
  folder,
  url,
  image,
  tool,
  git,
  diff,
  staged,
  session,
  contributed,
}

extension ComposerReferenceKindWire on ComposerReferenceKind {
  String get wireName => switch (this) {
    ComposerReferenceKind.file => 'file',
    ComposerReferenceKind.folder => 'folder',
    ComposerReferenceKind.url => 'url',
    ComposerReferenceKind.image => 'image',
    ComposerReferenceKind.tool => 'tool',
    ComposerReferenceKind.git => 'git',
    ComposerReferenceKind.diff => 'diff',
    ComposerReferenceKind.staged => 'staged',
    ComposerReferenceKind.session => 'session',
    ComposerReferenceKind.contributed => 'contributed',
  };
}

class ComposerReferenceSuggestion {
  final String id;
  final ComposerReferenceKind kind;
  final String insertText;
  final String display;
  final String? description;
  final bool isContainer;

  const ComposerReferenceSuggestion({
    required this.id,
    required this.kind,
    required this.insertText,
    required this.display,
    this.description,
    this.isContainer = false,
  });
}

class ComposerReferenceQuery {
  final int start;
  final int end;
  final String raw;
  final String query;
  final ComposerReferenceKind? kind;

  const ComposerReferenceQuery({
    required this.start,
    required this.end,
    required this.raw,
    required this.query,
    this.kind,
  });

  bool get isTyped => kind != null;
}

const _typedKinds = <String, ComposerReferenceKind>{
  'file': ComposerReferenceKind.file,
  'folder': ComposerReferenceKind.folder,
  'url': ComposerReferenceKind.url,
  'image': ComposerReferenceKind.image,
  'tool': ComposerReferenceKind.tool,
  'git': ComposerReferenceKind.git,
};

/// Finds the active @ reference at the caret. Unlike the previous trailing
/// regex this works in the middle of a draft and keeps the replacement range.
ComposerReferenceQuery? composerReferenceQuery(String source, {int? caret}) {
  final end = (caret ?? source.length).clamp(0, source.length);
  final prefix = source.substring(0, end);
  final match = RegExp(r'(^|\s)(@[^\s]*)$').firstMatch(prefix);
  if (match == null) return null;
  final raw = match.group(2)!;
  final body = raw.substring(1);
  final colon = body.indexOf(':');
  if (colon < 0) {
    return ComposerReferenceQuery(
      start: end - raw.length,
      end: end,
      raw: raw,
      query: body,
    );
  }
  final name = body.substring(0, colon).toLowerCase();
  final kind = _typedKinds[name];
  if (kind == null) return null;
  return ComposerReferenceQuery(
    start: end - raw.length,
    end: end,
    raw: raw,
    query: body.substring(colon + 1),
    kind: kind,
  );
}

List<ComposerReferenceSuggestion> composerReferenceStarters(String query) {
  final normalized = query.toLowerCase();
  final values = <ComposerReferenceSuggestion>[
    for (final entry in _typedKinds.entries)
      ComposerReferenceSuggestion(
        id: 'starter:${entry.key}',
        kind: entry.value,
        insertText: '@${entry.key}:',
        display: '@${entry.key}:',
        description: switch (entry.value) {
          ComposerReferenceKind.file => 'Attach a file reference',
          ComposerReferenceKind.folder => 'Attach a folder reference',
          ComposerReferenceKind.url => 'Attach a URL reference',
          ComposerReferenceKind.image => 'Attach an image reference',
          ComposerReferenceKind.tool => 'Attach a tool reference',
          ComposerReferenceKind.git => 'Attach git context',
          _ => null,
        },
        isContainer: true,
      ),
    const ComposerReferenceSuggestion(
      id: 'simple:diff',
      kind: ComposerReferenceKind.diff,
      insertText: '@diff',
      display: '@diff',
      description: 'Attach the current diff',
    ),
    const ComposerReferenceSuggestion(
      id: 'simple:staged',
      kind: ComposerReferenceKind.staged,
      insertText: '@staged',
      display: '@staged',
      description: 'Attach staged changes',
    ),
  ];
  return values
      .where((item) => item.insertText.substring(1).startsWith(normalized))
      .toList(growable: false);
}

ComposerReferenceSuggestion referenceSuggestionFromPath(
  PathSuggestion path,
  ComposerReferenceQuery query,
) {
  final kind =
      query.kind ??
      (path.isDirectory
          ? ComposerReferenceKind.folder
          : ComposerReferenceKind.file);
  final raw = path.referenceText;
  final value = raw.startsWith('@') ? raw : '@${kind.wireName}:${path.path}';
  return ComposerReferenceSuggestion(
    id: 'gateway:$value',
    kind: kind,
    insertText: value,
    display: path.displayName,
    description: path.meta ?? path.path,
    isContainer: path.isDirectory,
  );
}

String replaceComposerReference(
  String source,
  ComposerReferenceQuery query,
  ComposerReferenceSuggestion suggestion, {
  bool descend = false,
}) {
  var insert = suggestion.insertText;
  if (descend &&
      suggestion.isContainer &&
      !insert.endsWith(':') &&
      !insert.endsWith('/')) {
    insert = '$insert/';
  }
  final needsSpace = !descend && !suggestion.isContainer;
  return source.replaceRange(
    query.start,
    query.end,
    '$insert${needsSpace ? ' ' : ''}',
  );
}

/// One-segment ascent for hardware-keyboard Backspace navigation.
String? ascendComposerReference(String source, ComposerReferenceQuery query) {
  if (!query.isTyped || query.query.isEmpty) return null;
  var value = query.query;
  if (value.endsWith('/')) value = value.substring(0, value.length - 1);
  final slash = value.lastIndexOf('/');
  final parent = slash < 0 ? '' : value.substring(0, slash + 1);
  final replacement = '@${query.kind!.wireName}:$parent';
  return source.replaceRange(query.start, query.end, replacement);
}

class ComposerEmojiSuggestion {
  final String shortcode;
  final String emoji;
  final List<String> keywords;

  const ComposerEmojiSuggestion(
    this.shortcode,
    this.emoji, [
    this.keywords = const [],
  ]);
}

const composerEmojiCatalog = <ComposerEmojiSuggestion>[
  ComposerEmojiSuggestion('joy', '😂', ['laugh', 'happy']),
  ComposerEmojiSuggestion('laughing', '😆', ['happy']),
  ComposerEmojiSuggestion('smile', '😄', ['happy']),
  ComposerEmojiSuggestion('heart', '❤️', ['love']),
  ComposerEmojiSuggestion('thumbsup', '👍', ['like', '+1']),
  ComposerEmojiSuggestion('thumbsdown', '👎', ['dislike', '-1']),
  ComposerEmojiSuggestion('tada', '🎉', ['party']),
  ComposerEmojiSuggestion('fire', '🔥', ['lit']),
  ComposerEmojiSuggestion('rocket', '🚀', ['launch']),
  ComposerEmojiSuggestion('sparkles', '✨', ['shine']),
  ComposerEmojiSuggestion('warning', '⚠️', ['alert']),
  ComposerEmojiSuggestion('white_check_mark', '✅', ['done', 'check']),
  ComposerEmojiSuggestion('x', '❌', ['close', 'cancel']),
  ComposerEmojiSuggestion('eyes', '👀', ['look']),
  ComposerEmojiSuggestion('thinking', '🤔', ['hmm']),
  ComposerEmojiSuggestion('pray', '🙏', ['please', 'thanks']),
  ComposerEmojiSuggestion('wave', '👋', ['hello']),
  ComposerEmojiSuggestion('bug', '🐛', ['debug']),
  ComposerEmojiSuggestion('bulb', '💡', ['idea']),
  ComposerEmojiSuggestion('memo', '📝', ['note']),
];

({int start, int end, String query})? composerEmojiQuery(
  String source, {
  int? caret,
}) {
  final end = (caret ?? source.length).clamp(0, source.length);
  final match = RegExp(
    r'(^|\s):([a-z0-9_+-]{2,})$',
  ).firstMatch(source.substring(0, end));
  if (match == null) return null;
  final raw = match.group(0)!;
  final leading = match.group(1)!.length;
  return (
    start: end - raw.length + leading,
    end: end,
    query: match.group(2)!.toLowerCase(),
  );
}

List<ComposerEmojiSuggestion> composerEmojiSuggestions(String query) {
  final q = query.toLowerCase();
  final result = composerEmojiCatalog.where((item) {
    return item.shortcode.startsWith(q) ||
        item.shortcode.contains(q) ||
        item.keywords.any((word) => word.contains(q));
  }).toList();
  result.sort((a, b) {
    final ap = a.shortcode.startsWith(q);
    final bp = b.shortcode.startsWith(q);
    if (ap != bp) return ap ? -1 : 1;
    return a.shortcode.compareTo(b.shortcode);
  });
  return result.take(8).toList(growable: false);
}
