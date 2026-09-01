/// Human-readable tool-call presentation (desktop `fallback-model` parity).
library;

import 'dart:convert';

import '../l10n/runtime_l10n.dart';

enum ToolPresentationKind {
  terminal,
  executeCode,
  webSearch,
  webExtract,
  patch,
  readFile,
  writeFile,
  listFiles,
  generateImage,
  generic,
}

class ToolSearchHit {
  final String title;
  final String url;
  final String snippet;

  const ToolSearchHit({
    required this.title,
    required this.url,
    required this.snippet,
  });
}

String normalizeToolName(String name) {
  return name.trim().toLowerCase().replaceAll('-', '_');
}

bool _hasAnyKey(Map<String, dynamic> args, List<String> keys) {
  for (final key in keys) {
    final value = args[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return true;
  }
  return false;
}

ToolPresentationKind resolveToolKind(String name, Map<String, dynamic> args) {
  final normalized = normalizeToolName(name);
  switch (normalized) {
    case 'terminal':
    case 'bash':
    case 'sh':
    case 'shell':
    case 'run_terminal_cmd':
    case 'run_command':
    case 'shell_command':
    case 'process':
      return ToolPresentationKind.terminal;
    case 'execute_code':
      return ToolPresentationKind.executeCode;
    case 'web_search':
    case 'web.run':
    case 'search':
    case 'google_search':
    case 'bing_search':
    case 'session_search_recall':
      return ToolPresentationKind.webSearch;
    case 'web_extract':
      return ToolPresentationKind.webExtract;
    case 'patch':
    case 'apply_patch':
      return ToolPresentationKind.patch;
    case 'read_file':
      return ToolPresentationKind.readFile;
    case 'write_file':
    case 'edit_file':
      return ToolPresentationKind.writeFile;
    case 'list_files':
    case 'search_files':
      return ToolPresentationKind.listFiles;
    case 'generate_image':
    case 'image_generation':
    case 'create_image':
      return ToolPresentationKind.generateImage;
    default:
      break;
  }

  if (_hasAnyKey(args, ['command', 'shell_command', 'script'])) {
    return ToolPresentationKind.terminal;
  }
  if (_hasAnyKey(args, ['code']) &&
      _hasAnyKey(args, ['language', 'lang', 'runtime'])) {
    return ToolPresentationKind.executeCode;
  }
  if (_hasAnyKey(args, ['query', 'q', 'search_term', 'search'])) {
    return ToolPresentationKind.webSearch;
  }
  if (_hasAnyKey(args, ['url', 'href', 'link']) &&
      !_hasAnyKey(args, ['command', 'code'])) {
    return ToolPresentationKind.webExtract;
  }
  if (_hasAnyKey(args, ['patch', 'diff', 'content']) &&
      normalized.contains('patch')) {
    return ToolPresentationKind.patch;
  }
  if (_hasAnyKey(args, ['path', 'file', 'filepath', 'file_path'])) {
    if (_hasAnyKey(args, ['content', 'text', 'body', 'data'])) {
      return ToolPresentationKind.writeFile;
    }
    return ToolPresentationKind.readFile;
  }

  return ToolPresentationKind.generic;
}

/// Parse a raw tool-call payload's args from any of the shapes the gateway
/// sends (`args` map, `args_text` JSON/key-value string, `function.arguments`)
/// into a structured map. Shared by [HermesToolCard] and the tool-group
/// rollup so a collapsed summary line looks the same everywhere.
Map<String, dynamic> parseToolArgs(Map<String, dynamic> data) {
  final argsText = data['args_text'];
  final args = data['args'];

  // Try args_text first (string), then args (map), then args_text as map.
  if (argsText is String && argsText.isNotEmpty) {
    try {
      final decoded = jsonDecode(argsText);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Not JSON — try to parse as key=value or just return as single value.
    }
    return _parseToolKeyValueString(argsText);
  }

  if (args is Map) {
    return Map<String, dynamic>.from(args);
  }

  // If args_text is already a Map (from parsing).
  if (argsText is Map) {
    return Map<String, dynamic>.from(argsText);
  }

  final function = data['function'];
  if (function is Map) {
    final fnArgs = function['arguments'];
    if (fnArgs is String && fnArgs.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(fnArgs);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return _parseToolKeyValueString(fnArgs);
      }
    }
    if (fnArgs is Map) {
      return Map<String, dynamic>.from(fnArgs);
    }
  }

  return {};
}

/// Parse a string that may be in `key=value` or `key: value` format.
Map<String, dynamic> _parseToolKeyValueString(String text) {
  final result = <String, dynamic>{};
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}

  final lines = text.split(RegExp(r'[,\n]'));
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final colonIdx = trimmed.indexOf(':');
    final equalsIdx = trimmed.indexOf('=');

    int separatorIdx;
    if (colonIdx != -1 && equalsIdx != -1) {
      separatorIdx = colonIdx < equalsIdx ? colonIdx : equalsIdx;
    } else if (colonIdx != -1) {
      separatorIdx = colonIdx;
    } else if (equalsIdx != -1) {
      separatorIdx = equalsIdx;
    } else {
      continue;
    }

    final key = trimmed.substring(0, separatorIdx).trim();
    final value = trimmed.substring(separatorIdx + 1).trim();
    if (key.isNotEmpty) {
      result[key] = _tryParseToolValue(value);
    }
  }

  if (result.isEmpty && text.isNotEmpty) {
    result['input'] = text.trim();
  }

  return result;
}

/// Try to parse a string value into its actual type.
dynamic _tryParseToolValue(String value) {
  try {
    return jsonDecode(value);
  } catch (_) {}

  if (value.toLowerCase() == 'true') return true;
  if (value.toLowerCase() == 'false') return false;

  final number = num.tryParse(value);
  if (number != null) return number;

  if (value.toLowerCase() == 'null') return null;

  return value;
}

dynamic toolParseMaybeJson(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return value;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }
  return value;
}

Map<String, dynamic> toolParseMaybeObject(dynamic value) {
  final parsed = toolParseMaybeJson(value);
  if (parsed is Map) {
    return Map<String, dynamic>.from(parsed);
  }
  return {};
}

String toolFirstStringField(Map<String, dynamic> record, List<String> keys) {
  for (final key in keys) {
    final value = record[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString();
    }
  }
  return '';
}

String toolShellCommand(Map<String, dynamic> args) {
  return toolFirstStringField(args, [
    'command',
    'code',
    'script',
    'shell_command',
    'input',
    'context',
    'preview',
  ]);
}

String toolSearchQuery(Map<String, dynamic> args) {
  return toolFirstStringField(args, [
    'search_term',
    'query',
    'q',
    'search',
    'keywords',
  ]);
}

String toolFilePath(Map<String, dynamic> args) {
  return toolFirstStringField(args, [
    'path',
    'file',
    'filepath',
    'file_path',
    'target',
  ]);
}

Map<String, dynamic> _unwrapToolPayload(Map<String, dynamic> record) {
  for (final key in ['data', 'result', 'output', 'response', 'payload']) {
    final nested = record[key];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
  }
  return record;
}

List<dynamic> toolCollectResultItems(dynamic value) {
  if (value is List) return value;
  final record = toolParseMaybeObject(value);
  if (record.isEmpty) return const [];

  for (final key in [
    'web',
    'results',
    'search_results',
    'sources',
    'web_sources',
    'items',
    'organic_results',
    'organic',
    'matches',
    'documents',
    'data',
  ]) {
    final candidate = record[key];
    if (candidate is List) return candidate;
    if (candidate is Map) {
      final nested = toolCollectResultItems(candidate);
      if (nested.isNotEmpty) return nested;
    }
  }

  final payload = _unwrapToolPayload(record);
  if (identical(payload, record)) return const [];
  return toolCollectResultItems(payload);
}

List<ToolSearchHit> toolExtractSearchHits(dynamic result, {int limit = 8}) {
  final list = toolCollectResultItems(result);
  final hits = <ToolSearchHit>[];
  for (final item in list) {
    final row = toolParseMaybeObject(item);
    final title = toolFirstStringField(row, ['title', 'name', 'label']);
    final url = toolFirstStringField(row, ['url', 'href', 'link']);
    final snippet = toolFirstStringField(row, [
      'snippet',
      'description',
      'body',
      'content',
      'text',
    ]);
    if (title.isEmpty && url.isEmpty) continue;
    hits.add(
      ToolSearchHit(
        title: title.isEmpty ? url : title,
        url: url,
        snippet: snippet,
      ),
    );
    if (hits.length >= limit) break;
  }
  return hits;
}

class ToolTerminalStreams {
  final String stdout;
  final String stderr;
  final int? exitCode;

  const ToolTerminalStreams({
    required this.stdout,
    required this.stderr,
    this.exitCode,
  });

  bool get hasSplitStreams => stdout.isNotEmpty || stderr.isNotEmpty;
}

ToolTerminalStreams toolParseTerminalStreams(
  dynamic rawResult,
  String fallbackText,
) {
  final record = toolParseMaybeObject(rawResult);
  if (record.isNotEmpty) {
    final stdout = toolFirstStringField(record, [
      'stdout',
      'output',
      'output_preview',
      'text',
    ]);
    final stderr = toolFirstStringField(record, ['stderr']);
    final exitRaw = record['exit_code'] ?? record['exitCode'];
    final exitCode = exitRaw is num
        ? exitRaw.toInt()
        : int.tryParse('$exitRaw');
    if (stdout.isNotEmpty || stderr.isNotEmpty) {
      return ToolTerminalStreams(
        stdout: stdout,
        stderr: stderr,
        exitCode: exitCode,
      );
    }

    final lines = record['lines'];
    if (lines is List) {
      final joined = lines.map((e) => e.toString()).join('\n');
      if (joined.trim().isNotEmpty) {
        return ToolTerminalStreams(
          stdout: joined,
          stderr: '',
          exitCode: exitCode,
        );
      }
    }
  }

  final text = fallbackText.trim();
  if (text.isEmpty) {
    return const ToolTerminalStreams(stdout: '', stderr: '');
  }
  return ToolTerminalStreams(stdout: text, stderr: '');
}

String toolDisplayScalar(dynamic value, {int maxLen = 240}) {
  final parsed = toolParseMaybeJson(value);
  if (parsed == null) return '';
  if (parsed is String) {
    final trimmed = parsed.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen - 1)}…';
  }
  if (parsed is num || parsed is bool) return parsed.toString();
  if (parsed is List) {
    if (parsed.isEmpty) return runtimeL10n.toolEmptyList;
    final previews = parsed
        .take(4)
        .map(toolDisplayScalar)
        .where((s) => s.isNotEmpty)
        .toList();
    if (previews.isEmpty) {
      return runtimeL10n.toolItemCount(parsed.length);
    }
    final suffix = parsed.length > previews.length ? ' …' : '';
    return previews.join(' · ') + suffix;
  }
  if (parsed is Map) {
    final map = Map<String, dynamic>.from(parsed);
    final title = toolFirstStringField(map, [
      'title',
      'name',
      'path',
      'message',
      'summary',
      'url',
    ]);
    if (title.isNotEmpty) return title;
    return runtimeL10n.toolFieldCount(map.length);
  }
  return parsed.toString();
}

String toolHumanFieldLabel(String key) {
  final labels = {
    'command': runtimeL10n.toolCommand,
    'query': runtimeL10n.toolSearchQuery,
    'search_term': runtimeL10n.toolSearchQuery,
    'path': runtimeL10n.toolPath,
    'file': runtimeL10n.toolFile,
    'filepath': runtimeL10n.toolFile,
    'file_path': runtimeL10n.toolFile,
    'code': runtimeL10n.toolCode,
    'language': runtimeL10n.toolLanguage,
    'url': runtimeL10n.toolLink,
    'content': runtimeL10n.toolContent,
    'text': runtimeL10n.toolText,
    'message': runtimeL10n.toolMessage,
    'summary': runtimeL10n.toolSummary,
    'stdout': runtimeL10n.toolOutput,
    'stderr': runtimeL10n.toolErrorOutput,
    'result': runtimeL10n.toolResult,
    'output': runtimeL10n.toolOutput,
  };
  return labels[key] ?? key.replaceAll('_', ' ');
}

List<MapEntry<String, dynamic>> toolOrderedFields(Map<String, dynamic> record) {
  const priority = [
    'title',
    'name',
    'path',
    'file',
    'url',
    'command',
    'query',
    'search_term',
    'message',
    'summary',
    'description',
    'content',
    'text',
    'stdout',
    'stderr',
    'output',
    'result',
  ];
  final keys = record.keys.toList();
  final ordered = <String>[];
  for (final key in priority) {
    if (keys.contains(key)) ordered.add(key);
  }
  for (final key in keys) {
    if (!ordered.contains(key)) ordered.add(key);
  }
  return [
    for (final key in ordered)
      if (record[key] != null) MapEntry(key, record[key]),
  ];
}

String toolCollapsedSummary(
  ToolPresentationKind kind,
  Map<String, dynamic> args,
) {
  switch (kind) {
    case ToolPresentationKind.terminal:
      final command = toolShellCommand(args);
      return command.isEmpty ? runtimeL10n.toolExecuteCommand : command;
    case ToolPresentationKind.executeCode:
      final language = toolFirstStringField(args, ['language', 'lang']);
      return language.isEmpty
          ? runtimeL10n.toolRunCode
          : runtimeL10n.toolRunCodeLanguage(language);
    case ToolPresentationKind.webSearch:
      final query = toolSearchQuery(args);
      return query.isEmpty
          ? runtimeL10n.toolSearchingWeb
          : runtimeL10n.toolSearchFor(query);
    case ToolPresentationKind.webExtract:
      final url = toolFirstStringField(args, ['url', 'href', 'link']);
      return url.isEmpty ? runtimeL10n.toolExtractWeb : url;
    case ToolPresentationKind.patch:
      return runtimeL10n.toolApplyPatch;
    case ToolPresentationKind.readFile:
      final path = toolFilePath(args);
      return path.isEmpty ? runtimeL10n.toolReadingFile : path;
    case ToolPresentationKind.writeFile:
      final path = toolFilePath(args);
      return path.isEmpty ? runtimeL10n.toolWritingFile : path;
    case ToolPresentationKind.listFiles:
      return runtimeL10n.toolListFiles;
    case ToolPresentationKind.generateImage:
      return runtimeL10n.toolGenerateImage;
    case ToolPresentationKind.generic:
      return '';
  }
}

/// Desktop parity: `run-summary.ts` — collapses a run of tool calls into one
/// line ("Explored 3 files, ran 5 commands") instead of the bare "used N
/// tools" [ToolGroupCard] showed before. Clause order is fixed (edit →
/// explore → run → delegate → other) so the same run always reads the same
/// way. Simplified from desktop: a category with exactly one call there
/// names the actual target ("Edited wiring.tsx"); here every category is
/// just counted, since [ToolGroupCard] itself only ever renders for 2+
/// calls in the first place, so a single-tool clause is the less common
/// case rather than the norm.
enum ToolRunCategory { edit, explore, run, delegate, other }

const _toolRunCategoryOrder = [
  ToolRunCategory.edit,
  ToolRunCategory.explore,
  ToolRunCategory.run,
  ToolRunCategory.delegate,
  ToolRunCategory.other,
];

ToolRunCategory toolRunCategory(String name, Map<String, dynamic> args) {
  final normalized = normalizeToolName(name);
  if (normalized == 'delegate_task' || normalized == 'delegate') {
    return ToolRunCategory.delegate;
  }
  switch (resolveToolKind(name, args)) {
    case ToolPresentationKind.patch:
    case ToolPresentationKind.writeFile:
      return ToolRunCategory.edit;
    case ToolPresentationKind.readFile:
    case ToolPresentationKind.listFiles:
    case ToolPresentationKind.webSearch:
    case ToolPresentationKind.webExtract:
      return ToolRunCategory.explore;
    case ToolPresentationKind.terminal:
    case ToolPresentationKind.executeCode:
      return ToolRunCategory.run;
    case ToolPresentationKind.generateImage:
    case ToolPresentationKind.generic:
      return ToolRunCategory.other;
  }
}

String _toolRunClause(ToolRunCategory category, int count, bool live) {
  if (live) {
    return switch (category) {
      ToolRunCategory.edit => runtimeL10n.toolRunEditingFiles(count),
      ToolRunCategory.explore => runtimeL10n.toolRunExploringFiles(count),
      ToolRunCategory.run => runtimeL10n.toolRunRunningCommands(count),
      ToolRunCategory.delegate => runtimeL10n.toolRunDelegatingTasks(count),
      ToolRunCategory.other => runtimeL10n.toolRunUsingTools(count),
    };
  }
  return switch (category) {
    ToolRunCategory.edit => runtimeL10n.toolRunEditedFiles(count),
    ToolRunCategory.explore => runtimeL10n.toolRunExploredFiles(count),
    ToolRunCategory.run => runtimeL10n.toolRunRanCommands(count),
    ToolRunCategory.delegate => runtimeL10n.toolRunDelegatedTasks(count),
    ToolRunCategory.other => runtimeL10n.toolRunUsedTools(count),
  };
}

/// Summarizes a tool-call run for [ToolGroupCard]'s header. `live` picks the
/// present- vs. past-tense verb, matching the run's own running/settled
/// state so the line reads as work in progress or work already done.
String toolRunSummary(List<Map<String, dynamic>> tools, {required bool live}) {
  final counts = <ToolRunCategory, int>{};
  for (final tool in tools) {
    final name = (tool['name'] ?? tool['tool_name'] ?? 'tool').toString();
    final args = parseToolArgs(tool);
    final category = toolRunCategory(name, args);
    counts[category] = (counts[category] ?? 0) + 1;
  }
  final clauses = [
    for (final category in _toolRunCategoryOrder)
      if ((counts[category] ?? 0) > 0)
        _toolRunClause(category, counts[category]!, live),
  ];
  if (clauses.isEmpty) {
    return live
        ? runtimeL10n.toolRunUsingTools(tools.length)
        : runtimeL10n.toolRunUsedTools(tools.length);
  }
  return clauses.join(runtimeL10n.commonListSeparator);
}
