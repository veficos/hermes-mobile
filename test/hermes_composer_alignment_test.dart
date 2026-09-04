import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';

void main() {
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
