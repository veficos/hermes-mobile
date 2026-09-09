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
    expect(menu.backgroundColor!.resolve({})!.a, closeTo(.92, .005));
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

  testWidgets('wide Liquid form preserves editing and action result', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
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
                  content: const TextField(),
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
    await tester.enterText(find.byType(TextField), 'workspace');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'saved');
    expect(tester.takeException(), isNull);
  });

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
