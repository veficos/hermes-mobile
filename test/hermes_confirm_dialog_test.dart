import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_confirm_dialog.dart';
import 'package:hermes_mobile/widgets/h/hermes_button.dart';

void main() {
  for (final liquid in [false, true]) {
    testWidgets('confirmation preserves outcomes liquid=$liquid', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: liquid
                ? HermesVisualStyle.liquid
                : HermesVisualStyle.classic,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showHermesConfirmDialog(
                    context: context,
                    title: 'Delete item',
                    message: 'This cannot be undone.',
                    destructive: true,
                    confirmLabel: 'Delete',
                    cancelLabel: 'Cancel',
                  );
                },
              ),
            ),
          ),
        ),
      );
      for (final action in ['Cancel', 'Delete', 'barrier']) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          find.byType(BackdropFilter),
          liquid ? findsOneWidget : findsNothing,
        );
        final button = tester.widget<HermesButton>(
          find.widgetWithText(HermesButton, 'Delete'),
        );
        expect(button.variant, HermesButtonVariant.destructive);
        if (action == 'barrier') {
          await tester.tapAt(const Offset(2, 2));
        } else {
          await tester.tap(find.text(action));
        }
        await tester.pumpAndSettle();
        expect(result, action == 'Delete');
        expect(tester.takeException(), isNull);
      }
    });
  }
}
