import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/kanban/models.dart';
import 'package:hermes_mobile/kanban/store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/widgets/kanban_new_task_sheet.dart';

void main() {
  final zh = AppLocalizationsZh();

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
    await tester.enterText(
      find.widgetWithText(TextField, zh.commonTitle),
      'One task only',
    );
    await tester.enterText(
      find.widgetWithText(TextField, zh.kanbanParentTaskId),
      'parent-1',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final submit = find.text(zh.kanbanCreateTask, skipOffstage: false);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(client.createCalls, 1);
    expect(client.linkCalls, 1);
    expect(
      find.textContaining(zh.kanbanTaskCreatedLinkFailed('')),
      findsOneWidget,
    );
    expect(find.text(zh.kanbanCreateTask), findsNothing);
  });
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
