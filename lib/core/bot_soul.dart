library;

import 'stores/bot_store.dart';

/// Mirrors desktop's `botHandle` (plugin.js) — the @mention form used in the
/// "Message from" prefix. `default` reads as `hermes` since that's the alias
/// everyone already types.
String botHandle(String name) {
  return name.trim().toLowerCase() == 'default' ? 'hermes' : name;
}

/// Mirrors desktop's `displayName({name, title})` call shape: title wins,
/// else the profile name, dashes/underscores become spaces, each word
/// capitalized. `default` with no title reads as "Hermes".
String botDisplayName(String name, String? title) {
  if (name.trim().toLowerCase() == 'default' &&
      (title == null || title.trim().isEmpty)) {
    return 'Hermes';
  }
  final raw = (title?.trim().isNotEmpty == true ? title!.trim() : name)
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .trim();
  return raw
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

/// True when [soul] already carries the Bot Mode handoff section — ported
/// from desktop's `hasMessagingProtocol` so a re-composed SOUL never
/// duplicates it.
bool hasMessagingProtocol(String? soul) {
  return RegExp(r'(^|\n)## Messaging other agents(\s|$)').hasMatch(soul ?? '');
}

/// Ported verbatim (content-wise) from desktop's `messagingProtocolSection`
/// — instructs the AGENT RUNTIME (which has `hermes` CLI access wherever it
/// executes), not this client, so it must read identically regardless of
/// which client created the bot.
String messagingProtocolSection(String name, List<BotIdentity> roster) {
  final teammates = roster.where((b) => b.profile != name).toList();
  final handle = botHandle(name);
  final teammateLines = teammates.isEmpty
      ? ['- (none yet)']
      : teammates
          .map(
            (b) => '- `${b.profile}`${b.description.trim().isNotEmpty ? ' — ${b.description.trim()}' : ''}',
          )
          .toList();

  return [
    '## Messaging other agents',
    '',
    'You work alongside other named agents. Every agent (including you) has',
    'ONE canonical conversation titled "Bot Chat" — created with the agent,',
    'so it always exists. Agent-to-agent messages are delivered straight',
    'into it, like a DM. To message a teammate, run:',
    '',
    '```',
    'hermes -p <agent-name> chat --in ~ -c "Bot Chat" --create-if-missing -Q -q "Message from \u{1F916} $handle (@$handle): your message"',
    '',
    'Run the send with background=true and notify_on_complete=true on the',
    'terminal tool, then finish your turn — the reply arrives later as a',
    'background process notification. Never block waiting for it.',
    '```',
    '',
    '(`--in ~ -c "Bot Chat" --create-if-missing` resumes their canonical',
    'conversation in the home workspace, creating it if the target has no',
    '"Bot Chat" yet. `-Q` keeps output clean. Always open with the',
    '"Message from \u{1F916} $handle (@$handle):" prefix so they know',
    'who is talking (the @handle lets the app show your avatar to them).',
    'Their reply prints to stdout — relay the relevant part back to the',
    'user, and say which agent it came from.)',
    '',
    'If a message in YOUR chat starts with "Message from \u{1F916} <name>", it is',
    'a teammate messaging you, not the user. Answer it directly — your reply',
    'reaches them via their own delivery — and use the same command if you',
    'need to start a conversation yourself.',
    '',
    'When the user writes @<agent-name> or says "ask <name> to ..." /',
    '"tell <name> ...", that is a handoff: message that agent, wait for the',
    'reply, and report back.',
    '',
    'The roster grows over time — run `hermes profile list` for the LIVE',
    'teammate list before a handoff. Teammates when you were created:',
    ...teammateLines,
  ].join('\n');
}

/// Idempotent: appends the protocol once, never duplicates a custom SOUL
/// that already has it. No-op when the backend injects the protocol into
/// the system prompt itself (`serverInjectsProtocol`).
String ensureMessagingProtocol(
  String? soul,
  String name,
  List<BotIdentity> roster, {
  required bool serverInjectsProtocol,
}) {
  final text = (soul ?? '').trim();
  if (serverInjectsProtocol || hasMessagingProtocol(text)) return text;
  final section = messagingProtocolSection(name, roster);
  return text.isEmpty ? section : '$text\n\n$section';
}

/// SOUL.md for a new bot: identity (or the user's custom SOUL) + the
/// messaging protocol — which ships UNLESS the backend injects it into the
/// system prompt itself (`bot_mode_protocol` capability). Ported from
/// desktop's `composeSoul`.
String composeSoul({
  required String name,
  String? title,
  String? description,
  List<BotIdentity> roster = const [],
  String? customSoul,
  required bool serverInjectsProtocol,
}) {
  if (customSoul != null && customSoul.trim().isNotEmpty) {
    return ensureMessagingProtocol(
      customSoul,
      name,
      roster,
      serverInjectsProtocol: serverInjectsProtocol,
    );
  }

  final label = botDisplayName(name, title);
  final lines = [
    '# $label',
    '',
    if (title != null && title.trim().isNotEmpty) '**Role:** ${title.trim()}',
    if (description != null && description.trim().isNotEmpty)
      '**Mission:** ${description.trim()}',
    '',
    'You are $label, a persistent named agent (profile `$name`) on this machine.',
    'You keep your own memory, skills, and conversation history across sessions.',
  ];

  final identity = lines.join('\n');
  return serverInjectsProtocol
      ? identity
      : '$identity\n\n${messagingProtocolSection(name, roster)}';
}
