import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import '../../core/message_preview_targets.dart';
import '../../core/performance_metrics.dart';
import '../../core/session_refs.dart';
import '../../core/stores/plugin_contribution_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/h/hermes_markdown.dart';
import '../../widgets/message_preview_attachments.dart';
import '../../widgets/web_preview.dart' show openChatLink;
import '../content/embed_registry.dart';
import 'code_block.dart';
import 'inline_content.dart';
import 'inline_content_cache.dart';
import 'markdown_alert.dart';
import 'math_view.dart';
import 'preview_file_card.dart';
import 'pretty_links.dart';
import 'reference_chips.dart';
import 'resizable_markdown_table.dart';
import 'streaming_remend.dart';
import 'zoomable_markdown_image.dart';

/// How long a single text node may be before it is collapsed behind a
/// "show more" toggle (desktop `HugeTextFallback` / `ExpandableBlock`).
const _longTextChars = 12000;

class InlineContentRenderer extends StatelessWidget {
  final String text;
  final EmbedRegistry? embeds;
  final bool selectable;
  final bool cachePreparedContent;
  const InlineContentRenderer({
    super.key,
    required this.text,
    this.embeds,
    this.selectable = true,
    this.cachePreparedContent = true,
  });

  @override
  Widget build(BuildContext context) {
    ClientPerformanceMetrics.instance.markdownPrepares++;
    // L1: pull `@image:` / `@url:` / `@file:` refs out of the body — they
    // render as chips below, not as raw `@image:/path` text.
    final prepared = InlineContentCache.instance.prepare(
      text,
      cache: cachePreparedContent,
    );
    final refs = prepared.references;
    final nodes = prepared.nodes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final node in nodes)
          _RenderNode(
            node: node,
            selectable: selectable,
            enableHighlight: cachePreparedContent,
          ),
        if (refs.isNotEmpty) MessageReferenceChips(references: refs),
      ],
    );
  }
}

/// Streaming Markdown renderer that leaves completed blocks on the cached
/// path and reparses only the bounded, synthetically repaired tail.
class StreamingInlineContentRenderer extends StatefulWidget {
  final String text;
  final bool selectable;
  final String? Function(String id)? sessionTitleOf;

  const StreamingInlineContentRenderer({
    super.key,
    required this.text,
    this.selectable = false,
    this.sessionTitleOf,
  });

  @override
  State<StreamingInlineContentRenderer> createState() =>
      _StreamingInlineContentRendererState();
}

class _StreamingInlineContentRendererState
    extends State<StreamingInlineContentRenderer> {
  final IncrementalStreamingMarkdownScanner _scanner =
      IncrementalStreamingMarkdownScanner();
  final List<String> _stableBlocks = <String>[];
  int oldScannedLength = 0;

  @override
  void didUpdateWidget(covariant StreamingInlineContentRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.text.startsWith(oldWidget.text)) {
      _stableBlocks.clear();
      _scanner.reset();
      oldScannedLength = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final added = _scanner.update(widget.text);
    final metrics = ClientPerformanceMetrics.instance;
    metrics.markdownScannedChars += (widget.text.length - oldScannedLength)
        .clamp(0, widget.text.length);
    oldScannedLength = widget.text.length;
    for (final block in added) {
      _stableBlocks.add(
        linkifySessionRefs(block, titleOf: widget.sessionTitleOf),
      );
      ClientPerformanceMetrics.instance.streamingStablePrefixChars +=
          block.length;
    }
    final tail = linkifySessionRefs(
      _scanner.tail(widget.text),
      titleOf: widget.sessionTitleOf,
    );
    metrics.markdownTailChars += tail.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < _stableBlocks.length; index++)
          InlineContentRenderer(
            key: ValueKey('stream-block-$index'),
            text: _stableBlocks[index],
            selectable: widget.selectable,
          ),
        if (tail.isNotEmpty)
          InlineContentRenderer(
            text: remendStreamingMarkdown(tail),
            selectable: widget.selectable,
            cachePreparedContent: false,
          ),
      ],
    );
  }
}

/// One timeline node, wrapped so a synchronous render failure (pathological
/// markdown, a malformed math expression) degrades to plain selectable text
/// instead of taking the whole message down (desktop `ErrorBoundary` →
/// `HugeTextFallback`).
class _RenderNode extends StatelessWidget {
  final InlineContentNode node;
  final bool selectable;
  final bool enableHighlight;
  const _RenderNode({
    required this.node,
    required this.selectable,
    required this.enableHighlight,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return switch (node) {
        InlineCodeNode(:final code, :final language) => codeBlockOrArtifact(
          code,
          language,
          enableHighlight: enableHighlight,
        ),
        InlineDirectiveNode(:final name, :final value) => Chip(
          avatar: const Icon(Icons.tune, size: 15),
          label: Text('$name: $value'),
        ),
        InlinePreviewNode(:final target) => _PreviewNode(target: target),
        InlineAlertNode(:final type, :final body) => MarkdownAlertBox(
          type: type,
          body: body,
          selectable: selectable,
        ),
        InlineMathNode(:final tex) => MathBlockView(tex: tex),
        InlinePreviewFileNode(:final file, :final initialHeight) =>
          PreviewFileCard(file: file, initialHeight: initialHeight),
        InlinePluginDirectiveNode(
          :final name,
          :final attributes,
          :final source,
        ) =>
          _PluginDirectiveCard(
            name: name,
            attributes: attributes,
            source: source,
          ),
        InlineRichNode(:final segments) => MathInlineRun(
          segments: segments,
          selectable: selectable,
        ),
        InlineTextNode(:final text) => _TextNode(
          text: text,
          selectable: selectable,
        ),
      };
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'hermes inline content renderer',
        ),
      );
      return SelectableText(switch (node) {
        InlineTextNode(:final text) => text,
        InlineCodeNode(:final code) => code,
        InlineAlertNode(:final body) => body,
        InlineMathNode(:final tex) => tex,
        _ => node.toString(),
      }, style: HermesType.messageBody);
    }
  }
}

class _PluginDirectiveCard extends StatelessWidget {
  final String name;
  final Map<String, String> attributes;
  final String source;
  const _PluginDirectiveCard({
    required this.name,
    required this.attributes,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    PluginContributionStore? store;
    try {
      store = context.read<PluginContributionStore>();
    } on ProviderNotFoundException {
      return SelectableText(source);
    }
    final matches = store
        .forArea(MobileContributionArea.transcript)
        .where((item) => item.id == name)
        .toList(growable: false);
    if (matches.isEmpty) return SelectableText(source);
    final contribution = matches.first;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.extension_outlined),
        title: Text(contribution.title),
        subtitle: Text(
          contribution.description.isNotEmpty
              ? contribution.description
              : attributes.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join(' · '),
        ),
        trailing: const Icon(Icons.play_arrow),
        onTap: () async {
          try {
            final action = Map<String, dynamic>.from(contribution.action);
            final params =
                (action['params'] as Map?)?.cast<String, dynamic>() ?? const {};
            action['params'] = {
              ...params,
              'directive': name,
              'attributes': attributes,
            };
            final adapted = MobilePluginContribution(
              id: contribution.id,
              pluginId: contribution.pluginId,
              area: contribution.area,
              title: contribution.title,
              description: contribution.description,
              icon: contribution.icon,
              order: contribution.order,
              action: action,
              platforms: contribution.platforms,
              owner: contribution.owner,
            );
            await store!.invoke(adapted);
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.pluginsOperationFailed('$error')),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _TextNode extends StatefulWidget {
  final String text;
  final bool selectable;
  const _TextNode({required this.text, required this.selectable});

  @override
  State<_TextNode> createState() => _TextNodeState();
}

class _TextNodeState extends State<_TextNode> {
  bool _expanded = false;

  Widget _markdown(BuildContext context, String data) => MarkdownBody(
    data: prettifyBareLinks(upgradeImageLinks(data)),
    selectable: widget.selectable,
    styleSheet: hermesMarkdownStyle(context, compact: true),
    extensionSet: md.ExtensionSet.gitHubFlavored,
    builders: {'table': ResizableMarkdownTableBuilder()},
    sizedImageBuilder: hermesMarkdownImageBuilder,
    onTapLink: (_, href, _) {
      if (href != null && href.isNotEmpty) openChatLink(context, href);
    },
  );

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (text.length <= _longTextChars) return _markdown(context, text);
    if (!_expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText('${text.substring(0, _longTextChars)}\n\n…'),
          TextButton.icon(
            onPressed: () => setState(() => _expanded = true),
            icon: const Icon(Icons.expand_more),
            label: Text(context.l10n.commonViewAll),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _markdown(context, text),
        TextButton.icon(
          onPressed: () => setState(() => _expanded = false),
          icon: const Icon(Icons.expand_less),
          label: Text(context.l10n.commonCollapse),
        ),
      ],
    );
  }
}

class _PreviewNode extends StatelessWidget {
  final MessagePreviewTarget target;
  const _PreviewNode({required this.target});
  @override
  Widget build(BuildContext context) =>
      MessagePreviewAttachments(text: target.value);
}
