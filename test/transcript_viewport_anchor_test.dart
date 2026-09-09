import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/transcript/viewport_anchor.dart';

void main() {
  testWidgets('lazy keyed rows retain a visible anchor after a prepend', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final keys = <int, GlobalKey>{};
    Widget content(List<int> ids) => MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: controller,
          itemCount: ids.length,
          findChildIndexCallback: (key) {
            final index = ids.indexOf((key as ValueKey<int>).value);
            return index < 0 ? null : index;
          },
          itemBuilder: (_, index) => SizedBox(
            key: ValueKey(ids[index]),
            height: 80 + (ids[index] % 3) * 20,
            child: SizedBox(key: keys.putIfAbsent(ids[index], GlobalKey.new)),
          ),
        ),
      ),
    );
    final ids = List.generate(100, (i) => i + 10);
    await tester.pumpWidget(content(ids));
    controller.jumpTo(120);
    await tester.pump();
    final anchor = TranscriptViewportAnchor.capture(
      keys.values,
      controller.position,
    )!;
    final before = tester.getTopLeft(find.byKey(anchor.key)).dy;
    await tester.pumpWidget(
      content([for (var i = -40; i < 10; i++) i, ...ids]),
    );
    if (anchor.restoredOffset(controller.position) == null) {
      controller.jumpTo(controller.offset + 5000);
      await tester.pump();
    }
    final offset = anchor.restoredOffset(
      controller.position,
      userScrollDelta: 0,
    );
    expect(offset, isNotNull);
    controller.jumpTo(offset!);
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(anchor.key)).dy, closeTo(before, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'anchor ignores tail growth and preserves intervening scrolling',
    (tester) async {
      final controller = ScrollController();
      final key = GlobalKey();
      addTearDown(controller.dispose);
      Widget content(double head, double tail) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                SizedBox(height: head),
                SizedBox(key: key, height: 300, child: const Text('reading')),
                SizedBox(height: tail),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(content(100, 1000));
      controller.jumpTo(120);
      await tester.pump();
      final anchor = TranscriptViewportAnchor.capture([
        key,
      ], controller.position)!;
      controller.jumpTo(150);
      await tester.pumpWidget(content(300, 2000));
      expect(anchor.restoredOffset(controller.position), closeTo(350, .01));
      controller.jumpTo(anchor.restoredOffset(controller.position)!);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(key)).dy, closeTo(-50, .01));
    },
  );
}
