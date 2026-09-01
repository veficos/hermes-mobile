import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Regression coverage: `knowledgeGraph`/`starmapGraph` and
/// `knowledgeNode`/`starmapNode` used to independently call
/// `/api/v1/starmap/{graph,node}` — genuinely the SAME endpoint reached
/// through two parallel client methods, not two backend families. Now
/// `starmap*` delegates to `knowledge*` so there is one call site.
///
/// (`starmap_screen.dart`'s node-save error-handling fix — no longer
/// swallowing a rejected `knowledgeNodeUpdate` behind a bare `try {} catch
/// (_) {}` — isn't covered here: driving a tap through its hand-rolled
/// CustomPaint canvas from a widget test is unreliable (the outer pan/zoom
/// GestureDetector wins the gesture arena over the node's tap in this
/// harness), so that fix is verified by inspection instead.)
void main() {
  test('starmapGraph delegates to the same /starmap/graph request knowledgeGraph makes', () async {
    var requestCount = 0;
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        requestCount++;
        request = incoming;
        return http.Response(
          jsonEncode({
            'nodes': [
              {'id': 'n1', 'label': 'Node 1'},
            ],
            'edges': <Map<String, dynamic>>[],
          }),
          200,
        );
      }),
    );
    final graph = await api.starmapGraph();
    expect(requestCount, 1);
    expect(request.url.path, '/api/v1/starmap/graph');
    expect(graph.nodes.single.id, 'n1');
  });

  test('starmapNode delegates to the same /starmap/node request knowledgeNode makes', () async {
    late http.Request request;
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      apiKey: 'key',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(jsonEncode({'id': 'n1', 'content': 'hi'}), 200);
      }),
    );
    final detail = await api.starmapNode('n1');
    expect(request.url.path, '/api/v1/starmap/node');
    expect(request.url.queryParameters['id'], 'n1');
    expect(detail['content'], 'hi');
  });
}
