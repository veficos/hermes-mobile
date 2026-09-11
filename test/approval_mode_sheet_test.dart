import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/sheets/approval_mode_sheet.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_selection_row.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    testWidgets(
      '$style approval selection remains reachable on short screens',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: style,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showChatApprovalModeSheet(
                      context,
                      current: 'smart',
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
        final rows = tester.widgetList<GlassSelectionRow>(
          find.byType(GlassSelectionRow),
        );
        expect(rows.map((row) => row.selected), [false, true, false]);
        final option = find.byWidgetPredicate(
          (widget) => widget is RadioListTile<String> && widget.value == 'off',
        );
        await Scrollable.ensureVisible(tester.element(option), alignment: 1);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(result, 'off');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
