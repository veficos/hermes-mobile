/// Bounded text chunks with exact reconstruction. Prefer complete lines,
/// and never split a UTF-16 surrogate pair. Each search stays in its chunk.
List<String> boundedTextChunks(String source, {int maxChars = 2000}) {
  if (maxChars < 2) throw ArgumentError.value(maxChars, 'maxChars');
  final chunks = <String>[];
  var start = 0;
  while (start < source.length) {
    var end = (start + maxChars).clamp(0, source.length);
    if (end < source.length) {
      var newline = end - 1;
      while (newline >= start && source.codeUnitAt(newline) != 10) {
        newline--;
      }
      if (newline >= start) {
        end = newline + 1;
      } else {
        final last = source.codeUnitAt(end - 1);
        if (last >= 0xD800 && last <= 0xDBFF) end--;
      }
    }
    chunks.add(source.substring(start, end));
    start = end;
  }
  return chunks;
}
