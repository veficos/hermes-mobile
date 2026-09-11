import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/terminal_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/terminal/terminal_workspace.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';

class _ActiveTerminal extends TerminalStore {
  _ActiveTerminal(ConnectionStore superConnection)
    : super(connection: superConnection);
  final output = Terminal()..write('Workspace ready');
  final item = TerminalSession(
    id: 'local',
    runtimeSessionId: 'runtime',
    title: 'Shell',
    cwd: '/workspace',
    createdAt: DateTime(2026),
  );
  @override
  List<TerminalSession> get sessions => [item];
  @override
  String? get activeId => item.id;
  @override
  TerminalSession? get activeSession => item;
  @override
  Terminal? get activeTerminal => output;
  @override
  Terminal? terminal(String id) => output;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'active Liquid terminal keeps an opaque reading plane $brightness',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final connection = ConnectionStore();
        final store = _ActiveTerminal(connection);
        addTearDown(store.dispose);
        addTearDown(connection.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<TerminalStore>.value(
            value: store,
            child: MaterialApp(
              theme: buildHermesTheme(
                brightness: brightness,
                visualStyle: HermesVisualStyle.liquid,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: TerminalWorkspace()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final view = find.byType(TerminalView);
        expect(view, findsOneWidget);
        expect(tester.widget<TerminalView>(view).backgroundOpacity, 1);
        final backing =
            tester
                    .widget<DecoratedBox>(
                      find
                          .ancestor(
                            of: view,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(backing.color!.a, 1);
        expect(backing.boxShadow, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
