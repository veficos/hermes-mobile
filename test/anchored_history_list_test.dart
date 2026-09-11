import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/transcript/anchored_history_list.dart';

void main() {
  testWidgets('empty history can load, clear and load again', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var count = 0;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return Scaffold(
              body: AnchoredHistoryList(
                controller: controller,
                keys: [for (var i = 0; i < count; i++) ValueKey(i)],
                padding: const EdgeInsets.all(8),
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey(index),
                  height: 80,
                  child: Text('Entry $index'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final next in [3, 0, 4]) {
      change(() => count = next);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (next > 0) {
        expect(find.text('Entry 0').hitTestable(), findsOneWidget);
        expect(find.text('Entry ${next - 1}').hitTestable(), findsOneWidget);
      } else {
        expect(find.text('Entry 0'), findsNothing);
      }
    }
  });
  for (final reverse in [false, true]) {
    testWidgets(
      'inertial reading matches unchanged list after cached row resize reverse=$reverse',
      (tester) async {
        final controls = [ScrollController(), ScrollController()];
        for (final controller in controls) {
          addTearDown(controller.dispose);
        }
        var height = 80.0;
        var start = 0;
        final anchorId = reverse ? -5 : 9;
        late StateSetter change;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return Scaffold(
                  body: Row(
                    children: [
                      for (var side = 0; side < 2; side++)
                        Expanded(
                          child: AnchoredHistoryList(
                            controller: controls[side],
                            keys: [
                              for (var i = start; i < 60; i++)
                                ValueKey('$side-$i'),
                            ],
                            padding: EdgeInsets.zero,
                            itemBuilder: (_, index) => SizedBox(
                              key: ValueKey('$side-${index + start}'),
                              height:
                                  side == 1 &&
                                      index + start == (reverse ? -2 : 3)
                                  ? height
                                  : 80,
                              child: Text('Side $side row ${index + start}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (reverse) {
          change(() => start = -20);
          await tester.pumpAndSettle();
        }
        for (final controller in controls) {
          controller.jumpTo(reverse ? -760 : 280);
        }
        await tester.pumpAndSettle();
        final left = await tester.startGesture(
          const Offset(150, 400),
          pointer: 1,
        );
        final right = await tester.startGesture(
          const Offset(550, 400),
          pointer: 2,
        );
        for (var i = 0; i < 5; i++) {
          final stamp = Duration(milliseconds: (i + 1) * 16);
          await left.moveBy(const Offset(0, -10), timeStamp: stamp);
          await right.moveBy(const Offset(0, -10), timeStamp: stamp);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await left.up(timeStamp: const Duration(milliseconds: 81));
        await right.up(timeStamp: const Duration(milliseconds: 81));
        await tester.pump(const Duration(milliseconds: 16));
        expect(controls.first.position.isScrollingNotifier.value, isTrue);
        change(() => height = 240);
        for (var frame = 0; frame < 12; frame++) {
          if (frame == 4) change(() => height = 60);
          if (frame == 8) change(() => height = 180);
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getTopLeft(find.text('Side 1 row $anchorId')).dy,
            closeTo(tester.getTopLeft(find.text('Side 0 row $anchorId')).dy, 1),
            reason: 'inertial frame $frame',
          );
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final animationStarts = controls
            .map((controller) => controller.offset)
            .toList();
        final animations = [
          for (final controller in controls)
            controller.animateTo(
              1200,
              duration: const Duration(milliseconds: 240),
              curve: Curves.linear,
            ),
        ];
        await tester.pump();
        change(() => height = 60);
        for (var frame = 0; frame < 16; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final fraction = ((frame + 1) * 16 / 240).clamp(0.0, 1.0);
          for (var side = 0; side < 2; side++) {
            expect(
              controls[side].offset,
              closeTo(
                animationStarts[side] +
                    (1200 - animationStarts[side]) * fraction,
                1,
              ),
              reason: 'explicit animation side $side owns frame $frame',
            );
          }
        }
        await Future.wait(animations);
        expect(controls[1].offset, closeTo(1200, 1));
      },
    );
  }
  for (final mode in ['reading', 'top', 'dragging']) {
    final atTop = mode == 'top';
    final dragging = mode == 'dragging';
    testWidgets(
      'resizing newer rows preserves a reverse-history reader mode=$mode',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var ids = List.generate(40, (i) => i);
        var height = 80.0;
        late StateSetter change;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                final keys = <Key>[
                  const ValueKey('header'),
                  for (final id in ids) ValueKey(id),
                ];
                return Scaffold(
                  body: AnchoredHistoryList(
                    controller: controller,
                    keys: keys,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (_, index) => SizedBox(
                      key: keys[index],
                      height: index > 0 && ids[index - 1] == (atTop ? -15 : -2)
                          ? height
                          : 80,
                      child: Text(
                        index == 0 ? 'Header' : 'Old ${ids[index - 1]}',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        change(() => ids = [...List.generate(20, (i) => i - 20), ...ids]);
        await tester.pumpAndSettle();
        final destination = atTop
            ? controller.position.minScrollExtent
            : -760.0;
        controller.jumpTo(destination);
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(destination, 1));
        final anchor = find.text(atTop ? 'Header' : 'Old -9');
        final gesture = dragging
            ? await tester.startGesture(const Offset(200, 300))
            : null;
        if (gesture != null) {
          await gesture.moveBy(const Offset(0, -30));
          await tester.pump();
          expect(controller.position.isScrollingNotifier.value, isTrue);
        }
        final top = tester.getTopLeft(anchor).dy;
        var travel = 0.0;
        expect(top, inInclusiveRange(0, 600));
        for (final next in [240.0, 60.0, 180.0]) {
          change(() => height = next);
          for (var frame = 0; frame < 5; frame++) {
            if (gesture != null) {
              await gesture.moveBy(const Offset(0, -2));
              travel -= 2;
            }
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              tester.getTopLeft(anchor).dy,
              closeTo(top + travel, 1),
              reason: 'reverse height=$next',
            );
            expect(tester.takeException(), isNull);
          }
        }
        await gesture?.up();
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets('resizing a cached row above reading preserves the visible row', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var height = 80.0;
    late StateSetter change;
    final keys = <Key>[
      const ValueKey('header'),
      for (var i = 0; i < 40; i++) ValueKey('resize-row-$i'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return Scaffold(
              body: AnchoredHistoryList(
                controller: controller,
                keys: keys,
                padding: const EdgeInsets.all(8),
                itemBuilder: (_, index) => SizedBox(
                  key: keys[index],
                  height: index == 3 ? height : 80,
                  child: Text('Resize row $index'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(280);
    await tester.pumpAndSettle();
    final anchor = find.text('Resize row 5');
    final top = tester.getTopLeft(anchor).dy;
    for (final next in [240.0, 60.0, 180.0]) {
      change(() => height = next);
      await tester.pump();
      expect(
        tester.getTopLeft(anchor).dy,
        closeTo(top, 1),
        reason: 'height=$next must preserve the reading position',
      );
    }
  });
  testWidgets('ten prepends retain the visible row every frame', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var ids = List.generate(50, (i) => i);
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            final keys = <Key>[
              const ValueKey('header'),
              for (final id in ids) ValueKey(id),
            ];
            return Scaffold(
              body: AnchoredHistoryList(
                controller: controller,
                keys: keys,
                padding: const EdgeInsets.all(8),
                itemBuilder: (_, index) => SizedBox(
                  key: keys[index],
                  height: index == 0
                      ? 32
                      : 60 + (ids[index - 1].abs() % 7) * 15,
                  child: Text(index == 0 ? 'History' : 'Row ${ids[index - 1]}'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final anchor = find.text('Row 0');
    final top = tester.getTopLeft(anchor).dy;
    for (var page = 1; page <= 10; page++) {
      change(() => ids = [...List.generate(50, (i) => -page * 50 + i), ...ids]);
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getTopLeft(anchor).dy, closeTo(top, .1));
      }
    }
    expect(ids.length, 550);
    // Simulate trimming newer content, including the original zero-point row,
    // while the user is reading retained older content.
    controller.jumpTo(-200);
    await tester.pumpAndSettle();
    final retained = find.text('Row -1');
    expect(retained, findsOneWidget);
    final retainedTop = tester.getTopLeft(retained).dy;
    change(() => ids = ids.where((id) => id < 0).toList());
    await tester.pump();
    expect(tester.getTopLeft(retained).dy, closeTo(retainedTop, .1));
    // Restoring the newer window must reuse the same boundary.
    change(() => ids = [...ids, ...List.generate(50, (i) => i)]);
    await tester.pump();
    expect(tester.getTopLeft(retained).dy, closeTo(retainedTop, .1));
    expect(tester.takeException(), isNull);
  });

  for (final count in [2, 3, 5]) {
    testWidgets('short transcript with $count rows exposes its header', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final keys = [
        const ValueKey('header'),
        for (var i = 1; i < count; i++) ValueKey('message-$i'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnchoredHistoryList(
              controller: controller,
              keys: keys,
              padding: const EdgeInsets.all(8),
              itemBuilder: (_, i) => SizedBox(
                key: keys[i],
                height: 40,
                child: Text(i == 0 ? 'History' : 'Message'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('History')).dy,
        greaterThanOrEqualTo(0),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
