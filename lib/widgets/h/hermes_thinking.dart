/// HermesThinkingCard — collapsible reasoning block.
///
/// Shares [ToolCardShell] (the accent-striped `.toolcard` chrome now used
/// across every process block in the transcript) so a thinking block reads
/// as "the same kind of thing" as a tool call, distinguished only by its
/// own purple identity and a live breathing-bars indicator in place of a
/// running spinner. Supports a `streaming` state that shows an animated
/// indicator while reasoning content is still being generated in real-time,
/// a measured "thought for Xs" duration (desktop `useMeasuredDuration`), a
/// live preview that pins to the newest tokens, and markdown rendering of
/// the body.
library;

import 'package:flutter/material.dart';

import '../../chat/content/compact_markdown.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import 'hermes_tool.dart';

/// Repair reasoning-summary parts that got glued without a separator
/// (`**One****Two**`), mirroring desktop `separateGluedReasoningBlocks`.
String separateGluedReasoningBlocks(String text) => text
    .replaceAll(RegExp(r'(?<!\*)\*{4}(?!\*)'), '**\n\n**')
    .replaceAllMapped(
      RegExp(r'(?<=[^\s*])(\*\*(?=[^\s*])[^\n]*?\*\*)'),
      (m) => '\n\n${m.group(1)}',
    );

class HermesThinkingCard extends StatefulWidget {
  final String text;
  final bool initiallyExpanded;
  final bool streaming;

  const HermesThinkingCard({
    super.key,
    required this.text,
    this.initiallyExpanded = true,
    this.streaming = false,
  });

  @override
  State<HermesThinkingCard> createState() => _HermesThinkingCardState();
}

class _HermesThinkingCardState extends State<HermesThinkingCard> {
  final _scrollCtrl = ScrollController();

  // H1: wall-clock duration of the thinking phase. Started when this card
  // first sees `streaming == true`; frozen when it settles. A card that mounts
  // already-settled (history replay) has no duration and reads "思考过程".
  DateTime? _startedAt;
  Duration? _measured;

  @override
  void initState() {
    super.initState();
    if (widget.streaming) _startedAt = DateTime.now();
  }

  @override
  void didUpdateWidget(HermesThinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streaming && !oldWidget.streaming) {
      _startedAt ??= DateTime.now();
    }
    if (!widget.streaming && oldWidget.streaming && _startedAt != null) {
      _measured = DateTime.now().difference(_startedAt!);
    }
    // Pin the preview to the newest tokens while streaming.
    if (widget.streaming && widget.text != oldWidget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _headerLabel(BuildContext context) {
    if (widget.streaming) return context.l10n.thinkingActive;
    final d = _measured;
    if (d == null) return context.l10n.thinkingProcess;
    final s = d.inMilliseconds / 1000;
    if (s < 1) return context.l10n.thinkingBriefly;
    return s < 60
        ? context.l10n.thinkingSeconds(s.toStringAsFixed(s < 10 ? 1 : 0))
        : context.l10n.thinkingMinutes(d.inMinutes, d.inSeconds % 60);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = HermesPalette.of(context);
    final tint = hermesSemantic(
      context,
      HermesSemantic.purple,
      HermesSemanticDark.purple,
    );
    final rendered = separateGluedReasoningBlocks(widget.text);
    return ToolCardShell(
      key: const ValueKey('reasoning-card'),
      icon: Icons.psychology_alt_outlined,
      accentColor: tint,
      title: _headerLabel(context),
      subtitle: widget.text.isNotEmpty
          ? Text(
              widget.streaming
                  ? context.l10n.thinkingGeneratedCharacters(widget.text.length)
                  : context.l10n.thinkingCharacters(widget.text.length),
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.text3,
                fontSize: 10.5,
              ),
            )
          : null,
      trailing: widget.streaming ? HermesThinkingPulse(color: tint) : null,
      initiallyExpanded: widget.initiallyExpanded,
      children: [
        widget.text.isEmpty && widget.streaming
            ? Text(
                context.l10n.thinkingAnalyzing,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.text2,
                  height: 1.65,
                ),
              )
            // H2: while streaming, cap the height and follow the tail so
            // the newest reasoning is always visible.
            : widget.streaming
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 168),
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  child: CompactMarkdown(text: rendered, selectable: false),
                ),
              )
            : CompactMarkdown(text: rendered),
      ],
    );
  }
}

/// Three restrained breathing bars; avoids stacking a spinner and ellipsis.
class HermesThinkingPulse extends StatefulWidget {
  final Color color;
  final Animation<double>? animation;

  const HermesThinkingPulse({super.key, required this.color, this.animation});

  @override
  State<HermesThinkingPulse> createState() => _HermesThinkingPulseState();
}

class _HermesThinkingPulseState extends State<HermesThinkingPulse>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  Animation<double> get _animation => widget.animation ?? _controller!;

  @override
  void initState() {
    super.initState();
    if (widget.animation == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller!
        ..stop()
        ..value = .45;
    } else if (!_controller!.isAnimating) {
      _controller!.repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 19,
    height: 16,
    child: AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          final phase = (_animation.value + index * .22) % 1;
          final distance = (phase - .5).abs() * 2;
          final height = 5 + (1 - distance) * 8;
          return Container(
            width: 3,
            height: height,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: .45 + (1 - distance) * .5),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    ),
  );
}
