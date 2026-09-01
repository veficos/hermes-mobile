import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/starmap_layout.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/screens/starmap_screen.dart';
import 'package:provider/provider.dart';

/// Gap #4 from the desktop comparison: desktop's ring date labels are
/// clickable (toggles a lit-band highlight); mobile's were static text.
/// `ringLabelRect`/`hitTestRingLabel` are the pure hit-test math backing the
/// fix — tested directly here since a CustomPainter's drawn output isn't
/// otherwise inspectable from a widget test.
void main() {
  group('ringLabelRect', () {
    test('is centered above the ring at its radius, growing with padding', () {
      final ring = StarmapRing(label: 'Jan 2026', r: 100, ratio: 0.5);
      const center = Offset(200, 200);
      const displayScale = 1.0;
      final rect = ringLabelRect(ring, center, displayScale);

      // Horizontally centered on the ring.
      expect(rect.center.dx, closeTo(center.dx, 0.5));
      // The rect's top sits clearly above the ring line (the label is drawn
      // outside the disk); the padded bottom edge may cross slightly past
      // the ring itself — that's a deliberately generous touch target.
      expect(rect.top, lessThan(center.dy - ring.r));
    });

    test('shrinks in canvas-local space as displayScale (zoom) grows', () {
      final ring = StarmapRing(label: 'Jan 2026', r: 100, ratio: 0.5);
      const center = Offset(200, 200);
      final zoomedOut = ringLabelRect(ring, center, 0.5);
      final zoomedIn = ringLabelRect(ring, center, 2.0);
      // Font size and padding both scale as 1/displayScale, so a higher zoom
      // means a SMALLER rect in this shared local-coordinate space (it still
      // reads the same size on screen once the shared Transform scales it
      // back up).
      expect(zoomedIn.width, lessThan(zoomedOut.width));
      expect(zoomedIn.height, lessThan(zoomedOut.height));
    });

    test('a ring with no label still returns a (degenerate but safe) rect', () {
      final ring = StarmapRing(label: null, r: 50, ratio: 0.2);
      final rect = ringLabelRect(ring, Offset.zero, 1.0);
      expect(rect.isFinite, isTrue);
    });
  });

  group('hitTestRingLabel', () {
    late StarmapTimeLayout layout;

    setUp(() {
      // Three dated skills spanning enough real time to build real rings.
      layout = buildStarmapTimeLayout([
        StarmapNode(id: 'a', timestamp: 1699900000),
        StarmapNode(id: 'b', timestamp: 1699950000),
        StarmapNode(id: 'c', timestamp: 1700000000),
      ]);
    });

    test('a tap on a ring label position resolves to that ring index', () {
      const origin = Offset(300, 300);
      const displayScale = 1.0;
      const center = Offset.zero;
      final ring = layout.rings.first;
      final rect = ringLabelRect(ring, center, displayScale);
      // Tap the label's center, converted back into the pre-Transform
      // (GestureDetector-local) space hitTestRingLabel expects.
      final tapLocal = rect.center * displayScale + origin;

      final hit = hitTestRingLabel(
        localPosition: tapLocal,
        origin: origin,
        displayScale: displayScale,
        center: center,
        layout: layout,
      );
      expect(hit, 0);
    });

    test('a tap far from every ring label misses', () {
      const origin = Offset(300, 300);
      final hit = hitTestRingLabel(
        localPosition: const Offset(3000, 3000),
        origin: origin,
        displayScale: 1.0,
        center: Offset.zero,
        layout: layout,
      );
      expect(hit, isNull);
    });

    test('hit-testing accounts for pan/zoom (origin + displayScale)', () {
      // Same math, but panned and zoomed — the tap position that hits ring 0
      // must shift accordingly.
      const origin = Offset(150, 400);
      const displayScale = 1.8;
      final ring = layout.rings.first;
      final rect = ringLabelRect(ring, Offset.zero, displayScale);
      final tapLocal = rect.center * displayScale + origin;

      final hit = hitTestRingLabel(
        localPosition: tapLocal,
        origin: origin,
        displayScale: displayScale,
        center: Offset.zero,
        layout: layout,
      );
      expect(hit, 0);
    });
  });

  group('StarmapScreen ring selection (widget)', () {
    testWidgets('tapping empty canvas space does not crash and selects nothing', (
      tester,
    ) async {
      final api = _StarmapApi();
      final connection = ConnectionStore()..api = api;
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionStore>.value(
          value: connection,
          child: const MaterialApp(home: StarmapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // A tap well away from any ring label (canvas center) must not throw —
      // the common case of just panning/tapping the empty disk.
      await tester.tapAt(tester.getCenter(find.byType(StarmapScreen)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

class _StarmapApi extends ApiClient {
  _StarmapApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<StarmapGraph> starmapGraph() async => StarmapGraph(
    nodes: [
      StarmapNode(id: 'a', label: 'a', kind: 'skill', timestamp: 1699900000),
      StarmapNode(id: 'b', label: 'b', kind: 'skill', timestamp: 1700000000),
    ],
  );
}
