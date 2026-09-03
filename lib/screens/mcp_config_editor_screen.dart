import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/mcp_import.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';

/// Full-screen JSON editor for one MCP server or the complete mcp.json file.
class McpConfigEditorScreen extends StatefulWidget {
  const McpConfigEditorScreen({
    super.key,
    required this.title,
    required this.initialValue,
    this.documentEditor = false,
  });

  final String title;
  final String initialValue;
  final bool documentEditor;

  @override
  State<McpConfigEditorScreen> createState() => _McpConfigEditorScreenState();
}

class McpServerDraftResult {
  const McpServerDraftResult({this.payload, this.imports});

  final Map<String, dynamic>? payload;
  final List<McpImportEntry>? imports;
}

/// Full-page structured editor for adding an MCP server.
class McpServerEditorScreen extends StatefulWidget {
  const McpServerEditorScreen({super.key});

  @override
  State<McpServerEditorScreen> createState() => _McpServerEditorScreenState();
}

class _McpServerEditorScreenState extends State<McpServerEditorScreen> {
  final _name = TextEditingController();
  final _endpoint = TextEditingController();
  final _args = TextEditingController();
  final _env = TextEditingController(text: '{}');
  final _bearer = TextEditingController();
  final _import = TextEditingController();
  String _transport = 'url';
  String _auth = 'none';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _args.dispose();
    _env.dispose();
    _bearer.dispose();
    _import.dispose();
    super.dispose();
  }

  void _parseImport() {
    final entries = parseMcpImport(_import.text);
    if (entries == null || entries.isEmpty) {
      setState(() => _error = context.l10n.mcpImportUnrecognized);
      return;
    }
    if (entries.length > 1) {
      Navigator.pop(context, McpServerDraftResult(imports: entries));
      return;
    }
    final entry = entries.single;
    final representableKeys = entry.config['url'] is String
        ? const {'url', 'auth'}
        : const {'command', 'args', 'env'};
    if (entry.config.keys.any((key) => !representableKeys.contains(key))) {
      Navigator.pop(context, McpServerDraftResult(imports: entries));
      return;
    }
    setState(() {
      _error = null;
      _name.text = entry.name;
      final url = entry.config['url'];
      if (url is String) {
        _transport = 'url';
        _endpoint.text = url;
        _auth = entry.config['auth']?.toString() ?? 'none';
      } else {
        _transport = 'stdio';
        _endpoint.text = entry.config['command']?.toString() ?? '';
        final rawArgs = entry.config['args'];
        _args.text = rawArgs is List ? rawArgs.join('\n') : '';
        final rawEnv = entry.config['env'];
        _env.text = rawEnv is Map
            ? const JsonEncoder.withIndent('  ').convert(rawEnv)
            : '{}';
      }
    });
  }

  void _save() {
    final name = _name.text.trim();
    final target = _endpoint.text.trim();
    if (name.isEmpty || target.isEmpty) {
      setState(() => _error = context.l10n.mcpJsonObjectRequired);
      return;
    }
    Map<String, dynamic> env = const {};
    if (_transport == 'stdio') {
      try {
        final decoded = jsonDecode(_env.text);
        if (decoded is! Map) throw const FormatException();
        env = {
          for (final item in decoded.entries)
            item.key.toString(): item.value.toString(),
        };
      } on FormatException {
        setState(() => _error = context.l10n.mcpEnvironmentMustBeJson);
        return;
      }
    }
    Navigator.pop(
      context,
      McpServerDraftResult(
        payload: {
          'name': name,
          if (_transport == 'url') 'url': target else 'command': target,
          if (_transport == 'stdio')
            'args': _args.text
                .split('\n')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(),
          if (_transport == 'stdio') 'env': env,
          if (_transport == 'url' && _auth != 'none') 'auth': _auth,
          if (_auth == 'header') 'bearer_token': _bearer.text,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mcpAddServer),
        actions: [
          TextButton(
            key: const ValueKey('mcp-server-save'),
            onPressed: _save,
            child: Text(context.l10n.commonAdd),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextField(
              controller: _import,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.l10n.mcpPasteImport,
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: context.l10n.mcpParse,
                  onPressed: _parseImport,
                  icon: const Icon(Icons.auto_fix_high),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('mcp-server-name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: context.l10n.commonName),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'url',
                  label: Text(context.l10n.mcpRemoteUrl),
                ),
                ButtonSegment(
                  value: 'stdio',
                  label: Text(context.l10n.mcpLocalStdio),
                ),
              ],
              selected: {_transport},
              onSelectionChanged: (value) =>
                  setState(() => _transport = value.first),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('mcp-server-endpoint'),
              controller: _endpoint,
              decoration: InputDecoration(
                labelText: _transport == 'url'
                    ? context.l10n.mcpServerUrl
                    : context.l10n.mcpCommand,
              ),
            ),
            if (_transport == 'stdio') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _args,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: context.l10n.mcpArgumentsOnePerLine,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _env,
                minLines: 4,
                maxLines: 10,
                style: HermesType.code,
                decoration: InputDecoration(
                  labelText: context.l10n.mcpEnvironmentJson,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _auth,
                decoration: InputDecoration(
                  labelText: context.l10n.mcpAuthentication,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text(context.l10n.mcpNoAuthentication),
                  ),
                  DropdownMenuItem(
                    value: 'oauth',
                    child: Text(context.l10n.mcpAuthOauth),
                  ),
                  DropdownMenuItem(
                    value: 'header',
                    child: Text(context.l10n.mcpAuthBearerToken),
                  ),
                ],
                onChanged: (value) => setState(() => _auth = value ?? 'none'),
              ),
              if (_auth == 'header') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _bearer,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.mcpAuthBearerToken,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _McpConfigEditorScreenState extends State<McpConfigEditorScreen> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    String? error;
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is! Map) error = context.l10n.mcpJsonObjectRequired;
    } on FormatException {
      error = context.l10n.mcpInvalidJsonSyntax;
    }
    if (_error != error) setState(() => _error = error);
  }

  void _save() {
    _validate();
    if (_error == null) Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        leadingWidth: 76,
        title: Text(widget.title),
        actions: [
          TextButton(
            key: const ValueKey('mcp-config-save'),
            onPressed: _save,
            child: Text(context.l10n.commonSave),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      widget.documentEditor
                          ? 'mcp.json'
                          : context.l10n.mcpEditConfiguration,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.text3),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: widget.documentEditor
                          ? const ValueKey('mcp-document-editor')
                          : const ValueKey('mcp-server-config-editor'),
                      controller: _controller,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: HermesType.code,
                      onChanged: (_) {
                        if (_error != null) _validate();
                      },
                      decoration: InputDecoration(
                        errorText: _error,
                        errorMaxLines: 2,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
