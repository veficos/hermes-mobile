import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/transcript/transcript_scroll_controller.dart';

void main() {
  testWidgets('listeners distinguish content corrections from user movement', (
    tester,
  ) async {
    final controller = TranscriptScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemExtent: 100,
            itemCount: 100,
            itemBuilder: (_, i) => Text('$i'),
          ),
        ),
      ),
    );
    final corrections = <bool>[];
    controller.addListener(() => corrections.add(controller.correctingContent));
    controller.correctContentOffset(300);
    expect(corrections, [true]);
    expect(controller.correctingContent, isFalse);
    controller.jumpTo(500);
    expect(corrections.last, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'content correction resumes ballistic scrolling at its new origin',
    (tester) async {
      final controller = TranscriptScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemExtent: 100,
              itemBuilder: (_, i) => Text('row $i'),
            ),
          ),
        ),
      );
      controller.jumpTo(1000);
      await tester.pump();
      (controller.position as ScrollPositionWithSingleContext).goBallistic(800);
      await tester.pump(const Duration(milliseconds: 16));
      final velocity = controller.position.activity!.velocity;
      final target = controller.offset + 300;
      controller.correctContentOffset(target);
      expect(controller.position.activity, isA<BallisticScrollActivity>());
      expect(controller.position.activity!.velocity, closeTo(velocity, 1));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.offset, greaterThan(target));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('content correction preserves an ongoing finger drag', (
    tester,
  ) async {
    final controller = TranscriptScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemExtent: 100,
            itemBuilder: (_, i) => Text('row $i'),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    final activity = controller.position.activity;
    expect(activity, isA<DragScrollActivity>());
    controller.correctContentOffset(controller.offset + 300);
    await tester.pump();
    expect(controller.position.activity, same(activity));
    final corrected = controller.offset;
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(controller.offset, closeTo(corrected + 40, .01));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
