import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_alert_dialog.dart';

void main() {
  testWidgets('Escape dismisses glass dialog and restores trigger focus', (
    tester,
  ) async {
    final trigger = FocusNode();
    addTearDown(trigger.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              focusNode: trigger,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const GlassAlertDialog(
                  title: Text('Details'),
                  content: TextField(autofocus: true),
                  actions: [],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    trigger.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(GlassAlertDialog), findsOneWidget);
    expect(trigger.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(GlassAlertDialog), findsNothing);
    expect(trigger.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('glass editor keeps actions above keyboard with long content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => GlassAlertDialog(
                    title: const Text('Font'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(controller: controller),
                        ...List.generate(20, (i) => Text('Font $i')),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(controller.text),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Menlo');
    await tester.pumpAndSettle();
    expect(find.text('Save').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text('Save')).bottom, lessThan(544));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'Menlo');
    expect(tester.takeException(), isNull);
  });
  for (final liquid in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets('alert material liquid=$liquid reduced=$reduced', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.dark,
              visualStyle: liquid
                  ? HermesVisualStyle.liquid
                  : HermesVisualStyle.classic,
              reduceTransparency: reduced,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => PopScope(
                      canPop: false,
                      child: GlassAlertDialog(
                        title: const Text('Handoff'),
                        content: Text(
                          liquid
                              ? List.filled(
                                  30,
                                  'Waiting for platform.',
                                ).join(' ')
                              : 'Waiting',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byType(BackdropFilter),
          liquid && !reduced ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(AlertDialog),
          liquid ? findsNothing : findsOneWidget,
        );
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(GlassAlertDialog), findsOneWidget);
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        if (liquid) {
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
          expect(find.text('Cancel').hitTestable(), findsOneWidget);
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(GlassAlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
