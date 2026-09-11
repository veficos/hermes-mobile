import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/transcript/chat_message_list.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('inline editor $brightness scale=$scale', (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController(text: '编辑这条消息');
        addTearDown(controller.dispose);
        var submitted = 0;
        var cancelled = 0;
        var attached = 0;
        await tester.pumpWidget(
          MaterialApp(
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
              body: SingleChildScrollView(
                child: InlineMessageEditor(
                  controller: controller,
                  onSubmit: () => submitted++,
                  onCancel: () => cancelled++,
                  onAttach: () => attached++,
                  attachmentCount: 2,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final editor = tester.widget<Container>(
          find.byKey(const ValueKey('inline-message-editor')),
        );
        expect((editor.decoration! as ShapeDecoration).color!.a, 1);
        expect(find.byType(BackdropFilter), findsNothing);
        for (final button in [
          find.byType(IconButton),
          find.byType(TextButton),
          find.byType(FilledButton),
        ]) {
          expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
          await tester.tap(button);
        }
        expect([attached, cancelled, submitted], [1, 1, 1]);
      });
    }
  }
}
