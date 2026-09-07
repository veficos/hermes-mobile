import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/artifact_registry.dart';

void main() {
  test('identity includes session, kind, language and title', () {
    final registry = ArtifactRegistry();
    final a = registry.upsert(
      sessionId: 's1',
      kind: 'code',
      language: 'dart',
      title: 'Demo',
      content: 'a',
      settled: true,
    );
    final b = registry.upsert(
      sessionId: 's1',
      kind: 'code',
      language: 'dart',
      title: 'Other',
      content: 'a',
      settled: true,
    );
    final c = registry.upsert(
      sessionId: 's2',
      kind: 'code',
      language: 'dart',
      title: 'Demo',
      content: 'a',
      settled: true,
    );
    expect({a.id, b.id, c.id}, hasLength(3));
  });

  test('streaming ticks update one ephemeral slot then settle it', () {
    final registry = ArtifactRegistry();
    registry.upsert(
      sessionId: 's',
      kind: 'html',
      content: '<h1>',
      settled: false,
    );
    registry.upsert(
      sessionId: 's',
      kind: 'html',
      content: '<h1>A',
      settled: false,
    );
    final settled = registry.upsert(
      sessionId: 's',
      kind: 'html',
      content: '<h1>A</h1>',
      settled: true,
    );
    expect(settled.versions, hasLength(1));
    expect(settled.versions.single.ephemeral, isFalse);
    final next = registry.upsert(
      sessionId: 's',
      kind: 'html',
      content: '<h1>B</h1>',
      settled: true,
    );
    expect(next.versions, hasLength(2));
  });
}
