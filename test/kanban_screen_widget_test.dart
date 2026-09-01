import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/kanban/models.dart';
import 'package:hermes_mobile/kanban/store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/kanban_canonical_screen.dart';
import 'package:provider/provider.dart';

void main() {
  for (final width in [320.0, 900.0]) {
    testWidgets('kanban renders at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = KanbanStore(KanbanApi(_NoopClient()))
        ..boardData = KanbanBoard.fromJson({
          'columns': [
            {
              'name': 'todo',
              'tasks': [
                {'id': '1', 'title': 'Task one', 'status': 'todo'},
              ],
            },
          ],
        });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(home: KanbanCanonicalScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('看板'), findsOneWidget);
      expect(find.text('Task one'), findsOneWidget);
      expect(tester.takeException(), isNull);
      store.dispose();
    });
  }

  testWidgets('project scope never displays an unrelated board', (
    tester,
  ) async {
    final store = KanbanStore(KanbanApi(_ProjectClient()))
      ..boardData = KanbanBoard.fromJson({
        'columns': [
          {
            'name': 'todo',
            'tasks': [
              {'id': 'other', 'title': 'Unrelated task', 'status': 'todo'},
            ],
          },
        ],
      });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(
          home: KanbanCanonicalScreen(initialProjectId: 'project-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('此项目没有关联看板'), findsWidgets);
    expect(find.text('Unrelated task'), findsNothing);
    store.dispose();
  });

  testWidgets(
    'project board load failure is retryable and not an empty result',
    (tester) async {
      final client = _FailingProjectClient();
      final store = KanbanStore(KanbanApi(client))
        ..boardData = KanbanBoard.fromJson({
          'columns': [
            {
              'name': 'todo',
              'tasks': [
                {'id': 'other', 'title': 'Unrelated task', 'status': 'todo'},
              ],
            },
          ],
        });
      addTearDown(store.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(
            home: KanbanCanonicalScreen(initialProjectId: 'project-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('此项目没有关联看板'), findsNothing);
      expect(find.text('Unrelated task'), findsNothing);
      expect(client.calls, 1);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(client.calls, 2);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    },
  );

  testWidgets('kanban supports Arabic RTL at 320px and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final store = KanbanStore(KanbanApi(_NoopClient()))
      ..boardData = KanbanBoard.fromJson({
        'columns': [
          {
            'name': 'todo',
            'tasks': [
              {'id': '1', 'title': 'مهمة طويلة للاختبار', 'status': 'todo'},
            ],
          },
        ],
      });
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const KanbanCanonicalScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
    semantics.dispose();
  });
}

class _NoopClient extends ApiClient {
  _NoopClient() : super(baseUrl: 'http://invalid', apiKey: 'key');
}

class _ProjectClient extends _NoopClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (path == '/api/v1/kanban/boards') {
      return {
        'current': 'other',
        'boards': [
          {'slug': 'other', 'name': 'Other', 'project_id': 'project-2'},
        ],
      };
    }
    return <String, dynamic>{};
  }
}

class _FailingProjectClient extends _NoopClient {
  int calls = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (path == '/api/v1/kanban/boards') {
      calls++;
      throw StateError('offline');
    }
    return <String, dynamic>{};
  }
}
