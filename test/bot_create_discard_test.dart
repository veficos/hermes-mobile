import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/core/stores/bot_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/screens/bot_create_screen.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/widgets/glass/glass_alert_dialog.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';

class _PendingBots extends BotStore {
  _PendingBots(super.connection);
  final completion = Completer<void>();
  int calls = 0;

  @override
  Future<void> createBot({
    required String name,
    String? title,
    String? description,
    String cloneFrom = 'default',
    String? customSoul,
    bool noSkills = false,
    bool shareAuth = false,
    String? model,
    String? provider,
    ConnectionId? connectionId,
  }) {
    calls++;
    return completion.future;
  }
}

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final success in [false, true]) {
      testWidgets('Bot create busy back and result $style success=$success', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final connection = ConnectionStore();
        final bots = _PendingBots(connection);
        Object? result;
        await tester.pumpWidget(
          ChangeNotifierProvider<BotStore>.value(
            value: bots,
            child: MaterialApp(
              theme: buildHermesTheme(
                brightness: Brightness.light,
                visualStyle: style,
              ),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const BotCreateScreen(),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(BotCreateScreen), findsNothing);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'review-bot');
        await tester.pump();
        await tester.ensureVisible(find.text('Create'));
        await tester.tap(find.text('Create'));
        await tester.pump();
        final navigator = Navigator.of(
          tester.element(find.byType(BotCreateScreen)),
        );
        await tester.tap(find.byTooltip('Back'));
        await navigator.maybePop();
        await tester.pump();
        expect(find.byType(BotCreateScreen), findsOneWidget);
        expect(find.byType(GlassAlertDialog), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(bots.calls, 1);
        if (success) {
          bots.completion.complete();
        } else {
          bots.completion.completeError(StateError('Creation failed'));
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(BotCreateScreen),
          success ? findsNothing : findsOneWidget,
        );
        if (success) {
          expect(result, isTrue);
          expect(find.byType(GlassAlertDialog), findsNothing);
        } else {
          expect(find.text('review-bot'), findsOneWidget);
          expect(find.textContaining('Creation failed'), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.byType(GlassAlertDialog), findsOneWidget);
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(find.text('review-bot'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        bots.dispose();
        connection.dispose();
      });
    }
  }
  testWidgets('Bot create retains draft on cancel and exits only on discard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final connection = ConnectionStore();
    final bots = BotStore(connection);
    await tester.pumpWidget(
      ChangeNotifierProvider<BotStore>.value(
        value: bots,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BotCreateScreen(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'review-bot');
    await tester.pump();
    final navigator = Navigator.of(
      tester.element(find.byType(BotCreateScreen)),
    );
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(GlassAlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('review-bot'), findsOneWidget);
    expect(find.byType(BotCreateScreen), findsOneWidget);
    await navigator.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(BotCreateScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    bots.dispose();
    connection.dispose();
  });
}
