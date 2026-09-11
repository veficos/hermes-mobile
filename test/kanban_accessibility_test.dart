import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/kanban/models.dart';
import 'package:hermes_mobile/kanban/store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/screens/kanban_canonical_screen.dart';
import 'package:hermes_mobile/widgets/h/hermes_segmented_control.dart';
import 'package:provider/provider.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'support/review_capture.dart';

void main() {
  final l10n = AppLocalizationsZh();
  const longTitle = 'Task one · 统一聊天历史分页、审批反馈和液态玻璃界面的无障碍展示';

  Future<void> keyboardActivate(WidgetTester tester, Finder target) async {
    final focus = Focus.of(tester.element(target));
    for (var step = 0; step < 15 && !focus.hasFocus; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(focus.hasFocus, isTrue, reason: 'Tab must reach $target');
    expect(target.hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  KanbanStore buildStore() =>
      KanbanStore(KanbanApi(_NoopClient()))
        ..boardData = KanbanBoard.fromJson({
          'columns': [
            {
              'name': 'todo',
              'tasks': [
                {'id': '1', 'title': 'Task one', 'status': 'todo'},
                {'id': '2', 'title': 'Task two', 'status': 'todo'},
              ],
            },
            {
              'name': 'done',
              'tasks': [
                {'id': '3', 'title': 'Task three', 'status': 'done'},
              ],
            },
          ],
        });

  Future<void> pumpKanban(
    WidgetTester tester,
    KanbanStore store, {
    TextDirection direction = TextDirection.ltr,
  }) {
    return tester.pumpWidget(
      ChangeNotifierProvider<KanbanStore>.value(
        value: store,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              Directionality(textDirection: direction, child: child!),
          home: const KanbanCanonicalScreen(),
        ),
      ),
    );
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'five-column visible range follows actual viewport $direction',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = buildStore();
        addTearDown(store.dispose);
        store.boardData = KanbanBoard.fromJson({
          'columns': [
            for (var i = 0; i < 5; i++)
              {
                'name': 'column-$i',
                'tasks': [
                  {'id': '$i', 'title': 'Task $i', 'status': 'column-$i'},
                ],
              },
          ],
        });
        await pumpKanban(tester, store, direction: direction);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(HermesSegmentedControl<bool>),
            matching: find.text(l10n.taskBoardView),
          ),
        );
        await tester.pumpAndSettle();
        void checkRange() {
          final viewport = tester.getRect(
            find.byKey(const PageStorageKey('task-board-horizontal')),
          );
          final visible = <int>[];
          for (var i = 0; i < 5; i++) {
            final rect = tester.getRect(
              find
                  .ancestor(
                    of: find.byKey(PageStorageKey('task-column-column-$i')),
                    matching: find.byType(Container),
                  )
                  .first,
            );
            if (rect.right > viewport.left && rect.left < viewport.right) {
              visible.add(i + 1);
            }
          }
          expect(visible, isNotEmpty);
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('task-board-visible-columns')),
                )
                .data,
            l10n.taskVisibleColumns(visible.first, visible.last, 5),
          );
        }

        checkRange();
        final bar = tester.widget<Scrollbar>(
          find.byKey(const ValueKey('task-board-scrollbar')),
        );
        for (var i = 0; i < 5; i++) {
          final next = tester.widget<IconButton>(
            find.byKey(const ValueKey('task-board-next')),
          );
          if (next.onPressed == null) break;
          await tester.tap(find.byKey(const ValueKey('task-board-next')));
          await tester.pumpAndSettle();
          checkRange();
        }
        expect(bar.controller!.position.extentAfter, 0);
        tester.view.physicalSize = const Size(1600, 844);
        await tester.pumpAndSettle();
        checkRange();
        expect(find.text(l10n.taskVisibleColumns(1, 5, 5)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final style in HermesVisualStyle.values) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0, 430.0, 768.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '${style.name} task toolbar and search $brightness scale=$scale width=$width',
            (tester) async {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final store = buildStore();
              store.boardData = KanbanBoard.fromJson({
                'assignees': ['reviewer'],
                'tenants': ['workspace'],
                'columns': [
                  {
                    'name': 'todo',
                    'tasks': [
                      {
                        'id': '1',
                        'title': longTitle,
                        'status': 'todo',
                        'assignee': '负责界面与交互验收的协作助手',
                        'priority': 2,
                        'comment_count': 12,
                      },
                      {'id': '2', 'title': '检查深色模式与键盘遮挡', 'status': 'todo'},
                    ],
                  },
                  {
                    'name': 'done',
                    'tasks': [
                      {'id': '3', 'title': '完成审批按钮交互回归', 'status': 'done'},
                    ],
                  },
                ],
              });
              addTearDown(store.dispose);
              await tester.pumpWidget(
                ChangeNotifierProvider<KanbanStore>.value(
                  value: store,
                  child: MaterialApp(
                    locale: const Locale('zh'),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: buildHermesTheme(
                      brightness: brightness,
                      visualStyle: style,
                    ),
                    builder: (context, child) => RepaintBoundary(
                      key: const ValueKey('tasks-overlay-review'),
                      child: MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!,
                      ),
                    ),
                    home: const RepaintBoundary(
                      key: ValueKey('tasks-review'),
                      child: KanbanCanonicalScreen(),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              const reviewDir = String.fromEnvironment('UI_REVIEW_DIR');
              Future<void> captureFilter(String state) async {
                if (reviewDir.isEmpty || style != HermesVisualStyle.liquid) {
                  return;
                }
                await captureReview(
                  tester,
                  find.byKey(const ValueKey('tasks-overlay-review')),
                  '$reviewDir/tasks-filter-$state-${brightness.name}-$scale-${width.toInt()}.png',
                );
              }

              if (reviewDir.isNotEmpty && style == HermesVisualStyle.liquid) {
                await captureReview(
                  tester,
                  find.byKey(const ValueKey('tasks-review')),
                  '$reviewDir/tasks-${brightness.name}-$scale${width == 320 ? '' : '-${width.toInt()}'}.png',
                );
              }
              final toggle = find.byType(HermesSegmentedControl<bool>);
              if (style == HermesVisualStyle.liquid) {
                expect(
                  tester.widget<Text>(find.text(longTitle)).maxLines,
                  isNull,
                );
              }
              await tester.tap(
                find.descendant(
                  of: toggle,
                  matching: find.text(l10n.taskBoardView),
                ),
              );
              await tester.pumpAndSettle();
              expect(find.text(longTitle), findsOneWidget);
              expect(tester.takeException(), isNull);
              if (reviewDir.isNotEmpty && style == HermesVisualStyle.liquid) {
                await captureReview(
                  tester,
                  find.byKey(const ValueKey('tasks-review')),
                  '$reviewDir/tasks-board-${brightness.name}-$scale${width == 320 ? '' : '-${width.toInt()}'}.png',
                );
              }
              await tester.tap(
                find.descendant(
                  of: toggle,
                  matching: find.text(l10n.taskListView),
                ),
              );
              await tester.pumpAndSettle();
              final search = find.byTooltip(l10n.taskSearch);
              if (width == 320 || scale > 1.5) {
                expect(
                  tester.getRect(search).top,
                  greaterThanOrEqualTo(tester.getRect(toggle).bottom),
                );
              }
              await tester.tap(search);
              await tester.pumpAndSettle();
              expect(find.byType(TextField), findsOneWidget);
              await tester.enterText(find.byType(TextField), 'Task one');
              await tester.pumpAndSettle();
              expect(
                store.filteredTasks.every(
                  (task) => task.title.contains('Task one'),
                ),
                isTrue,
              );
              await keyboardActivate(tester, find.byIcon(Icons.tune));
              await keyboardActivate(tester, find.text(l10n.taskFilter));
              await captureFilter('overview');
              final assigneeAction = find.text(
                l10n.taskAssigneeFilter(l10n.taskAll),
              );
              await keyboardActivate(tester, assigneeAction);
              expect(find.text(l10n.kanbanAssignee), findsOneWidget);
              expect(
                tester
                    .widgetList<Semantics>(
                      find.ancestor(
                        of: find.text(l10n.kanbanAssignee),
                        matching: find.byType(Semantics),
                      ),
                    )
                    .any((widget) => widget.properties.header == true),
                isTrue,
              );
              await keyboardActivate(tester, find.text('reviewer'));
              final selectedAssignee = find
                  .text(l10n.taskAssigneeFilter('reviewer'))
                  .hitTestable();
              await keyboardActivate(tester, selectedAssignee);
              expect(find.text('reviewer').hitTestable(), findsOneWidget);
              final reviewerTile = tester.widget<ListTile>(
                find.ancestor(
                  of: find.text('reviewer'),
                  matching: find.byType(ListTile),
                ),
              );
              expect(reviewerTile.selected, style == HermesVisualStyle.liquid);
              if (style == HermesVisualStyle.liquid) {
                expect(reviewerTile.trailing, isA<Icon>());
              }
              await captureFilter('assignee-selected');
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(store.assigneeFilter, 'reviewer');
              expect(store.search, 'Task one');
              expect(find.text('reviewer'), findsNothing);
              expect(selectedAssignee, findsOneWidget);
              expect(
                Focus.of(tester.element(selectedAssignee)).hasFocus,
                isTrue,
              );
              final tenantAction = find.text(
                l10n.taskTenantFilter(l10n.taskAll),
              );
              await keyboardActivate(tester, tenantAction);
              expect(find.text(l10n.kanbanTenant), findsOneWidget);
              await captureFilter('tenant');
              await keyboardActivate(tester, find.text('workspace'));
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(
                find.text(l10n.taskAssigneeFilter('reviewer')),
                findsOneWidget,
              );
              expect(
                find.text(l10n.taskTenantFilter('workspace')),
                findsOneWidget,
              );
              final clear = find.byKey(
                const ValueKey('task-clear-visible-filters'),
              );
              expect(clear.hitTestable(), findsOneWidget);
              await tester.tap(clear);
              await tester.pumpAndSettle();
              expect(store.assigneeFilter, isEmpty);
              expect(store.tenantFilter, isEmpty);
              expect(store.search, 'Task one');
              expect(clear, findsNothing);
              await tester.enterText(find.byType(TextField), 'missing-task');
              await tester.pumpAndSettle();
              expect(find.text(l10n.commonNoMatches), findsOneWidget);
              final reset = find.text(l10n.taskClearFilters);
              await tester.ensureVisible(reset);
              await tester.tap(reset);
              await tester.pumpAndSettle();
              expect(store.search, isEmpty);
              expect(store.filteredTasks, isNotEmpty);
              expect(find.text(l10n.commonNoMatches), findsNothing);
              await tester.tap(find.byType(TextField));
              tester.testTextInput.updateEditingValue(
                const TextEditingValue(
                  text: 'ren',
                  selection: TextSelection.collapsed(offset: 3),
                  composing: TextRange(start: 0, end: 3),
                ),
              );
              await tester.pumpAndSettle();
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(find.byType(TextField), findsOneWidget);
              tester.testTextInput.updateEditingValue(
                const TextEditingValue(
                  text: '任务',
                  selection: TextSelection.collapsed(offset: 2),
                ),
              );
              store.setFilters(assignee: 'reviewer', tenant: 'workspace');
              await tester.pumpAndSettle();
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(find.byType(TextField), findsNothing);
              expect(store.search, isEmpty);
              expect(store.assigneeFilter, 'reviewer');
              expect(store.tenantFilter, 'workspace');
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              await tester.pumpAndSettle();
              expect(find.byType(TextField), findsOneWidget);
              expect(
                tester
                    .widget<EditableText>(find.byType(EditableText))
                    .focusNode
                    .hasFocus,
                isTrue,
              );
              store.setFilters(assignee: '', tenant: '');
              await tester.pumpAndSettle();
              if (style == HermesVisualStyle.classic) {
                expect(tester.takeException(), isNull);
                return;
              }
              await tester.ensureVisible(find.text(longTitle));
              await tester.longPress(find.text(longTitle));
              await tester.pumpAndSettle();
              final bulk = find.byKey(const ValueKey('task-bulk-glass'));
              expect(bulk, findsOneWidget);
              expect(find.text(l10n.taskSelectedCount(1)), findsOneWidget);
              final clearSelection = find.byTooltip(l10n.kanbanClearSelection);
              final move = find.byTooltip(l10n.kanbanMoveSelected);
              expect(clearSelection.hitTestable(), findsOneWidget);
              expect(move.hitTestable(), findsOneWidget);
              expect(
                tester.getSize(clearSelection).height,
                greaterThanOrEqualTo(44),
              );
              expect(tester.getRect(bulk).bottom, lessThanOrEqualTo(844));
              await tester.tap(clearSelection);
              await tester.pumpAndSettle();
              expect(store.selectedIds, isEmpty);
              expect(bulk, findsNothing);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
  for (final direction in TextDirection.values) {
    testWidgets(
      'vertical board drag refreshes but horizontal drag does not $direction',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = _RefreshStore()..boardData = buildStore().boardData;
        addTearDown(store.dispose);
        await pumpKanban(tester, store, direction: direction);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(HermesSegmentedControl<bool>),
            matching: find.text(l10n.taskBoardView),
          ),
        );
        await tester.pumpAndSettle();
        final before = store.loads;
        final bar = tester.widget<Scrollbar>(
          find.byKey(const ValueKey('task-board-scrollbar')),
        );
        expect(bar.thumbVisibility, isTrue);
        expect(bar.interactive, isTrue);
        expect(bar.controller!.positions, hasLength(1));
        expect(bar.controller!.position.axis, Axis.horizontal);
        expect(bar.controller!.position.maxScrollExtent, greaterThan(0));
        final next = find.byKey(const ValueKey('task-board-next'));
        expect(tester.widget<IconButton>(next).tooltip, l10n.taskNextColumn);
        expect(find.text(l10n.taskVisibleColumns(1, 2, 2)), findsOneWidget);
        final previous = find.byKey(const ValueKey('task-board-previous'));
        expect(
          tester.widget<IconButton>(previous).tooltip,
          l10n.taskPreviousColumn,
        );
        expect(tester.widget<IconButton>(previous).onPressed, isNull);
        expect(tester.widget<IconButton>(next).onPressed, isNotNull);
        expect(tester.getSize(next).height, greaterThanOrEqualTo(44));
        final nextIcon = find.descendant(of: next, matching: find.byType(Icon));
        Focus.of(tester.element(nextIcon)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(bar.controller!.offset, greaterThan(0));
        expect(tester.widget<IconButton>(next).onPressed, isNull);
        expect(tester.widget<IconButton>(previous).onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('task-board-previous')));
        await tester.pumpAndSettle();
        expect(bar.controller!.offset, 0);
        expect(tester.widget<IconButton>(previous).onPressed, isNull);
        expect(tester.widget<IconButton>(next).onPressed, isNotNull);
        final boardOffset = bar.controller!.offset;
        final barRect = tester.getRect(
          find.byKey(const ValueKey('task-board-scrollbar')),
        );
        final rtl = direction == TextDirection.rtl;
        final paint = tester.widget<CustomPaint>(
          find
              .descendant(
                of: find.byKey(const ValueKey('task-board-scrollbar')),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is CustomPaint &&
                      w.foregroundPainter is ScrollbarPainter,
                ),
              )
              .first,
        );
        Offset? thumbStart;
        for (double y = barRect.bottom - 1; y > barRect.bottom - 40; y--) {
          final point = Offset(rtl ? barRect.right - 40 : barRect.left + 40, y);
          if ((paint.foregroundPainter! as ScrollbarPainter)
              .hitTestOnlyThumbInteractive(
                point - barRect.topLeft,
                ui.PointerDeviceKind.mouse,
              )) {
            thumbStart = point;
            break;
          }
        }
        expect(
          thumbStart,
          isNotNull,
          reason: 'drag must hit the painted thumb',
        );
        final mouse = await tester.startGesture(
          thumbStart!,
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.moveBy(Offset(rtl ? -70 : 70, 0));
        await tester.pump();
        await mouse.moveBy(Offset(rtl ? -40 : 40, 0));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(bar.controller!.offset, greaterThan(boardOffset));
        expect(store.loads, before);
        await tester.tap(previous);
        await tester.pumpAndSettle();
        expect(bar.controller!.offset, 0);
        final column = find.byKey(const PageStorageKey('task-column-todo'));
        await tester.drag(column, Offset(rtl ? 100 : -100, 0));
        await tester.pumpAndSettle();
        expect(store.loads, before);
        expect(bar.controller!.offset, greaterThan(boardOffset));
        await tester.drag(column, const Offset(0, 400));
        await tester.pumpAndSettle();
        expect(store.loads, before + 1);
        tester.view.physicalSize = const Size(1280, 844);
        await tester.pumpAndSettle();
        final wideBar = tester.widget<Scrollbar>(
          find.byKey(const ValueKey('task-board-scrollbar')),
        );
        expect(wideBar.controller!.position.maxScrollExtent, 0);
        expect(tester.widget<IconButton>(previous).onPressed, isNull);
        expect(tester.widget<IconButton>(next).onPressed, isNull);
      },
    );
  }
  testWidgets('long list and board build lazily and reach last task', (
    tester,
  ) async {
    final store = buildStore();
    addTearDown(store.dispose);
    store.boardData = KanbanBoard.fromJson({
      'columns': [
        {
          'name': 'todo',
          'tasks': List.generate(
            100,
            (i) => {'id': '$i', 'title': 'Lazy task $i', 'status': 'todo'},
          ),
        },
      ],
    });
    await pumpKanban(tester, store);
    await tester.pumpAndSettle();
    expect(find.text('Lazy task 99'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Lazy task 99'),
      400,
      scrollable: find.descendant(
        of: find.byKey(
          PageStorageKey((store.api.client, store.api.boardSlug, 'task-list')),
        ),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 100,
    );
    expect(find.text('Lazy task 99').hitTestable(), findsOneWidget);
    var listPosition = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(
              PageStorageKey((
                store.api.client,
                store.api.boardSlug,
                'task-list',
              )),
            ),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    await Scrollable.ensureVisible(
      tester.element(find.byType(HermesSegmentedControl<bool>)),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    listPosition = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(
              PageStorageKey((
                store.api.client,
                store.api.boardSlug,
                'task-list',
              )),
            ),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    await tester.tap(
      find.descendant(
        of: find.byType(HermesSegmentedControl<bool>),
        matching: find.text(l10n.taskBoardView),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lazy task 99'), findsNothing);
    final column = find.byKey(const PageStorageKey('task-column-todo'));
    final scrollable = find.descendant(
      of: column,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Lazy task 99'),
      400,
      scrollable: scrollable,
      maxScrolls: 100,
    );
    expect(find.text('Lazy task 99').hitTestable(), findsOneWidget);
    final columnPosition = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    Future<void> view(bool board) async {
      await Scrollable.ensureVisible(
        tester.element(find.byType(HermesSegmentedControl<bool>)),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(HermesSegmentedControl<bool>),
          matching: find.text(board ? l10n.taskBoardView : l10n.taskListView),
        ),
      );
      await tester.pumpAndSettle();
    }

    double currentListPosition() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(
              PageStorageKey((
                store.api.client,
                store.api.boardSlug,
                'task-list',
              )),
            ),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    await view(false);
    expect(currentListPosition(), closeTo(listPosition, 1));
    await tester.scrollUntilVisible(
      find.text('Lazy task 99'),
      400,
      scrollable: find.descendant(
        of: find.byKey(
          PageStorageKey((store.api.client, store.api.boardSlug, 'task-list')),
        ),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 100,
    );
    listPosition = currentListPosition();
    expect(listPosition, greaterThan(0));
    final original = store.api.boardSlug;
    store.api.boardSlug = 'other';
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(currentListPosition(), 0);
    store.api.boardSlug = original;
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(currentListPosition(), closeTo(listPosition, 1));
    await view(true);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(columnPosition, 1),
    );
    store.api.boardSlug = 'other';
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    store.api.boardSlug = original;
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(columnPosition, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('kanban cards expose button semantics with title and status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final store = buildStore();
    addTearDown(store.dispose);
    await pumpKanban(tester, store);
    await tester.pump();

    final cardLabel =
        'Task one · ${l10n.taskStatusTodo} · ${l10n.taskPriorityNormal} · ${l10n.taskUnassigned} · ${l10n.taskCommentCount(0)}';
    expect(
      tester.getSemantics(find.bySemanticsLabel(cardLabel)),
      matchesSemantics(
        label: cardLabel,
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    expect(tester.takeException(), isNull);

    // 切到看板列视图，320px 下列宽自适应且不溢出。
    await tester.tap(
      find.descendant(
        of: find.byType(HermesSegmentedControl<bool>),
        matching: find.text(l10n.taskBoardView),
      ),
    );
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel(cardLabel)),
      matchesSemantics(
        label: cardLabel,
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('task reading semantics includes metadata and progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = buildStore()
      ..boardData = KanbanBoard.fromJson({
        'columns': [
          {
            'name': 'todo',
            'tasks': [
              {
                'id': 'readable',
                'title': '审查任务',
                'status': 'todo',
                'priority': 2,
                'assignee': '设计助手',
                'comment_count': 12,
                'progress': {'current': 3, 'total': 4},
              },
            ],
          },
        ],
      });
    addTearDown(store.dispose);
    await pumpKanban(tester, store);
    await tester.pumpAndSettle();
    final label =
        '审查任务 · ${l10n.taskStatusTodo} · ${l10n.taskPriorityUrgent} · 设计助手 · ${l10n.taskCommentCount(12)}';
    final node = tester.getSemantics(find.bySemanticsLabel(label));
    expect(node.value, '75%');
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('long-press multi-select exposes selected state and bulk bar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = buildStore();
    addTearDown(store.dispose);
    await pumpKanban(tester, store);
    await tester.pump();

    final cardLabel =
        'Task one · ${l10n.taskStatusTodo} · ${l10n.taskPriorityNormal} · ${l10n.taskUnassigned} · ${l10n.taskCommentCount(0)}';
    expect(
      tester.getSemantics(find.bySemanticsLabel(cardLabel)),
      matchesSemantics(
        label: cardLabel,
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );

    await tester.longPress(find.text('Task one'));
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel(cardLabel)),
      matchesSemantics(
        label: cardLabel,
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    expect(find.text(l10n.taskSelectedCount(1)), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.kanbanMoveSelected), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.kanbanClearSelection), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('view toggle segments expose button and selected semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = buildStore();
    addTearDown(store.dispose);
    await pumpKanban(tester, store);
    await tester.pump();

    // 分段控件为每个选项自带 Semantics（button + selected + label），
    // 其 label 与内部 Text 合并为 "\n" 拼接的双行文本，这里用 RegExp
    // 匹配并断言存在带 button 语义、selected 状态正确的节点。
    for (final (label, selected) in [
      (l10n.taskListView, true),
      (l10n.taskBoardView, false),
    ]) {
      final finder = find.bySemanticsLabel(RegExp('^$label'));
      expect(finder, findsWidgets);
      final found = <bool>[];
      for (var i = 0; i < finder.evaluate().length; i++) {
        final flags = tester
            .getSemantics(finder.at(i))
            .getSemanticsData()
            .flagsCollection;
        if (flags.isButton) {
          found.add(flags.isSelected == ui.Tristate.isTrue);
        }
      }
      expect(found, contains(selected));
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

class _NoopClient extends ApiClient {
  _NoopClient() : super(baseUrl: 'http://invalid', apiKey: 'key');
}

class _RefreshStore extends KanbanStore {
  _RefreshStore() : super(KanbanApi(_NoopClient()));
  int loads = 0;
  @override
  Future<void> load({KanbanApi? expectedApi}) async {
    loads++;
  }
}
