/// Star-map share code — a direct port of hermes-agent desktop's
/// `app/starmap/share-code.ts`, riding [Loadout] (the generic bit-packed
/// codec in `starmap_loadout.dart`, itself a port of `lib/loadout.ts`). A
/// code produced here decodes on desktop and vice versa: same field order,
/// same enum tables, same bit widths.
///
/// We encode what the map RENDERS — each node's kind, its time POSITION
/// (12-bit quantized, not an absolute epoch), radius inputs
/// (useCount/state/pinned), and an interned label + category — plus edges as
/// fixed-width node indices. Memory prose is dropped; labels are trimmed.
library;

import 'models.dart';
import 'starmap_loadout.dart';

const _version = 3;
const _prefix = 'HML'; // "Hermes Memory Loadout"
const _maxLabel = 64;

String _trim(String s) => s.length > _maxLabel ? s.substring(0, _maxLabel) : s;

const _kinds = ['skill', 'memory'];
const _states = ['active', 'archived', 'disabled', 'draft'];
const _memSources = ['none', 'memory', 'profile'];
const _createdBy = ['none', 'agent', 'user'];

const _recBits = 12; // time position resolution: 1/4096 of the span.
const _recMax = (1 << _recBits) - 1;

int? _finiteTs(int? v) => v == null ? null : (v < 0 ? 0 : v);

void _writeNode(BitWriter w, StarmapNode n, Dict dict, int minTs, int span) {
  w.uint(idxOf(_kinds, n.kind), 1);
  w.varint(dict.id(_trim(n.label)));
  w.varint(dict.id(n.category));
  w.varint(n.useCount < 0 ? 0 : n.useCount);
  w.uint(idxOf(_states, n.state), 2);
  w.uint(idxOf(_memSources, n.memorySource ?? 'none'), 2);
  w.uint(idxOf(_createdBy, n.createdBy ?? 'none'), 2);
  w.bit(n.pinned);

  final ts = _finiteTs(n.timestamp);
  if (ts == null) {
    w.bit(false);
  } else {
    w.bit(true);
    w.uint(span > 0 ? (((ts - minTs) / span) * _recMax).round() : 0, _recBits);
  }
}

StarmapNode _readNode(
  BitReader r,
  List<String> dict,
  int i,
  int minTs,
  int span,
) {
  final kind = _kinds[r.uint(1)];
  final label = dict[r.varint()];
  final category = dict[r.varint()];
  final useCount = r.varint();
  final state = _states[r.uint(2)];
  final memSrc = _memSources[r.uint(2)];
  final createdBy = _createdBy[r.uint(2)];
  final pinned = r.bit() == 1;
  final timestamp = r.bit() == 1
      ? minTs + (span > 0 ? ((r.uint(_recBits) / _recMax) * span).round() : 0)
      : null;

  final isMemory = kind == 'memory';
  final source = memSrc == 'none' ? 'memory' : memSrc;

  return StarmapNode(
    id: isMemory ? 'memory:$source:$i' : 's$i',
    label: label,
    kind: kind,
    category: category,
    useCount: useCount,
    state: state,
    createdBy: createdBy == 'none' ? null : createdBy,
    pinned: pinned,
    timestamp: timestamp,
    memorySource: isMemory ? source : null,
  );
}

void _writeGraph(BitWriter w, StarmapGraph graph) {
  final dict = Dict();
  for (final n in graph.nodes) {
    dict.id(_trim(n.label));
    dict.id(n.category);
  }

  final stamps = graph.nodes
      .map((n) => _finiteTs(n.timestamp))
      .whereType<int>()
      .toList();
  final minTs = stamps.isEmpty ? 0 : stamps.reduce((a, b) => a < b ? a : b);
  final maxTs = stamps.isEmpty ? 0 : stamps.reduce((a, b) => a > b ? a : b);
  final span = maxTs - minTs;

  w.varint(minTs);
  w.varint(maxTs);
  w.varint(dict.list.length);
  for (final s in dict.list) {
    w.str(s);
  }

  w.varint(graph.nodes.length);
  for (final n in graph.nodes) {
    _writeNode(w, n, dict, minTs, span);
  }

  final order = {
    for (var i = 0; i < graph.nodes.length; i++) graph.nodes[i].id: i,
  };
  final edges = graph.edges
      .where((e) => order.containsKey(e.source) && order.containsKey(e.target))
      .toList();
  final bits = indexBits(graph.nodes.length);
  w.varint(edges.length);
  for (final e in edges) {
    w.uint(order[e.source]!, bits);
    w.uint(order[e.target]!, bits);
  }
}

StarmapGraph _readGraph(BitReader r) {
  final minTs = r.varint();
  final maxTs = r.varint();
  final span = maxTs - minTs;

  final dictLen = r.varint();
  final dict = <String>[];
  for (var i = 0; i < dictLen; i++) {
    dict.add(r.str());
  }

  final nodeCount = r.varint();
  final nodes = <StarmapNode>[];
  for (var i = 0; i < nodeCount; i++) {
    nodes.add(_readNode(r, dict, i, minTs, span));
  }

  final bits = indexBits(nodeCount);
  final edgeCount = r.varint();
  final edges = <StarmapEdge>[];
  for (var i = 0; i < edgeCount; i++) {
    final src = nodes[r.uint(bits)];
    final dst = nodes[r.uint(bits)];
    edges.add(StarmapEdge(source: src.id, target: dst.id));
  }

  final counts = <String, int>{};
  for (final n in nodes) {
    counts[n.category] = (counts[n.category] ?? 0) + 1;
  }
  final clusters =
      counts.entries.map((e) => {'category': e.key, 'count': e.value}).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

  // Memory cards are dropped (viz-only); `imported: true` lets the UI tell a
  // decoded map apart from a freshly-scanned one.
  return StarmapGraph(
    nodes: nodes,
    edges: edges,
    clusters: clusters,
    memory: const [],
    stats: const {'imported': true},
  );
}

class ShareCodeError extends LoadoutError {
  const ShareCodeError(super.message);
}

final _codec = Loadout<StarmapGraph>(
  prefix: _prefix,
  version: _version,
  write: _writeGraph,
  read: _readGraph,
  noun: 'map code',
  errorFactory: ShareCodeError.new,
);

/// Serialize a star-map graph to a short, opaque, clipboard-safe loadout
/// string.
String encodeStarmapShareCode(StarmapGraph graph) => _codec.encode(graph);

/// Parse a loadout string back into a (viz-complete, text-synthesized) graph.
StarmapGraph decodeStarmapShareCode(String code) => _codec.decode(code);
