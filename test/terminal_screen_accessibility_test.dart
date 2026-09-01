import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/terminal_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/terminal_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('terminal supports Arabic RTL at 320px and 2x text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final connection = ConnectionStore();
    final terminal = TerminalStore(connection: connection);
    addTearDown(terminal.dispose);
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<TerminalStore>.value(value: terminal),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const TerminalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ar = AppLocalizations.of(tester.element(find.byType(TerminalScreen)));
    expect(find.text(ar.featureTerminal), findsOneWidget);
    expect(find.text('终端'), findsNothing);
    expect(
      Directionality.of(tester.element(find.byType(TerminalScreen))),
      TextDirection.rtl,
    );
    semantics.dispose();
  });
}
