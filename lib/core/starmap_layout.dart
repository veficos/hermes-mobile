/// Star-map radial time layout — a port of hermes-agent desktop's
/// `app/starmap/{geometry,time-axis,simulation}.ts` math. Time is RADIAL:
/// oldest at the core, newest on the outer rings. Desktop settles this with
/// a d3-force simulation (radial force dominant, charge/collide/link only
/// add organic jitter around an already-fully-determined target position);
/// this port skips the physics settling and places nodes directly at their
/// deterministic target position, which is what the simulation converges to.
library;

import 'dart:math' as math;

import 'models.dart';

// ── Disk geometry (constants.ts) ────────────────────────────────────────────
const double ringInner = 58;
const double ringOuter = 340;
const int ringSteps = 4;

// ── Recency (time-axis.ts) ──────────────────────────────────────────────────
// Empty lead-in: push the oldest node off 0 so a play-through opens on a beat
// of emptiness. Radial position is otherwise a truthful linear map of time.
const double leadIn = 0.06;
double recForRatio(double ratio) => leadIn + (1 - leadIn) * ratio.clamp(0, 1);

class Recency {
  final int? minTs;
  final int? maxTs;
  final Map<String, double> rec; // id -> recency ratio (0 oldest … 1 newest)
  final bool timed;

  Recency({this.minTs, this.maxTs, required this.rec, required this.timed});
}

/// Shared recency model: a node's ring distance and its ignite/reveal time
/// agree. Timed by timestamp when the span is real, else ordinal so an
/// undated graph still "builds up" in a stable order.
Recency computeRecency(List<StarmapNode> nodes) {
  final known = nodes.map((n) => n.timestamp).whereType<int>().toList();
  final minTs = known.isEmpty ? null : known.reduce(math.min);
  final maxTs = known.isEmpty ? null : known.reduce(math.max);
  final timed = minTs != null && maxTs != null && maxTs > minTs;

  final ordered = [...nodes]
    ..sort((a, b) {
      final at = a.timestamp ?? double.maxFinite.toInt();
      final bt = b.timestamp ?? double.maxFinite.toInt();
      return at == bt ? a.id.compareTo(b.id) : at.compareTo(bt);
    });
  final ordRatio = <String, double>{
    for (var i = 0; i < ordered.length; i++)
      ordered[i].id: ordered.length > 1 ? i / (ordered.length - 1) : 0,
  };

  final rec = <String, double>{};
  for (final n in nodes) {
    final ratio = (timed && n.timestamp != null)
        ? (n.timestamp! - minTs) / (maxTs - minTs)
        : (ordRatio[n.id] ?? 0);
    rec[n.id] = recForRatio(ratio);
  }

  return Recency(minTs: minTs, maxTs: maxTs, rec: rec, timed: timed);
}

/// Target radius for a node at recency [rec] (oldest at the core).
double radiusForRecency(double rec, {double outer = ringOuter}) =>
    ringInner + rec * (outer - ringInner);

// ── Node visuals (geometry.ts) ──────────────────────────────────────────────
/// FNV-1a — stable per-id seed for layout angle / jitter.
int fnv1aHash(String input) {
  var h = 2166136261;
  for (final code in input.codeUnits) {
    h ^= code;
    h = (h * 16777619) & 0xffffffff;
  }
  return h & 0xffffffff;
}

double nodeDotRadius(StarmapNode n) {
  if (n.kind == 'memory') return 4.4;
  final base = (n.state == 'archived' || n.state == 'stale') ? 2.4 : 3.0;
  return base +
      math.sqrt(math.max(0, n.useCount)) * 0.55 +
      (n.pinned ? 0.8 : 0);
}

/// Smoothstep recency → ink alpha along the age gradient (old = quiet, recent
/// = bright). Mirrors `recencyInk` (AGE_GRADIENT: mid .52, oldInk .42, midInk
/// .74, newInk .95, reach 1).
double recencyInk(double rec) {
  const mid = 0.52, oldInk = 0.42, midInk = 0.74, newInk = 0.95, reach = 1.0;
  final t = (rec / reach).clamp(0.0, 1.0);
  if (t <= mid) {
    final p = t / mid;
    return oldInk + (midInk - oldInk) * (p * p * (3 - 2 * p));
  }
  final p = (t - mid) / (1 - mid);
  return midInk + (newInk - midInk) * (p * p * (3 - 2 * p));
}

// ── Ring/time bucketing (simulation.ts) ─────────────────────────────────────
const int _daySeconds = 86400;
// Roughly how many nodes share one ignite burst within a ring band.
const int clusterSize = 5;

final double _ringCore = radiusForRecency(recForRatio(0));
final double _ringBand =
    (radiusForRecency(recForRatio(1)) - _ringCore) / ringSteps;
double ringRadius(int i) => _ringCore + i * _ringBand;

/// Position INSIDE a ring's band (the annulus the ring caps), biased toward
/// mid-band so a node reads as "within the ring", only occasionally grazing
/// an edge — never sitting on the outline like a bead.
double placeRadiusInBand(int i, String id) {
  final outer = ringRadius(i);
  final inner = i > 0 ? ringRadius(i - 1) : _ringCore - _ringBand * 0.5;
  final h = (fnv1aHash(id) % 1000) / 1000;
  return outer - (0.15 + 0.7 * h) * (outer - inner);
}

class _Unit {
  final bool isDay; // day vs month
  final int step;
  const _Unit(this.isDay, this.step);
}

// "Nice" calendar intervals, fine → coarse, with intermediate rungs so the
// bucketer can land near the target ring count.
const List<_Unit> _units = [
  _Unit(true, 1),
  _Unit(true, 2),
  _Unit(true, 7),
  _Unit(true, 14),
  _Unit(false, 1),
  _Unit(false, 2),
  _Unit(false, 3),
  _Unit(false, 6),
  _Unit(false, 12),
];

/// Floor a timestamp (epoch seconds) to the start of its calendar bucket.
int _bucketStart(int ts, _Unit u) {
  if (u.isDay) {
    final period = u.step * _daySeconds;
    return (ts / period).floor() * period;
  }
  final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
  final absMonth = ((d.year * 12 + (d.month - 1)) / u.step).floor() * u.step;
  final bucketYear = (absMonth / 12).floor();
  final bucketMonth = absMonth % 12;
  final bucketed = DateTime.utc(bucketYear, bucketMonth + 1, 1);
  return bucketed.millisecondsSinceEpoch ~/ 1000;
}

List<int> _populatedStarts(List<int> stamps, _Unit u) {
  final starts = stamps.map((t) => _bucketStart(t, u)).toSet().toList()..sort();
  return starts;
}

/// "Nice ticks" for time: aim for a target ring count that grows ~log2 with
/// the span, then snap to the calendar interval whose POPULATED count lands
/// nearest it. Floor of 5 rings for a smooth build-up.
_Unit _chooseUnit(List<int> stamps, double spanDays) {
  final target = (4 + math.log(math.max(1, spanDays / 60)) / math.ln2)
      .round()
      .clamp(5, 12);
  var best = _units.first;
  var bestScore = double.infinity;
  for (final u in _units) {
    final count = _populatedStarts(stamps, u).length;
    if (count == 0) continue;
    final score = (count - target).abs() + (count > target ? 0.5 : 0);
    if (score < bestScore) {
      bestScore = score.toDouble();
      best = u;
    }
  }
  return best;
}

String _bucketLabel(int ts, _Unit u) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
  if (u.isDay) return _formatDate(d);
  if (u.step >= 12) return '${d.year}';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

String _formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// One dated ring — a populated calendar bucket.
class StarmapRing {
  final String? label;
  final double r; // world radius
  final double ratio; // reveal position [0,1] a ring spawns at

  StarmapRing({this.label, required this.r, required this.ratio});
}

/// Final per-node layout: world position + reveal (ignite) time + ring index.
class StarmapNodeLayout {
  final StarmapNode node;
  final double x;
  final double y;
  final double rec; // reveal coordinate [0,1]
  final int ringIndex;

  StarmapNodeLayout({
    required this.node,
    required this.x,
    required this.y,
    required this.rec,
    required this.ringIndex,
  });
}

class StarmapTimeLayout {
  final List<StarmapRing> rings;
  final List<StarmapNodeLayout> nodes;
  final Map<String, StarmapNodeLayout> byId;
  final bool timed;
  final int? minTs;
  final int? maxTs;

  StarmapTimeLayout({
    required this.rings,
    required this.nodes,
    required this.byId,
    required this.timed,
    this.minTs,
    this.maxTs,
  });

  /// World-space bounding radius (outermost ring), for fit/reset framing.
  double get outerRadius => rings.isEmpty ? ringOuter : rings.last.r;
}

/// Even, unlabeled-ish fallback when there's no usable time span (undated
/// graph or one instant): a fixed 5-ring layout so nothing regresses.
StarmapTimeLayout _evenLayout(List<StarmapNode> allNodes, Recency recency) {
  final rings = List.generate(ringSteps + 1, (i) {
    String? label;
    if (recency.timed && recency.minTs != null && recency.maxTs != null) {
      final ts =
          (recency.minTs! + (recency.maxTs! - recency.minTs!) * (i / ringSteps))
              .round();
      label = _formatDate(
        DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
      );
    }
    return StarmapRing(
      label: label,
      r: ringRadius(i),
      ratio: recForRatio(i / ringSteps),
    );
  });

  int capRing(double rec) {
    for (var i = 0; i < rings.length; i++) {
      if (rings[i].ratio >= rec - 1e-3) return i;
    }
    return rings.length - 1;
  }

  final layouts = <StarmapNodeLayout>[];
  final byId = <String, StarmapNodeLayout>{};
  for (final n in allNodes) {
    final rec = recency.rec[n.id] ?? 0;
    final tr = radiusForRecency(rec);
    final angle = (fnv1aHash(n.id) % 3600) / 3600 * 2 * math.pi;
    final layout = StarmapNodeLayout(
      node: n,
      x: math.cos(angle) * tr,
      y: math.sin(angle) * tr,
      rec: rec,
      ringIndex: capRing(rec),
    );
    layouts.add(layout);
    byId[n.id] = layout;
  }

  return StarmapTimeLayout(
    rings: rings,
    nodes: layouts,
    byId: byId,
    timed: recency.timed,
    minTs: recency.minTs,
    maxTs: recency.maxTs,
  );
}

/// Build the radial time layout: one equal-width ring per POPULATED calendar
/// bucket; a bucket's nodes fill the band inside their ring (fanned by angle)
/// and ignite staggered across it.
StarmapTimeLayout buildStarmapTimeLayout(List<StarmapNode> allNodes) {
  final recency = computeRecency(allNodes);
  final stamps = allNodes.map((n) => n.timestamp).whereType<int>().toList();

  if (!(recency.timed &&
      recency.minTs != null &&
      recency.maxTs != null &&
      recency.maxTs! > recency.minTs! &&
      stamps.isNotEmpty)) {
    return _evenLayout(allNodes, recency);
  }

  final span = recency.maxTs! - recency.minTs!;
  final unit = _chooseUnit(stamps, span / _daySeconds);
  final starts = _populatedStarts(stamps, unit);

  if (starts.length < 2) {
    return _evenLayout(allNodes, recency);
  }

  final indexOfStart = {for (var i = 0; i < starts.length; i++) starts[i]: i};
  final last = math.max(1, starts.length - 1);

  final rings = List.generate(
    starts.length,
    (i) => StarmapRing(
      label: _bucketLabel(starts[i], unit),
      r: ringRadius(i),
      ratio: recForRatio(i / last),
    ),
  );

  int indexFor(StarmapNode n) {
    final ts = n.timestamp;
    if (ts == null) return starts.length - 1;
    return indexOfStart[_bucketStart(ts, unit)] ?? starts.length - 1;
  }

  final buckets = List.generate(starts.length, (_) => <StarmapNode>[]);
  for (final n in allNodes) {
    buckets[indexFor(n)].add(n);
  }

  int tsOf(StarmapNode n) => n.timestamp ?? (1 << 62);
  final recByNode = <String, double>{};

  for (var i = 0; i < buckets.length; i++) {
    final bucket = buckets[i]
      ..sort((a, b) {
        final at = tsOf(a), bt = tsOf(b);
        return at == bt ? a.id.compareTo(b.id) : at.compareTo(bt);
      });
    final hi = rings[i].ratio;
    final lo = i > 0 ? rings[i - 1].ratio : 0.0;
    final m = bucket.length;
    final clusters = math.max(1, (m / clusterSize).round());

    for (var k = 0; k < bucket.length; k++) {
      final n = bucket[k];
      final c = math.min(clusters - 1, ((k / m) * clusters).floor());
      final jitter = ((fnv1aHash(n.id) % 100) / 100 - 0.5) * (0.5 / clusters);
      final f = ((c + 1) / clusters + jitter).clamp(0.02, 1.0);
      recByNode[n.id] = lo + f * (hi - lo);
    }
  }

  final layouts = <StarmapNodeLayout>[];
  final byId = <String, StarmapNodeLayout>{};
  for (final n in allNodes) {
    final ringIndex = indexFor(n);
    final tr = placeRadiusInBand(ringIndex, n.id);
    final angle = (fnv1aHash(n.id) % 3600) / 3600 * 2 * math.pi;
    final layout = StarmapNodeLayout(
      node: n,
      x: math.cos(angle) * tr,
      y: math.sin(angle) * tr,
      rec: recByNode[n.id] ?? 0,
      ringIndex: ringIndex,
    );
    layouts.add(layout);
    byId[n.id] = layout;
  }

  return StarmapTimeLayout(
    rings: rings,
    nodes: layouts,
    byId: byId,
    timed: true,
    minTs: recency.minTs,
    maxTs: recency.maxTs,
  );
}
