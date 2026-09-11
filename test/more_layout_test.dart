import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/more_screen.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_mobile_surfaces.dart';
import 'support/review_capture.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final style in HermesVisualStyle.values) {
    for (final scale in [1.0, 2.0]) {
      for (final width in [320.0, 390.0, 430.0, 768.0, 1280.0]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'More directory width=$width scale=$scale $brightness ${style.name}',
            (tester) async {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final connection = ConnectionStore();
              final chat = ChatStore();
              final requests = RequestStore();
              final session = SessionStore(
                connection: connection,
                chat: chat,
                requests: requests,
              );
              addTearDown(() {
                session.dispose();
                requests.dispose();
                chat.dispose();
                connection.dispose();
              });
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(value: connection),
                    ChangeNotifierProvider.value(value: session),
                  ],
                  child: MaterialApp(
                    locale: const Locale('zh'),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: buildHermesTheme(
                      brightness: brightness,
                      visualStyle: style,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: const RepaintBoundary(
                      key: ValueKey('more-review'),
                      child: MoreScreen(),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(find.text('Hermes Mobile'), findsOneWidget);
              final l10n = AppLocalizations.of(
                tester.element(find.byType(MoreScreen)),
              );
              expect(find.text(l10n.commonOffline), findsOneWidget);
              expect(find.text(l10n.commonIdle), findsNothing);
              expect(
                tester
                    .widgetList<HermesMobileRow>(find.byType(HermesMobileRow))
                    .every((row) => row.alignLeadingToTop),
                isTrue,
              );
              expect(tester.takeException(), isNull);
              const reviewDir = String.fromEnvironment('UI_REVIEW_DIR');
              if (reviewDir.isNotEmpty) {
                await captureReview(
                  tester,
                  find.byKey(const ValueKey('more-review')),
                  '$reviewDir/more-${style == HermesVisualStyle.classic ? 'classic-' : ''}${brightness.name}-$scale${width == 320 ? '' : '-${width.toInt()}'}.png',
                );
              }
              final directoryCount = find
                  .byType(HermesMobileRow)
                  .evaluate()
                  .length;
              await tester.tap(find.byTooltip(l10n.moreSearchDirectory));
              await tester.pumpAndSettle();
              expect(find.text('Hermes Mobile'), findsNothing);
              expect(find.byType(TextField).hitTestable(), findsOneWidget);
              await tester.enterText(find.byType(TextField), '  SHELL  ');
              await tester.pumpAndSettle();
              expect(find.byType(HermesMobileRow), findsOneWidget);
              expect(
                find.text(l10n.featureTerminal).hitTestable(),
                findsOneWidget,
              );
              await tester.enterText(find.byType(TextField), 'settings 外观');
              await tester.pumpAndSettle();
              expect(find.byType(HermesMobileRow), findsOneWidget);
              await tester.enterText(
                find.byType(TextField),
                'no-match-xyz-987',
              );
              await tester.pumpAndSettle();
              expect(
                find.text(l10n.moreNoMatches).hitTestable(),
                findsOneWidget,
              );
              expect(find.byType(HermesMobileRow), findsNothing);
              await tester.tap(find.byTooltip(l10n.moreCloseSearch));
              await tester.pumpAndSettle();
              expect(find.text('Hermes Mobile'), findsOneWidget);
              expect(find.byType(TextField), findsNothing);
              expect(
                find.byType(HermesMobileRow),
                findsNWidgets(directoryCount),
              );
              final directory = find.byKey(
                const PageStorageKey('more-directory'),
              );
              final scrollable = find
                  .descendant(of: directory, matching: find.byType(Scrollable))
                  .first;
              final position = tester
                  .state<ScrollableState>(scrollable)
                  .position;
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
              final savedOffset = position.pixels;
              expect(savedOffset, greaterThan(0));
              await tester.tap(find.byTooltip(l10n.moreSearchDirectory));
              await tester.pumpAndSettle();
              expect(find.byType(TextField).hitTestable(), findsOneWidget);
              tester.testTextInput.updateEditingValue(
                const TextEditingValue(
                  text: 'zhong',
                  selection: TextSelection.collapsed(offset: 5),
                  composing: TextRange(start: 0, end: 5),
                ),
              );
              await tester.pumpAndSettle();
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(
                find.byType(TextField),
                findsOneWidget,
                reason: 'Composition Escape must not dismiss directory search',
              );
              tester.testTextInput.updateEditingValue(
                const TextEditingValue(
                  text: '中',
                  selection: TextSelection.collapsed(offset: 1),
                ),
              );
              await tester.pumpAndSettle();
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(find.byType(TextField), findsNothing);
              expect(
                tester.state<ScrollableState>(scrollable).position.pixels,
                closeTo(savedOffset, 1),
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              await tester.pumpAndSettle();
              expect(
                find.byType(TextField),
                findsOneWidget,
                reason: 'Search trigger regains keyboard focus after close',
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
