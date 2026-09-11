import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/sheets/slash_help_dialog.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final liquid in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets('slash help liquid=$liquid reduced=$reduced', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        addTearDown(tester.view.reset);
        final connection = ConnectionStore();
        final commands = CommandStore(connection: connection);
        addTearDown(commands.dispose);
        addTearDown(connection.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: commands,
            child: MaterialApp(
              theme: buildHermesTheme(
                brightness: Brightness.light,
                visualStyle: liquid
                    ? HermesVisualStyle.liquid
                    : HermesVisualStyle.classic,
                reduceTransparency: reduced,
              ),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(liquid ? 2 : 1)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showChatSlashHelpDialog(context),
                    child: const Text('Open help'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open help'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final panel = find.byKey(const ValueKey('slash-help-glass'));
        expect(panel, liquid ? findsOneWidget : findsNothing);
        expect(
          find.byType(BackdropFilter),
          liquid && !reduced ? findsOneWidget : findsNothing,
        );
        if (liquid) {
          final bounds = tester.getRect(panel);
          expect(bounds.left, greaterThanOrEqualTo(12));
          expect(bounds.right, lessThanOrEqualTo(378));
          expect(bounds.top, greaterThanOrEqualTo(71));
          expect(bounds.bottom, lessThanOrEqualTo(542));
        }
        final close = find.widgetWithText(TextButton, 'Close');
        expect(close.hitTestable(), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(close.hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
