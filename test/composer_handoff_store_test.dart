import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/stores/composer_handoff_store.dart';

void main() {
  test('text handoff remains isolated by owner and retains metadata', () {
    final store = ComposerHandoffStore();
    const owner = OwnerRoute(connectionId: ConnectionId('work'), profile: 'p');
    store.addText(
      const ComposerTextHandoff(
        owner: owner,
        text: '[error] preview failed',
        kind: 'preview_console',
        metadata: {'tab_id': 'preview-1'},
      ),
    );
    expect(
      store.takeTextFor(const OwnerRoute(connectionId: ConnectionId('other'))),
      isEmpty,
    );
    final result = store.takeTextFor(owner);
    expect(result.single.kind, 'preview_console');
    expect(result.single.metadata['tab_id'], 'preview-1');
    expect(store.takeTextFor(owner), isEmpty);
  });

  test('snippet handoffs are consumed only by their exact owner', () {
    final store = ComposerHandoffStore();
    addTearDown(store.dispose);
    const work = OwnerRoute(
      connectionId: ConnectionId('primary'),
      profile: 'work',
    );
    const personal = OwnerRoute(
      connectionId: ConnectionId('primary'),
      profile: 'personal',
    );
    store.addSnippet(
      const ComposerSnippetHandoff(
        owner: work,
        path: '/workspace/a.dart',
        repositoryRoot: '/workspace',
        startLine: 4,
        endLine: 8,
        revision: '12',
        text: 'selected',
      ),
    );

    expect(store.takeFor(personal), isEmpty);
    final result = store.takeFor(work);
    expect(result, hasLength(1));
    expect(result.single.startLine, 4);
    expect(result.single.revision, '12');
    expect(store.takeFor(work), isEmpty);
  });
}
