import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/screens/project_screen.dart';
import 'package:provider/provider.dart';

/// Desktop's project sidebar has a right-click/kebab menu for renaming,
/// re-coloring/re-iconing (projects.update's real `color`/`icon` fields),
/// and deleting a project — mobile's project list previously only supported
/// create + open, with color purely a client-side hash so it could never be
/// customized or persisted.
class _Gateway extends GatewayClient {
  _Gateway() : super(serverBaseUrl: 'http://project.invalid', apiKey: 'x');

  List<Map<String, dynamic>> projects = [
    {'id': 'p1', 'name': 'Alpha', 'session_count': 3},
  ];
  final List<Map<String, dynamic>> updateCalls = [];
  final List<String> deleteCalls = [];

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    switch (method) {
      case 'projects.list':
        return {'projects': projects, 'active_id': null};
      case 'projects.update':
        updateCalls.add(params);
        final id = params['id'];
        projects = [
          for (final p in projects)
            if (p['id'] == id)
              {
                ...p,
                if (params.containsKey('name') && params['name'] != null)
                  'name': params['name'],
                if (params.containsKey('color')) 'color': params['color'],
                if (params.containsKey('icon')) 'icon': params['icon'],
              }
            else
              p,
        ];
        return {'project': projects.firstWhere((p) => p['id'] == id)};
      case 'projects.delete':
        deleteCalls.add(params['id']?.toString() ?? '');
        projects = projects.where((p) => p['id'] != params['id']).toList();
        return {'projects': projects, 'active_id': null};
      default:
        return {};
    }
  }
}

class _Connection extends ConnectionStore {
  _Connection(GatewayClient client) {
    gateway = client;
  }

  @override
  Future<void> ensureConnected() async {}

  void exposeGateway(GatewayClient? value) {
    gateway = value;
    notifyListeners();
  }
}

class _DelayedGateway extends _Gateway {
  final listResponse = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    if (method == 'projects.list') return listResponse.future;
    return super.request(method, params, timeout: timeout);
  }
}

Future<_Gateway> _pump(WidgetTester tester) async {
  final gateway = _Gateway();
  final connection = _Connection(gateway);
  addTearDown(connection.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ConnectionStore>.value(
      value: connection,
      child: const MaterialApp(home: ProjectScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return gateway;
}

void main() {
  testWidgets('offline projects show a retryable disconnected state', (
    tester,
  ) async {
    final connection = ConnectionStore();
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: const MaterialApp(home: ProjectScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsZh().backendDisconnected), findsOneWidget);
    expect(find.textContaining('Null check operator'), findsNothing);
  });

  testWidgets(
    'renaming a project calls projects.update and refreshes the list',
    (tester) async {
      final gateway = await _pump(tester);
      expect(find.text('Alpha'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '项目名称'), 'Beta');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(gateway.updateCalls.single, containsPair('name', 'Beta'));
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
    },
  );

  testWidgets('an old gateway list cannot overwrite a new connection', (
    tester,
  ) async {
    final oldGateway = _DelayedGateway()
      ..projects = [
        {'id': 'old', 'name': 'Old project'},
      ];
    final newGateway = _Gateway()
      ..projects = [
        {'id': 'new', 'name': 'New project'},
      ];
    final connection = _Connection(oldGateway);
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: const MaterialApp(home: ProjectScreen()),
      ),
    );
    await tester.pump();

    connection.exposeGateway(newGateway);
    await tester.pumpAndSettle();
    expect(find.text('New project'), findsOneWidget);

    oldGateway.listResponse.complete({'projects': oldGateway.projects});
    await tester.pumpAndSettle();
    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Old project'), findsNothing);
  });

  testWidgets('picking a color and icon persists via projects.update', (
    tester,
  ) async {
    final gateway = await _pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑外观'));
    await tester.pumpAndSettle();

    expect(find.text('颜色'), findsOneWidget);
    expect(find.text('图标'), findsOneWidget);

    // The rocket icon and the first real (non-"clear") color swatch.
    await tester.tap(find.byIcon(Icons.rocket_launch_outlined));
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w is InkWell &&
                w.key is ValueKey &&
                (w.key! as ValueKey).value.toString().startsWith(
                  'project-appearance-swatch-#',
                ),
          )
          .first,
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(gateway.updateCalls.single['icon'], 'rocket');
    expect(gateway.updateCalls.single['color'], isNotNull);
    expect(
      (gateway.updateCalls.single['color'] as String).startsWith('#'),
      isTrue,
    );
  });

  testWidgets('deleting a project confirms, then calls projects.delete', (
    tester,
  ) async {
    final gateway = await _pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除 Alpha？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(gateway.deleteCalls, ['p1']);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets(
    'a project with a persisted color/icon renders them instead of the hash fallback',
    (tester) async {
      final gateway = _Gateway()
        ..projects = [
          {'id': 'p1', 'name': 'Alpha', 'color': '#3366ff', 'icon': 'rocket'},
        ];
      final connection = _Connection(gateway);
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionStore>.value(
          value: connection,
          child: const MaterialApp(home: ProjectScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.rocket_launch_outlined),
      );
      expect(icon.color, const Color(0xFF3366FF));
    },
  );
}
