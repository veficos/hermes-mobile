import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/kanban/models.dart';
import 'package:hermes_mobile/kanban/store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/kanban_canonical_screen.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'support/review_capture.dart';

class _MoveApi extends KanbanApi {
  _MoveApi()
    : super(
        ApiClient(baseUrl: 'http://invalid', apiKey: 'test'),
        boardSlug: 'original',
      );
  final pending = Completer<dynamic>();
  final calls = <(List<String>, Map<String, dynamic>)>[];
  final data = KanbanBoard.fromJson({
    'columns': [
      {
        'name': 'todo',
        'tasks': [
          {'id': '1', 'title': 'Move this task', 'status': 'todo'},
        ],
      },
      {'name': 'done', 'tasks': []},
      {'name': '等待设计与无障碍体验联合验收', 'tasks': []},
    ],
  });
  @override
  Future<KanbanBoard> board({bool archived = false}) async => data;
  @override
  Future<dynamic> bulk(List<String> ids, Map<String, dynamic> patch) {
    calls.add((List.of(ids), Map.of(patch)));
    return pending.future;
  }
}

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final brightness in Brightness.values) {
      for (final scenario in [
        'success',
        'failure',
        'board',
        'disconnect',
        'custom',
        'opaque-keyboard',
      ]) {
        testWidgets('bulk move $scenario $brightness $style at 320px 2x', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final api = _MoveApi();
          final store = KanbanStore(api)..boardData = api.data;
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: store,
              child: MaterialApp(
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: buildHermesTheme(
                  brightness: brightness,
                  visualStyle: style,
                  reduceTransparency: scenario == 'opaque-keyboard',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: RepaintBoundary(
                    key: const ValueKey('task-move-review'),
                    child: child!,
                  ),
                ),
                home: const KanbanCanonicalScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.longPress(find.text('Move this task'));
          await tester.pumpAndSettle();
          Future<void> capture(String state) async {
            const directory = String.fromEnvironment('UI_REVIEW_DIR');
            if (directory.isEmpty || scenario != 'failure') return;
            await captureReview(
              tester,
              find.byKey(const ValueKey('task-move-review')),
              '$directory/tasks-bulk-${style.name}-${brightness.name}-2.0-$state.png',
            );
          }

          final move = find.widgetWithIcon(IconButton, Icons.drive_file_move);
          expect(move.hitTestable(), findsOneWidget);
          await capture('selected');
          await tester.tap(move);
          await tester.pumpAndSettle();
          expect(tester.widget<IconButton>(move).onPressed, isNull);
          final status = scenario == 'custom' ? '等待设计与无障碍体验联合验收' : 'done';
          final target = find.byKey(ValueKey('task-move-target-$status'));
          final l10n = AppLocalizations.of(tester.element(target));
          expect(find.byKey(const ValueKey('task-move-title')), findsOneWidget);
          expect(
            find.descendant(
              of: target,
              matching: find.text(
                scenario == 'custom' ? status : l10n.taskStatusDone,
              ),
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          if (scenario == 'opaque-keyboard') {
            expect(find.byType(BackdropFilter), findsNothing);
          }
          await capture('destination');
          expect(
            find.byKey(const ValueKey('task-bulk-processing')),
            findsNothing,
          );
          if (scenario == 'board') api.boardSlug = 'other';
          if (scenario == 'disconnect') store.bindApi(null);
          if (scenario == 'opaque-keyboard') {
            Focus.of(
              tester.element(
                find.descendant(
                  of: target,
                  matching: find.text(l10n.taskStatusDone),
                ),
              ),
            ).requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            await tester.tap(target);
          }
          await tester.pumpAndSettle();
          if (scenario == 'board' || scenario == 'disconnect') {
            expect(api.calls, isEmpty);
          } else {
            expect(api.calls, hasLength(1));
            expect(api.calls.single.$1, ['1']);
            expect(api.calls.single.$2, {'status': status});
            expect(tester.widget<IconButton>(move).onPressed, isNull);
            final processing = find.byKey(
              const ValueKey('task-bulk-processing'),
            );
            expect(processing, findsOneWidget);
            expect(tester.getRect(processing).bottom, lessThanOrEqualTo(844));
            final clear = find.widgetWithIcon(IconButton, Icons.close);
            expect(tester.widget<IconButton>(clear).onPressed, isNull);
            await capture('pending');
            api.pending.complete({
              'failed': scenario == 'failure' ? ['1'] : [],
            });
            await tester.pumpAndSettle();
            expect(processing, findsNothing);
            expect(store.selectedIds, scenario == 'failure' ? {'1'} : isEmpty);
            if (scenario == 'failure') {
              expect(tester.widget<IconButton>(move).onPressed, isNotNull);
              expect(tester.widget<IconButton>(clear).onPressed, isNotNull);
              await capture('failed');
            } else {
              expect(
                find.byKey(const ValueKey('task-bulk-glass')),
                findsNothing,
              );
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          store.dispose();
        });
      }
    }
  }
}
