import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/kanban/store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/files_screen.dart';
import 'package:hermes_mobile/screens/kanban_canonical_screen.dart';
import 'package:hermes_mobile/screens/project_detail_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('project module routes preserve project scope', (tester) async {
    final connection = ConnectionStore();
    final session = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    final kanban = KanbanStore();
    addTearDown(() {
      session.dispose();
      connection.dispose();
      kanban.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<SessionStore>.value(value: session),
          ChangeNotifierProvider<KanbanStore>.value(value: kanban),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProjectDetailScreen(
            project: {
              'id': 'project-1',
              'name': 'Mobile',
              'primary_path': '/repo/project',
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Project details'), findsOneWidget);
    expect(find.text('项目详情'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('project-files-panel')),
    );
    await tester.tap(find.byKey(const ValueKey('project-files-panel')));
    await tester.pumpAndSettle();
    final files = tester.widget<FilesScreen>(find.byType(FilesScreen));
    expect(files.initialPath, '/repo/project');

    Navigator.of(tester.element(find.byType(FilesScreen))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('project-tasks-panel')),
    );
    await tester.tap(find.byKey(const ValueKey('project-tasks-panel')));
    await tester.pumpAndSettle();
    final tasks = tester.widget<KanbanCanonicalScreen>(
      find.byType(KanbanCanonicalScreen),
    );
    expect(tasks.initialProjectId, 'project-1');
  });
}
