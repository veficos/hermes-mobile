library;

enum ComposerTokenKind { text, slash, file, folder, url, image, session }

class ComposerToken {
  final ComposerTokenKind kind;
  final String value;
  final int start;
  final int end;

  const ComposerToken({
    required this.kind,
    required this.value,
    required this.start,
    required this.end,
  });

  bool get atomic => kind != ComposerTokenKind.text;
}

List<ComposerToken> parseComposerTokens(String source) {
  if (source.isEmpty) return const [];
  final matches = RegExp(
    r'^/[\w.-]+(?=\s|$)|@(file|folder|url|image|session):(?:`[^`]+`|\S+)|https?://\S+',
    multiLine: true,
  ).allMatches(source);
  final result = <ComposerToken>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      result.add(
        ComposerToken(
          kind: ComposerTokenKind.text,
          value: source.substring(cursor, match.start),
          start: cursor,
          end: match.start,
        ),
      );
    }
    final value = match.group(0)!;
    final kind = value.startsWith('/')
        ? ComposerTokenKind.slash
        : value.startsWith('@file:')
        ? ComposerTokenKind.file
        : value.startsWith('@folder:')
        ? ComposerTokenKind.folder
        : value.startsWith('@image:')
        ? ComposerTokenKind.image
        : value.startsWith('@session:')
        ? ComposerTokenKind.session
        : ComposerTokenKind.url;
    result.add(
      ComposerToken(
        kind: kind,
        value: value,
        start: match.start,
        end: match.end,
      ),
    );
    cursor = match.end;
  }
  if (cursor < source.length) {
    result.add(
      ComposerToken(
        kind: ComposerTokenKind.text,
        value: source.substring(cursor),
        start: cursor,
        end: source.length,
      ),
    );
  }
  return List.unmodifiable(result);
}

String serializeComposerTokens(Iterable<ComposerToken> tokens) =>
    tokens.map((token) => token.value).join();

ComposerToken? tokenAtOffset(List<ComposerToken> tokens, int offset) {
  for (final token in tokens) {
    if (token.atomic && offset >= token.start && offset <= token.end) {
      return token;
    }
  }
  return null;
}
