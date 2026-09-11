import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/core/stores/keybind_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/keybind_settings_screen.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_alert_dialog.dart';

void main() {
  for (final liquid in [false, true]) {
    for (final embedded in [false, true]) {
      testWidgets('keybind layout liquid=$liquid embedded=$embedded', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = KeybindStore();
        addTearDown(store.dispose);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: store,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildHermesTheme(
                brightness: Brightness.light,
                visualStyle: liquid
                    ? HermesVisualStyle.liquid
                    : HermesVisualStyle.classic,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: embedded
                  ? const Scaffold(body: KeybindSettingsScreen(embedded: true))
                  : const KeybindSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byType(SliverAppBar),
          liquid && !embedded ? findsOneWidget : findsNothing,
        );
        expect(find.byType(ListView), embedded ? findsOneWidget : findsNothing);
        final change = find.widgetWithText(TextButton, 'Change').first;
        await tester.ensureVisible(change);
        await tester.tap(change);
        await tester.pumpAndSettle();
        expect(find.byType(GlassAlertDialog), findsOneWidget);
        expect(
          find.byType(AlertDialog),
          liquid ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Change'));
        await tester.pumpAndSettle();
        expect(
          store.bindingsFor('chat.undo').single.trigger,
          LogicalKeyboardKey.keyK,
        );
        expect(find.byType(GlassAlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
