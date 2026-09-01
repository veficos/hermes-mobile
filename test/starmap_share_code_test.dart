import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/starmap_share_code.dart';

/// Direct Dart port of hermes-agent desktop's `app/starmap/share-code.test.ts`
/// sample graph and assertions, so the codec's behavior is verified against
/// the same fixture as the TypeScript original.
StarmapGraph _sampleGraph() => StarmapGraph(
  clusters: const [],
  edges: [
    StarmapEdge(source: 'skill-a', target: 'skill-b'),
    StarmapEdge(source: 'skill-b', target: 'memory:profile:0'),
  ],
  memory: [
    StarmapMemoryCard(
      body: 'Prefers concise answers.',
      source: 'profile',
      timestamp: 1700000000,
      title: 'Tone',
    ),
    StarmapMemoryCard(
      body: 'Uses a worktree.',
      source: 'memory',
      timestamp: null,
      title: 'Env',
    ),
  ],
  nodes: [
    StarmapNode(
      category: 'devops',
      createdBy: 'agent',
      id: 'skill-a',
      kind: 'skill',
      label: 'skill-a',
      pinned: true,
      state: 'active',
      timestamp: 1699900000,
      useCount: 7,
    ),
    StarmapNode(
      category: 'devops',
      createdBy: null,
      id: 'skill-b',
      kind: 'skill',
      label: 'skill-b',
      pinned: false,
      state: 'draft',
      timestamp: 1699950000,
      useCount: 0,
    ),
    StarmapNode(
      category: 'memory',
      createdBy: null,
      id: 'memory:profile:0',
      kind: 'memory',
      label: 'A fact',
      memorySource: 'profile',
      pinned: false,
      state: 'active',
      timestamp: 1700000000,
      useCount: 0,
    ),
  ],
  stats: const {},
);

List<List<int>> _topology(StarmapGraph g) {
  final idx = {for (var i = 0; i < g.nodes.length; i++) g.nodes[i].id: i};
  return g.edges.map((e) => [idx[e.source]!, idx[e.target]!]).toList();
}

/// Rough analogue of `JSON.stringify(graph).length` for the "compact" checks
/// — exact byte parity with the TS fixture isn't the point, only that the
/// loadout is dramatically smaller than a naive full-fidelity dump.
int _naiveJsonLength(StarmapGraph g) {
  final map = {
    'nodes': [
      for (final n in g.nodes)
        {
          'id': n.id,
          'label': n.label,
          'kind': n.kind,
          'category': n.category,
          'timestamp': n.timestamp,
          'useCount': n.useCount,
          'state': n.state,
          'createdBy': n.createdBy,
          'pinned': n.pinned,
          'memorySource': n.memorySource,
        },
    ],
    'edges': [
      for (final e in g.edges) {'source': e.source, 'target': e.target},
    ],
    'memory': [
      for (final m in g.memory)
        {
          'source': m.source,
          'timestamp': m.timestamp,
          'title': m.title,
          'body': m.body,
        },
    ],
  };
  return jsonEncode(map).length;
}

void main() {
  group('starmap share code', () {
    test('preserves the visualization', () {
      final g = _sampleGraph();
      final decoded = decodeStarmapShareCode(encodeStarmapShareCode(g));
      const span = 1700000000 - 1699900000;
      final tol = (span / 4095).ceil() + 1;

      expect(decoded.nodes, hasLength(g.nodes.length));

      for (var i = 0; i < decoded.nodes.length; i++) {
        final d = decoded.nodes[i];
        final o = g.nodes[i];
        expect(d.kind, o.kind);
        expect(d.label, o.label);
        expect(d.useCount, o.useCount);
        expect(d.state, o.state);
        expect(d.pinned, o.pinned);
        expect(d.category, o.category);
        expect(d.memorySource, o.memorySource);
        expect(d.createdBy, o.createdBy);

        if (o.timestamp == null) {
          expect(d.timestamp, isNull);
        } else {
          expect((d.timestamp! - o.timestamp!).abs(), lessThanOrEqualTo(tol));
        }
      }

      expect(_topology(decoded), _topology(g));
    });

    test('drops memory prose (loadout is viz-only)', () {
      expect(
        decodeStarmapShareCode(encodeStarmapShareCode(_sampleGraph())).memory,
        isEmpty,
      );
    });

    test('rebuilds clusters from node categories', () {
      final decoded = decodeStarmapShareCode(encodeStarmapShareCode(_sampleGraph()));
      final devops = decoded.clusters.firstWhere((c) => c['category'] == 'devops');
      expect(devops['count'], 2);
    });

    test('produces a short, opaque, prefixed code', () {
      final code = encodeStarmapShareCode(_sampleGraph());
      expect(code.startsWith('HML'), isTrue);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code.substring(3)), isTrue);
      // Strictly smaller than a naive full-fidelity JSON dump of the same
      // graph (which also carries memory prose the loadout drops).
      expect(code.length, lessThan(_naiveJsonLength(_sampleGraph())));
    });

    test('stays compact on a large graph (no string bloat)', () {
      final nodes = List.generate(
        500,
        (i) => StarmapNode(
          category: 'cat-${i % 8}',
          createdBy: 'agent',
          id: 's$i',
          kind: 'skill',
          label: 'A fairly verbose skill label number $i',
          pinned: false,
          state: 'active',
          timestamp: 1700000000 + i * 3600,
          useCount: i % 50,
        ),
      );
      final graph = StarmapGraph(nodes: nodes);
      final code = encodeStarmapShareCode(graph);
      expect(code.length, lessThan(_naiveJsonLength(graph) ~/ 5));
    });

    test('handles an empty graph', () {
      final decoded = decodeStarmapShareCode(encodeStarmapShareCode(StarmapGraph()));
      expect(decoded.nodes, isEmpty);
      expect(decoded.edges, isEmpty);
    });

    test('drops edges whose endpoints are missing', () {
      final g = _sampleGraph();
      final withBadEdge = StarmapGraph(
        nodes: g.nodes,
        edges: [...g.edges, StarmapEdge(source: 'skill-a', target: 'does-not-exist')],
        clusters: g.clusters,
        memory: g.memory,
        stats: g.stats,
      );
      expect(
        decodeStarmapShareCode(encodeStarmapShareCode(withBadEdge)).edges,
        hasLength(2),
      );
    });

    test('rejects garbage with a ShareCodeError', () {
      expect(
        () => decodeStarmapShareCode('not a real code !!!'),
        throwsA(isA<ShareCodeError>()),
      );
      expect(() => decodeStarmapShareCode(''), throwsA(isA<ShareCodeError>()));
    });

    test('rejects a corrupted (bit-flipped) code', () {
      final code = encodeStarmapShareCode(_sampleGraph());
      final i = code.length ~/ 2;
      final flipped = code[i] == 'A' ? 'B' : 'A';
      final corrupted = code.substring(0, i) + flipped + code.substring(i + 1);
      expect(() => decodeStarmapShareCode(corrupted), throwsA(isA<ShareCodeError>()));
    });

    test('tolerates whitespace, including internal wraps', () {
      final code = encodeStarmapShareCode(_sampleGraph());
      final wrapped = '  ${code.substring(0, 20)}\n${code.substring(20)}\t';
      final decoded = decodeStarmapShareCode(wrapped);
      expect(decoded.nodes, hasLength(_sampleGraph().nodes.length));
    });
  });
}
