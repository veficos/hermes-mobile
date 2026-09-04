import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/kanban/models.dart';
import 'package:hermes_mobile/kanban/store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/widgets/kanban_board_sheet.dart';
import 'package:hermes_mobile/widgets/kanban_new_task_sheet.dart';

void main() {
  final zh = AppLocalizationsZh();

  testWidgets('board picker dismisses before the selected board loads', (
    tester,
  ) async {
    final client = _DelayedBoardClient();
    final store = _DelayedKanbanStore(KanbanApi(client));
    addTearDown(() {
      if (!store.boardLoad.isCompleted) store.boardLoad.complete();
      store.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showKanbanBoardSheet(context, store),
              child: const Text('boards'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('boards'));
    await tester.pumpAndSettle();
    expect(find.text('Slow board'), findsOneWidget);

    await tester.tap(find.text('Slow board'));
    await tester.pumpAndSettle();

    expect(store.selectedSlug, 'slow');
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ModalBarrier && widget.color != null,
      ),
      findsNothing,
    );
  });

  testWidgets('parent link failure does not invite duplicate task creation', (
    tester,
  ) async {
    final client = _TaskClient();
    final store = KanbanStore(KanbanApi(client))
      ..boardData = KanbanBoard.fromJson({
        'columns': [
          {'name': 'triage', 'tasks': const []},
        ],
      });
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showKanbanNewTaskSheet(context, store),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('kanban-new-task-screen')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, zh.commonTitle),
      'One task only',
    );
    final advanced = find.byKey(const ValueKey('kanban-new-task-advanced'));
    await tester.scrollUntilVisible(
      advanced,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, zh.kanbanParentTaskId),
      'parent-1',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('kanban-new-task-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(client.createCalls, 1);
    expect(client.linkCalls, 1);
    expect(
      find.textContaining(zh.kanbanTaskCreatedLinkFailed('')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('kanban-new-task-screen')), findsNothing);
  });

  testWidgets('task creation page fits a narrow phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = KanbanStore(KanbanApi(_TaskClient()))
      ..boardData = KanbanBoard.fromJson({
        'columns': [
          {'name': 'triage', 'tasks': const []},
        ],
      });
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showKanbanNewTaskSheet(context, store),
              child: const Text('open narrow'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open narrow'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('kanban-new-task-screen')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.byKey(const ValueKey('kanban-new-task-submit')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('kanban-new-task-submit')));
    await tester.pumpAndSettle();
    expect(find.text(zh.kanbanTaskTitleRequired), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedBoardClient extends ApiClient {
  _DelayedBoardClient()
    : super(baseUrl: 'http://delayed-board.invalid', apiKey: 'test');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (path == '/api/v1/kanban/boards') {
      return {
        'current': 'current',
        'boards': [
          {'slug': 'slow', 'name': 'Slow board', 'total': 0},
        ],
      };
    }
    return <String, dynamic>{};
  }
}

class _DelayedKanbanStore extends KanbanStore {
  _DelayedKanbanStore(super.api);

  final Completer<void> boardLoad = Completer<void>();
  String? selectedSlug;

  @override
  Future<void> selectBoard(String slug, {KanbanApi? expectedApi}) async {
    selectedSlug = slug;
    await boardLoad.future;
  }
}

class _TaskClient extends ApiClient {
  _TaskClient() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int createCalls = 0;
  int linkCalls = 0;

  @override
  Future<dynamic> post(
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
    bool allowExplicitFailure = false,
  }) async {
    if (path == '/api/v1/kanban/tasks') {
      createCalls++;
      return {'id': 'task-1'};
    }
    if (path == '/api/v1/kanban/links') {
      linkCalls++;
      throw StateError('link failed');
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (path == '/api/v1/kanban/board') {
      return {
        'columns': [
          {'name': 'triage', 'tasks': const []},
        ],
      };
    }
    return <String, dynamic>{};
  }
}
