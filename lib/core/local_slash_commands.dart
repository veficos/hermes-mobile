/// WebUI / ui-tui built-in slash commands handled on the client before send.
library;

import '../l10n/generated/app_localizations.dart';

class LocalSlashCommand {
  final String name;
  final List<String> aliases;
  final String description;
  final LocalSlashHandler handler;
  final bool discoverable;

  const LocalSlashCommand({
    required this.name,
    this.aliases = const [],
    required this.description,
    required this.handler,
    this.discoverable = true,
  });

  bool matchesToken(String token) {
    final normalized = token.toLowerCase();
    if (name == normalized) return true;
    return aliases.any((a) => a.toLowerCase() == normalized);
  }
}

enum LocalSlashHandler {
  retry,
  clear,
  undo,
  steer,
  status,
  title,
  newChat,
  yolo,
  handoff,
  profile,
  help,
  background,
  compress,
  queue,
  usage,
  version,
  stop,
  tools,
  approvals,
  model,
  wake,
  journey,
  pet,
  hatch,
  save,
  unavailable,
}

/// Desktop `DESKTOP_COMMAND_SPECS` verbs the mobile client can honour locally.
const List<LocalSlashCommand> kLocalSlashCommands = [
  LocalSlashCommand(
    name: 'retry',
    description: 'retry',
    handler: LocalSlashHandler.retry,
  ),
  LocalSlashCommand(
    name: 'clear',
    aliases: ['cls'],
    description: 'clear',
    handler: LocalSlashHandler.clear,
  ),
  LocalSlashCommand(
    name: 'undo',
    description: 'undo',
    handler: LocalSlashHandler.undo,
  ),
  LocalSlashCommand(
    name: 'steer',
    description: 'steer',
    handler: LocalSlashHandler.steer,
  ),
  LocalSlashCommand(
    name: 'status',
    description: 'status',
    handler: LocalSlashHandler.status,
  ),
  LocalSlashCommand(
    name: 'title',
    description: 'title',
    handler: LocalSlashHandler.title,
  ),
  LocalSlashCommand(
    name: 'new',
    aliases: ['reset'],
    description: 'new',
    handler: LocalSlashHandler.newChat,
  ),
  LocalSlashCommand(
    name: 'yolo',
    description: 'yolo',
    handler: LocalSlashHandler.yolo,
  ),
  LocalSlashCommand(
    name: 'handoff',
    description: 'handoff',
    handler: LocalSlashHandler.handoff,
  ),
  LocalSlashCommand(
    name: 'profile',
    description: 'profile',
    handler: LocalSlashHandler.profile,
  ),
  LocalSlashCommand(
    name: 'help',
    aliases: ['commands'],
    description: 'help',
    handler: LocalSlashHandler.help,
  ),
  LocalSlashCommand(
    name: 'background',
    aliases: ['bg'],
    description: 'background',
    handler: LocalSlashHandler.background,
  ),
  LocalSlashCommand(
    name: 'compress',
    aliases: ['compact'],
    description: 'compress',
    handler: LocalSlashHandler.compress,
  ),
  LocalSlashCommand(
    name: 'queue',
    aliases: ['q'],
    description: 'queue',
    handler: LocalSlashHandler.queue,
  ),
  LocalSlashCommand(
    name: 'usage',
    description: 'usage',
    handler: LocalSlashHandler.usage,
  ),
  LocalSlashCommand(
    name: 'version',
    description: 'version',
    handler: LocalSlashHandler.version,
  ),
  LocalSlashCommand(
    name: 'stop',
    description: 'stop',
    handler: LocalSlashHandler.stop,
  ),
  LocalSlashCommand(
    name: 'tools',
    description: 'tools',
    handler: LocalSlashHandler.tools,
  ),
  LocalSlashCommand(
    name: 'approvals',
    description: 'approvals',
    handler: LocalSlashHandler.approvals,
  ),
  LocalSlashCommand(
    name: 'model',
    description: 'model',
    handler: LocalSlashHandler.model,
  ),
  LocalSlashCommand(
    name: 'wake',
    description: 'wake',
    handler: LocalSlashHandler.wake,
  ),
  LocalSlashCommand(
    name: 'skin',
    description: 'skin',
    handler: LocalSlashHandler.unavailable,
    discoverable: false,
  ),
  LocalSlashCommand(
    name: 'browser',
    description: 'browser',
    handler: LocalSlashHandler.unavailable,
    discoverable: false,
  ),
  LocalSlashCommand(
    name: 'journey',
    description: 'journey',
    handler: LocalSlashHandler.journey,
  ),
  LocalSlashCommand(
    name: 'pet',
    description: 'pet',
    handler: LocalSlashHandler.pet,
  ),
  LocalSlashCommand(
    name: 'hatch',
    description: 'hatch',
    handler: LocalSlashHandler.hatch,
  ),
  LocalSlashCommand(
    name: 'save',
    description: 'save',
    handler: LocalSlashHandler.save,
  ),
  LocalSlashCommand(
    name: 'reload-config',
    description: 'reload-config',
    handler: LocalSlashHandler.unavailable,
    discoverable: false,
  ),
];

LocalSlashCommand? matchLocalSlashInvocation(String invocation) {
  final trimmed = invocation.trim();
  if (!trimmed.startsWith('/')) return null;
  final body = trimmed.substring(1).trim();
  if (body.isEmpty) return null;
  final token = body.split(RegExp(r'\s+')).first;
  for (final cmd in kLocalSlashCommands) {
    if (cmd.matchesToken(token)) return cmd;
  }
  return null;
}

String localSlashDescription(
  LocalSlashCommand command,
  AppLocalizations l10n,
) => switch (command.description) {
  'retry' => l10n.slashDescRetry,
  'clear' => l10n.slashDescClear,
  'undo' => l10n.slashDescUndo,
  'steer' => l10n.slashDescSteer,
  'status' => l10n.slashDescStatus,
  'title' => l10n.slashDescTitle,
  'new' => l10n.slashDescNew,
  'yolo' => l10n.slashDescYolo,
  'handoff' => l10n.slashDescHandoff,
  'profile' => l10n.slashDescProfile,
  'help' => l10n.slashDescHelp,
  'background' => l10n.slashDescBackground,
  'compress' => l10n.slashDescCompress,
  'queue' => l10n.slashDescQueue,
  'usage' => l10n.slashDescUsage,
  'version' => l10n.slashDescVersion,
  'stop' => l10n.slashDescStop,
  'tools' => l10n.slashDescTools,
  'approvals' => l10n.slashDescApprovals,
  'model' => l10n.slashDescModel,
  'wake' => l10n.slashDescWake,
  'skin' => l10n.slashDescSkinUnavailable,
  'browser' => l10n.slashDescBrowserUnavailable,
  'journey' => l10n.slashDescJourney,
  'pet' => l10n.slashDescPet,
  'hatch' => l10n.slashDescHatch,
  'save' => l10n.slashDescSave,
  'reload-config' => l10n.slashDescReloadConfigUnavailable,
  _ => command.name,
};

List<(String name, String description)> localSlashCommandPairs(
  AppLocalizations l10n,
) {
  final out = <(String, String)>[];
  for (final cmd in kLocalSlashCommands) {
    if (!cmd.discoverable) continue;
    final description = localSlashDescription(cmd, l10n);
    out.add((cmd.name, description));
    for (final alias in cmd.aliases) {
      out.add((alias, description));
    }
  }
  return out;
}

bool isMobileSlashSuggestionHidden(String name) {
  final normalized = name.trim().replaceFirst(RegExp(r'^/'), '').toLowerCase();
  return const {'skin', 'browser', 'reload-config'}.contains(normalized);
}

/// Argument text after the matched slash token (`/steer hello` → `hello`).
String localSlashArg(String invocation, LocalSlashCommand cmd) {
  final trimmed = invocation.trim();
  if (!trimmed.startsWith('/')) return '';
  final body = trimmed.substring(1).trim();
  if (body.isEmpty) return '';
  final token = body.split(RegExp(r'\s+')).first;
  if (!cmd.matchesToken(token)) return '';
  if (body.length <= token.length) return '';
  return body.substring(token.length).trim();
}
