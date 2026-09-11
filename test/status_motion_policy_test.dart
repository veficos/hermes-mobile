import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/widgets/h/hermes_status.dart';
import 'package:hermes_mobile/widgets/h/hermes_states.dart';

void main() {
  testWidgets(
    'typing dots keep cycling and cancel delayed starts on policy change',
    (tester) async {
      Widget app({bool reduce = false, bool navigation = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduce,
            accessibleNavigation: navigation,
          ),
          child: const Center(child: HermesTypingDots()),
        ),
      );
      final scales = find.descendant(
        of: find.byType(HermesTypingDots),
        matching: find.byType(ScaleTransition),
      );
      for (final navigation in [false, true]) {
        await tester.pumpWidget(app());
        await tester.pump(const Duration(milliseconds: 80));
        // Switch before the second and third delayed starts are due.
        await tester.pumpWidget(
          app(reduce: !navigation, navigation: navigation),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(scales, findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        expect(
          tester.getSize(find.byType(HermesTypingDots)),
          const Size(40, 18),
        );
        await tester.pumpWidget(app());
        for (var frame = 0; frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(scales, findsNWidgets(3));
        final before = tester
            .widgetList<ScaleTransition>(scales)
            .map((w) => w.scale.value)
            .toList();
        await tester.pump(const Duration(milliseconds: 100));
        final after = tester
            .widgetList<ScaleTransition>(scales)
            .map((w) => w.scale.value)
            .toList();
        for (var i = 0; i < 3; i++) {
          expect(after[i], isNot(before[i]));
        }
        expect(after.toSet().length, greaterThan(1));
        await tester.pumpWidget(const SizedBox());
      }
      // Removal during the start delay must also cancel the timers.
      await tester.pumpWidget(app());
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('skeleton stops scheduling frames for both runtime policies', (
    tester,
  ) async {
    Widget app({bool reduce = false, bool navigation = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduce,
          accessibleNavigation: navigation,
        ),
        child: const Center(child: HermesSkeletonBlock(width: 160)),
      ),
    );
    for (final navigation in [false, true]) {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      final size = tester.getSize(find.byType(HermesSkeletonBlock));
      await tester.pumpWidget(app(reduce: !navigation, navigation: navigation));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.getSize(find.byType(HermesSkeletonBlock)), size);
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  for (final navigation in [false, true]) {
    testWidgets(
      'status pulse stops and resumes runtime policy navigation=$navigation',
      (tester) async {
        Widget app(bool reduce) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: !navigation && reduce,
              accessibleNavigation: navigation && reduce,
            ),
            child: const Scaffold(
              body: Center(
                child: HermesStatusChip(
                  color: Colors.green,
                  label: 'Running',
                  pulse: true,
                ),
              ),
            ),
          ),
        );
        final fades = find.descendant(
          of: find.byType(HermesStatusChip),
          matching: find.byType(FadeTransition),
        );
        await tester.pumpWidget(app(true));
        await tester.pumpAndSettle();
        expect(fades, findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        final size = tester.getSize(find.byType(HermesStatusChip));
        for (var cycle = 0; cycle < 2; cycle++) {
          await tester.pumpWidget(app(false));
          await tester.pump(const Duration(milliseconds: 150));
          expect(fades, findsOneWidget);
          final first = tester.widget<FadeTransition>(fades).opacity.value;
          await tester.pump(const Duration(milliseconds: 150));
          expect(
            tester.widget<FadeTransition>(fades).opacity.value,
            lessThan(first),
          );
          expect(tester.binding.transientCallbackCount, greaterThan(0));
          await tester.pumpWidget(app(true));
          await tester.pumpAndSettle();
          expect(fades, findsNothing);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.getSize(find.byType(HermesStatusChip)), size);
          expect(find.text('Running'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }
}
