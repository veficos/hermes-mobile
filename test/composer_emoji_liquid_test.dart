import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';
import 'package:hermes_mobile/widgets/glass/glass_action_group.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';

void main() {
  for (final mode in ['animated', 'disabled', 'accessible']) {
    testWidgets('Liquid toolbar expansion motion $mode', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: mode == 'disabled',
              accessibleNavigation: mode == 'accessible',
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: HermesComposer(controller: controller, onSend: (_) {}),
              ),
            ),
          ),
        ),
      );
      final expansion = find.byKey(const ValueKey('composer-tools-expansion'));
      final collapsed = tester.getSize(expansion).height;
      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final intermediate = tester.getSize(expansion).height;
      await tester.pumpAndSettle();
      final expanded = tester.getSize(expansion).height;
      expect(expanded, greaterThan(collapsed));
      if (mode == 'animated') {
        expect(intermediate, greaterThan(collapsed));
        expect(intermediate, lessThan(expanded));
      } else {
        expect(intermediate, expanded);
      }
      await tester.tap(find.byIcon(Icons.emoji_emotions));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final shrinking = tester.getSize(expansion).height;
      if (mode == 'animated') {
        expect(shrinking, greaterThan(collapsed));
        expect(shrinking, lessThan(expanded));
      } else {
        expect(shrinking, collapsed);
      }
      await tester.pumpAndSettle();
      expect(tester.getSize(expansion).height, collapsed);
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    for (final reduced in [false, true]) {
      testWidgets(
        'Liquid emoji targets and insertion at 320px $brightness reduced=$reduced',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesTheme(
                brightness: brightness,
                visualStyle: HermesVisualStyle.liquid,
                reduceTransparency: reduced,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: HermesComposer(
                    controller: controller,
                    onSend: (_) {},
                    personalityLabel: 'Profile',
                    workspaceLabel: 'Workspace',
                    modelLabel: 'Model',
                    difficultyLabel: 'High',
                    yoloEnabled: false,
                    onToolsTap: () {},
                    quotaLabel: 'Quota',
                  ),
                ),
              ),
            ),
          );
          final toggle = find.byIcon(Icons.emoji_emotions_outlined);
          expect(toggle.hitTestable(), findsOneWidget);
          final tools = find.ancestor(
            of: find.byIcon(Icons.person_outline),
            matching: find.byType(SingleChildScrollView),
          );
          final initialToggleRect = tester.getRect(toggle);
          final restingFilterCount = find
              .byType(BackdropFilter)
              .evaluate()
              .length;
          expect(restingFilterCount, reduced ? 0 : greaterThan(0));
          await tester.drag(tools, const Offset(-220, 0));
          await tester.pumpAndSettle();
          expect(tester.getRect(toggle), initialToggleRect);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          final panelGroup = find.ancestor(
            of: find.byType(GridView),
            matching: find.byType(GlassActionGroup),
          );
          expect(panelGroup, findsOneWidget);
          expect(
            find.descendant(
              of: panelGroup,
              matching: find.byType(GlassSurface),
            ),
            findsOneWidget,
          );
          expect(
            find.byType(BackdropFilter).evaluate().length,
            restingFilterCount,
          );
          final close = find.ancestor(
            of: find.byIcon(Icons.close),
            matching: find.byType(GlassButton),
          );
          expect(close, findsOneWidget);
          expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
          final emoji = find.ancestor(
            of: find.text('😀'),
            matching: find.byType(InkWell),
          );
          expect(tester.getSize(emoji).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(emoji).height, greaterThanOrEqualTo(44));
          await tester.tap(emoji);
          await tester.pump();
          expect(controller.text, '😀');
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(find.byType(GridView), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
