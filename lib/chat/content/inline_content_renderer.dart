import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import '../../core/message_preview_targets.dart';
import '../../core/performance_metrics.dart';
import '../../core/session_refs.dart';
import '../../core/stores/plugin_contribution_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_glass_theme.dart';
import '../../widgets/h/hermes_markdown.dart';
import '../../widgets/h/hermes_states.dart';
import '../../widgets/h/hermes_glass.dart';
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
import 'streaming_word_drain.dart';
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
  static const _wordCadence = Duration(milliseconds: 42);
  static const _maxRevealLag = Duration(milliseconds: 600);
  final IncrementalStreamingMarkdownScanner _scanner =
      IncrementalStreamingMarkdownScanner();
  final List<String> _stableBlocks = <String>[];
  final List<Widget> _stableWidgets = <Widget>[];

  Widget _stableWidget(int index) => InlineContentRenderer(
    key: ValueKey('stream-block-$index'),
    text: linkifySessionRefs(
      _stableBlocks[index],
      titleOf: widget.sessionTitleOf,
    ),
    selectable: widget.selectable,
  );
  int oldScannedLength = 0;
  String _displayedText = '';
  Timer? _paceTimer;
  String? _countedTarget;
  int _remainingUnits = 0;
  int _revealTicksLeft = 0;

  @override
  void initState() {
    super.initState();
    // Paint already-received text immediately on mount (including remounts
    // while scrolling). Only subsequent additions need a paced reveal.
    _displayedText = widget.text;
  }

  @override
  void dispose() {
    _paceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StreamingInlineContentRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_displayedText.isEmpty && widget.text.isNotEmpty) {
      _displayedText = widget.text;
    } else if (!widget.text.startsWith(oldWidget.text)) {
      _stableBlocks.clear();
      _stableWidgets.clear();
      _scanner.reset();
      oldScannedLength = 0;
      _displayedText = widget.text;
      _countedTarget = null;
    } else if (widget.text.length > _displayedText.length) {
      _schedulePace();
    }
    if (oldWidget.selectable != widget.selectable) {
      _stableWidgets
        ..clear()
        ..addAll(List.generate(_stableBlocks.length, _stableWidget));
    } else if (oldWidget.sessionTitleOf != widget.sessionTitleOf) {
      // Parents commonly allocate a new resolver closure on each token.
      // Only reference-bearing blocks can change, and equal resolved text
      // should retain the existing widget configuration.
      for (var i = 0; i < _stableBlocks.length; i++) {
        if (!_stableBlocks[i].contains('@session:')) continue;
        final resolved = linkifySessionRefs(
          _stableBlocks[i],
          titleOf: widget.sessionTitleOf,
        );
        if ((_stableWidgets[i] as InlineContentRenderer).text != resolved) {
          _stableWidgets[i] = _stableWidget(i);
        }
      }
    }
  }

  void _schedulePace() {
    if (_paceTimer != null) return;
    _revealTicksLeft =
        (_maxRevealLag.inMicroseconds ~/ _wordCadence.inMicroseconds).clamp(
          1,
          1000,
        );
    _paceTimer = Timer.periodic(_wordCadence, (_) {
      if (!mounted) return;
      final target = widget.text;
      if (_displayedText.length >= target.length) {
        _paceTimer?.cancel();
        _paceTimer = null;
        return;
      }
      final cursor = _displayedText.length;
      // Normally reveal one word per cadence tick. If a provider delivered a
      // large burst, increase the quota so the visible text catches up instead
      // of leaving the UI many seconds behind the network stream (Hermex's
      // lag-bound word drain behaves the same way).
      final remainder = target.substring(cursor);
      if (!identical(_countedTarget, target)) {
        _countedTarget = target;
        _remainingUnits = StreamingWordDrain.unitCount(remainder);
      }
      // Spend the remaining cadence budget instead of repeatedly granting
      // the shrinking backlog a fresh 600ms. New tokens do not postpone
      // completion of a burst already being displayed.
      final quota = (_remainingUnits / _revealTicksLeft).ceil().clamp(
        1,
        _remainingUnits.clamp(1, 1 << 30),
      );
      _revealTicksLeft = (_revealTicksLeft - 1).clamp(1, 1000);
      final take = StreamingWordDrain.splitOffset(remainder, quota);
      _remainingUnits = (_remainingUnits - quota).clamp(0, _remainingUnits);
      setState(() {
        _displayedText = target.substring(0, cursor + take);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep the active tail readable while smoothing large token bursts. The
    // final target is always reached verbatim, so pacing cannot lose content.
    if (MediaQuery.disableAnimationsOf(context)) {
      _paceTimer?.cancel();
      _paceTimer = null;
      _displayedText = widget.text;
    }
    if (_displayedText.length < widget.text.length) _schedulePace();
    final sourceText = _displayedText;
    // didUpdateWidget resets the scanner on source replacement; the pacing
    // cursor only advances through that validated source between updates.
    final added = _scanner.update(sourceText, appendOnly: true);
    final metrics = ClientPerformanceMetrics.instance;
    metrics.markdownScannedChars += (sourceText.length - oldScannedLength)
        .clamp(0, sourceText.length);
    oldScannedLength = sourceText.length;
    for (final block in added) {
      _stableBlocks.add(block);
      _stableWidgets.add(_stableWidget(_stableBlocks.length - 1));
      ClientPerformanceMetrics.instance.streamingStablePrefixChars +=
          block.length;
    }
    final tail = linkifySessionRefs(
      _scanner.tail(sourceText),
      titleOf: widget.sessionTitleOf,
    );
    metrics.markdownTailChars += tail.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reuse immutable widget configurations so a tail update does not
        // rebuild completed Markdown. Inherited theme changes still rebuild
        // the dependent descendants normally.
        ..._stableWidgets,
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
      }, style: HermesLiquidTypography.messageBody(context));
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
    return HermesGlassCard(
      padding: EdgeInsets.zero,
      radius: 16,
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
              showHermesErrorSnackBar(
                context,
                error,
                fallback: context.l10n.pluginsOperationFailed('$error'),
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
  final ScrollController _expandedScrollController = ScrollController();

  @override
  void dispose() {
    _expandedScrollController.dispose();
    super.dispose();
  }

  Widget _markdown(BuildContext context, String data) => MarkdownBody(
    data: prettifyBareLinks(upgradeImageLinks(data)),
    selectable: widget.selectable,
    styleSheet: hermesMarkdownStyle(context, compact: true, conversation: true),
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
        SizedBox(
          height: 480,
          child: Markdown(
            key: const ValueKey('expanded-markdown-viewport'),
            controller: _expandedScrollController,
            data: prettifyBareLinks(upgradeImageLinks(text)),
            selectable: widget.selectable,
            padding: EdgeInsets.zero,
            styleSheet: hermesMarkdownStyle(
              context,
              compact: true,
              conversation: true,
            ),
            extensionSet: md.ExtensionSet.gitHubFlavored,
            builders: {'table': ResizableMarkdownTableBuilder()},
            sizedImageBuilder: hermesMarkdownImageBuilder,
            onTapLink: (_, href, _) {
              if (href != null && href.isNotEmpty) openChatLink(context, href);
            },
          ),
        ),
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
