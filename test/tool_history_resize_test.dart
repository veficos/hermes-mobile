import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/chat/tools/tool_group_card.dart';
import 'package:hermes_mobile/chat/transcript/anchored_history_list.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'mounted tool resize preserves downstream reader $brightness $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final scroll = ScrollController();
          final dismiss = ToolDismissStore();
          var count = 35;
          late StateSetter change;
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: dismiss,
              child: MaterialApp(
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: buildHermesTheme(
                  brightness: brightness,
                  visualStyle: HermesVisualStyle.liquid,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      change = setState;
                      return AnchoredHistoryList(
                        controller: scroll,
                        keys: [
                          for (var i = 0; i < count; i++) ValueKey('row-$i'),
                        ],
                        padding: EdgeInsets.zero,
                        itemBuilder: (_, index) => index == 3
                            ? ToolGroupCard(
                                key: const ValueKey('row-3'),
                                groupId: 'resize',
                                parts: [
                                  ChatPart.toolCall({
                                    'name': 'read_file',
                                    'args': {'path': 'a.dart'},
                                    'result_text': 'a',
                                  }),
                                  ChatPart.toolCall({
                                    'name': 'terminal',
                                    'args': {'command': 'pwd'},
                                    'result_text': '/workspace',
                                  }),
                                ],
                              )
                            : SizedBox(
                                key: ValueKey('row-$index'),
                                height: 90,
                                child: Text('Reading row $index'),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.expand_more));
          await tester.pumpAndSettle();
          final tool = find.byKey(const ValueKey('row-3'));
          final reader = find.text('Reading row 4');
          await Scrollable.ensureVisible(
            tester.element(reader),
            alignment: .35,
          );
          await tester.pumpAndSettle();
          scroll.jumpTo(scroll.offset + tester.getTopLeft(reader).dy - 8);
          await tester.pumpAndSettle();
          expect(reader.hitTestable(), findsOneWidget);
          expect(tool, findsOneWidget);
          final originalHeight = tester.getSize(tool).height;
          expect(originalHeight, greaterThan(100));
          final y = tester.getTopLeft(reader).dy;
          expect(y, closeTo(8, 1));
          expect(tester.getBottomLeft(tool).dy, lessThanOrEqualTo(y));
          expect(scroll.position.extentBefore, greaterThan(100));
          expect(scroll.position.extentAfter, greaterThan(800));
          dismiss.dismiss('resize');
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tool, findsOneWidget);
            expect(tester.getSize(tool).height, lessThan(originalHeight - 20));
            expect(tester.getTopLeft(reader).dy, closeTo(y, 2));
          }
          final hiddenHeight = tester.getSize(tool).height;
          // Trim newer rows while restoring real content above the reader.
          change(() => count = 25);
          dismiss.restore('resize');
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tool, findsOneWidget);
            expect(tester.getSize(tool).height, greaterThan(hiddenHeight));
            expect(tester.getTopLeft(reader).dy, closeTo(y, 2));
            expect(scroll.position.extentAfter, greaterThan(400));
          }
          expect(find.byIcon(Icons.expand_more), findsOneWidget);
          expect(
            tester
                .widget<AnchoredHistoryList>(find.byType(AnchoredHistoryList))
                .keys,
            hasLength(25),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          scroll.dispose();
          dismiss.dispose();
        },
      );
    }
  }
}
