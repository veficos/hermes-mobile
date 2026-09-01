/// Starmap: a radial time map of what Hermes has learned — oldest at the
/// core, newest on the outer rings (mirrors hermes-agent desktop's
/// `app/starmap/`). Backed by `/api/v1/starmap/graph` and
/// `/api/v1/starmap/node`; layout math lives in `core/starmap_layout.dart`
/// and the share/import codec in `core/starmap_share_code.dart`, both direct
/// ports of the desktop TypeScript originals.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/clipboard.dart';
import '../core/models.dart';
import '../core/connection_reload_mixin.dart';
import '../core/starmap_layout.dart';
import '../core/starmap_loadout.dart' show LoadoutError;
import '../core/starmap_share_code.dart';
import '../core/stores/connection_store.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';
import '../l10n/l10n.dart';

// How long a full play-through sweep takes, reveal 0 → 1.
const _sweepDuration = Duration(seconds: 15);

// How far to relax the ease toward a flat linear march — see cineEase.
const double _gentle = 0.45;

/// Cinematic timing: cubic smoothstep (gentle ease-in/ease-out) relaxed
/// toward linear by [_gentle], so the middle never rushes. Monotonic on
/// [0,1]. Port of desktop's `cineEase` (star-map.tsx).
double _cineEase(double t) {
  final u = t.clamp(0.0, 1.0);
  final smooth = u * u * (3 - 2 * u);
  return _gentle * u + (1 - _gentle) * smooth;
}

/// Numeric inverse (monotonic bisection) so a resume maps the current reveal
/// back to clock progress without a closed-form solution.
double _invCineEase(double y) {
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    if (_cineEase(mid) < y) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

class StarmapScreen extends StatefulWidget {
  const StarmapScreen({super.key});

  @override
  State<StarmapScreen> createState() => _StarmapScreenState();
}

class _StarmapScreenState extends State<StarmapScreen>
    with SingleTickerProviderStateMixin, ConnectionReloadMixin<StarmapScreen> {
  StarmapGraph? _graph; // live-loaded graph
  StarmapGraph? _imported; // pasted share-code graph (overrides _graph)
  String? _error;
  bool _busy = false;

  // Transform state.
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;

  StarmapTimeLayout? _layout;
  Map<String, StarmapMemoryCard> _memoryById = const {};

  // Playback / scrubber: reveal 1 = the whole map (idle default); lower
  // values hide not-yet-reached nodes so playing/scrubbing "builds it up".
  late final AnimationController _playController;
  double _reveal = 1.0;

  // Tapping a ring's date label selects it (toggle) — a lit band + brighter
  // outline/label, matching desktop's clickable ring labels.
  int? _selectedRing;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _playController = AnimationController(vsync: this, duration: _sweepDuration)
      ..addListener(() {
        setState(() => _reveal = _cineEase(_playController.value));
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) setState(() {});
      });
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    setState(() {
      _graph = null;
      _imported = null;
      _layout = null;
      _memoryById = const {};
      _error = null;
      _busy = true;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _playController.dispose();
    super.dispose();
  }

  StarmapGraph? get _shown => _imported ?? _graph;

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    setState(() => _busy = true);
    try {
      final graph = await api.starmapGraph();
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() {
        _graph = graph;
        // A fresh profile scan drops a stale import (mirrors desktop's
        // index.tsx: "Drop a stale import when the underlying profile graph
        // changes out from under it").
        _imported = null;
        _error = null;
        _playController.stop();
        _reveal = 1;
      });
      _applyShown(graph);
    } catch (e) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() => _error = '$e');
    } finally {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, connection.api)) {
        setState(() => _busy = false);
      }
    }
  }

  void _applyShown(StarmapGraph graph) {
    setState(() {
      _layout = buildStarmapTimeLayout(graph.nodes);
      _memoryById = {
        for (var i = 0; i < graph.memory.length; i++)
          'memory:${graph.memory[i].source}:$i': graph.memory[i],
      };
      // A new ring set may not even have this many rings anymore.
      _selectedRing = null;
    });
  }

  Future<void> _onNodeTap(StarmapNode node) async {
    final l10n = context.l10n;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    try {
      final detail = await api.starmapNode(node.id);
      if (!mounted || !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(HermesRadius.sheet),
          ),
        ),
        builder: (_) => _StarmapNodeSheet(
          node: node,
          detail: detail,
          ownerApi: api,
          memoryCard: _memoryById[node.id],
          onChanged: _load,
        ),
      );
    } catch (e) {
      if (mounted && identical(api, context.read<ConnectionStore>().api)) {
        showHermesToast(context, message: l10n.starmapLoadDetailFailed('$e'));
      }
    }
  }

  void _resetTransform() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
      _selectedRing = null;
    });
  }

  void _togglePlay() {
    if (_playController.isAnimating) {
      _playController.stop();
      setState(() {});
      return;
    }
    if (_reveal >= 1) {
      _reveal = 0;
      _playController.value = 0;
    } else {
      _playController.value = _invCineEase(_reveal);
    }
    _playController.forward();
  }

  void _onScrub(double value) {
    _playController.stop();
    setState(() => _reveal = value.clamp(0, 1));
  }

  Future<void> _openShareDialog() async {
    final graph = _shown;
    if (graph == null) return;
    final decoded = await showDialog<StarmapGraph>(
      context: context,
      builder: (_) => _ShareDialog(shareCode: encodeStarmapShareCode(graph)),
    );
    if (decoded == null || !mounted) return;
    setState(() => _imported = decoded);
    _applyShown(decoded);
  }

  void _resetToMine() {
    final graph = _graph;
    if (graph == null) return;
    setState(() {
      _imported = null;
      _playController.stop();
      _reveal = 1;
    });
    _applyShown(graph);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featureStarmap),
        actions: [
          if (_imported != null)
            IconButton(
              tooltip: l10n.starmapRestoreMine,
              onPressed: _resetToMine,
              icon: const Icon(Icons.undo),
            ),
          IconButton(
            tooltip: l10n.starmapShareImport,
            onPressed: _shown == null ? null : _openShareDialog,
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: l10n.starmapResetView,
            onPressed: _resetTransform,
            icon: const Icon(Icons.center_focus_strong_outlined),
          ),
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    if (_shown == null && _error == null) {
      return HermesLoadingState(label: l10n.starmapLoading);
    }
    if (_error != null && _shown == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    final graph = _shown;
    final layout = _layout;
    if (graph == null || layout == null) {
      return HermesEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: l10n.starmapNoData,
      );
    }
    if (graph.nodes.isEmpty) {
      return HermesEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: l10n.starmapEmpty,
        description: l10n.starmapEmptyDescription,
      );
    }
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(HermesSpacing.sm),
            child: HermesNoticeBar(
              message: _error == connectionOfflineErrorCode
                  ? context.l10n.backendDisconnected
                  : _error!,
              color: HermesSemantic.red,
              icon: Icons.error_outline,
              onTap: _load,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              _GraphView(
                graph: graph,
                layout: layout,
                scale: _scale,
                offset: _offset,
                reveal: _reveal,
                selectedRing: _selectedRing,
                onNodeTap: _onNodeTap,
                onRingTap: (i) => setState(() => _selectedRing = i),
                onScaleStart: () {
                  _baseScale = _scale;
                },
                onScaleUpdate: (detail) {
                  setState(() {
                    _scale = (_baseScale * detail.scale).clamp(0.3, 3.5);
                    _offset += detail.focalPointDelta;
                  });
                },
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 8,
                child: _StarmapScrubber(
                  layout: layout,
                  reveal: _reveal,
                  playing: _playController.isAnimating,
                  onTogglePlay: _togglePlay,
                  onScrub: _onScrub,
                ),
              ),
            ],
          ),
        ),
        const _StarmapLegend(),
      ],
    );
  }
}

/// Share / import dialog — one code field pre-filled with the current map's
/// share code (copy it to share); paste a different one and Load to view it.
/// Owns its own [TextEditingController] so disposal is tied correctly to
/// this widget's element lifecycle (a controller created and disposed by the
/// caller around `showDialog` races the dialog's close transition, which can
/// still touch the field for one more frame).
class _ShareDialog extends StatefulWidget {
  final String shareCode;

  const _ShareDialog({required this.shareCode});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.shareCode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = _controller.text.trim();
    final canLoad = code.isNotEmpty && code != widget.shareCode.trim();
    return AlertDialog(
      title: Text(l10n.starmapShareTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.starmapShareDescription,
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: HermesSpacing.sm),
            TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 4,
              style: HermesType.code,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: l10n.starmapShareCodeHint,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(color: HermesSemantic.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => copyTextOrNotify(
            context,
            widget.shareCode,
            successMessage: l10n.commonCopied,
          ),
          child: Text(l10n.starmapCopy),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
        FilledButton(
          onPressed: canLoad
              ? () {
                  try {
                    final decoded = decodeStarmapShareCode(code);
                    Navigator.of(context).pop(decoded);
                  } on LoadoutError {
                    setState(() => _error = l10n.starmapInvalidShareCode);
                  } catch (e) {
                    setState(() => _error = l10n.starmapInvalidShareCode);
                  }
                }
              : null,
          child: Text(l10n.starmapLoad),
        ),
      ],
    );
  }
}

/// Playback scrubber: play/pause + a draggable track with ring-spawn tick
/// markers and a playhead. Functional port of desktop's constellation
/// `Timeline` (star map twinkling-star visuals are decorative and skipped;
/// scrub/play semantics match exactly).
class _StarmapScrubber extends StatelessWidget {
  final StarmapTimeLayout layout;
  final double reveal;
  final bool playing;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onScrub;

  const _StarmapScrubber({
    required this.layout,
    required this.reveal,
    required this.playing,
    required this.onTogglePlay,
    required this.onScrub,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: playing ? l10n.starmapPause : l10n.starmapPlay,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: onTogglePlay,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (d) =>
                      onScrub(d.localPosition.dx / constraints.maxWidth),
                  onPanUpdate: (d) =>
                      onScrub(d.localPosition.dx / constraints.maxWidth),
                  child: SizedBox(
                    height: 24,
                    child: CustomPaint(
                      painter: _ScrubberPainter(
                        layout: layout,
                        reveal: reveal,
                        trackColor: palette.border,
                        markColor: palette.text3,
                        playheadColor: palette.text,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  final StarmapTimeLayout layout;
  final double reveal;
  final Color trackColor;
  final Color markColor;
  final Color playheadColor;

  const _ScrubberPainter({
    required this.layout,
    required this.reveal,
    required this.trackColor,
    required this.markColor,
    required this.playheadColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = trackColor
        ..strokeWidth = 1,
    );

    for (final ring in layout.rings) {
      final active = ring.ratio <= reveal;
      canvas.drawCircle(
        Offset(ring.ratio * size.width, midY),
        active ? 2.5 : 1.5,
        Paint()..color = markColor.withValues(alpha: active ? 1 : 0.4),
      );
    }

    canvas.drawLine(
      Offset(reveal * size.width, 0),
      Offset(reveal * size.width, size.height),
      Paint()
        ..color = playheadColor
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter old) =>
      old.reveal != reveal || old.layout != layout;
}

/// Legend — skill (dot) / memory (diamond) / recency axis, matching desktop's
/// bottom-left legend exactly (no per-category colors: time is the only
/// organizing axis now).
class _StarmapLegend extends StatelessWidget {
  const _StarmapLegend();

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final l10n = context.l10n;
    final style = TextStyle(fontSize: 11, color: palette.text3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(l10n.starmapSkillLegend, style: style),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: 0.785398,
                child: Container(
                  width: 6,
                  height: 6,
                  color: HermesSemantic.purple,
                ),
              ),
              const SizedBox(width: 5),
              Text(l10n.starmapMemoryLegend, style: style),
            ],
          ),
          Text(l10n.starmapChronologyLegend, style: style),
        ],
      ),
    );
  }
}

class _GraphView extends StatelessWidget {
  final StarmapGraph graph;
  final StarmapTimeLayout layout;
  final double scale;
  final Offset offset;
  final double reveal;
  final int? selectedRing;
  final ValueChanged<StarmapNode> onNodeTap;
  final ValueChanged<int?> onRingTap;
  final VoidCallback onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;

  const _GraphView({
    required this.graph,
    required this.layout,
    required this.scale,
    required this.offset,
    required this.reveal,
    required this.selectedRing,
    required this.onNodeTap,
    required this.onRingTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final side = layout.outerRadius * 2 + 160;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitScale = ((constraints.maxWidth - 32) / side)
            .clamp(.05, 1.0)
            .toDouble();
        final displayScale = fitScale * scale;
        final origin = Offset(
          constraints.maxWidth / 2 + offset.dx,
          constraints.maxHeight / 2 + offset.dy,
        );
        final transform = Matrix4.identity()
          ..translateByDouble(origin.dx, origin.dy, 0, 1)
          ..scaleByDouble(displayScale, displayScale, 1, 1);
        final visible = layout.nodes.where((n) => n.rec <= reveal).toList();
        final center = Offset(side / 2, side / 2);

        void handleTapUp(TapUpDetails details) {
          final hit = hitTestRingLabel(
            localPosition: details.localPosition,
            origin: origin,
            displayScale: displayScale,
            center: center,
            layout: layout,
          );
          if (hit != null) onRingTap(selectedRing == hit ? null : hit);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => onScaleStart(),
          onScaleUpdate: onScaleUpdate,
          onTapUp: handleTapUp,
          child: ClipRect(
            child: Transform(
              alignment: Alignment.topLeft,
              transform: transform,
              child: SizedBox(
                width: side,
                height: side,
                child: CustomPaint(
                  painter: _StarmapPainter(
                    layout: layout,
                    edges: graph.edges,
                    visible: visible,
                    selectedRing: selectedRing,
                    accent: theme.colorScheme.primary,
                    onSurfaceVariant: theme.colorScheme.onSurfaceVariant,
                    displayScale: displayScale,
                    center: center,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final n in visible)
                        _NodeHitTarget(
                          node: n.node,
                          position: Offset(side / 2 + n.x, side / 2 + n.y),
                          onTap: () => onNodeTap(n.node),
                          onSurface: theme.colorScheme.onSurface,
                          displayScale: displayScale,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bounding box (in the shared canvas-local space, generously padded for a
/// touch target) of one ring's date label — the SAME formula both
/// [_StarmapPainter] uses to draw the label and [_GraphView] uses to hit-test
/// a tap against it, so a tap always lands exactly where the label reads.
Rect ringLabelRect(StarmapRing ring, Offset center, double displayScale) {
  final tp = TextPainter(
    text: TextSpan(
      text: ring.label,
      style: TextStyle(fontSize: 10 / displayScale),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final topLeft = Offset(
    center.dx - tp.width / 2,
    center.dy - ring.r - tp.height - 2 / displayScale,
  );
  final padding = 6 / displayScale;
  return Rect.fromLTWH(
    topLeft.dx - padding,
    topLeft.dy - padding,
    tp.width + padding * 2,
    tp.height + padding * 2,
  );
}

/// Which ring (if any) a tap at [localPosition] hits, where [localPosition]
/// is in the outer `GestureDetector`'s own coordinate space (pre-Transform —
/// a child `Transform` doesn't affect its parent's hit-test coordinates,
/// which is exactly what `TapUpDetails.localPosition` reports here). Undoes
/// the shared translate-then-scale transform to land back in the same
/// canvas-local space [ringLabelRect] and the painter both use.
int? hitTestRingLabel({
  required Offset localPosition,
  required Offset origin,
  required double displayScale,
  required Offset center,
  required StarmapTimeLayout layout,
}) {
  final local = (localPosition - origin) / displayScale;
  for (var i = 0; i < layout.rings.length; i++) {
    if (layout.rings[i].label == null) continue;
    if (ringLabelRect(layout.rings[i], center, displayScale).contains(local)) {
      return i;
    }
  }
  return null;
}

class _NodeHitTarget extends StatelessWidget {
  final StarmapNode node;
  final Offset position;
  final VoidCallback onTap;
  final Color onSurface;
  final double displayScale;

  const _NodeHitTarget({
    required this.node,
    required this.position,
    required this.onTap,
    required this.onSurface,
    required this.displayScale,
  });

  @override
  Widget build(BuildContext context) {
    final label = node.label.isEmpty ? node.id : node.label;
    return Positioned(
      left: position.dx - 40 / displayScale,
      top: position.dy - 20 / displayScale,
      width: 80 / displayScale,
      height: 34 / displayScale,
      child: Semantics(
        button: true,
        label: context.l10n.starmapOpenNode(label),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11 / displayScale,
                fontWeight: FontWeight.w500,
                color: onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarmapPainter extends CustomPainter {
  final StarmapTimeLayout layout;
  final List<StarmapEdge> edges;
  final List<StarmapNodeLayout> visible;
  final int? selectedRing;
  final Color accent;
  final Color onSurfaceVariant;
  final double displayScale;
  final Offset center;

  const _StarmapPainter({
    required this.layout,
    required this.edges,
    required this.visible,
    required this.selectedRing,
    required this.accent,
    required this.onSurfaceVariant,
    required this.displayScale,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // A tapped ring's date: a lit band wash between it and its inner
    // neighbor, plus a brighter outline + label — lets a viewer pick a date
    // out of the disk the same way desktop's clickable ring labels do.
    final selected = selectedRing;
    if (selected != null && selected < layout.rings.length) {
      final ring = layout.rings[selected];
      final inner = selected > 0 ? layout.rings[selected - 1].r : 0.0;
      canvas.drawCircle(
        center,
        (ring.r + inner) / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (ring.r - inner)
          ..color = accent.withValues(alpha: 0.06),
      );
    }

    // Dated rings — equal-width gridlines, oldest (core) to newest (outer).
    for (var i = 0; i < layout.rings.length; i++) {
      final ring = layout.rings[i];
      final isSelected = i == selected;
      canvas.drawCircle(
        center,
        ring.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isSelected ? 1.6 : 1) / displayScale
          ..color = isSelected
              ? accent.withValues(alpha: 0.6)
              : onSurfaceVariant.withValues(alpha: 0.14),
      );
      if (ring.label != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: ring.label,
            style: TextStyle(
              fontSize: 10 / displayScale,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              color: isSelected
                  ? accent
                  : onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            center.dx - tp.width / 2,
            center.dy - ring.r - tp.height - 2 / displayScale,
          ),
        );
      }
    }

    final visibleIds = visible.map((n) => n.node.id).toSet();

    // Edges — only drawn once both endpoints have ignited.
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / displayScale
      ..color = onSurfaceVariant.withValues(alpha: 0.3);
    for (final e in edges) {
      if (!visibleIds.contains(e.source) || !visibleIds.contains(e.target)) {
        continue;
      }
      final a = layout.byId[e.source];
      final b = layout.byId[e.target];
      if (a == null || b == null) continue;
      canvas.drawLine(
        center + Offset(a.x, a.y),
        center + Offset(b.x, b.y),
        edgePaint,
      );
    }

    // Nodes: circle (skill) vs diamond (memory), age-gradient ink.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / displayScale
      ..color = Colors.black.withValues(alpha: 0.18);
    for (final n in visible) {
      final p = center + Offset(n.x, n.y);
      final ink = recencyInk(n.rec);
      final r = nodeDotRadius(n.node) / displayScale.clamp(0.6, 1.4);
      final color = (n.node.kind == 'memory' ? HermesSemantic.purple : accent)
          .withValues(alpha: ink);
      if (n.node.kind == 'memory') {
        final path = Path()
          ..moveTo(p.dx, p.dy - r)
          ..lineTo(p.dx + r, p.dy)
          ..lineTo(p.dx, p.dy + r)
          ..lineTo(p.dx - r, p.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
        canvas.drawPath(path, outline);
      } else {
        canvas.drawCircle(p, r, Paint()..color = color);
        canvas.drawCircle(p, r, outline);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarmapPainter old) =>
      old.visible.length != visible.length ||
      old.edges.length != edges.length ||
      old.selectedRing != selectedRing ||
      old.accent != accent ||
      old.displayScale != displayScale ||
      old.layout != layout;
}

/// Bottom sheet: node detail with edit/archive (skill or memory node — both
/// are learning-graph nodes server-side, see `ApiClient.knowledgeNode*`).
class _StarmapNodeSheet extends StatefulWidget {
  final StarmapNode node;
  final Map<String, dynamic> detail;
  final ApiClient ownerApi;
  final StarmapMemoryCard? memoryCard;
  final VoidCallback onChanged;

  const _StarmapNodeSheet({
    required this.node,
    required this.detail,
    required this.ownerApi,
    this.memoryCard,
    required this.onChanged,
  });

  @override
  State<_StarmapNodeSheet> createState() => _StarmapNodeSheetState();
}

class _StarmapNodeSheetState extends State<_StarmapNodeSheet> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.detail['content'] ?? widget.memoryCard?.body ?? '')
          .toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    setState(() => _saving = true);
    try {
      requireActiveApi(context, connection, api);
      // Starmap nodes ARE knowledge-graph nodes — same backend endpoint, see
      // ApiClient.starmapNode.
      await api.knowledgeNodeUpdate(widget.node.id, _controller.text);
      if (mounted) {
        requireActiveApi(context, connection, api);
        showHermesToast(
          context,
          message: l10n.starmapSaved,
          kind: HermesToastKind.success,
        );
        setState(() => _editing = false);
        widget.onChanged();
      }
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        showHermesToast(context, message: l10n.starmapSaveFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.starmapDeleteQuestion),
        content: Text(l10n.starmapDeleteDescription(widget.node.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      requireActiveApi(context, connection, api);
      await api.knowledgeNodeDelete(widget.node.id);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      Navigator.of(context).pop();
      widget.onChanged();
      showHermesToast(
        context,
        message: l10n.starmapDeleted,
        kind: HermesToastKind.success,
      );
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        showHermesToast(context, message: l10n.starmapDeleteFailed('$e'));
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final kind = (widget.detail['kind'] ?? widget.node.kind).toString();
    final category = (widget.detail['category'] ?? widget.node.category)
        .toString();
    final useCount =
        int.tryParse(
          (widget.detail['useCount'] ??
                  widget.detail['use_count'] ??
                  widget.node.useCount)
              .toString(),
        ) ??
        0;
    final displayedKind = switch (kind) {
      'skill' => l10n.starmapSkillLegend,
      'memory' => l10n.starmapMemoryLegend,
      _ => kind,
    };
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (ctx, scrollCtrl) => Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(HermesSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.node.label.isEmpty
                              ? widget.node.id
                              : widget.node.label,
                          style: HermesType.onSurface(HermesType.title, theme),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (kind.isNotEmpty)
                              HermesStatusChip(
                                color: HermesSemantic.purple,
                                label: displayedKind,
                              ),
                            if (category.isNotEmpty)
                              HermesStatusChip(
                                color: HermesSemantic.blue,
                                label: category,
                              ),
                            HermesStatusChip(
                              color: HermesSemantic.orange,
                              label: l10n.starmapUseCount(useCount),
                            ),
                            if (widget.node.pinned)
                              HermesStatusChip(
                                color: HermesSemantic.red,
                                label: l10n.sessionGroupPinned,
                              ),
                            if (widget.node.state == 'archived')
                              HermesStatusChip(
                                color: HermesSemantic.gray,
                                label: l10n.starmapStateArchived,
                              ),
                            if (widget.node.createdBy?.isNotEmpty == true)
                              HermesStatusChip(
                                color: HermesSemantic.gray,
                                label: l10n.starmapCreatedBy(
                                  widget.node.createdBy!,
                                ),
                              ),
                            if (widget.node.memorySource?.isNotEmpty == true)
                              HermesStatusChip(
                                color: HermesSemantic.gray,
                                label: l10n.starmapSource(
                                  widget.node.memorySource!,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _editing ? l10n.commonCancel : l10n.commonEdit,
                    icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
                    onPressed: () => setState(() => _editing = !_editing),
                  ),
                  if (!_editing)
                    IconButton(
                      tooltip: l10n.commonDelete,
                      icon: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.delete_outline,
                              color: HermesSemantic.red,
                            ),
                      onPressed: _deleting ? null : _delete,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _editing
                  ? Padding(
                      padding: const EdgeInsets.all(HermesSpacing.md),
                      child: Column(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                                labelText: l10n.starmapContent,
                              ),
                            ),
                          ),
                          const SizedBox(height: HermesSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _saving ? l10n.starmapSaving : l10n.commonSave,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(HermesSpacing.md),
                      child: SelectableText(
                        _controller.text.isEmpty
                            ? (widget.node.content ?? l10n.skillsNoContent)
                            : _controller.text,
                        style: HermesType.onSurface(HermesType.body, theme),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
