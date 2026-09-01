import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/pane_tree.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/pane_workspace_store.dart';
import 'package:hermes_mobile/core/stores/plugin_contribution_store.dart';
import 'package:hermes_mobile/screens/pane_workspace_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({PaneWorkspaceStore workspace, PluginContributionStore plugins})> _pump(
  WidgetTester tester, {
  required Size size,
  int paneCount = 2,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final connection = ConnectionStore();
  final plugins = PluginContributionStore(connection);
  const owner = OwnerRoute(connectionId: ConnectionId('primary'));
  plugins.adaptPluginInventory([
    for (var index = 0; index < paneCount; index++)
      {
        'id': 'plugin-$index',
        'enabled': true,
        'mobile_contributions': [
          {
            'id': 'pane-$index',
            'area': 'pane',
            'title': 'Plugin Pane $index',
            'action': {
              'kind': 'gateway',
              'method': 'demo.run',
              'params': <String, dynamic>{},
            },
          },
        ],
      },
  ], owner: owner);
  final workspace = PaneWorkspaceStore();
  await workspace.load();
  for (final item in plugins.forArea(MobileContributionArea.pane)) {
    await workspace.openPlugin(item);
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connection),
        ChangeNotifierProvider.value(value: plugins),
        ChangeNotifierProvider.value(value: workspace),
      ],
      child: const MaterialApp(home: PaneWorkspaceScreen()),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() {
    workspace.dispose();
    plugins.dispose();
    connection.dispose();
  });
  return (workspace: workspace, plugins: plugins);
}

void main() {
  testWidgets('phone workspace collapses panes into persistent tabs', (
    tester,
  ) async {
    final stores = await _pump(tester, size: const Size(420, 800));
    expect(find.text('Plugin Pane 0'), findsWidgets);
    expect(find.text('Plugin Pane 1'), findsWidgets);
    expect(find.byIcon(Icons.close), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.add_box_outlined));
    await tester.pumpAndSettle();
    expect(find.text('终端'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
    expect(find.text('审查'), findsOneWidget);
    expect(find.text('日志'), findsOneWidget);
    expect(find.text('预览'), findsOneWidget);
    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plugin Pane 0').first);
    await tester.pumpAndSettle();
    expect(stores.workspace.focusedPaneId, contains('plugin-0'));
  });

  testWidgets('wide workspace renders the persisted split tree', (
    tester,
  ) async {
    final stores = await _pump(tester, size: const Size(1200, 800));
    expect(find.text('Plugin Pane 0'), findsWidgets);
    expect(find.text('Plugin Pane 1'), findsWidgets);
    expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.grid_view_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移到下方'));
    await tester.pumpAndSettle();
    expect((stores.workspace.tree as PaneSplit).axis, PaneSplitAxis.vertical);
  });
}
