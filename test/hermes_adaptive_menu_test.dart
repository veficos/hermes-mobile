import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_adaptive_menu.dart';

void main() {
  Widget app({required ValueChanged<String> onSelected}) {
    return MaterialApp(
      theme: buildHermesTheme(brightness: Brightness.light),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            HermesAdaptiveMenuButton<String>(
              tooltip: 'Actions',
              initialValue: 'selected',
              onSelected: onSelected,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'normal',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'selected',
                  checked: true,
                  child: Text('Selected'),
                ),
                PopupMenuItem(
                  value: 'disabled',
                  enabled: false,
                  child: Text('Disabled'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('uses a safe, scrollable bottom sheet on phones', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(app(onSelected: (value) => selected = value));

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(SafeArea), findsWidgets);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(selected, 'normal');
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('keeps the anchored popup on larger screens', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(app(onSelected: (value) => selected = value));

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(selected, 'normal');
  });

  testWidgets('phone sheet handles RTL and large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.6),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: app(onSelected: (_) {}),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
