import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_page_scaffold.dart';

void main() {
  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 800),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('mobile shell has no overflow at ${size.width}dp', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(brightness: Brightness.light),
          home: MobilePageScaffold(
            title: '一个很长的移动端页面标题，用于验证窄屏不会溢出',
            actions: const [
              IconButton(onPressed: null, icon: Icon(Icons.more_vert)),
            ],
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                TextField(decoration: InputDecoration(labelText: '输入内容')),
                SizedBox(height: 700),
                FilledButton(onPressed: null, child: Text('保存')),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('输入内容'), findsOneWidget);
    });
  }

  testWidgets('keyboard inset keeps sheet editor above the obscured area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showMobileSheet<void>(
                context,
                (_) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(labelText: '评论'),
                  ),
                ),
              ),
              child: const Text('编辑'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('评论'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
