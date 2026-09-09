/// Pure helpers for revealing streamed assistant text at a word cadence.
///
/// Splits at word boundaries and individual CJK characters, so every returned
/// prefix is an exact prefix of the source and joining the parts never changes
/// the response. This mirrors Hermex's `StreamingWordDrain`.
abstract final class StreamingWordDrain {
  static bool _isCjk(int rune) =>
      (rune >= 0x3400 && rune <= 0x9FFF) ||
      (rune >= 0x20000 && rune <= 0x3134F) ||
      (rune >= 0x3040 && rune <= 0x30FF) ||
      (rune >= 0xAC00 && rune <= 0xD7AF);
  static final _whitespace = RegExp(r'^\s$', unicode: true);
  static int unitCount(String text) {
    if (text.isEmpty) return 0;
    var count = 1;
    var sawNonWhitespace = false;
    var previousWasWhitespace = false;
    var previousWasCjk = false;
    for (final rune in text.runes) {
      final current = String.fromCharCode(rune);
      final isWhitespace = _whitespace.hasMatch(current);
      if (!isWhitespace && sawNonWhitespace &&
          (previousWasWhitespace || previousWasCjk || _isCjk(rune))) {
        count++;
      }
      previousWasCjk = _isCjk(rune);
      if (!isWhitespace) sawNonWhitespace = true;
      previousWasWhitespace = isWhitespace;
    }
    return count;
  }

  /// Returns the UTF-16 offset immediately after the first [unitCount] units.
  static int splitOffset(String text, int unitCount) {
    if (unitCount <= 0 || text.isEmpty) return 0;
    var unitsSeen = 0;
    var sawNonWhitespace = false;
    var previousWasWhitespace = false;
    var previousWasCjk = false;
    var offset = 0;
    for (final rune in text.runes) {
      final current = String.fromCharCode(rune);
      final isWhitespace = _whitespace.hasMatch(current);
      if (unitsSeen == 0) {
        unitsSeen = 1;
      } else if (!isWhitespace && sawNonWhitespace &&
          (previousWasWhitespace || previousWasCjk || _isCjk(rune))) {
        unitsSeen++;
        if (unitsSeen > unitCount) return offset;
      }
      if (!isWhitespace) sawNonWhitespace = true;
      previousWasCjk = _isCjk(rune);
      previousWasWhitespace = isWhitespace;
      offset += rune > 0xFFFF ? 2 : 1;
    }
    return text.length;
  }

  /// Normally drains one word. The quota scales when that would exceed the
  /// allowed visual lag, keeping bursty providers close to real time.
  static int drainQuota({
    required int backlogUnitCount,
    required Duration cadence,
    required Duration maxLag,
  }) {
    if (backlogUnitCount <= 1) return 1;
    if (cadence <= Duration.zero || maxLag <= Duration.zero) {
      return backlogUnitCount;
    }
    final quota =
        (backlogUnitCount * cadence.inMicroseconds / maxLag.inMicroseconds)
            .ceil();
    return quota.clamp(1, backlogUnitCount);
  }
}
