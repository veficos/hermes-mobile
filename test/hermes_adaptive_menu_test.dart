import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_adaptive_menu.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/widgets/glass/glass_selection_row.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';

void main() {
  for (final width in [390.0, 900.0]) {
    testWidgets('menu Escape restores keyboard trigger $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var cancellations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: Scaffold(
            body: Column(
              children: [
                HermesAdaptiveMenuButton<String>(
                  tooltip: 'Keyboard actions',
                  onCanceled: () => cancellations++,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'one', child: Text('One')),
                  ],
                ),
                TextButton(onPressed: () {}, child: const Text('Next control')),
              ],
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final trigger = FocusManager.instance.primaryFocus;
      expect(trigger, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('One'), findsNothing);
      expect(cancellations, 1);
      expect(FocusManager.instance.primaryFocus, same(trigger));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(cancellations, 2);
      expect(tester.takeException(), isNull);
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('phone close shares Liquid feedback reduced=$reduced', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var cancellations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Scaffold(
            body: HermesAdaptiveMenuButton<String>(
              tooltip: 'Actions',
              onCanceled: () => cancellations++,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'one', child: Text('One')),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      final close = find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(GlassButton),
      );
      expect(close, findsOneWidget);
      final rect = tester.getRect(close);
      expect(rect.shortestSide, greaterThanOrEqualTo(44));
      final press = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester
            .widget<AnimatedScale>(
              find.descendant(of: close, matching: find.byType(AnimatedScale)),
            )
            .scale,
        reduced ? 1 : .92,
      );
      await press.up();
      await tester.pumpAndSettle();
      expect(cancellations, 1);
      expect(find.text('One'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final enabled in [true, false]) {
    testWidgets('Liquid destructive label respects state enabled=$enabled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = buildHermesTheme(
        brightness: Brightness.light,
        visualStyle: HermesVisualStyle.liquid,
      );
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: HermesAdaptiveMenuButton<String>(
              tooltip: 'Open danger',
              onSelected: (_) => calls++,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  enabled: enabled,
                  child: const Text('Delete item'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Open danger'));
      await tester.pumpAndSettle();
      final label = find.text('Delete item');
      expect(
        DefaultTextStyle.of(tester.element(label)).style.color,
        enabled
            ? theme.colorScheme.error
            : theme.popupMenuTheme.labelTextStyle!.resolve({
                WidgetState.disabled,
              })!.color,
      );
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(calls, enabled ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Liquid phone menu shares selected row material and clipping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Scaffold(
          body: Center(
            child: HermesAdaptiveMenuButton<String>(
              tooltip: 'Open menu',
              initialValue: 'one',
              onSelected: (value) => selected = value,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'one', child: Text('One')),
                PopupMenuItem(value: 'two', child: Text('Two')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    final rows = tester
        .widgetList<GlassSelectionRow>(find.byType(GlassSelectionRow))
        .toList();
    expect(rows.map((row) => row.selected), [true, false]);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.clipBehavior, Clip.none);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(selected, 'two');
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone trigger does not inherit desktop menu width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Scaffold(
          body: Center(
            child: HermesAdaptiveMenuButton<String>(
              constraints: const BoxConstraints.tightFor(width: 280),
              onSelected: (value) => selected = value,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'one', child: Text('One')),
              ],
            ),
          ),
        ),
      ),
    );
    final trigger = find.byType(IconButton);
    expect(tester.getSize(trigger).width, lessThan(80));
    expect(tester.getSize(trigger).shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(selected, 'one');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Liquid menu inherits themed position and inner padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme:
            buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
            ).copyWith(
              popupMenuTheme: const PopupMenuThemeData(
                position: PopupMenuPosition.over,
                menuPadding: EdgeInsets.all(18),
              ),
            ),
        home: Scaffold(
          body: Center(
            child: HermesAdaptiveMenuButton<String>(
              tooltip: 'Themed menu',
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'one', child: Text('One')),
              ],
            ),
          ),
        ),
      ),
    );
    final button = tester.widget<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>),
    );
    expect(button.position, PopupMenuPosition.over);
    expect(button.offset, Offset.zero);
    await tester.tap(find.byTooltip('Themed menu'));
    await tester.pumpAndSettle();
    final scroll = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(scroll.padding, const EdgeInsets.all(18));
    expect(tester.takeException(), isNull);
  });
  Widget app({
    required ValueChanged<String> onSelected,
    bool liquid = false,
    VoidCallback? onCanceled,
    bool accessibility = false,
    double bottomSafe = 0,
  }) {
    return MaterialApp(
      builder: (context, child) => accessibility || bottomSafe > 0
          ? MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(accessibility ? 2 : 1),
                viewInsets: EdgeInsets.only(bottom: accessibility ? 300 : 0),
                padding: EdgeInsets.only(bottom: bottomSafe),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              ),
            )
          : child!,
      theme: buildHermesTheme(
        brightness: Brightness.light,
        visualStyle: liquid
            ? HermesVisualStyle.liquid
            : HermesVisualStyle.classic,
      ),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            HermesAdaptiveMenuButton<String>(
              tooltip: 'Actions',
              initialValue: 'selected',
              onSelected: onSelected,
              onCanceled: onCanceled,
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

  testWidgets('Liquid menu floats above the home indicator', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(liquid: true, bottomSafe: 34, onSelected: (_) {}),
    );
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.byType(GlassSurface)).dy, 798);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Liquid menu owns its outline and supports select and cancel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    var canceled = 0;
    await tester.pumpWidget(
      app(
        liquid: true,
        onSelected: (value) => selected = value,
        onCanceled: () => canceled++,
      ),
    );
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isFalse);
    expect(sheet.shape, const RoundedRectangleBorder());
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(selected, 'normal');
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(canceled, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Liquid menu remains actionable with RTL, 2x text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    await tester.pumpWidget(
      app(
        liquid: true,
        accessibility: true,
        onSelected: (value) => selected = value,
      ),
    );
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    final textContext = tester.element(find.text('Edit'));
    expect(MediaQuery.textScalerOf(textContext).scale(10), 20);
    expect(Directionality.of(textContext), TextDirection.rtl);
    expect(tester.getBottomRight(find.text('Edit')).dy, lessThan(544));
    // The whole glass panel, not just its actionable text, stays above IME.
    expect(
      tester.getBottomRight(find.byType(GlassSurface)).dy,
      lessThanOrEqualTo(532),
    );
    final panel = tester.getRect(find.byType(GlassSurface));
    expect(panel.left, 12);
    expect(panel.right, 378);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(selected, 'normal');
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

  testWidgets('wide Liquid menu anchors one glass panel and keeps actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    var canceled = 0;
    await tester.pumpWidget(
      app(
        liquid: true,
        onSelected: (value) => selected = value,
        onCanceled: () => canceled++,
      ),
    );
    final trigger = tester.getRect(find.byTooltip('Actions'));
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final panel = tester.getRect(find.byType(GlassSurface));
    expect(panel.top, greaterThanOrEqualTo(trigger.bottom));
    expect(panel.right, lessThanOrEqualTo(892));
    expect(panel.bottom, lessThanOrEqualTo(792));
    expect(
      tester
          .widget<CheckedPopupMenuItem<String>>(
            find.byType(CheckedPopupMenuItem<String>),
          )
          .checked,
      isTrue,
    );
    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(selected, 'normal');
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(canceled, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide Liquid long menu scrolls to the final action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.dark,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: HermesAdaptiveMenuButton<int>(
              tooltip: 'Long menu',
              constraints: const BoxConstraints(maxHeight: 240),
              initialValue: 29,
              onSelected: (value) => selected = value,
              itemBuilder: (_) => List.generate(
                30,
                (index) => PopupMenuItem<int>(
                  value: index,
                  child: Text('Action $index'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Long menu'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    final panelBefore = tester.getRect(find.byType(GlassSurface));
    expect(panelBefore.height, 240);
    expect(panelBefore.top, greaterThanOrEqualTo(55));
    expect(panelBefore.bottom, lessThanOrEqualTo(558));
    await tester.scrollUntilVisible(
      find.text('Action 29'),
      250,
      scrollable: find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    final last = tester.getRect(find.text('Action 29'));
    expect(tester.getRect(find.byType(GlassSurface)), panelBefore);
    expect(last.bottom, lessThanOrEqualTo(592));
    expect(last.top, greaterThanOrEqualTo(8));
    await tester.tap(find.text('Action 29'));
    await tester.pumpAndSettle();
    expect(selected, 29);
    // Keyboard traversal also reveals offscreen entries inside that same
    // stationary panel, rather than moving the route's outer scroll view.
    await tester.tap(find.byTooltip('Long menu'));
    await tester.pumpAndSettle();
    final keyboardPanel = tester.getRect(find.byType(GlassSurface));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    for (var i = 0; i < 29; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(tester.getRect(find.byType(GlassSurface)), keyboardPanel);
    expect(find.text('Action 29').hitTestable(), findsOneWidget);
    selected = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 29);
    expect(tester.takeException(), isNull);
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
