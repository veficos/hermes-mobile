import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_adaptive_ui.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_page_scaffold.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: buildHermesTheme(brightness: Brightness.light),
    home: child,
  );

  testWidgets('large page title shares scrolling with a list body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        HermesPageScaffold(
          title: '会话',
          titleMode: HermesPageTitleMode.large,
          body: ListView.builder(
            itemCount: 40,
            itemBuilder: (_, index) => ListTile(title: Text('会话 $index')),
          ),
        ),
      ),
    );
    await tester.drag(find.text('会话 0'), const Offset(0, -500));
    await tester.pumpAndSettle();

    // SliverAppBar keeps both expanded and compact title renderers alive
    // during the collapse transition.
    expect(find.text('会话'), findsWidgets);
    expect(find.text('会话 10'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker sheet selects a typed option', (tester) async {
    String? selected;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await showHermesPickerSheet<String>(
                context,
                title: '选择模型',
                options: const [
                  HermesPickerOption(value: 'a', label: 'Model A'),
                  HermesPickerOption(value: 'b', label: 'Model B'),
                ],
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Model B'));
    await tester.pumpAndSettle();

    expect(selected, 'b');
  });

  testWidgets('activity pill exposes progress without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: HermesActivityPill(
                label: '正在上传 1/3',
                state: HermesActivityState.processing,
                progress: .42,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('正在上传 1/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
