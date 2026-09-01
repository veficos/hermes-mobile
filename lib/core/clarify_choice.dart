/// Helpers for clarify-tool choice strings. The backend tags its preferred
/// option by appending `(Recommended)` (desktop `RECOMMENDED_LABEL`); the raw
/// value it expects back is the choice *without* that tag.
library;

final _recommendedTag = RegExp(
  r'\s*\((?:recommended|推荐)\)\s*$',
  caseSensitive: false,
);

/// The choice text with any trailing `(Recommended)` marker removed — this is
/// what gets sent back to `clarify.respond`.
String bareChoice(String choice) =>
    choice.replaceFirst(_recommendedTag, '').trim();

bool isRecommendedChoice(String choice) => _recommendedTag.hasMatch(choice);

/// Reorder so a recommended option floats to the front, preserving the
/// relative order of the rest.
List<String> orderChoices(List<String> choices) {
  final recommended = choices.where(isRecommendedChoice).toList();
  final rest = choices.where((c) => !isRecommendedChoice(c)).toList();
  return [...recommended, ...rest];
}

/// The A/B/C… letter shown as a keyboard-hint badge on choice [index].
String choiceKeyBadge(int index) =>
    index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';

/// Encode a batch/multi answer the way `clarify.respond` expects: a JSON array
/// for multi-select, the bare string otherwise (desktop parity).
String encodeClarifyAnswer(
  Iterable<String> selected, {
  required bool multiSelect,
}) {
  final cleaned = selected.map(bareChoice).where((s) => s.isNotEmpty).toList();
  if (multiSelect) {
    return '[${cleaned.map((s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"').join(',')}]';
  }
  return cleaned.isEmpty ? '' : cleaned.first;
}
