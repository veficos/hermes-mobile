/// MCP log tail — the mobile equivalent of desktop's "MCP Logs" pane pinned
/// under the mcp.json editor (`McpLogs` in `mcp-tab.tsx`). Polls
/// `GET /api/v1/logs` every 2s, scoped to a server when opened from its row.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/connection_store.dart';
import '../core/connection_reload_mixin.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';

const _logPollInterval = Duration(seconds: 2);

final _stdioMarkerRe = RegExp(
  r"^===== \[.*\] starting MCP server '(.+)' =====$",
);

/// Keep only the stdio-log sections belonging to one server — the shared file
/// has no per-line tags, so a section starts at that server's session marker
/// and runs until the next marker (any server's).
List<String> _filterStdioSections(List<String> lines, String server) {
  final out = <String>[];
  var inSection = false;
  for (final line in lines) {
    final match = _stdioMarkerRe.firstMatch(line.trim());
    if (match != null) inSection = match.group(1) == server;
    if (inSection) out.add(line);
  }
  return out;
}

class McpLogsScreen extends StatefulWidget {
  final String? serverName;
  final bool embedded;
  final String initialSource;
  final String? title;

  const McpLogsScreen({
    super.key,
    this.serverName,
    this.embedded = false,
    this.initialSource = 'stdio',
    this.title,
  });

  @override
  State<McpLogsScreen> createState() => _McpLogsScreenState();
}

class _McpLogsScreenState extends State<McpLogsScreen>
    with ConnectionReloadMixin<McpLogsScreen> {
  List<String>? _lines;
  String? _error;
  late String _source;
  bool _disposed = false;
  bool _polling = false;
  Timer? _pollTimer;
  final _scrollController = ScrollController();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _source = widget.initialSource;
    _poll();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _disposed = true;
    _pollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    _generation++;
    _pollTimer?.cancel();
    _polling = false;
    if (mounted) {
      setState(() {
        _lines = null;
        _error = null;
      });
    }
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_disposed || _polling) return;
    _polling = true;
    final generation = _generation;
    final api = context.read<ConnectionStore>().api;
    final source = _source;
    if (api != null) {
      try {
        final data = source == 'stdio'
            ? await api.getLogs(file: 'mcp', lines: 500)
            : await api.getLogs(
                file: 'agent',
                lines: 300,
                search: widget.serverName ?? 'mcp',
              );
        final rawLines = (data is Map ? data['lines'] : null) as List?;
        var lines =
            rawLines?.map((e) => e.toString()).toList() ?? const <String>[];
        if (source == 'stdio' && widget.serverName != null) {
          lines = _filterStdioSections(lines, widget.serverName!);
        }
        if (!_disposed &&
            mounted &&
            generation == _generation &&
            source == _source &&
            identical(api, context.read<ConnectionStore>().api)) {
          setState(() {
            _lines = lines;
            _error = null;
          });
        }
      } catch (e) {
        if (!_disposed &&
            mounted &&
            generation == _generation &&
            source == _source &&
            identical(api, context.read<ConnectionStore>().api)) {
          setState(() => _error = '$e');
        }
      }
    } else if (mounted) {
      setState(() => _error = connectionOfflineErrorCode);
    }
    if (generation == _generation) _polling = false;
    if (_disposed) return;
    if (generation != _generation) return;
    if (source != _source) {
      unawaited(_poll());
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer(_logPollInterval, _poll);
  }

  void _switchSource(String source) {
    setState(() {
      _source = source;
      _lines = null;
    });
    unawaited(_poll());
  }

  @override
  Widget build(BuildContext context) {
    final sourcePicker = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'stdio',
            label: Text(context.l10n.mcpLogsSourceStdio),
          ),
          ButtonSegment(
            value: 'agent',
            label: Text(context.l10n.mcpLogsSourceAgent),
          ),
        ],
        selected: {_source},
        onSelectionChanged: (value) => _switchSource(value.first),
      ),
    );
    if (widget.embedded) {
      return Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title ??
                        widget.serverName ??
                        context.l10n.mcpLogsAllServers,
                  ),
                ),
                sourcePicker,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody(context)),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? widget.serverName ?? context.l10n.mcpLogsAllServers,
        ),
        actions: [sourcePicker],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final lines = _lines;
    if (lines == null && _error == null) {
      return HermesLoadingState(label: context.l10n.mcpLogsLoading);
    }
    if (_error != null && (lines == null || lines.isEmpty)) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _poll,
      );
    }
    if (lines == null || lines.isEmpty) {
      return HermesEmptyState(
        icon: Icons.article_outlined,
        title: context.l10n.mcpLogsEmpty,
      );
    }
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? HermesBackground.darkSecondary
          : HermesBackground.lightTertiary,
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(HermesSpacing.md),
          child: SelectableText(
            lines.join('\n'),
            style: HermesType.onSurface(HermesType.code, Theme.of(context)),
          ),
        ),
      ),
    );
  }
}
