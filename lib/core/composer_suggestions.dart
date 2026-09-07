/// Desktop parity: `store/suggestion-providers/*` — passive draft analysis
/// that surfaces a dismissible suggestion instead of requiring the user to
/// know a slash command exists. The pure high-precision matchers live here so
/// both the stateful provider bus and unit tests share exactly one contract.
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

String _escapeRegex(String value) =>
    value.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');

/// Skill names match completed whole words. Hyphens/underscores may be typed
/// as spaces (`pr-ready` -> `pr ready`), but `read` never matches `already`.
bool composerSkillHit(String text, String name) {
  if (name.length < 4 || text.trimLeft().startsWith('/')) return false;
  final flexible = name
      .toLowerCase()
      .split(RegExp(r'[-_]'))
      .map(_escapeRegex)
      .join(r'[-_ ]');
  final pattern = RegExp(
    r'(?<![\p{L}\p{N}])'
    '$flexible'
    r'(?![\p{L}\p{N}-])',
    caseSensitive: false,
    unicode: true,
  );
  return pattern.allMatches(text).any((m) => m.end < text.length);
}

bool composerSkillCollidesWithWorkspace(String name, String cwd) {
  if (name.isEmpty || cwd.isEmpty) return false;
  final escaped = _escapeRegex(name.toLowerCase());
  return RegExp(
    r'(?<![\p{L}\p{N}])'
    '$escaped'
    r'(?![\p{L}\p{N}])',
    unicode: true,
  ).hasMatch(cwd.toLowerCase());
}

final _githubHost = RegExp(
  r'''https?://([^\s/,)\]}"'<>]*@)?([\w.-]*\.)?github\.com(?=[/\s:,)\]}"'<>]|$)''',
  caseSensitive: false,
);
final _githubWord = RegExp(
  r'(?<![\p{L}\p{N}])github(?![\p{L}\p{N}])',
  caseSensitive: false,
  unicode: true,
);

bool composerGithubHit(String text) {
  if (text.trimLeft().startsWith('/')) return false;
  if (_githubHost.hasMatch(text)) return true;
  final withoutUrls = text.replaceAll(RegExp(r'https?://[^\s]+'), ' ');
  return _githubWord
      .allMatches(withoutUrls)
      .any((m) => m.end < withoutUrls.length);
}

List<({String server, String trigger})> composerMcpMatches(
  String text,
  Iterable<Map<String, dynamic>> catalog, {
  int limit = 2,
}) {
  final lower = text.toLowerCase();
  final urlHosts =
      RegExp(r'''https?://([^\s/,)\]}"'<>]+)''', caseSensitive: false)
          .allMatches(text)
          .map(
            (m) => m
                .group(1)!
                .split('@')
                .last
                .replaceFirst(RegExp(r':\d+$'), '')
                .toLowerCase(),
          )
          .toList();
  final result = <({String server, String trigger})>[];
  for (final entry in catalog) {
    final name = entry['name']?.toString() ?? '';
    final suggest = entry['suggest'];
    if (name.isEmpty || suggest is! Map) continue;
    final hosts = (suggest['hosts'] as List? ?? const []).map(
      (e) => e.toString().toLowerCase(),
    );
    final keywords = (suggest['keywords'] as List? ?? const []).map(
      (e) => e.toString().toLowerCase(),
    );
    String? trigger;
    for (final suffix in hosts) {
      if (urlHosts.any((host) => host == suffix || host.endsWith('.$suffix'))) {
        trigger = suffix;
        break;
      }
    }
    if (trigger == null) {
      for (final keyword in keywords) {
        final escaped = _escapeRegex(keyword);
        final re = RegExp(
          r'(?<![\p{L}\p{N}])'
          '$escaped'
          r'(?![\p{L}\p{N}])',
          unicode: true,
        );
        if (re.allMatches(lower).any((m) => m.end < lower.length)) {
          trigger = keyword;
          break;
        }
      }
    }
    if (trigger != null) result.add((server: name, trigger: trigger));
    if (result.length >= limit) break;
  }
  return result;
}

final composerMcpRepairError = RegExp(
  r'\b(401|403|unauthorized|forbidden|token .*(expired|invalid)|oauth|authenticat\w+ (failed|required|expired)|connection (refused|closed|reset|failed)|server (unavailable|disconnected|not connected)|ECONNREFUSED)\b',
  caseSensitive: false,
);

String? composerMcpServerFromTool(String toolName) =>
    RegExp(r'^mcp__([^_]+(?:_[^_]+)*?)__').firstMatch(toolName)?.group(1);
