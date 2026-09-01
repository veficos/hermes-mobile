/// Background-process ("terminal(background=true)") output viewer.
///
/// Desktop parity: clicking a background-process row in the composer status
/// stack opens `AgentTerminalInstance`, a live read-only terminal mirror
/// docked in the right sidebar. Mobile has no side-panel real estate, so
/// this surfaces as a bottom sheet instead — but it reuses the exact same
/// data source: `ComposerStatusItem.output` (the gateway's `output_tail`),
/// kept fresh by the same 5s `process.list` poll the status row's spinner
/// already depends on (`ChatScreen._startBackgroundPolling`). No separate
/// live-stream subscription is needed; watching [ComposerStatusStore]
/// rebuilds this sheet exactly when the row itself would update.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/composer_status_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/h/hermes_status.dart';
import '../../widgets/h/hermes_tool.dart';

Future<void> showBackgroundProcessSheet(
  BuildContext context, {
  required String sessionId,
  required String processId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: .6,
      minChildSize: .35,
      maxChildSize: .92,
      expand: false,
      builder: (_, scrollController) => _BackgroundProcessView(
        sessionId: sessionId,
        processId: processId,
        scrollController: scrollController,
      ),
    ),
  );
}

class _BackgroundProcessView extends StatefulWidget {
  final String sessionId;
  final String processId;
  final ScrollController scrollController;

  const _BackgroundProcessView({
    required this.sessionId,
    required this.processId,
    required this.scrollController,
  });

  @override
  State<_BackgroundProcessView> createState() => _BackgroundProcessViewState();
}

class _BackgroundProcessViewState extends State<_BackgroundProcessView> {
  String? _lastOutput;
  bool _stopping = false;

  // Output is a tail, not a diff — jump to the bottom whenever it changes so
  // the newest lines stay in view, matching the desktop mirror's live tail.
  void _followOutput(String? output) {
    if (output == _lastOutput) return;
    _lastOutput = output;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.scrollController.hasClients) return;
      widget.scrollController.jumpTo(
        widget.scrollController.position.maxScrollExtent,
      );
    });
  }

  Future<void> _stop(String sessionId, String id) async {
    setState(() => _stopping = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ComposerStatusStore>().stopBackgroundProcess(
        sessionId,
        id,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.backgroundStopFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final composer = context.watch<ComposerStatusStore>();
    final item = composer
        .itemsFor(widget.sessionId)
        .where(
          (i) =>
              i.type == ComposerStatusType.background &&
              i.id == widget.processId,
        )
        .firstOrNull;

    if (item == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 32, color: palette.text3),
            const SizedBox(height: 8),
            Text(
              context.l10n.backgroundProcessRemoved,
              style: TextStyle(color: palette.text3),
            ),
          ],
        ),
      );
    }

    _followOutput(item.output);
    final running = item.state == ComposerStatusState.running;
    final failed = item.state == ComposerStatusState.failed;
    final statusColor = failed
        ? hermesSemantic(context, HermesSemantic.red, HermesSemanticDark.red)
        : running
        ? hermesSemantic(
            context,
            HermesSemantic.green,
            HermesSemanticDark.green,
          )
        : palette.text3;

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, size: 18, color: palette.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.backgroundTerminal,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: palette.text,
                  ),
                ),
              ),
              HermesStatusChip(
                color: statusColor,
                label: failed
                    ? context.l10n.statusFailed
                    : running
                    ? context.l10n.statusRunning
                    : context.l10n.statusCompleted,
                pulse: running,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.toolCommand,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.text3,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 11),
            decoration: toolCodeBoxDecoration(context),
            child: SelectableText(
              item.title,
              style: HermesType.code.copyWith(
                color: palette.text,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.toolOutput,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.text3,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 11),
            decoration: toolCodeBoxDecoration(context),
            child: SelectableText(
              item.output?.isNotEmpty == true
                  ? item.output!
                  : (running
                        ? context.l10n.backgroundWaitingOutput
                        : context.l10n.toolNoReadableContent),
              style: HermesType.code.copyWith(
                color: item.output?.isNotEmpty == true
                    ? palette.text
                    : palette.text3,
                fontSize: 12,
              ),
            ),
          ),
          if (!running && item.exitCode != null) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.toolExitCode(item.exitCode!),
              style: TextStyle(
                fontSize: 11,
                color: failed ? statusColor : palette.text3,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: running
                ? OutlinedButton.icon(
                    onPressed: _stopping
                        ? null
                        : () => _stop(widget.sessionId, item.id),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: Text(
                      _stopping
                          ? context.l10n.backgroundStopping
                          : context.l10n.backgroundStopProcess,
                    ),
                  )
                : FilledButton.icon(
                    onPressed: () {
                      context
                          .read<ComposerStatusStore>()
                          .dismissBackgroundProcess(widget.sessionId, item.id);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(context.l10n.backgroundCloseAndHide),
                  ),
          ),
        ],
      ),
    );
  }
}
