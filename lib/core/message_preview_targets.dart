library;

enum MessagePreviewKind { session, url, file }

class MessagePreviewTarget {
  final MessagePreviewKind kind;
  final String value;
  const MessagePreviewTarget(this.kind, this.value);
}

List<MessagePreviewTarget> extractMessagePreviewTargets(
  String text, {
  int limit = 3,
}) {
  final found = <String, MessagePreviewTarget>{};
  final patterns = <(MessagePreviewKind, RegExp)>[
    (
      MessagePreviewKind.session,
      RegExp(r'(?<![\w/])@session:([^\s)\],;.!?]+)'),
    ),
    (MessagePreviewKind.url, RegExp(r'https?://[^\s<>]+')),
    (MessagePreviewKind.file, RegExp(r'file://[^\s<>]+')),
  ];
  for (final (kind, pattern) in patterns) {
    for (final match in pattern.allMatches(text)) {
      var value = match.group(kind == MessagePreviewKind.session ? 1 : 0)!;
      value = value.replaceAll(RegExp(r'''^[`"']|[`"']$'''), '');
      if (value.isEmpty) continue;
      found.putIfAbsent(
        '$kind:$value',
        () => MessagePreviewTarget(kind, value),
      );
      if (found.length >= limit) return found.values.toList(growable: false);
    }
  }
  return found.values.toList(growable: false);
}
