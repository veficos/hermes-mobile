import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/timeline/chat_timeline.dart';
import 'package:hermes_mobile/chat/timeline/turn_activity_card.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'Liquid activity wraps at 200px and respects opacity: $reduced',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
              reduceTransparency: reduced,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SizedBox(
                  width: 200,
                  child: TurnActivityCard(
                    activity: TurnActivity(
                      id: 'turn',
                      startIndex: 0,
                      endIndex: 2,
                      startedAt: DateTime(2026),
                      completedAt: DateTime(
                        2026,
                      ).add(const Duration(minutes: 5)),
                      toolCount: 123,
                      reasoningBlocks: 45,
                      running: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(TurnActivityCard),
            matching: find.byType(Container),
          ),
        );
        expect(
          (container.decoration! as BoxDecoration).color!.a,
          closeTo(reduced ? 1 : .78, .005),
        );
        expect(tester.getSize(find.byType(TurnActivityCard)).width, 200);
      },
    );
  }
}
