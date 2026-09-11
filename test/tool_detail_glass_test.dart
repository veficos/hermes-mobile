import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hermes_mobile/chat/tools/tool_group_card.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('tool detail opens and scrolls in Liquid, reduced=$reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ToolDismissStore(),
          child: MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
              reduceTransparency: reduced,
            ),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ToolGroupCard(
                groupId: 'tools',
                parts: [
                  ChatPart.toolCall({
                    'name': 'read_file',
                    'args': {'path': 'example.dart'},
                    'result_text': 'done',
                  }),
                ],
                detailBuilder: (tool) => Column(
                  children: [
                    Text('Detail: ${tool['name']}'),
                    const SizedBox(height: 1200),
                    const Text('end-of-detail'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final shell = tester.widget<Container>(
        find.byKey(const ValueKey('timeline-tool-group-read_file')),
      );
      final decoration = shell.decoration! as ShapeDecoration;
      expect(decoration.color!.a, 1);
      expect(decoration.shape, isA<RoundedSuperellipseBorder>());
      expect(find.byType(BackdropFilter), findsNothing);
      final hide = find.widgetWithIcon(IconButton, Icons.visibility_off_outlined);
      expect(tester.getSize(hide).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(hide).height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('浏览了 1 个文件'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('read_file'));
      await tester.pumpAndSettle();
      expect(find.text('Detail: read_file'), findsOneWidget);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, Colors.transparent);
      expect(sheet.shape, const RoundedRectangleBorder());
      expect(sheet.elevation, 0);
      expect(
        find.byType(BackdropFilter),
        reduced ? findsNothing : findsOneWidget,
      );
      final scroll = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(SingleChildScrollView),
      );
      for (var i = 0; i < 10; i++) {
        await tester.drag(scroll, const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(find.text('end-of-detail').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
