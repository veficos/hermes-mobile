import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('Liquid focus preserves composer geometry reduced=$reduced', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Hello');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: reduced),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 320,
                  child: HermesComposer(controller: controller, onSend: (_) {}),
                ),
              ),
            ),
          ),
        ),
      );
      final surface = find.byKey(const ValueKey('composer-input-surface'));
      final send = find.byKey(const ValueKey('composer-send'));
      final field = find.byType(EditableText);
      final initial = [
        tester.getRect(surface),
        tester.getRect(field),
        tester.getRect(send),
      ];
      final focus = tester.widget<EditableText>(field).focusNode;
      focus.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect([
        tester.getRect(surface),
        tester.getRect(field),
        tester.getRect(send),
      ], initial);
      await tester.pumpAndSettle();
      final container = tester.widget<AnimatedContainer>(surface);
      final shape =
          (container.foregroundDecoration! as ShapeDecoration).shape
              as RoundedSuperellipseBorder;
      expect(shape.side.width, 1.4);
      if (reduced) expect(container.duration, Duration.zero);
      expect([
        tester.getRect(surface),
        tester.getRect(field),
        tester.getRect(send),
      ], initial);
      focus.unfocus();
      await tester.pumpAndSettle();
      expect([
        tester.getRect(surface),
        tester.getRect(field),
        tester.getRect(send),
      ], initial);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('composer text/cursor vertically centers with the send button', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'hi');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: HermesComposer(controller: controller, onSend: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();

    final textRect = tester.getRect(find.byType(EditableText));
    final buttonRect = tester.getRect(
      find.byKey(const ValueKey('composer-send')),
    );

    // The single-line text/cursor should sit at the same vertical center as
    // the circular send button beside it, not visibly lower.
    expect((textRect.center.dy - buttonRect.center.dy).abs(), lessThan(2));
  });

  testWidgets('before-send action is inside the field and left of send', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'hi');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HermesComposer(
            controller: controller,
            onSend: (_) {},
            beforeSendAction: const SizedBox(
              key: ValueKey('voice-action'),
              width: 36,
              height: 36,
            ),
          ),
        ),
      ),
    );

    final voiceRect = tester.getRect(
      find.byKey(const ValueKey('voice-action')),
    );
    final sendRect = tester.getRect(
      find.byKey(const ValueKey('composer-send')),
    );
    expect(voiceRect.right, lessThanOrEqualTo(sendRect.left));
    expect((voiceRect.center.dy - sendRect.center.dy).abs(), lessThan(2));
  });
}
