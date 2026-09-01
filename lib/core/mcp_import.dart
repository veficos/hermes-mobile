/// Desktop parity: `lib/mcp-import.ts` — turn whatever a README tells the
/// user to copy (an mcp.json snippet, a bare `npx`/`docker`/`uvx` command, a
/// `claude mcp add` line, or a plain server URL) into named server configs,
/// so adding an MCP server doesn't require hand-filling every field from a
/// pasted example. Pure / side-effect free.
///
/// Trimmed from the desktop parser: the Cursor deeplink format
/// (`cursor://…/mcp/install?config=<base64>`) is desktop-install-flow
/// specific and dropped here; everything else (JSON, claude-add, shell
/// command lines, bare URLs) is ported line-for-line.
library;

import 'dart:convert';

class McpImportEntry {
  final String name;
  final Map<String, dynamic> config;
  const McpImportEntry({required this.name, required this.config});
}

final _urlRe = RegExp(r'^https?://\S+$', caseSensitive: false);
const _stdioCommands = {'bunx', 'docker', 'node', 'npx', 'uvx'};
const _dockerValueFlags = {
  '--entrypoint', '--env', '--label', '--mount', '--name', '--network', //
  '--platform', '--publish', '--pull', '--user', '--volume', '--workdir',
  '-e', '-l', '-p', '-u', '-v', '-w',
};

String _nameFromUrl(String raw) {
  try {
    final labels = Uri.parse(raw).host.split('.').where((s) => s.isNotEmpty).toList();
    while (labels.length > 1 && const {'api', 'mcp', 'www'}.contains(labels.first)) {
      labels.removeAt(0);
    }
    return labels.isNotEmpty ? labels.first : 'server';
  } catch (_) {
    return 'server';
  }
}

String _cleanupName(String base) {
  var stripped = base.replaceFirst(RegExp(r'\.(cjs|js|mjs|py|ts)$', caseSensitive: false), '');
  stripped = stripped.replaceFirst(RegExp(r'^(mcp-server-|server-|mcp-)'), '');
  stripped = stripped.replaceFirst(RegExp(r'(-mcp-server|-mcp|-server)$'), '');
  return stripped.isNotEmpty ? stripped : base;
}

String _packageBasename(String spec) {
  var bare = spec.split('==').first;
  final at = bare.lastIndexOf('@');
  if (at > 0) bare = bare.substring(0, at);
  final segments = bare.split('/');
  return _cleanupName(segments.isNotEmpty ? segments.last : bare);
}

/// Whitespace-splits a line respecting single/double quotes (and backslash
/// escapes inside double quotes); null on an unterminated quote.
List<String>? _tokenize(String line) {
  final tokens = <String>[];
  final current = StringBuffer();
  var sawQuote = false;
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quote != null) {
      if (ch == quote) {
        quote = null;
      } else if (ch == r'\' && quote == '"' && i + 1 < line.length) {
        current.write(line[++i]);
      } else {
        current.write(ch);
      }
    } else if (ch == '"' || ch == "'") {
      quote = ch;
      sawQuote = true;
    } else if (RegExp(r'\s').hasMatch(ch)) {
      if (current.isNotEmpty || sawQuote) {
        tokens.add(current.toString());
        current.clear();
        sawQuote = false;
      }
    } else {
      current.write(ch);
    }
  }
  if (quote != null) return null;
  if (current.isNotEmpty || sawQuote) tokens.add(current.toString());
  return tokens;
}

String _inferCommandName(String command, List<String> args) {
  if (command == 'docker') {
    var i = args.isNotEmpty && args[0] == 'run' ? 1 : 0;
    for (; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('-')) {
        if (_dockerValueFlags.contains(arg)) i++;
        continue;
      }
      final ref = arg.split('/').last.split(':').first;
      return _cleanupName(ref);
    }
    return 'docker';
  }
  if (command == 'node') {
    final script = args.firstWhere((a) => !a.startsWith('-'), orElse: () => '');
    if (script.isEmpty) return 'node';
    return _cleanupName(script.split(RegExp(r'[/\\]')).last);
  }
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('-')) {
      if (arg == '--from' || arg == '--package' || arg == '-p') i++;
      continue;
    }
    return _packageBasename(arg);
  }
  return command;
}

McpImportEntry? _fromCommandLine(List<String> tokens) {
  final command = tokens.isNotEmpty ? tokens.first : '';
  if (!_stdioCommands.contains(command)) return null;
  final args = tokens.skip(1).toList();
  return McpImportEntry(
    name: _inferCommandName(command, args),
    config: {'command': command, 'args': args},
  );
}

/// `claude mcp add NAME [--transport http|sse] [-e K=V]... [--] CMD ARGS...`
/// and `claude mcp add NAME URL`.
McpImportEntry? _fromClaudeAdd(List<String> tokens) {
  String? name;
  String? transport;
  List<String>? rest;
  final env = <String, String>{};
  final headers = <String, String>{};

  for (var i = 3; i < tokens.length; i++) {
    final token = tokens[i];
    if (token == '--') {
      rest = tokens.sublist(i + 1);
      break;
    }
    if (token == '--transport' || token == '-t') {
      transport = ++i < tokens.length ? tokens[i] : null;
      continue;
    }
    if (token == '--env' || token == '-e') {
      final pair = ++i < tokens.length ? tokens[i] : '';
      final eq = pair.indexOf('=');
      if (eq > 0) env[pair.substring(0, eq)] = pair.substring(eq + 1);
      continue;
    }
    if (token == '--header' || token == '-H') {
      final pair = ++i < tokens.length ? tokens[i] : '';
      final colon = pair.indexOf(':');
      if (colon > 0) {
        headers[pair.substring(0, colon).trim()] = pair.substring(colon + 1).trim();
      }
      continue;
    }
    if (token == '--scope' || token == '-s') {
      i++;
      continue;
    }
    if (token.startsWith('-')) continue;
    if (name == null) {
      name = token;
      continue;
    }
    rest = tokens.sublist(i);
    break;
  }

  if (name == null || rest == null || rest.isEmpty) return null;

  if (rest.length == 1 && _urlRe.hasMatch(rest[0])) {
    final config = <String, dynamic>{'url': rest[0]};
    if (transport != null) config['transport'] = transport;
    if (headers.isNotEmpty) config['headers'] = headers;
    return McpImportEntry(name: name, config: config);
  }

  final config = <String, dynamic>{
    'command': rest[0],
    'args': rest.skip(1).toList(),
  };
  if (env.isNotEmpty) config['env'] = env;
  return McpImportEntry(name: name, config: config);
}

String _inferNameFromConfig(Map<String, dynamic> config) {
  final url = config['url'];
  if (url is String) return _nameFromUrl(url);
  final command = config['command'];
  if (command is String) {
    final rawArgs = config['args'];
    final args = rawArgs is List ? rawArgs.whereType<String>().toList() : <String>[];
    return _inferCommandName(command, args);
  }
  return 'server';
}

bool _isServerShape(Map<String, dynamic> value) =>
    value['url'] is String || value['command'] is String;

/// mcp.json snippets: `{"mcpServers": {...}}`, a bare name→config map, or a
/// single unnamed server object (name inferred from its command/url).
List<McpImportEntry>? _fromJson(String text) {
  dynamic parsed;
  try {
    parsed = jsonDecode(text);
  } catch (_) {
    return null;
  }
  if (parsed is! Map) return null;
  final parsedMap = parsed.cast<String, dynamic>();

  if (_isServerShape(parsedMap)) {
    return [McpImportEntry(name: _inferNameFromConfig(parsedMap), config: parsedMap)];
  }

  final wrapper = parsedMap['mcpServers'] ?? parsedMap['mcp_servers'];
  final map = wrapper is Map ? wrapper.cast<String, dynamic>() : parsedMap;
  if (map.isEmpty) return null;

  final out = <McpImportEntry>[];
  for (final entry in map.entries) {
    final value = entry.value;
    if (value is! Map) return null;
    final config = value.cast<String, dynamic>();
    if (!_isServerShape(config)) return null;
    out.add(McpImportEntry(name: entry.key, config: config));
  }
  return out;
}

McpImportEntry? _parseLine(String line) {
  if (_urlRe.hasMatch(line)) {
    return McpImportEntry(name: _nameFromUrl(line), config: {'url': line});
  }
  final tokens = _tokenize(line);
  if (tokens == null || tokens.isEmpty) return null;
  if (tokens.length >= 3 && tokens[0] == 'claude' && tokens[1] == 'mcp' && tokens[2] == 'add') {
    return _fromClaudeAdd(tokens);
  }
  return _fromCommandLine(tokens);
}

/// Parses any pasted MCP server description into named server configs.
/// Returns null when nothing recognizable is in the text.
List<McpImportEntry>? parseMcpImport(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final json = _fromJson(trimmed);
  if (json != null) return json;

  // Command / URL territory: fold shell line continuations, then parse each
  // remaining line independently (a README block can list several commands).
  final folded = trimmed.replaceAll(RegExp(r'\\\r?\n'), ' ');
  final results = <McpImportEntry>[];
  for (final rawLine in folded.split('\n')) {
    final clean = rawLine.trim();
    if (clean.isEmpty) continue;
    final entry = _parseLine(clean);
    if (entry != null) results.add(entry);
  }
  return results.isNotEmpty ? results : null;
}
