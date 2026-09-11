import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/chat/tools/tool_group_card.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('tool actions separate $style $brightness at 320px 2x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = ToolDismissStore();
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
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ToolGroupCard(
                    groupId: 'actions',
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
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final disclosure = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.expanded != null,
        );
        final hide = find.widgetWithIcon(
          IconButton,
          Icons.visibility_off_outlined,
        );
        if (style == HermesVisualStyle.liquid) {
          final summary = find.descendant(
            of: disclosure,
            matching: find.byWidgetPredicate(
              (w) => w is Text && (w.data?.contains('浏览了') ?? false),
            ),
          );
          expect(summary, findsOneWidget);
          expect(tester.widget<Text>(summary).maxLines, isNull);
          expect(
            tester.widget<Text>(summary).overflow,
            isNot(TextOverflow.ellipsis),
          );
          expect(
            tester.getRect(summary).right,
            lessThan(tester.getRect(hide).left),
          );
        }
        expect(find.descendant(of: disclosure, matching: hide), findsNothing);
        expect(tester.getSize(hide).height, greaterThanOrEqualTo(44));
        expect(tester.getSize(hide).width, greaterThanOrEqualTo(44));
        expect(tester.widget<Semantics>(disclosure).properties.expanded, false);
        Focus.of(tester.element(find.byIcon(Icons.expand_more))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(disclosure).properties.expanded, true);
        expect(store.isDismissed('actions'), false);
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pumpAndSettle();
        await tester.tap(hide);
        await tester.pumpAndSettle();
        expect(store.isDismissed('actions'), true);
        expect(disclosure, findsNothing);
        final restore = find.widgetWithIcon(
          TextButton,
          Icons.visibility_outlined,
        );
        expect(restore.hitTestable(), findsOneWidget);
        expect(tester.getSize(restore).height, greaterThanOrEqualTo(44));
        Focus.of(
          tester.element(find.byIcon(Icons.visibility_outlined)),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(store.isDismissed('actions'), false);
        expect(tester.widget<Semantics>(disclosure).properties.expanded, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      });
    }
  }
}
