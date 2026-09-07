import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/pane_tree.dart';
import 'package:hermes_mobile/core/plugin_contributions.dart';
import 'package:hermes_mobile/core/stores/pane_workspace_store.dart';
import 'package:hermes_mobile/core/stores/plugin_contribution_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('workspace persists session and plugin panes with layout', () async {
    const owner = OwnerRoute(
      connectionId: ConnectionId('ssh:build'),
      profile: 'work',
    );
    final store = PaneWorkspaceStore();
    await store.load();
    final sessionId = await store.openSession(
      durableId: 'session/one',
      title: 'Build release',
      owner: owner,
    );
    final plugin = MobilePluginContribution(
      id: 'board',
      pluginId: 'kanban',
      area: MobileContributionArea.pane,
      title: 'Board',
      owner: owner,
      view: const MobilePluginView(type: MobileContributionViewType.list),
    );
    final pluginId = await store.openPlugin(plugin);
    await store.flush();

    expect(store.tree, isA<PaneSplit>());
    expect(store.focusedPaneId, pluginId);
    expect(store.panes[sessionId]!.referenceId, 'session/one');

    final restored = PaneWorkspaceStore();
    await restored.load();
    expect(restored.orderedPanes.map((pane) => pane.referenceId), [
      'session/one',
      'kanban:board',
    ]);
    expect(restored.panes[sessionId]!.owner, owner);
    expect(restored.focusedPaneId, pluginId);

    restored.close(pluginId);
    await restored.flush();
    expect(restored.tree, isA<PaneGroup>());
    expect(restored.focusedPaneId, sessionId);
  });

  test(
    'workspace deduplicates a reopened pane and enforces its bound',
    () async {
      const owner = OwnerRoute(connectionId: ConnectionId('primary'));
      final store = PaneWorkspaceStore();
      await store.load();
      final first = await store.openSession(
        durableId: 'same',
        title: 'First title',
        owner: owner,
      );
      final second = await store.openSession(
        durableId: 'same',
        title: 'Updated title',
        owner: owner,
      );
      expect(first, second);
      expect(store.panes.length, 1);
      expect(store.panes[first]!.title, 'Updated title');

      for (var index = 1; index < PaneWorkspaceStore.maxPanes; index++) {
        await store.openSession(
          durableId: 'session-$index',
          title: 'Session $index',
          owner: owner,
          position: PaneDropPosition.center,
        );
      }
      await expectLater(
        store.openSession(
          durableId: 'overflow',
          title: 'Overflow',
          owner: owner,
        ),
        throwsStateError,
      );
    },
  );

  test('core panes persist with their route and reference', () async {
    const owner = OwnerRoute(
      connectionId: ConnectionId('cloud:team'),
      profile: 'reviewer',
    );
    final store = PaneWorkspaceStore();
    await store.load();
    final filesId = await store.openCorePane(
      kind: WorkspacePaneKind.files,
      title: 'Files',
      referenceId: '/workspace/hermes',
      owner: owner,
    );
    final logsId = await store.openCorePane(
      kind: WorkspacePaneKind.logs,
      title: 'Logs',
      owner: owner,
      position: PaneDropPosition.bottom,
    );
    await store.flush();

    final restored = PaneWorkspaceStore();
    await restored.load();
    expect(restored.panes[filesId]!.kind, WorkspacePaneKind.files);
    expect(restored.panes[filesId]!.referenceId, '/workspace/hermes');
    expect(restored.panes[filesId]!.owner, owner);
    expect(restored.panes[logsId]!.kind, WorkspacePaneKind.logs);
  });

  test('file preview metadata survives workspace restoration', () async {
    const owner = OwnerRoute(connectionId: ConnectionId('primary'));
    final store = PaneWorkspaceStore();
    await store.load();
    final id = await store.openCorePane(
      kind: WorkspacePaneKind.preview,
      title: 'README',
      referenceId: '/workspace/README.md',
      repositoryRoot: '/workspace',
      byteSize: 4096,
      mimeType: 'text/markdown',
      owner: owner,
    );
    await store.flush();

    final restored = PaneWorkspaceStore();
    await restored.load();
    final pane = restored.panes[id]!;
    expect(pane.repositoryRoot, '/workspace');
    expect(pane.byteSize, 4096);
    expect(pane.mimeType, 'text/markdown');
  });

  test(
    'oversized or negative pane metadata is dropped, not the whole pane',
    () async {
      const owner = OwnerRoute(connectionId: ConnectionId('primary'));
      final oversizedMimeType = 'x' * 257;
      final validJson = {
        'id': 'preview-1',
        'kind': WorkspacePaneKind.preview.name,
        'reference_id': '/workspace/README.md',
        'title': 'README',
        'connection_id': owner.connectionId.value,
        'repository_root': '/workspace',
        'byte_size': 4096,
        'mime_type': 'text/markdown',
      };

      final withBadMimeType = Map<String, Object?>.of(validJson)
        ..['mime_type'] = oversizedMimeType;
      final paneWithBadMimeType = WorkspacePane.fromJson(withBadMimeType);
      expect(paneWithBadMimeType, isNotNull);
      expect(paneWithBadMimeType!.mimeType, isNull);
      expect(paneWithBadMimeType.repositoryRoot, '/workspace');
      expect(paneWithBadMimeType.byteSize, 4096);

      final withNegativeByteSize = Map<String, Object?>.of(validJson)
        ..['byte_size'] = -1;
      final paneWithNegativeByteSize = WorkspacePane.fromJson(
        withNegativeByteSize,
      );
      expect(paneWithNegativeByteSize, isNotNull);
      expect(paneWithNegativeByteSize!.byteSize, isNull);
      expect(paneWithNegativeByteSize.mimeType, 'text/markdown');
      expect(paneWithNegativeByteSize.repositoryRoot, '/workspace');

      final withBadRepositoryRoot = Map<String, Object?>.of(validJson)
        ..['repository_root'] = 'x' * 4097;
      final paneWithBadRepositoryRoot = WorkspacePane.fromJson(
        withBadRepositoryRoot,
      );
      expect(paneWithBadRepositoryRoot, isNotNull);
      expect(paneWithBadRepositoryRoot!.repositoryRoot, isNull);
      expect(paneWithBadRepositoryRoot.byteSize, 4096);
      expect(paneWithBadRepositoryRoot.mimeType, 'text/markdown');
    },
  );

  test('all layout presets preserve each pane exactly once', () async {
    const owner = OwnerRoute(connectionId: ConnectionId('primary'));
    final store = PaneWorkspaceStore();
    await store.load();
    await store.openSession(durableId: 'one', title: 'One', owner: owner);
    for (final kind in const [
      WorkspacePaneKind.files,
      WorkspacePaneKind.review,
      WorkspacePaneKind.terminal,
      WorkspacePaneKind.logs,
      WorkspacePaneKind.preview,
    ]) {
      await store.openCorePane(kind: kind, title: kind.name, owner: owner);
    }
    final expected = store.panes.keys.toSet();

    for (final preset in WorkspaceLayoutPreset.values) {
      store.applyLayoutPreset(preset);
      final ids = paneIds(store.tree);
      expect(ids.toSet(), expected, reason: preset.name);
      expect(ids.length, expected.length, reason: preset.name);
    }
    expect(store.tree, isA<PaneSplit>());
  });

  test('touch tab management renames and closes every sibling', () async {
    const owner = OwnerRoute(connectionId: ConnectionId('primary'));
    final store = PaneWorkspaceStore();
    await store.load();
    final keep = await store.openSession(
      durableId: 'keep',
      title: 'Original',
      owner: owner,
    );
    await store.openSession(durableId: 'drop', title: 'Drop', owner: owner);
    await store.openCorePane(
      kind: WorkspacePaneKind.files,
      title: 'Files',
      owner: owner,
    );

    store.rename(keep, 'Renamed');
    store.closeOthers(keep);
    await store.flush();

    expect(store.panes.keys, [keep]);
    expect(store.panes[keep]?.title, 'Renamed');
    expect(paneIds(store.tree), [keep]);
    expect(store.focusedPaneId, keep);
  });

  test('close to right removes later tabs in the same group only', () async {
    const owner = OwnerRoute(connectionId: ConnectionId('primary'));
    final store = PaneWorkspaceStore();
    await store.load();
    final first = await store.openSession(
      durableId: 'first',
      title: 'First',
      owner: owner,
      position: PaneDropPosition.center,
    );
    final keep = await store.openSession(
      durableId: 'keep',
      title: 'Keep',
      owner: owner,
      position: PaneDropPosition.center,
    );
    await store.openSession(
      durableId: 'third',
      title: 'Third',
      owner: owner,
      position: PaneDropPosition.center,
    );

    store.closeToRight(keep);

    expect(store.panes.keys.toSet(), {first, keep});
    expect(paneIds(store.tree), [first, keep]);
  });
}
