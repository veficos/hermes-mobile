import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/sheets/option_sheet.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('Liquid options wrap labels and return selection ($reduced)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.dark,
            visualStyle: HermesVisualStyle.liquid,
            reduceTransparency: reduced,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showChatOptionSheet<String>(
                    context,
                    title: 'Reasoning',
                    subtitle: 'Choose effort',
                    current: 'high',
                    selectedLabel: 'Currently selected reasoning effort',
                    options: const [
                      ('high', Icons.whatshot),
                      ('low', Icons.eco),
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
      expect(
        find.byType(BackdropFilter),
        reduced ? findsNothing : findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Currently selected reasoning effort'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('low'));
      await tester.tap(find.text('low'));
      await tester.pumpAndSettle();
      expect(result, 'low');
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
