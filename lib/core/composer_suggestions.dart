/// Desktop parity: `store/suggestion-providers/*` — passive draft analysis
/// that surfaces a dismissible suggestion instead of requiring the user to
/// know a slash command exists. Desktop renders these as hover pills above
/// the composer; only the cron/recurrence provider is ported here (the
/// others — GitHub auth nudge, MCP directory match, tool-failure repair,
/// installed-skill match — depend on live catalogs or auth probes that would
/// need real backend wiring to be trustworthy rather than noisy, so they're
/// left for a follow-up rather than shipped half-verified).
///
/// Mobile adaptation: a debounced regex check runs on composer text changes
/// (chat_screen.dart's existing 250ms `_onComposerChanged` debounce) and, on
/// a hit, shows a closeable suggestion card above the composer rather than
/// desktop's hover pill — tapping it prefixes the draft with a scheduling
/// instruction (the agent still owns actually parsing the schedule and
/// creating the cron job), it never sends on the user's behalf.
library;

// Recurrence phrasing, deliberately narrow (a precise regex beats a fuzzy
// one that fires on unrelated text). Whole-word, unicode boundaries; hyphen
// counts as a word character so "weekly-report.pdf" stays quiet.
final _recurrenceReEn = RegExp(
  r'(?<![\p{L}\p{N}-])(?:(?:every|each)\s+(?:\d+\s+)?'
  r'(?:second|minute|hour|morning|afternoon|evening|night|day|weekday|week|month|'
  r'monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?|'
  r'daily|weekly|monthly|nightly|hourly)(?![\p{L}\p{N}-])',
  caseSensitive: false,
  unicode: true,
);

// A bare frequency adverb immediately followed by a capitalized word is a
// proper noun ("the Daily Prophet"), not a schedule.
final _adverbRe = RegExp(
  r'^(daily|weekly|monthly|nightly|hourly)$',
  caseSensitive: false,
);
final _capitalizedNextRe = RegExp(r'^\s+\p{Lu}', unicode: true);

// Chinese recurrence phrasing has no case-based proper-noun ambiguity to
// guard against, so a direct match is enough.
final _recurrenceReZh = RegExp(
  r'每(?:天(?:早上|晚上|中午)?|日|周[一二三四五六日天]?|星期[一二三四五六日天]?|月|年|小时|分钟|次)',
);

/// The recurrence phrase that fired, or null. Exported for tests.
String? matchRecurrence(String text) {
  for (final match in _recurrenceReEn.allMatches(text)) {
    final phrase = match.group(0)!;
    if (_adverbRe.hasMatch(phrase) &&
        _capitalizedNextRe.hasMatch(text.substring(match.end))) {
      continue;
    }
    return phrase;
  }
  final zh = _recurrenceReZh.firstMatch(text);
  return zh?.group(0);
}

/// Whether [draft] should show the "schedule this as a cron job" suggestion.
/// False once the draft already leads with a slash command or with the
/// instruction the suggestion itself inserts (so accepting it, or editing
/// afterward, doesn't keep re-showing the same pill).
bool shouldSuggestCron(
  String draft, {
  String acceptedPrefix = cronSuggestionPrefix,
}) {
  final trimmed = draft.trimLeft();
  if (trimmed.startsWith('/')) return false;
  if (trimmed.startsWith(acceptedPrefix)) return false;
  return matchRecurrence(draft) != null;
}

/// Prefix inserted into the draft when the cron suggestion is accepted.
const cronSuggestionPrefix = 'Schedule this as a recurring task: ';
