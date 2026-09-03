/// HermesToolCard — collapsible tool-call card with detailed view.
///
/// Matches the desktop design:
/// - Header bar: icon + name + status + copy + expand/collapse
/// - Collapsed: one-line summary with key args
/// - Expanded: structured parameters (key-value pairs) + formatted result
/// - Full detail dialog for long content
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../chat/content/ansi_text.dart';
import '../../chat/content/compact_markdown.dart';
import '../../chat/tools/tool_dismiss_store.dart';
import '../../core/stores/tool_view_mode_store.dart';
import '../../core/clipboard.dart';
import '../../core/tool_presentation.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import 'hermes_status.dart';

enum _ToolSection { arguments, result }

/// Unified interaction logger for tool-card interactions.
///
/// Format: `[HermesToolCard][action] ts=ISO-8601 source=tap|shortcut|gesture`
/// followed by the tool name, status, previous state, next state, and JSON
/// interaction context.
void _logInteraction({
  required String action,
  required String source,
  required String toolName,
  required HermesToolStatus status,
  Map<String, dynamic> contextExtra = const {},
  String? prevState,
  String? nextState,
}) {
  final ts = DateTime.now().toUtc().toIso8601String();
  final statusLabel = status.name;
  final ctx = jsonEncode(contextExtra.isEmpty ? const {} : contextExtra);
  debugPrint(
    '[HermesToolCard][$action] ts=$ts source=$source tool="$toolName" '
    'status=$statusLabel '
    '${prevState != null ? 'prev=$prevState ' : ''}'
    '${nextState != null ? 'next=$nextState ' : ''}'
    'ctx=$ctx',
  );
}

class HermesToolCard extends StatefulWidget {
  final Map<String, dynamic> data;

  /// Forces the initial expand state (used when this card is the sole focus
  /// of a detail sheet, e.g. tapped out of a [ToolGroupCard] row). Leave
  /// null for the default transcript behavior: every tool card starts
  /// collapsed, regardless of run state.
  final bool? initiallyExpanded;

  const HermesToolCard({super.key, required this.data, this.initiallyExpanded});

  @override
  State<HermesToolCard> createState() => _HermesToolCardState();
}

class _HermesToolCardState extends State<HermesToolCard> {
  bool _expanded = false;
  bool _showArgs = true;
  bool _showResult = true;
  bool _technical = false;

  static const _inlineLimit = 20000;

  @override
  void initState() {
    super.initState();
    // Every tool card starts collapsed to keep the transcript compact —
    // including while running; the header's spinner/status still shows
    // progress without forcing the body open.
    _expanded = widget.initiallyExpanded ?? false;
  }

  HermesToolStatus get _status {
    final d = widget.data;
    if (d['is_error'] == true) return HermesToolStatus.failed;
    if (d['running'] == true) return HermesToolStatus.running;
    return HermesToolStatus.completed;
  }

  String get _toolName =>
      (widget.data['name'] ?? widget.data['tool_name'] ?? 'tool').toString();

  /// Stable id for per-row dismissal (desktop `dismissToolRow`).
  String get _dismissId =>
      'tool-row:${widget.data['tool_id'] ?? widget.data['id'] ?? _toolName}';

  ToolDismissStore? _dismissStore(BuildContext context) {
    try {
      return context.watch<ToolDismissStore>();
    } catch (_) {
      return null;
    }
  }

  String get _currentTopLevelState => _expanded ? 'expanded' : 'collapsed';

  String _sectionState(_ToolSection section) =>
      (section == _ToolSection.arguments ? _showArgs : _showResult)
      ? 'open'
      : 'closed';

  /// Parse args from multiple possible formats into a structured map.
  Map<String, dynamic> _parseArgs() => parseToolArgs(widget.data);

  /// Format a value for display (handles maps, lists, strings, etc.)
  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is Map || value is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    if (value is String) {
      // If string looks like JSON, format it
      final trimmed = value.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final decoded = jsonDecode(trimmed);
          return const JsonEncoder.withIndent('  ').convert(decoded);
        } catch (_) {
          // Not valid JSON, return as-is
        }
      }
      return value;
    }
    return value.toString();
  }

  String _getResultText() {
    final d = widget.data;
    final resultText = d['result_text']?.toString();
    final result = d['result'];
    final summary = d['summary']?.toString();

    if (resultText != null && resultText.isNotEmpty) return resultText;
    if (result != null) return _formatValue(result);
    if (summary != null && summary.isNotEmpty) return summary;
    return '';
  }

  dynamic _rawResult() {
    final d = widget.data;
    if (d.containsKey('result')) return d['result'];
    final text = d['result_text']?.toString() ?? '';
    if (text.isEmpty) return null;
    return toolParseMaybeJson(text);
  }

  ToolPresentationKind get _presentationKind =>
      resolveToolKind(_toolName, _parseArgs());

  /// Whether the structured readable presentation can be rendered inline.
  ///
  /// Oversized payloads fall back to the generic args/result sections, where
  /// `_buildResultView` clamps inline output at [_inlineLimit] and offers a
  /// "查看完整" affordance — this keeps long stdout / file bodies from
  /// flooding the transcript.
  bool get _hasReadablePresentation {
    if (_getResultText().length > _inlineLimit) return false;
    for (final value in _parseArgs().values) {
      if (_formatValue(value).length > _inlineLimit) return false;
    }
    return true;
  }

  IconData get _toolIcon => toolKindIcon(_presentationKind);

  String _collapsedSummary(Map<String, dynamic> args) =>
      toolCollapsedSummary(_presentationKind, args);

  Widget _buildReadablePresentation(
    BuildContext context,
    Map<String, dynamic> args,
    String result,
    bool isDark,
  ) {
    final palette = HermesPalette.of(context);
    final codeColor = palette.text;
    final muted = palette.text3;
    Widget labeledCode(String label, String value, {String? hint}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          // Prototype parity (`.codebox{padding:9px 11px}`).
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 11),
          decoration: toolCodeBoxDecoration(context),
          constraints: const BoxConstraints(maxHeight: 220),
          child: SingleChildScrollView(
            // ANSI-coloured command output renders as spans, not raw \x1B noise.
            child: value.isEmpty
                ? SelectableText(
                    hint ?? context.l10n.toolValueNotProvided,
                    style: HermesType.code.copyWith(
                      color: codeColor,
                      fontSize: 12,
                    ),
                  )
                : AnsiText.contains(value)
                ? AnsiText(
                    text: value,
                    style: HermesType.code.copyWith(
                      color: codeColor,
                      fontSize: 12,
                    ),
                  )
                : SelectableText(
                    value,
                    style: HermesType.code.copyWith(
                      color: codeColor,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
      ],
    );

    switch (_presentationKind) {
      case ToolPresentationKind.terminal:
        final command = toolShellCommand(args);
        final streams = toolParseTerminalStreams(_rawResult(), result);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labeledCode(
              context.l10n.toolCommand,
              command,
              hint: context.l10n.toolWaitingCommand,
            ),
            if (streams.stdout.isNotEmpty) ...[
              const SizedBox(height: 12),
              labeledCode(context.l10n.toolOutput, streams.stdout),
            ],
            if (streams.stderr.isNotEmpty) ...[
              const SizedBox(height: 12),
              labeledCode(context.l10n.toolErrorOutput, streams.stderr),
            ],
            if (streams.exitCode != null) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.toolExitCode(streams.exitCode!),
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ],
        );
      case ToolPresentationKind.executeCode:
        final language = toolFirstStringField(args, ['language', 'lang']);
        final code = toolFirstStringField(args, ['code', 'script', 'source']);
        final streams = toolParseTerminalStreams(_rawResult(), result);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labeledCode(
              language.isEmpty
                  ? context.l10n.toolCode
                  : context.l10n.toolCodeLanguage(language),
              code,
              hint: context.l10n.toolWaitingCode,
            ),
            if (streams.stdout.isNotEmpty) ...[
              const SizedBox(height: 12),
              labeledCode(context.l10n.toolExecutionResult, streams.stdout),
            ] else if (result.isNotEmpty) ...[
              const SizedBox(height: 12),
              labeledCode(context.l10n.toolExecutionResult, result),
            ],
          ],
        );
      case ToolPresentationKind.patch:
        final patch = toolFirstStringField(args, ['patch', 'content', 'diff']);
        final files = RegExp(
          r'^\*\*\* (?:Update|Add|Delete) File: (.+)$',
          multiLine: true,
        ).allMatches(patch).map((match) => match.group(1)!).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (files.isNotEmpty) ...[
              Text(
                context.l10n.toolChangedFiles(files.length),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              for (final file in files)
                Text(
                  file,
                  style: HermesType.code.copyWith(fontSize: 12, color: muted),
                ),
              const SizedBox(height: 10),
            ],
            labeledCode(
              context.l10n.toolPatchContent,
              patch,
              hint: context.l10n.toolWaitingPatch,
            ),
            if (result.isNotEmpty) ...[
              const SizedBox(height: 12),
              labeledCode(context.l10n.toolResult, result),
            ],
          ],
        );
      case ToolPresentationKind.webSearch:
        final query = toolSearchQuery(args);
        final hits = toolExtractSearchHits(_rawResult() ?? result);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labeledCode(
              context.l10n.toolSearchQuery,
              query,
              hint: context.l10n.toolSearchingWeb,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.toolSearchResults(hits.length),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            if (hits.isEmpty)
              labeledCode(
                context.l10n.toolResult,
                result,
                hint: context.l10n.toolNoResults,
              )
            else
              for (final hit in hits)
                _buildSearchResultRow(
                  {'title': hit.title, 'url': hit.url, 'snippet': hit.snippet},
                  codeColor,
                  muted,
                ),
          ],
        );
      case ToolPresentationKind.webExtract:
        final url = toolFirstStringField(args, ['url', 'href', 'link']);
        final record = toolParseMaybeObject(_rawResult() ?? result);
        final content = toolFirstStringField(record, [
          'content',
          'text',
          'markdown',
          'body',
          'summary',
          'message',
        ]);
        final body = content.isNotEmpty ? content : result;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (url.isNotEmpty) labeledCode(context.l10n.toolLink, url),
            if (url.isNotEmpty && body.isNotEmpty) const SizedBox(height: 12),
            if (body.isNotEmpty) labeledCode(context.l10n.toolContent, body),
          ],
        );
      case ToolPresentationKind.readFile:
        final path = toolFilePath(args);
        final record = toolParseMaybeObject(_rawResult() ?? result);
        final content = toolFirstStringField(record, [
          'content',
          'text',
          'body',
          'data',
        ]);
        final body = content.isNotEmpty
            ? content
            : (record.isEmpty ? result : '');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labeledCode(
              context.l10n.toolFile,
              path,
              hint: context.l10n.toolReadingFile,
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 12),
              labeledCode(context.l10n.toolContent, body),
            ],
          ],
        );
      case ToolPresentationKind.writeFile:
        final path = toolFilePath(args);
        final content = toolFirstStringField(args, [
          'content',
          'text',
          'body',
          'data',
        ]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labeledCode(
              context.l10n.toolFile,
              path,
              hint: context.l10n.toolWritingFile,
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              labeledCode(context.l10n.toolWriteContent, content),
            ],
            if (result.isNotEmpty) ...[
              const SizedBox(height: 12),
              labeledCode(context.l10n.toolResult, result),
            ],
          ],
        );
      case ToolPresentationKind.listFiles:
        final items = toolCollectResultItems(_rawResult() ?? result);
        final paths = <String>[];
        for (final item in items) {
          final row = toolParseMaybeObject(item);
          final path = toolFirstStringField(row, [
            'path',
            'file',
            'name',
            'title',
            'filepath',
          ]);
          if (path.isNotEmpty) paths.add(path);
        }
        if (paths.isEmpty) {
          final record = toolParseMaybeObject(_rawResult() ?? result);
          final files = record['files'];
          if (files is List) {
            for (final file in files) {
              final path = toolDisplayScalar(file);
              if (path.isNotEmpty) paths.add(path);
            }
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.toolFileList(paths.length),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            if (paths.isEmpty)
              labeledCode(
                context.l10n.toolResult,
                result,
                hint: context.l10n.toolNoFiles,
              )
            else
              for (final path in paths.take(24))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    path,
                    style: HermesType.code.copyWith(fontSize: 12, color: muted),
                  ),
                ),
          ],
        );
      case ToolPresentationKind.generateImage:
      case ToolPresentationKind.generic:
        return _buildGenericReadablePresentation(
          context,
          args: args,
          result: result,
          isDark: isDark,
          labeledCode: labeledCode,
          muted: muted,
        );
    }
  }

  Widget _buildGenericReadablePresentation(
    BuildContext context, {
    required Map<String, dynamic> args,
    required String result,
    required bool isDark,
    required Widget Function(String label, String value, {String? hint})
    labeledCode,
    required Color muted,
  }) {
    final children = <Widget>[];
    for (final entry in toolOrderedFields(args)) {
      final label = toolHumanFieldLabel(entry.key);
      final value = toolDisplayScalar(entry.value, maxLen: 1200);
      if (value.isEmpty) continue;
      children.add(labeledCode(label, value));
      children.add(const SizedBox(height: 10));
    }

    final raw = _rawResult() ?? result;
    final hits = toolExtractSearchHits(raw);
    if (hits.isNotEmpty) {
      children.add(
        Text(
          context.l10n.toolSearchResults(hits.length),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
      children.add(const SizedBox(height: 5));
      for (final hit in hits) {
        children.add(
          _buildSearchResultRow(
            {'title': hit.title, 'url': hit.url, 'snippet': hit.snippet},
            HermesPalette.of(context).text,
            muted,
          ),
        );
      }
    } else {
      final record = toolParseMaybeObject(raw);
      if (record.isNotEmpty) {
        for (final entry in toolOrderedFields(record)) {
          if (entry.key == 'results' || entry.key == 'items') continue;
          final label = toolHumanFieldLabel(entry.key);
          final value = toolDisplayScalar(entry.value, maxLen: 1200);
          if (value.isEmpty) continue;
          children.add(labeledCode(label, value));
          children.add(const SizedBox(height: 10));
        }
      } else if (result.trim().isNotEmpty) {
        children.add(labeledCode(context.l10n.toolResult, result));
      }
    }

    if (children.isEmpty) {
      return labeledCode(
        context.l10n.toolDetails,
        context.l10n.toolNoReadableContent,
        hint: context.l10n.toolWaitingForResult,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildSearchResultRow(
    Map<String, dynamic> item,
    Color primary,
    Color muted,
  ) {
    final title =
        (item['title'] ??
                item['name'] ??
                item['label'] ??
                context.l10n.toolUntitledResult)
            .toString();
    final url = (item['url'] ?? item['link'] ?? item['href'] ?? '').toString();
    final snippet =
        (item['snippet'] ??
                item['description'] ??
                item['content'] ??
                item['text'] ??
                '')
            .toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: toolCodeBoxDecoration(context, radius: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
          if (url.isNotEmpty)
            Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: hermesSemantic(
                  context,
                  HermesSemantic.blue,
                  HermesSemanticDark.blue,
                ),
              ),
            ),
          if (snippet.isNotEmpty)
            Text(
              snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: muted),
            ),
        ],
      ),
    );
  }

  void _showFullDetail(String title, String content) {
    final codeColor = HermesPalette.of(context).text;
    _logInteraction(
      action: 'open-full-detail',
      source: 'button-tap',
      toolName: _toolName,
      status: _status,
      prevState: _currentTopLevelState,
      contextExtra: {
        'title': title,
        'content_length': content.length,
        'args_section': _sectionState(_ToolSection.arguments),
        'result_section': _sectionState(_ToolSection.result),
      },
    );
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: context.l10n.toolCopyAll,
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  final copied = await copyTextOrNotify(
                    ctx,
                    content,
                    successMessage: context.l10n.commonCopied,
                  );
                  if (!copied) return;
                  _logInteraction(
                    action: 'copy-full-detail',
                    source: 'dialog-button-tap',
                    toolName: _toolName,
                    status: _status,
                    contextExtra: {
                      'title': title,
                      'content_length': content.length,
                    },
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              content,
              style: HermesType.code.copyWith(color: codeColor),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = widget.data;
    final name = (d['name'] ?? 'tool').toString();
    final status = _status;
    final isFailed = status == HermesToolStatus.failed;
    final codeBg = palette.codeBg;

    final argsMap = _parseArgs();
    final resultText = _getResultText();
    final settled =
        status != HermesToolStatus.running &&
        status != HermesToolStatus.pending;

    // A7: hover/settled per-row dismiss (desktop `dismissToolRow`).
    final dismiss = _dismissStore(context);
    if (settled && dismiss != null && dismiss.isDismissed(_dismissId)) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: ValueKey('restore-$_dismissId'),
          onPressed: () => dismiss.restore(_dismissId),
          icon: const Icon(Icons.visibility_outlined, size: 14),
          label: Text(context.l10n.toolHiddenRestore(name)),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 11),
          ),
        ),
      );
    }

    // A5: a landed `memory` write gets a gold→purple gradient title.
    final memoryLegendary =
        settled &&
        _toolName == 'memory' &&
        status == HermesToolStatus.completed;

    final statusIcon = switch (status) {
      HermesToolStatus.running => Icons.settings_ethernet,
      HermesToolStatus.failed => Icons.error_outline,
      HermesToolStatus.pending => Icons.schedule,
      HermesToolStatus.cancelled => Icons.cancel_outlined,
      _ => Icons.check_circle_outline,
    };

    // Collapsed summary: show first 2 key args
    final summaryArgs = argsMap.entries
        .take(2)
        .map(
          (e) =>
              '${toolHumanFieldLabel(e.key)}: ${toolDisplayScalar(e.value, maxLen: 36)}',
        )
        .join(', ');
    final readableSummary = _collapsedSummary(argsMap);

    final failedBorder = hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    );
    // Prototype parity (`.toolcard{border-left:3px solid var(--accent);
    // background:var(--codeBg)}`): a tool card gets its own accent-striped,
    // codeBg-toned identity — distinct from ordinary `surface` cards
    // elsewhere in the app — so it reads as "tool call" at a glance in a
    // long transcript. The stripe turns the failure color on error, mirroring
    // the prototype's own `tone` override for special tool cards.
    final edgeColor = isFailed
        ? failedBorder.withValues(alpha: 0.4)
        : palette.border;
    final stripeColor = isFailed ? failedBorder : palette.accent;
    // Flutter can't combine a non-uniform-color Border with a borderRadius
    // (throws "A borderRadius can only be given on borders with uniform
    // colors" at paint time), so the accent stripe is a separate clipped
    // child instead of a colored BorderSide.
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: codeBg,
        // Prototype parity (`.toolcard{border-radius:0 11px 11px 0}`): the
        // left edge stays square where the accent stripe sits flush against
        // it; only the right corners round off.
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(kToolCardRadius),
          bottomRight: Radius.circular(kToolCardRadius),
        ),
        border: Border.all(color: edgeColor),
        boxShadow: hermesShadow(context),
      ),
      // IntrinsicHeight lets the stripe stretch to match the content's own
      // height even when an ancestor (a scrollable transcript) gives this
      // card unbounded height — CrossAxisAlignment.stretch alone would
      // throw ("BoxConstraints forces an infinite height") in that case.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: stripeColor),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header bar（§6.7：折叠态高 40 标题行）──
                  InkWell(
                    onTap: () {
                      final prev = _currentTopLevelState;
                      final next = _expanded ? 'collapsed' : 'expanded';
                      _logInteraction(
                        action: 'toggle-expand',
                        source: 'header-tap',
                        toolName: _toolName,
                        status: _status,
                        prevState: prev,
                        nextState: next,
                        contextExtra: {
                          'args_count': argsMap.length,
                          'result_length': resultText.length,
                          'args_section': _sectionState(_ToolSection.arguments),
                          'result_section': _sectionState(_ToolSection.result),
                          'tap_position': 'header-bar',
                        },
                      );
                      setState(() => _expanded = !_expanded);
                    },
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(kToolCardRadius - 1),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Padding(
                        // Prototype parity (`.toolhead{padding:10px 11px}`).
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 11,
                        ),
                        child: Row(
                          children: [
                            // Prototype parity (`.toolhead>span:first-child{
                            // font-size:15px;color:var(--accent)}`): the
                            // kind icon is always accent-colored, matching
                            // the stripe — not re-tinted by run status.
                            Icon(
                              _hasReadablePresentation ? _toolIcon : statusIcon,
                              size: 15,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final label =
                                          status == HermesToolStatus.running
                                          ? '$name…'
                                          : name;
                                      final titleStyle = HermesType.subheadline
                                          .copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: palette.text,
                                          );
                                      if (!memoryLegendary) {
                                        return Text(
                                          label,
                                          style: titleStyle,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      }
                                      return ShaderMask(
                                        blendMode: BlendMode.srcIn,
                                        shaderCallback: (rect) =>
                                            const LinearGradient(
                                              colors: [
                                                Color(0xFFE5B94E),
                                                Color(0xFF9D6BE8),
                                              ],
                                            ).createShader(rect),
                                        child: Text(
                                          label,
                                          style: titleStyle.copyWith(
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                  if (!_expanded &&
                                      (readableSummary.isNotEmpty ||
                                          summaryArgs.isNotEmpty))
                                    Text(
                                      readableSummary.isNotEmpty
                                          ? readableSummary
                                          : summaryArgs,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: palette.text3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            HermesToolStatusView(status: status),
                            const SizedBox(width: 3),
                            // Prototype parity (`.toolhead-actions button{
                            // width:23px;height:23px;border-radius:7px}`):
                            // tight, compact icon buttons — not full 44px
                            // touch targets — so the action row stays as
                            // slim as the prototype's, instead of crowding
                            // out the title on a narrow phone.
                            if (_expanded)
                              _HeadAction(
                                tooltip: _technical
                                    ? context.l10n.toolReadableView
                                    : context.l10n.toolRawJsonView,
                                on: _technical,
                                icon: _technical
                                    ? Icons.data_object
                                    : Icons.data_object_outlined,
                                onTap: () =>
                                    setState(() => _technical = !_technical),
                              ),
                            if (settled && dismiss != null)
                              _HeadAction(
                                tooltip: context.l10n.toolHideRow,
                                icon: Icons.visibility_off_outlined,
                                onTap: () => dismiss.dismiss(_dismissId),
                              ),
                            if (resultText.isNotEmpty)
                              _HeadAction(
                                tooltip: context.l10n.toolCopyResult,
                                icon: Icons.copy_outlined,
                                onTap: () async {
                                  final copied = await copyTextOrNotify(
                                    context,
                                    resultText,
                                    successMessage: context.l10n.commonCopied,
                                  );
                                  if (!copied) return;
                                  _logInteraction(
                                    action: 'copy-result',
                                    source: 'icon-button-tap',
                                    toolName: _toolName,
                                    status: _status,
                                    prevState: _currentTopLevelState,
                                    contextExtra: {
                                      'result_length': resultText.length,
                                      'tap_position': 'header-copy-icon',
                                    },
                                  );
                                },
                              ),
                            // Prototype parity (`.chevicon`): a purely
                            // decorative rotating chevron — the whole header
                            // (this InkWell) is already the tap target, so
                            // this isn't its own separate button.
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: AnimatedRotation(
                                turns: _expanded ? .5 : 0,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.expand_more,
                                  size: 14,
                                  color: palette.text4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Expanded view: structured args + result ──
                  // Prototype parity (`.toolbody{padding:0 11px 11px}`): no
                  // divider between header and body — the transition is
                  // seamless (both share the card's own `codeBg` tone), and
                  // there's no top padding since the header already ends
                  // with its own bottom padding.
                  if (_expanded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
                      child: _technical
                          ? _buildTechnicalView(context, argsMap, resultText)
                          : _buildFriendlyExpanded(
                              context,
                              argsMap,
                              resultText,
                              isDark,
                              isFailed,
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Raw args + result JSON, for the `technical` view mode (desktop
  /// `ToolPayloadDisclosure`).
  Widget _buildTechnicalView(
    BuildContext context,
    Map<String, dynamic> argsMap,
    String resultText,
  ) {
    final palette = HermesPalette.of(context);
    Widget block(String label, String body) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 11),
          decoration: toolCodeBoxDecoration(context),
          child: SingleChildScrollView(
            child: SelectableText(
              body.isEmpty ? '—' : body,
              style: HermesType.code.copyWith(
                fontSize: 11,
                color: palette.text,
              ),
            ),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block('args', ToolViewModeStore.prettyJson(widget.data['args'])),
        const SizedBox(height: 10),
        block(
          'result',
          ToolViewModeStore.prettyJson(_rawResult() ?? resultText),
        ),
      ],
    );
  }

  Widget _buildFriendlyExpanded(
    BuildContext context,
    Map<String, dynamic> argsMap,
    String resultText,
    bool isDark,
    bool isFailed,
  ) {
    // No `color:` here — the whole card already sits on `codeBg`
    // (prototype `.toolcard{background:var(--codeBg)}`).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasReadablePresentation) ...[
          _buildReadablePresentation(context, argsMap, resultText, isDark),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showFullDetail(
                context.l10n.toolRawDetailsTitle(_toolName),
                const JsonEncoder.withIndent('  ').convert(widget.data),
              ),
              icon: const Icon(Icons.data_object_outlined, size: 16),
              label: Text(context.l10n.toolViewRawDetails),
            ),
          ),
        ] else ...[
          // ── Arguments section ──
          if (argsMap.isNotEmpty) ...[
            _buildSection(
              context,
              title: context.l10n.toolArguments,
              section: _ToolSection.arguments,
              icon: Icons.settings,
              child: _buildArgsList(argsMap),
            ),
            const SizedBox(height: 12),
          ],

          // ── Result section ──
          // A4: skip a result that just echoes the summary or is a
          // trivial ok/done acknowledgement (desktop `looksRedundant`).
          if (resultText.isNotEmpty &&
              !_resultIsRedundant(resultText, argsMap)) ...[
            _buildSection(
              context,
              title: context.l10n.toolResult,
              section: _ToolSection.result,
              icon: Icons.check_circle,
              child: _buildResultView(resultText, isFailed),
            ),
          ],

          // ── Empty state ──
          if (argsMap.isEmpty && resultText.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.l10n.toolNoDetailedData,
                style: TextStyle(
                  fontSize: 12,
                  color: HermesPalette.of(context).text3,
                ),
              ),
            ),
        ],
      ],
    );
  }

  static final _emptyOkResult = RegExp(
    r'^\s*(?:"ok"|\{\s*"?ok"?\s*:\s*true\s*\}|\[\s*\]|\{\s*\})\s*$',
    caseSensitive: false,
  );

  /// A result worth hiding only when it adds nothing over the summary line, or
  /// is a bare `{"ok": true}` acknowledgement (desktop `looksRedundant`). A
  /// short human string like "Done!" is NOT redundant.
  bool _resultIsRedundant(String result, Map<String, dynamic> args) {
    final trimmed = result.trim();
    if (trimmed.isEmpty || _emptyOkResult.hasMatch(trimmed)) return true;
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final summary = norm(_collapsedSummary(args));
    return summary.isNotEmpty && norm(trimmed) == summary;
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required _ToolSection section,
    required IconData icon,
    required Widget child,
  }) {
    final palette = HermesPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            final sectionKey = section.name;
            final prev = _sectionState(section);
            final next = prev == 'open' ? 'closed' : 'open';
            _logInteraction(
              action: 'toggle-section',
              source: 'section-header-tap',
              toolName: _toolName,
              status: _status,
              prevState: '${sectionKey.toLowerCase()}-$prev',
              nextState: '${sectionKey.toLowerCase()}-$next',
              contextExtra: {
                'section': sectionKey,
                'top_level_state': _currentTopLevelState,
              },
            );
            setState(() {
              if (section == _ToolSection.arguments) {
                _showArgs = !_showArgs;
              } else {
                _showResult = !_showResult;
              }
            });
          },
          child: Row(
            children: [
              Icon(icon, size: 14, color: palette.text2),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.text2,
                ),
              ),
              const Spacer(),
              Icon(
                (section == _ToolSection.arguments ? _showArgs : _showResult)
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 16,
                color: palette.text3,
              ),
            ],
          ),
        ),
        if (section == _ToolSection.arguments ? _showArgs : _showResult)
          Padding(padding: const EdgeInsets.only(top: 6), child: child),
      ],
    );
  }

  Widget _buildArgsList(Map<String, dynamic> args) {
    final palette = HermesPalette.of(context);
    final children = <Widget>[];
    for (final entry in args.entries) {
      final key = entry.key;
      final value = entry.value;
      final formattedValue = _formatValue(value);

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                constraints: const BoxConstraints(minWidth: 80),
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.text2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (formattedValue.length > 200) {
                      _logInteraction(
                        action: 'open-arg-detail',
                        source: 'arg-value-tap',
                        toolName: _toolName,
                        status: _status,
                        prevState: _currentTopLevelState,
                        contextExtra: {
                          'arg_key': key,
                          'arg_value_length': formattedValue.length,
                        },
                      );
                      _showFullDetail(
                        context.l10n.toolArgumentDetailsTitle(key),
                        formattedValue,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: toolCodeBoxDecoration(context),
                    child: Text(
                      formattedValue.length > 300
                          ? '${formattedValue.substring(0, 300)}…'
                                '\n${context.l10n.toolTapForFullContent(formattedValue.length)}'
                          : formattedValue,
                      style: HermesType.code.copyWith(
                        fontSize: 12,
                        color: palette.text,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildResultView(String resultText, bool isFailed) {
    final palette = HermesPalette.of(context);
    final hasLongContent = resultText.length > _inlineLimit;
    final displayText = hasLongContent
        ? resultText.substring(0, _inlineLimit)
        : resultText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 11),
          decoration: toolCodeBoxDecoration(context),
          constraints: const BoxConstraints(maxHeight: 220),
          child: SingleChildScrollView(
            child: isFailed || AnsiText.contains(displayText)
                ? AnsiText(
                    text: displayText,
                    style: HermesType.code.copyWith(
                      fontSize: 12,
                      color: isFailed
                          ? hermesSemantic(
                              context,
                              HermesSemantic.red,
                              HermesSemanticDark.red,
                            )
                          : palette.text,
                    ),
                  )
                : CompactMarkdown(text: displayText),
          ),
        ),
        if (hasLongContent) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                context.l10n.toolContentTooLong(resultText.length),
                style: TextStyle(fontSize: 11, color: palette.text3),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _logInteraction(
                    action: 'open-result-detail',
                    source: 'result-button-tap',
                    toolName: _toolName,
                    status: _status,
                    prevState: _currentTopLevelState,
                    contextExtra: {
                      'result_length': resultText.length,
                      'has_long_content': hasLongContent,
                    },
                  );
                  _showFullDetail(
                    context.l10n.toolFullResultTitle(
                      (widget.data['name'] ?? 'tool').toString(),
                    ),
                    resultText,
                  );
                },
                icon: const Icon(Icons.open_in_full, size: 16),
                label: Text(context.l10n.toolViewFull),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Prototype's own tool-card corner radius (`.toolcard{border-radius:0 11px
/// 11px 0}`) — distinct from the app's general [HermesRadius.card] (15),
/// which every OTHER card type (sessions, settings rows, …) uses.
const double kToolCardRadius = 11;

/// Prototype parity (`.toolhead-actions button{width:23px;height:23px;
/// border-radius:7px}`): a compact header icon button, sized to the
/// prototype's own tight footprint rather than a full 44px touch target —
/// several of these sit in a row next to the title, so oversizing any one
/// of them crowds out the whole header on a narrow phone.
class _HeadAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool on;

  const _HeadAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.on = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: on ? palette.accentBg : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 25,
            height: 25,
            child: Icon(
              icon,
              size: 13,
              color: on ? palette.accent : palette.text4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-tool-kind icon (prototype `icon()` mapping parity), shared by
/// [HermesToolCard] and [ToolGroupCard]'s rollup rows so a tool reads the
/// same regardless of whether it's showing individually or inside a group.
IconData toolKindIcon(ToolPresentationKind kind) {
  switch (kind) {
    case ToolPresentationKind.terminal:
      return Icons.terminal;
    case ToolPresentationKind.executeCode:
      return Icons.code;
    case ToolPresentationKind.webSearch:
      return Icons.travel_explore;
    case ToolPresentationKind.webExtract:
      return Icons.link;
    case ToolPresentationKind.patch:
      return Icons.difference_outlined;
    case ToolPresentationKind.writeFile:
      return Icons.edit_document;
    case ToolPresentationKind.readFile:
      return Icons.description_outlined;
    case ToolPresentationKind.listFiles:
      return Icons.folder_open_outlined;
    case ToolPresentationKind.generateImage:
      return Icons.image_outlined;
    case ToolPresentationKind.generic:
      return Icons.build_outlined;
  }
}

/// Prototype parity (`.codebox{background:var(--elevated);border:1px solid
/// var(--border)}`): a crisp, bordered "one level up" box for nested
/// code/value content inside a tool card — instead of an ad-hoc black/white
/// alpha blend layered on top of the card's own tint, which (a) reads
/// slightly differently at every call site since each one picked its own
/// alpha, and (b) went the wrong direction in dark mode for at least one
/// caller (adding black on top of an already-dark surface darkens it
/// further instead of elevating it).
BoxDecoration toolCodeBoxDecoration(
  BuildContext context, {
  double radius = HermesRadius.smallCard,
}) {
  final palette = HermesPalette.of(context);
  return BoxDecoration(
    color: palette.elevated,
    border: Border.all(color: palette.border),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// Shared "tool call" card chrome (prototype `.toolcard` parity: accent
/// left-stripe + codeBg base + rounded corners), factored out of
/// [HermesToolCard]'s header so every dedicated tool card (terminal, diff,
/// changed-files, web search, …) shares the exact same identity instead of
/// each falling back to a bare default Material `Card`/`ExpansionTile` —
/// which is what made historical tool calls look inconsistent card-to-card.
class ToolCardShell extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;

  /// Overrides both the stripe and the default icon tint (still `palette
  /// .accent` when omitted). Lets callers give a shell a distinct identity
  /// — e.g. the reasoning card's purple — while keeping identical chrome.
  final Color? accentColor;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool initiallyExpanded;
  final bool failed;
  final List<Widget> children;

  const ToolCardShell({
    super.key,
    required this.icon,
    this.iconColor,
    this.accentColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.initiallyExpanded = false,
    this.failed = false,
    required this.children,
  });

  @override
  State<ToolCardShell> createState() => _ToolCardShellState();
}

class _ToolCardShellState extends State<ToolCardShell> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant ToolCardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final failedBorder = hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    );
    final edgeColor = widget.failed
        ? failedBorder.withValues(alpha: 0.4)
        : palette.border;
    final tint = widget.accentColor ?? palette.accent;
    final stripeColor = widget.failed ? failedBorder : tint;
    // Flutter can't combine a non-uniform-color Border with a borderRadius,
    // so the accent stripe is a separate clipped child, not a BorderSide.
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.codeBg,
        // Prototype parity (`.toolcard{border-radius:0 11px 11px 0}`).
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(kToolCardRadius),
          bottomRight: Radius.circular(kToolCardRadius),
        ),
        border: Border.all(color: edgeColor),
        boxShadow: hermesShadow(context),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: stripeColor),
            Expanded(child: _buildShellBody(context, palette, tint)),
          ],
        ),
      ),
    );
  }

  Widget _buildShellBody(
    BuildContext context,
    HermesPalette palette,
    Color tint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(kToolCardRadius - 1),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              // Prototype parity (`.toolhead{padding:10px 11px}`).
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 11),
              child: Row(
                children: [
                  Icon(widget.icon, size: 15, color: widget.iconColor ?? tint),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: HermesType.subheadline.copyWith(
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle != null) widget.subtitle!,
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 4),
                    widget.trailing!,
                  ],
                  // Prototype parity (`.chevicon`): decorative only — the
                  // whole header (this InkWell) is already the tap target.
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.expand_more,
                        size: 14,
                        color: palette.text4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Prototype parity (`.toolbody{padding:0 11px 11px}`): no divider,
        // seamless with the header above.
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}
