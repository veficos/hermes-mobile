import 'composer_reference_completion.dart';

enum CompletionKind { slash, path, session, emoji, url, plugin }

class CompletionQuery {
  final CompletionKind kind;
  final String query;
  final int replaceStart;
  final int replaceEnd;
  const CompletionQuery({
    required this.kind,
    required this.query,
    required this.replaceStart,
    required this.replaceEnd,
  });
}

CompletionQuery? detectCompletionQuery(String text, {int? caret}) {
  final end = (caret ?? text.length).clamp(0, text.length);
  final prefix = text.substring(0, end);
  final ref = composerReferenceQuery(text, caret: end);
  if (ref != null) {
    final kind = switch (ref.kind) {
      ComposerReferenceKind.session => CompletionKind.session,
      ComposerReferenceKind.url => CompletionKind.url,
      _ => CompletionKind.path,
    };
    return CompletionQuery(
      kind: kind,
      query: ref.query,
      replaceStart: ref.start,
      replaceEnd: ref.end,
    );
  }
  final slash = RegExp(r'(^|\s)/([^\s]*)$').firstMatch(prefix);
  if (slash != null) {
    return CompletionQuery(
      kind: CompletionKind.slash,
      query: slash.group(2)!,
      replaceStart: end - slash.group(2)!.length - 1,
      replaceEnd: end,
    );
  }
  // Argument stage: the command token is complete (`/cmd arg…`), completion
  // continues for the argument suffix. `query` carries the command name (used
  // for merging local commands); the actual replacement range comes from the
  // gateway's `replace_from`.
  final slashArgs = RegExp(r'^/([^\s]+)\s').firstMatch(prefix);
  if (slashArgs != null) {
    return CompletionQuery(
      kind: CompletionKind.slash,
      query: slashArgs.group(1)!,
      replaceStart: 1,
      replaceEnd: end,
    );
  }
  final emoji = RegExp(r'(^|\s):([A-Za-z0-9_+-]*)$').firstMatch(prefix);
  if (emoji != null) {
    return CompletionQuery(
      kind: CompletionKind.emoji,
      query: emoji.group(2)!,
      replaceStart: end - emoji.group(2)!.length - 1,
      replaceEnd: end,
    );
  }
  return null;
}
