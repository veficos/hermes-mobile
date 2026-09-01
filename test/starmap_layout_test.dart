import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/starmap_layout.dart';

int _ts(int year, int month, int day) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ 1000;

void main() {
  group('computeRecency', () {
    test('undated graph falls back to stable ordinal ranking', () {
      final nodes = [
        StarmapNode(id: 'b'),
        StarmapNode(id: 'a'),
      ];
      final recency = computeRecency(nodes);
      expect(recency.timed, isFalse);
      // Ordinal by id (a < b), each scaled into [leadIn, 1].
      expect(recency.rec['a'], lessThan(recency.rec['b']!));
      expect(recency.rec['a'], closeTo(leadIn, 1e-9));
      expect(recency.rec['b'], closeTo(1.0, 1e-9));
    });

    test('dated graph is a truthful linear map of time, oldest at leadIn', () {
      final nodes = [
        StarmapNode(id: 'old', timestamp: _ts(2026, 1, 1)),
        StarmapNode(id: 'mid', timestamp: _ts(2026, 1, 11)),
        StarmapNode(id: 'new', timestamp: _ts(2026, 1, 21)),
      ];
      final recency = computeRecency(nodes);
      expect(recency.timed, isTrue);
      expect(recency.rec['old'], closeTo(leadIn, 1e-9));
      expect(recency.rec['new'], closeTo(1.0, 1e-9));
      // Midpoint in time lands at the midpoint of the recency range.
      expect(recency.rec['mid'], closeTo(leadIn + (1 - leadIn) * 0.5, 1e-6));
    });

    test('a single instant (no span) is not "timed"', () {
      final nodes = [
        StarmapNode(id: 'a', timestamp: _ts(2026, 1, 1)),
        StarmapNode(id: 'b', timestamp: _ts(2026, 1, 1)),
      ];
      expect(computeRecency(nodes).timed, isFalse);
    });
  });

  group('nodeDotRadius', () {
    test('memory nodes are a fixed size regardless of other fields', () {
      final n = StarmapNode(id: 'm', kind: 'memory', useCount: 999, pinned: true);
      expect(nodeDotRadius(n), 4.4);
    });

    test('skill radius grows with useCount and pinned, shrinks when archived', () {
      final base = nodeDotRadius(StarmapNode(id: 's', kind: 'skill'));
      final used = nodeDotRadius(StarmapNode(id: 's', kind: 'skill', useCount: 16));
      final pinned = nodeDotRadius(StarmapNode(id: 's', kind: 'skill', pinned: true));
      final archived = nodeDotRadius(
        StarmapNode(id: 's', kind: 'skill', state: 'archived'),
      );
      expect(used, greaterThan(base));
      expect(pinned, greaterThan(base));
      expect(archived, lessThan(base));
    });
  });

  group('recencyInk', () {
    test('is monotonically non-decreasing from old to new', () {
      final samples = [0.0, 0.2, 0.4, 0.52, 0.6, 0.8, 1.0].map(recencyInk).toList();
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
      }
      expect(samples.first, closeTo(0.42, 1e-9));
      expect(samples.last, closeTo(0.95, 1e-9));
    });
  });

  group('fnv1aHash', () {
    test('is deterministic and spreads distinct ids apart', () {
      expect(fnv1aHash('skill-a'), fnv1aHash('skill-a'));
      expect(fnv1aHash('skill-a'), isNot(fnv1aHash('skill-b')));
    });
  });

  group('buildStarmapTimeLayout', () {
    test('undated graph falls back to the fixed 5-ring layout', () {
      final layout = buildStarmapTimeLayout([
        StarmapNode(id: 'a'),
        StarmapNode(id: 'b'),
      ]);
      expect(layout.timed, isFalse);
      expect(layout.rings, hasLength(ringSteps + 1));
      expect(layout.nodes, hasLength(2));
    });

    test('a dated graph spanning weeks builds ~5-12 populated rings', () {
      final nodes = List.generate(
        30,
        (i) => StarmapNode(
          id: 'n$i',
          timestamp: _ts(2026, 1, 1) + i * 2 * 86400, // spread across ~2 months
        ),
      );
      final layout = buildStarmapTimeLayout(nodes);
      expect(layout.timed, isTrue);
      expect(layout.rings.length, inInclusiveRange(2, 30));
      // Every ring's radius grows monotonically outward.
      for (var i = 1; i < layout.rings.length; i++) {
        expect(layout.rings[i].r, greaterThan(layout.rings[i - 1].r));
      }
      // Every node landed inside the outermost ring's radius.
      for (final n in layout.nodes) {
        final dist = (n.x * n.x + n.y * n.y);
        expect(dist, lessThanOrEqualTo(layout.outerRadius * layout.outerRadius + 1));
      }
    });

    test('oldest node sits closer to the core than the newest', () {
      final nodes = [
        StarmapNode(id: 'old', timestamp: _ts(2025, 1, 1)),
        StarmapNode(id: 'new', timestamp: _ts(2026, 6, 1)),
        // A few more so there's enough span/count for real bucketing.
        StarmapNode(id: 'm1', timestamp: _ts(2025, 6, 1)),
        StarmapNode(id: 'm2', timestamp: _ts(2025, 9, 1)),
        StarmapNode(id: 'm3', timestamp: _ts(2025, 12, 1)),
      ];
      final layout = buildStarmapTimeLayout(nodes);
      final oldDist = _distFromCore(layout.byId['old']!);
      final newDist = _distFromCore(layout.byId['new']!);
      expect(oldDist, lessThan(newDist));
    });

    test('rings only grow the disk outward — more buckets never shrink RING_INNER', () {
      final nodes = List.generate(
        60,
        (i) => StarmapNode(id: 'n$i', timestamp: _ts(2020, 1, 1) + i * 30 * 86400),
      );
      final layout = buildStarmapTimeLayout(nodes);
      expect(layout.rings.first.r, greaterThanOrEqualTo(ringInner));
    });
  });
}

double _distFromCore(StarmapNodeLayout n) {
  return (n.x * n.x + n.y * n.y);
}
