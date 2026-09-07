/// Pure helpers for revealing streamed assistant text at a word cadence.
///
/// Splits only at whitespace-to-non-whitespace boundaries, so every returned
/// prefix is an exact prefix of the source and joining the parts never changes
/// the response. This mirrors Hermex's `StreamingWordDrain`.
abstract final class StreamingWordDrain {
  static int unitCount(String text) {
    if (text.isEmpty) return 0;
    var count = 1;
    var sawNonWhitespace = false;
    var previousWasWhitespace = false;
    for (final rune in text.runes) {
      final current = String.fromCharCode(rune);
      final isWhitespace = RegExp(r'^\s$', unicode: true).hasMatch(current);
      if (previousWasWhitespace && !isWhitespace && sawNonWhitespace) count++;
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
    var offset = 0;
    for (final rune in text.runes) {
      final current = String.fromCharCode(rune);
      final isWhitespace = RegExp(r'^\s$', unicode: true).hasMatch(current);
      if (unitsSeen == 0) {
        unitsSeen = 1;
      } else if (previousWasWhitespace && !isWhitespace && sawNonWhitespace) {
        unitsSeen++;
        if (unitsSeen > unitCount) return offset;
      }
      if (!isWhitespace) sawNonWhitespace = true;
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
