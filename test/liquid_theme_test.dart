import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/core/stores/appearance_store.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';
import 'package:hermes_mobile/widgets/adaptive_form_dialog.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_page_scaffold.dart';
import 'package:hermes_mobile/widgets/glass/glass_environment.dart';

void main() {
  test('Liquid fallback modal contours stay opaque and continuous', () {
    for (final brightness in Brightness.values) {
      final theme = buildHermesTheme(
        brightness: brightness,
        visualStyle: HermesVisualStyle.liquid,
      );
      expect(theme.dialogTheme.shape, isA<RoundedSuperellipseBorder>());
      final sheet = theme.bottomSheetTheme.shape! as RoundedSuperellipseBorder;
      expect(
        sheet.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(30)),
      );
      expect(theme.dialogTheme.backgroundColor!.a, 1);
      expect(theme.bottomSheetTheme.modalBackgroundColor!.a, 1);
      final classic = buildHermesTheme(brightness: brightness);
      expect(classic.dialogTheme.shape, isA<RoundedRectangleBorder>());
      expect(classic.bottomSheetTheme.shape, isA<RoundedRectangleBorder>());
    }
  });
  for (final brightness in Brightness.values) {
    test('Liquid segmented material states $brightness', () {
      final theme = buildHermesTheme(
        brightness: brightness,
        visualStyle: HermesVisualStyle.liquid,
      );
      final style = theme.segmentedButtonTheme.style!;
      expect(style.side!.resolve({}), BorderSide.none);
      expect(style.overlayColor!.resolve({}), Colors.transparent);
      expect(
        style.overlayColor!.resolve({WidgetState.focused})!.a,
        closeTo(.12, .001),
      );
      expect(
        style.overlayColor!.resolve({WidgetState.hovered})!.a,
        closeTo(.06, .001),
      );
      expect(
        style.overlayColor!.resolve({
          WidgetState.pressed,
          WidgetState.focused,
        })!.a,
        closeTo(.14, .001),
      );
      expect(
        style.overlayColor!.resolve({
          WidgetState.disabled,
          WidgetState.focused,
        }),
        Colors.transparent,
      );
      expect(style.minimumSize!.resolve({}), const Size(44, 44));
      expect(style.backgroundColor!.resolve({}), Colors.transparent);
      expect(
        style.backgroundColor!.resolve({WidgetState.selected}),
        theme.colorScheme.primaryContainer,
      );
      expect(
        style.foregroundColor!.resolve({WidgetState.selected}),
        theme.colorScheme.onPrimaryContainer,
      );
      expect(
        style.backgroundColor!.resolve({
          WidgetState.disabled,
          WidgetState.selected,
        }),
        style.backgroundColor!.resolve({WidgetState.disabled}),
      );
      expect(
        buildHermesTheme(brightness: brightness).segmentedButtonTheme.style,
        isNull,
      );
    });
  }
  for (final useSafe in [false, true]) {
    testWidgets(
      'sheet consumes bottom safe area only when requested ($useSafe)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        double? receivedPadding;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(bottom: 34)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showMobileSheet<void>(context, (context) {
                    receivedPadding = MediaQuery.paddingOf(context).bottom;
                    return const SafeArea(
                      child: SizedBox(height: 100, width: double.infinity),
                    );
                  }, useSafeArea: useSafe),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(receivedPadding, useSafe ? 0 : 34);
        expect(
          tester.getBottomRight(find.byType(GlassSurface)).dy,
          useSafe ? 798 : 832,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final embedded in [false, true]) {
    testWidgets('Liquid page owns or reuses its environment ($embedded)', (
      tester,
    ) async {
      const page = HermesPageScaffold(
        title: 'Page',
        showAppBar: false,
        body: Text('Content'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: embedded ? const GlassEnvironment(child: page) : page,
        ),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (box) =>
                box.decoration is BoxDecoration &&
                (box.decoration as BoxDecoration).gradient != null,
          );
      expect(gradients.length, 1);
      expect(find.text('Content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('explicit page backgrounds override the Liquid environment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.dark,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const HermesPageScaffold(
          title: 'Editor',
          backgroundColor: Colors.black,
          body: SizedBox(),
        ),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.black,
    );
    expect(find.byType(GlassEnvironment), findsNothing);
  });
  for (final style in HermesVisualStyle.values) {
    testWidgets('compact scrolling header samples content in $style', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: style,
          ),
          home: HermesPageScaffold(
            title: 'Settings',
            subtitle: 'Preferences',
            scrollable: true,
            actions: [
              IconButton(
                onPressed: () => presses++,
                icon: const Icon(Icons.add),
              ),
            ],
            body: Column(
              children: List.generate(
                30,
                (i) => SizedBox(
                  height: 80,
                  child: Center(child: Text('Content $i')),
                ),
              ),
            ),
          ),
        ),
      );
      final titleTop = tester.getTopLeft(find.text('Settings')).dy;
      expect(
        tester.getTopLeft(find.text('Content 0')).dy,
        greaterThan(titleTop),
      );
      final scroll = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scroll).position.jumpTo(80);
      await tester.pump();
      expect(tester.getTopLeft(find.text('Settings')).dy, titleTop);
      if (style == HermesVisualStyle.liquid) {
        expect(find.byType(SliverAppBar), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Content 0')).dy,
          lessThan(titleTop),
        );
        expect(find.byType(BackdropFilter), findsOneWidget);
      } else {
        expect(find.byType(SliverAppBar), findsNothing);
      }
      await tester.tap(find.byIcon(Icons.add));
      expect(presses, 1);
      tester.state<ScrollableState>(scroll).position.jumpTo(10000);
      await tester.pumpAndSettle();
      expect(find.text('Content 29').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('unadapted dialog and sheet themes keep an opaque readable base', () {
    for (final brightness in Brightness.values) {
      final theme = buildHermesTheme(
        brightness: brightness,
        visualStyle: HermesVisualStyle.liquid,
      );
      expect(theme.dialogTheme.backgroundColor!.a, 1);
      expect(theme.bottomSheetTheme.backgroundColor!.a, 1);
      expect(theme.bottomSheetTheme.modalBackgroundColor!.a, 1);
    }
  });
  for (final reduced in [false, true]) {
    testWidgets(
      'environment has a solid base under accessibility (reduced=$reduced)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
              reduceTransparency: reduced,
            ),
            home: MediaQuery(
              data: MediaQueryData(highContrast: !reduced),
              child: const GlassEnvironment(child: SizedBox.expand()),
            ),
          ),
        );
        final base = find.descendant(
          of: find.byType(GlassEnvironment),
          matching: find.byType(ColoredBox),
        );
        expect(base, findsOneWidget);
        expect(tester.widget<ColoredBox>(base).color.a, 1);
        expect(
          find.descendant(
            of: find.byType(GlassEnvironment),
            matching: find.byType(DecoratedBox),
          ),
          findsNothing,
        );
      },
    );
  }
  testWidgets('specular layer fills a loosely constrained surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const Scaffold(
          body: Center(
            child: GlassSurface(
              child: SizedBox(
                key: ValueKey('surface-foreground'),
                width: 240,
                height: 80,
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('glass-specular-layer'))),
      const Size(240, 80),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    final materialStack = tester.widget<Stack>(
      find
          .descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(Stack),
          )
          .first,
    );
    // Foreground paints last; the highlight must never wash out labels/icons.
    final foreground = find.byKey(const ValueKey('surface-foreground'));
    expect(tester.getSize(foreground), const Size(240, 80));
    final foregroundStack = tester.widget<Stack>(
      find.ancestor(of: foreground, matching: find.byType(Stack)).first,
    );
    expect(foregroundStack.children.last, tester.widget(foreground));
    expect(
      find.descendant(
        of: find.byWidget(materialStack.children.last),
        matching: foreground,
      ),
      findsOneWidget,
    );
    expect(materialStack.children.take(2), everyElement(isA<Positioned>()));
    expect(tester.takeException(), isNull);
  });
  test('Liquid theme publishes distinct popup and menu surfaces', () {
    final theme = buildHermesTheme(
      brightness: Brightness.light,
      visualStyle: HermesVisualStyle.liquid,
    );
    final popup = theme.popupMenuTheme;
    expect(popup.surfaceTintColor, Colors.transparent);
    expect(popup.shape, isA<RoundedRectangleBorder>());
    final menu = theme.menuTheme.style!;
    expect(menu.surfaceTintColor?.resolve({}), Colors.transparent);
    expect(menu.shape?.resolve({}), isA<RoundedRectangleBorder>());
    expect(
      (popup.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(HermesGlassTokens.controlRadius),
    );
    expect(menu.backgroundColor!.resolve({})!.a, 1);
    expect(popup.color!.a, 1);
    expect(
      theme.dropdownMenuTheme.menuStyle!.backgroundColor!.resolve({})!.a,
      1,
    );
    for (final reduced in [false, true]) {
      final dark = buildHermesTheme(
        brightness: Brightness.dark,
        visualStyle: HermesVisualStyle.liquid,
        reduceTransparency: reduced,
      );
      expect(dark.menuTheme.style!.elevation!.resolve({}), 0);
      if (reduced) {
        expect(dark.menuTheme.style!.backgroundColor!.resolve({})!.a, 1);
      }
    }
  });

  testWidgets('glass environment stays inert in Classic', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(brightness: Brightness.light),
        home: const GlassEnvironment(child: Text('Content')),
      ),
    );
    expect(find.byType(DecoratedBox), findsNothing);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('Liquid surface adds specular layer without extra blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.dark,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const Scaffold(body: GlassSurface(child: Text('Readable'))),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(Stack), findsWidgets);
    expect(find.text('Readable'), findsOneWidget);
  });

  testWidgets(
    'extended page scrolls beneath navigation without hiding last row',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: Scaffold(
            extendBody: true,
            bottomNavigationBar: const SizedBox(
              key: ValueKey('nav'),
              height: 90,
            ),
            body: Builder(
              builder: (context) => HermesPageScaffold(
                title: 'Page',
                extendBehindNavigation: true,
                body: ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: 30,
                  itemExtent: 60,
                  itemBuilder: (_, i) => Text('Row $i'),
                ),
              ),
            ),
          ),
        ),
      );
      final list = find.byType(ListView);
      final navigation = tester.getRect(find.byKey(const ValueKey('nav')));
      expect(tester.getRect(list).bottom, navigation.bottom);
      await tester.drag(list, const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Row 29')).bottom,
        lessThanOrEqualTo(navigation.top),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final phone in [false, true]) {
    testWidgets(
      'Liquid form preserves editing and action result phone=$phone',
      (tester) async {
        String? result;
        if (phone) {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.reset);
        }
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(phone ? 2 : 1)),
              child: child!,
            ),
            theme: buildHermesTheme(
              brightness: Brightness.dark,
              visualStyle: HermesVisualStyle.liquid,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showAdaptiveFormDialog<String>(
                      context: context,
                      title: 'Form',
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TextField(),
                          if (phone)
                            ...List.generate(20, (i) => Text('Form field $i')),
                        ],
                      ),
                      actions: [
                        Builder(
                          builder: (ctx) => TextButton(
                            onPressed: () => Navigator.of(ctx).pop('saved'),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
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
        expect(find.byType(BackdropFilter), findsOneWidget);
        if (phone) {
          final glass = tester.getRect(find.byType(GlassSurface));
          expect(glass.bottom, lessThanOrEqualTo(532));
          expect(find.text('Save').hitTestable(), findsOneWidget);
          final padding = tester.widget<AnimatedPadding>(
            find.byKey(const ValueKey('adaptive-phone-form-sheet')),
          );
          expect(padding.padding, EdgeInsets.zero);
        }
        await tester.enterText(find.byType(TextField), 'workspace');
        await tester.pumpAndSettle();
        if (phone) {
          await tester.scrollUntilVisible(
            find.text('Form field 19'),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(find.text('Form field 19').hitTestable(), findsOneWidget);
          expect(find.text('Save').hitTestable(), findsOneWidget);
        }
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(result, 'saved');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('system high contrast disables glass sampling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.dark,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: Scaffold(body: GlassSurface(child: Text('Readable'))),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
    'nested glass shares one backdrop and controls remain actionable',
    (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.dark,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: Scaffold(
            body: GlassSurface(
              child: GlassSurface(
                child: GlassButton(
                  tooltip: 'Action',
                  onPressed: () => presses++,
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await tester.tap(find.byType(IconButton));
      expect(presses, 1);
    },
  );

  testWidgets('liquid sheet constrains long content above keyboard in RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.light,
          visualStyle: HermesVisualStyle.liquid,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: const EdgeInsets.only(bottom: 240),
            textScaler: const TextScaler.linear(2),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMobileSheet<void>(
                context,
                (_) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: 50,
                  itemBuilder: (_, i) => ListTile(title: Text('Option $i')),
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
    expect(find.byType(BackdropFilter), findsOneWidget);
    final panel = tester.getRect(find.byType(GlassSurface));
    final route = tester.getRect(find.byType(BottomSheet));
    expect(panel.left - route.left, greaterThanOrEqualTo(12));
    expect(route.right - panel.right, panel.left - route.left);
    expect(route.bottom - panel.bottom, 252);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('Liquid style and reduced transparency survive reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppearanceStore();
    await store.setVisualStyle(HermesVisualStyle.liquid);
    await store.setReduceTransparency(true);
    final restored = AppearanceStore();
    await restored.load();
    expect(restored.visualStyle, HermesVisualStyle.liquid);
    expect(restored.reduceTransparency, isTrue);
    store.dispose();
    restored.dispose();
  });
  testWidgets('glass respects classic and opaque appearance', (tester) async {
    for (final style in HermesVisualStyle.values) {
      for (final opaque in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: style,
              reduceTransparency: opaque,
            ),
            home: const Scaffold(body: GlassSurface(child: Text('Content'))),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(BackdropFilter),
          style == HermesVisualStyle.liquid && !opaque
              ? findsOneWidget
              : findsNothing,
        );
        expect(find.text('Content'), findsOneWidget);
      }
    }
  });
}
