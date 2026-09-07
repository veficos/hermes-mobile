import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

void main() {
  final l10n = AppLocalizationsZh();

  KanbanStore buildStore() => KanbanStore(KanbanApi(_NoopClient()))
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

  Future<void> pumpKanban(WidgetTester tester, KanbanStore store) {
    return tester.pumpWidget(
      ChangeNotifierProvider<KanbanStore>.value(
        value: store,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const KanbanCanonicalScreen(),
        ),
      ),
    );
  }

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

    final cardLabel = 'Task one · ${l10n.taskStatusTodo}';
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

  testWidgets('long-press multi-select exposes selected state and bulk bar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = buildStore();
    addTearDown(store.dispose);
    await pumpKanban(tester, store);
    await tester.pump();

    final cardLabel = 'Task one · ${l10n.taskStatusTodo}';
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
