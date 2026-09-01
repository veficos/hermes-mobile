/// Per-tool MCP gating — ported from hermes-agent's desktop
/// `lib/mcp-tool-filter.ts` and `lib/mcp-cost.ts`. A server's optional
/// `tools.include` (whitelist) / `tools.exclude` (denylist) decide which
/// discovered tools the agent registers — `include` wins, no filter means
/// all. Mirrors `_register_server_tools` in `tools/mcp_tool.py`.
library;

class McpToolsFilter {
  final List<String>? exclude;
  final List<String>? include;

  const McpToolsFilter({this.exclude, this.include});
}

List<String>? _asNames(dynamic value) {
  if (value is! List) return null;
  return value.whereType<String>().toList();
}

Map<String, dynamic> _toolsObject(Map<String, dynamic>? server) {
  final tools = server?['tools'];
  if (tools is Map) return tools.cast<String, dynamic>();
  return const {};
}

McpToolsFilter readToolsFilter(Map<String, dynamic>? server) {
  final tools = _toolsObject(server);
  return McpToolsFilter(
    exclude: _asNames(tools['exclude']),
    include: _asNames(tools['include']),
  );
}

bool isToolEnabled(Map<String, dynamic>? server, String name) {
  final filter = readToolsFilter(server);
  final include = filter.include;
  if (include != null && include.isNotEmpty) return include.contains(name);
  return !(filter.exclude?.contains(name) ?? false);
}

/// Toggle one tool, preserving the config's mode (include if present, else an
/// exclude denylist). Empty lists — and an emptied `tools` — are dropped.
Map<String, dynamic> toggleToolInServer(Map<String, dynamic> server, String name) {
  final filter = readToolsFilter(server);
  final useInclude = filter.include != null && filter.include!.isNotEmpty;
  final key = useInclude ? 'include' : 'exclude';
  final current = List<String>.from(
    (useInclude ? filter.include : filter.exclude) ?? const [],
  );
  if (current.contains(name)) {
    current.remove(name);
  } else {
    current.add(name);
  }
  final tools = Map<String, dynamic>.from(_toolsObject(server));
  if (current.isNotEmpty) {
    tools[key] = current;
  } else {
    tools.remove(key);
  }
  final next = Map<String, dynamic>.from(server);
  if (tools.isNotEmpty) {
    next['tools'] = tools;
  } else {
    next.remove('tools');
  }
  return next;
}

int countEnabledTools(Map<String, dynamic>? server, List<String> names) =>
    names.where((name) => isToolEnabled(server, name)).length;

/// Approximate per-call prompt-token cost of a server's tool schemas: the sum
/// of `ceil(schema_chars / 4)` over ENABLED tools. Returns null when no
/// enabled tool carries `schema_chars` (older backend, failed probe, or
/// everything filtered out) — the caller shows no estimate.
int? estimateServerTokens(
  Map<String, dynamic>? server,
  List<Map<String, dynamic>> tools,
) {
  var total = 0;
  var sawSchema = false;
  for (final tool in tools) {
    final chars = tool['schema_chars'];
    if (chars is! num || !chars.isFinite || chars <= 0) continue;
    final name = (tool['name'] ?? '').toString();
    if (!isToolEnabled(server, name)) continue;
    sawSchema = true;
    total += (chars / 4).ceil();
  }
  return sawSchema ? total : null;
}

/// Mirror of `sanitize_mcp_name_component` in tools/mcp_tool.py: hyphens (and
/// anything else outside `[A-Za-z0-9_]`) become underscores.
String sanitizeMcpNameComponent(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

/// Registry-name prefix for one server's tools — `mcp__<server>__`.
String mcpServerUsagePrefix(String serverName) =>
    'mcp__${sanitizeMcpNameComponent(serverName)}__';

/// Sum 30-day analytics call counts across one server's tools.
int serverUsageCount(String serverName, Map<String, dynamic> toolCalls) {
  final prefix = mcpServerUsagePrefix(serverName);
  var total = 0;
  for (final entry in toolCalls.entries) {
    if (entry.key.startsWith(prefix) && entry.value is num) {
      total += (entry.value as num).toInt();
    }
  }
  return total;
}
