import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/chat_message.dart';
import '../../core/tool_presentation.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/h/hermes_status.dart';
import '../../widgets/h/hermes_tool.dart';
import 'tool_dismiss_store.dart';
import '../../screens/request_sheet.dart';

/// Prototype `.subcard{border-radius:12px}` — deliberately distinct from
/// [HermesToolCard]'s asymmetric `kToolCardRadius` (11), since a rollup card
/// has no accent stripe and uses a uniform radius on all four corners.
const double kToolGroupRadius = 12;

/// Rollup card for a consecutive run of tool calls (two or more — a lone
/// call renders standalone instead) — prototype parity with
/// `toolGroupCard()`/`.subcard`: a compact header (icon + count + status)
/// over a list of per-tool rows, each with its own kind-specific icon and a
/// real one-line summary instead of a bare tool name.
///
/// Every tool call in the run lands here, exploratory (read_file,
/// list_files, …) and dedicated (patch, generate_image, …) alike — nothing
/// breaks out into its own separate card anymore, so a turn's tool activity
/// reads as one block instead of a scatter of siblings. Tapping a row opens
/// its full rich presentation (diff, image preview, subagent tree, …) via
/// [detailBuilder], which callers pass as `buildToolCallCard` (the same
/// per-name dispatcher used when a tool call rendered standalone).
class ToolGroupCard extends StatelessWidget {
  final String groupId;
  final List<ChatPart> parts;
  final List<ChatPart> interactions;

  /// Builds the row's detail-sheet content from raw tool data — normally
  /// `buildToolCallCard` (message_bubble.dart), which dispatches by tool
  /// name to the same specialized card (diff, image, subagent, …) the call
  /// would render as if it were standalone. Falls back to a plain
  /// [HermesToolCard] when omitted.
  final Widget Function(Map<String, dynamic> tool)? detailBuilder;

  const ToolGroupCard({
    super.key,
    required this.groupId,
    required this.parts,
    this.interactions = const [],
    this.detailBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final tools = parts
        .map((part) => part.tool ?? const <String, dynamic>{})
        .toList(growable: false);
    final failed = tools
        .where((tool) => tool['is_error'] == true || tool['error'] != null)
        .length;
    final dismiss = context.watch<ToolDismissStore>();
    final running = tools.any((tool) => tool['running'] == true);
    if (dismiss.isDismissed(groupId) && !running && interactions.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => dismiss.restore(groupId),
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: Text(context.l10n.toolGroupHiddenRestore(tools.length)),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }
    final Color chipColor;
    final String chipLabel;
    if (failed > 0) {
      chipColor = hermesSemantic(
        context,
        HermesSemantic.red,
        HermesSemanticDark.red,
      );
      chipLabel = context.l10n.toolGroupFailed(failed);
    } else if (running) {
      chipColor = hermesSemantic(
        context,
        HermesSemantic.green,
        HermesSemanticDark.green,
      );
      chipLabel = context.l10n.statusRunning;
    } else {
      chipColor = palette.text3;
      chipLabel = context.l10n.statusCompleted;
    }

    return _ExpandableToolGroup(
      groupKey: ValueKey(
        'timeline-tool-group-${tools.map((t) => t['tool_id'] ?? t['id'] ?? t['name']).join('-')}',
      ),
      initiallyExpanded: running || failed > 0 || interactions.isNotEmpty,
      running: running,
      title: toolRunSummary(tools, live: running),
      chipColor: chipColor,
      chipLabel: chipLabel,
      onDismiss: (!running && interactions.isEmpty)
          ? () => dismiss.dismiss(groupId)
          : null,
      children: [
        for (final interaction in interactions)
          RequestSheet(
            embedded: true,
            requestId: interaction.interaction?['request_id']?.toString(),
          ),
        for (final tool in tools)
          _ToolGroupRow(tool: tool, detailBuilder: detailBuilder),
      ],
    );
  }
}

class _ToolGroupRow extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Widget Function(Map<String, dynamic> tool)? detailBuilder;
  const _ToolGroupRow({required this.tool, this.detailBuilder});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final name = (tool['name'] ?? tool['tool_name'] ?? 'tool').toString();
    final args = parseToolArgs(tool);
    final kind = resolveToolKind(name, args);
    final running = tool['running'] == true;
    final failed = tool['is_error'] == true || tool['error'] != null;
    final summary = toolCollapsedSummary(kind, args);
    final subtitle = summary.isNotEmpty
        ? summary
        : (tool['summary'] ??
                  tool['message'] ??
                  (running ? context.l10n.commonProcessing : ''))
              .toString();
    final iconColor = failed
        ? hermesSemantic(context, HermesSemantic.red, HermesSemanticDark.red)
        : palette.accent;
    final Color rowChipColor;
    final String rowChipLabel;
    if (failed) {
      rowChipColor = hermesSemantic(
        context,
        HermesSemantic.red,
        HermesSemanticDark.red,
      );
      rowChipLabel = context.l10n.statusFailed;
    } else if (running) {
      rowChipColor = hermesSemantic(
        context,
        HermesSemantic.green,
        HermesSemanticDark.green,
      );
      rowChipLabel = context.l10n.statusRunning;
    } else {
      rowChipColor = hermesSemantic(
        context,
        HermesSemantic.green,
        HermesSemanticDark.green,
      );
      rowChipLabel = context.l10n.statusCompleted;
    }

    return InkWell(
      onTap: () => _showToolDetail(context, tool, detailBuilder),
      borderRadius: BorderRadius.circular(HermesRadius.smallCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 25,
              height: 25,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(HermesRadius.smallCard),
              ),
              child: Icon(toolKindIcon(kind), size: 13, color: iconColor),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: palette.text3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            HermesStatusChip(
              color: rowChipColor,
              label: rowChipLabel,
              pulse: running,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tapping a rollup row opens the tool's full detail (args, result,
/// diff/image/subagent presentation, …) in a sheet — the rollup row itself
/// only ever has room for a one-line summary. Uses [detailBuilder] (the
/// same per-name dispatcher a standalone call renders through) when given,
/// so a `patch`/`generate_image`/`delegate_task`/… row opens its real
/// specialized card instead of the generic fallback.
void _showToolDetail(
  BuildContext context,
  Map<String, dynamic> tool,
  Widget Function(Map<String, dynamic> tool)? detailBuilder,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: .55,
      minChildSize: .3,
      maxChildSize: .9,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        child: detailBuilder != null
            ? detailBuilder(tool)
            : HermesToolCard(data: tool, initiallyExpanded: true),
      ),
    ),
  );
}

/// Prototype parity (`.subcard`/`.subhead`): plain-bordered rounded card,
/// codeBg header strip, surface body — visually distinct from
/// [HermesToolCard]'s accent-striped single-tool chrome, so a rollup reads
/// as "several minor calls" rather than "one important call".
class _ExpandableToolGroup extends StatefulWidget {
  final Key groupKey;
  final bool initiallyExpanded;
  final bool running;
  final String title;
  final Color chipColor;
  final String chipLabel;
  final VoidCallback? onDismiss;
  final List<Widget> children;

  const _ExpandableToolGroup({
    required this.groupKey,
    required this.initiallyExpanded,
    required this.running,
    required this.title,
    required this.chipColor,
    required this.chipLabel,
    required this.onDismiss,
    required this.children,
  });

  @override
  State<_ExpandableToolGroup> createState() => _ExpandableToolGroupState();
}

class _ExpandableToolGroupState extends State<_ExpandableToolGroup> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant _ExpandableToolGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running && !oldWidget.running) _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      key: widget.groupKey,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(kToolGroupRadius),
        border: Border.all(color: palette.border),
        boxShadow: hermesShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: palette.codeBg,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 11),
              child: Row(
                children: [
                  Icon(Icons.build_outlined, size: 15, color: palette.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  HermesStatusChip(
                    color: widget.chipColor,
                    label: widget.chipLabel,
                    pulse: widget.running,
                  ),
                  if (widget.onDismiss != null) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 25,
                      height: 25,
                      child: Tooltip(
                        message: context.l10n.toolHideRow,
                        child: InkWell(
                          onTap: widget.onDismiss,
                          borderRadius: BorderRadius.circular(7),
                          child: Icon(
                            Icons.visibility_off_outlined,
                            size: 13,
                            color: palette.text4,
                          ),
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
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
          if (_expanded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
        ],
      ),
    );
  }
}
