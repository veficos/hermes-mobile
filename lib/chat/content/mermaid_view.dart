import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/l10n.dart';
import '../../widgets/web_preview.dart' show webViewSupported;

class MermaidPreview extends StatelessWidget {
  final String source;
  const MermaidPreview({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.chatMermaidDiagram)),
      body: MermaidDiagramView(source: source),
    );
  }
}

/// Pure-Flutter transcript preview. Unlike [MermaidDiagramView], this never
/// creates a platform view and is safe to recycle in a scrolling sliver.
class MermaidStaticDiagramView extends StatelessWidget {
  final String source;
  const MermaidStaticDiagramView({super.key, required this.source});

  @override
  Widget build(BuildContext context) =>
      _MermaidFallback(source: source, interactive: false);
}

/// Full Mermaid 11 renderer backed by an offline, CSP-restricted WebView host.
/// The bundled engine covers flowchart, sequence, class, state, ER, gantt,
/// journey, mindmap, timeline, quadrant, sankey, XY and newer Mermaid syntax.
/// Unsupported platforms and parse failures retain the lightweight flowchart
/// painter/source fallback so a transcript is never blank.
class MermaidDiagramView extends StatefulWidget {
  final String source;
  final bool interactive;
  const MermaidDiagramView({
    super.key,
    required this.source,
    this.interactive = true,
  });

  @override
  State<MermaidDiagramView> createState() => _MermaidDiagramViewState();
}

class _MermaidDiagramViewState extends State<MermaidDiagramView> {
  WebViewController? _controller;
  bool _hostReady = false;
  bool _rendered = false;
  bool? _lastDark;
  String? _error;
  double _contentHeight = 220;

  @override
  void initState() {
    super.initState();
    if (!webViewSupported) return;
    try {
      _controller = WebViewController()
        ..setBackgroundColor(Colors.transparent)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'MermaidBridge',
          onMessageReceived: _onBridgeMessage,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _hostReady = true;
              unawaited(_render());
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == false || !mounted) return;
              setState(() => _error = error.description);
            },
          ),
        )
        ..loadFlutterAsset('assets/vendor/mermaid/mermaid_host.html');
    } catch (error) {
      _error = '$error';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_lastDark != null && _lastDark != dark && _hostReady) {
      _lastDark = dark;
      unawaited(_render());
    } else {
      _lastDark = dark;
    }
  }

  @override
  void didUpdateWidget(covariant MermaidDiagramView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source && _hostReady) {
      unawaited(_render());
    }
  }

  Future<void> _render() async {
    final controller = _controller;
    if (controller == null || !_hostReady) return;
    if (mounted) {
      setState(() {
        _rendered = false;
        _error = null;
      });
    }
    try {
      await controller.runJavaScript(
        'window.renderMermaid(${jsonEncode(widget.source)}, ${_lastDark == true})',
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    dynamic decoded;
    try {
      decoded = jsonDecode(message.message);
    } catch (_) {
      return;
    }
    if (!mounted || decoded is! Map) return;
    if (decoded['type'] == 'error') {
      setState(() {
        _error =
            decoded['message']?.toString() ??
            context.l10n.chatMermaidParseError;
        _rendered = false;
      });
      return;
    }
    if (decoded['type'] != 'rendered') return;
    final height = decoded['height'];
    setState(() {
      _rendered = true;
      if (height is num && height.isFinite && height > 0) {
        _contentHeight = height.toDouble().clamp(140, 720);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _error != null) {
      return _MermaidFallback(
        source: widget.source,
        interactive: widget.interactive,
      );
    }
    Widget view = Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: controller),
        if (!_rendered)
          const IgnorePointer(
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
    if (!widget.interactive) {
      view = IgnorePointer(
        child: SizedBox(height: _contentHeight.clamp(140, 360), child: view),
      );
    }
    return view;
  }
}

class _MermaidFallback extends StatelessWidget {
  const _MermaidFallback({required this.source, required this.interactive});

  final String source;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final graph = MermaidGraph.parse(source);
    if (graph.nodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            source,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    }
    final horizontal = graph.horizontal;
    final layers = graph.layerCount;
    final widest = graph.widestLayer;
    final size = horizontal
        ? Size((layers * 240 + 80).toDouble(), (widest * 110 + 80).toDouble())
        : Size((widest * 220 + 80).toDouble(), (layers * 120 + 80).toDouble());
    final painted = CustomPaint(
      size: size,
      painter: MermaidPainter(
        graph: graph,
        colorScheme: Theme.of(context).colorScheme,
      ),
    );
    if (!interactive) return FittedBox(fit: BoxFit.contain, child: painted);
    return InteractiveViewer(
      constrained: false,
      minScale: .3,
      maxScale: 4,
      child: painted,
    );
  }
}

/// A deliberately small flowchart parser: `graph`/`flowchart` with a direction,
/// `A[Label] -->|edge| B(Label)` edges, node shapes by bracket style. Not a
/// full mermaid implementation — sequence/class/state/gantt diagrams fall back
/// to their source. Desktop uses the real `mermaid` library.
class MermaidNode {
  final String id;
  String label;
  String shape; // rect | round | diamond
  MermaidNode(this.id, this.label, this.shape);
}

class MermaidEdge {
  final String from;
  final String to;
  final String label;
  const MermaidEdge(this.from, this.to, this.label);
}

class MermaidGraph {
  final List<MermaidNode> nodes;
  final List<MermaidEdge> edges;
  final bool horizontal;
  final Map<String, int> depth;
  final Map<String, int> lane;

  MermaidGraph(this.nodes, this.edges, this.horizontal, this.depth, this.lane);

  int get layerCount => depth.values.isEmpty
      ? 1
      : depth.values.reduce((a, b) => a > b ? a : b) + 1;
  int get widestLayer {
    final counts = <int, int>{};
    for (final d in depth.values) {
      counts[d] = (counts[d] ?? 0) + 1;
    }
    return counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);
  }

  static ({String label, String shape}) _shape(String? open, String? body) {
    final label = (body ?? '')
        .replaceAll(RegExp(r'''^["']|["']$'''), '')
        .trim();
    return switch (open) {
      '(' || '([' || '((' => (label: label, shape: 'round'),
      '{' => (label: label, shape: 'diamond'),
      _ => (label: label, shape: 'rect'),
    };
  }

  static MermaidGraph parse(String source) {
    final byId = <String, MermaidNode>{};
    final ordered = <MermaidNode>[];
    final edges = <MermaidEdge>[];
    var horizontal = false;

    MermaidNode node(String id, {String? open, String? body}) {
      final existing = byId[id];
      final parsed = body == null ? null : _shape(open, body);
      if (existing != null) {
        if (parsed != null && parsed.label.isNotEmpty) {
          existing.label = parsed.label;
          existing.shape = parsed.shape;
        }
        return existing;
      }
      final n = MermaidNode(
        id,
        parsed?.label.isNotEmpty == true ? parsed!.label : id,
        parsed?.shape ?? 'rect',
      );
      byId[id] = n;
      ordered.add(n);
      return n;
    }

    final dir = RegExp(
      r'^\s*(?:graph|flowchart)\s+(TB|TD|BT|LR|RL)\b',
      caseSensitive: false,
    );
    final edge = RegExp(
      r'([A-Za-z0-9_]+)\s*(\(\(|\(\[|\[|\(|\{)?\s*([^\]\)\}\n]*)\s*[\]\)\}]*\s*'
      r'-{2,3}>?\s*(?:\|([^|]*)\|\s*)?'
      r'([A-Za-z0-9_]+)\s*(\(\(|\(\[|\[|\(|\{)?\s*([^\]\)\}\n]*)\s*[\]\)\}]*',
    );

    for (final raw in source.split('\n')) {
      final line = raw.trim();
      final d = dir.firstMatch(line);
      if (d != null) {
        final code = d.group(1)!.toUpperCase();
        horizontal = code == 'LR' || code == 'RL';
        continue;
      }
      final m = edge.firstMatch(line);
      if (m == null) continue;
      final a = node(
        m.group(1)!,
        open: m.group(2),
        body: m.group(3)?.isEmpty == true ? null : m.group(3),
      );
      final b = node(
        m.group(5)!,
        open: m.group(6),
        body: m.group(7)?.isEmpty == true ? null : m.group(7),
      );
      edges.add(MermaidEdge(a.id, b.id, (m.group(4) ?? '').trim()));
    }

    // Layered layout: depth = longest path from a root; lane = order within depth.
    final adj = <String, List<String>>{};
    final indeg = <String, int>{for (final n in ordered) n.id: 0};
    for (final e in edges) {
      (adj[e.from] ??= []).add(e.to);
      indeg[e.to] = (indeg[e.to] ?? 0) + 1;
    }
    final depth = <String, int>{};
    final queue = <String>[
      for (final n in ordered)
        if ((indeg[n.id] ?? 0) == 0) n.id,
    ];
    for (final id in queue) {
      depth[id] = 0;
    }
    var head = 0;
    while (head < queue.length) {
      final id = queue[head++];
      for (final next in adj[id] ?? const <String>[]) {
        final cand = (depth[id] ?? 0) + 1;
        if (cand > (depth[next] ?? -1)) {
          depth[next] = cand;
          queue.add(next);
        }
      }
    }
    for (final n in ordered) {
      depth.putIfAbsent(n.id, () => 0);
    }
    final lane = <String, int>{};
    final perDepth = <int, int>{};
    for (final n in ordered) {
      final d = depth[n.id]!;
      lane[n.id] = perDepth[d] ?? 0;
      perDepth[d] = (perDepth[d] ?? 0) + 1;
    }

    return MermaidGraph(ordered, edges, horizontal, depth, lane);
  }
}

class MermaidPainter extends CustomPainter {
  final MermaidGraph graph;
  final ColorScheme colorScheme;
  const MermaidPainter({required this.graph, required this.colorScheme});

  static const _w = 160.0;
  static const _h = 52.0;

  Offset _center(String id) {
    final d = graph.depth[id] ?? 0;
    final l = graph.lane[id] ?? 0;
    return graph.horizontal
        ? Offset(60 + _w / 2 + d * 220, 50 + _h / 2 + l * 100)
        : Offset(50 + _w / 2 + l * 200, 50 + _h / 2 + d * 110);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = colorScheme.primaryContainer;

    for (final e in graph.edges) {
      if (!graph.depth.containsKey(e.from) || !graph.depth.containsKey(e.to)) {
        continue;
      }
      final a = _center(e.from);
      final b = _center(e.to);
      canvas.drawLine(a, b, stroke..style = PaintingStyle.stroke);
      // Arrowhead.
      final dir = (b - a);
      final len = dir.distance;
      if (len > 1) {
        final u = dir / len;
        final tip = b - u * (_h / 2);
        final left = tip - u * 10 + Offset(-u.dy, u.dx) * 5;
        final right = tip - u * 10 - Offset(-u.dy, u.dx) * 5;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(left.dx, left.dy)
            ..lineTo(right.dx, right.dy)
            ..close(),
          Paint()..color = colorScheme.outline,
        );
      }
      if (e.label.isNotEmpty) {
        final mid = Offset.lerp(a, b, 0.5)!;
        final tp = TextPainter(
          text: TextSpan(
            text: e.label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 140);
        final bg = Rect.fromCenter(
          center: mid,
          width: tp.width + 8,
          height: tp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bg, const Radius.circular(4)),
          Paint()..color = colorScheme.surface,
        );
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }

    for (final n in graph.nodes) {
      final center = _center(n.id);
      final rect = Rect.fromCenter(center: center, width: _w, height: _h);
      if (n.shape == 'diamond') {
        final path = Path()
          ..moveTo(center.dx, rect.top)
          ..lineTo(rect.right, center.dy)
          ..lineTo(center.dx, rect.bottom)
          ..lineTo(rect.left, center.dy)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke..style = PaintingStyle.stroke);
      } else {
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(n.shape == 'round' ? 26 : 10),
        );
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, stroke..style = PaintingStyle.stroke);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: n.label,
          style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: _w - 16);
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant MermaidPainter oldDelegate) =>
      oldDelegate.graph != graph || oldDelegate.colorScheme != colorScheme;
}
