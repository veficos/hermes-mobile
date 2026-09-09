import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/core/app_navigation.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_palette_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/session_tab_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:hermes_mobile/widgets/command_palette.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for the command palette overlay lifecycle:
///
/// * `_selectCurrent` closes the palette (unmounting the overlay State on the
///   next frame) and only then awaits `resumeSession`. Gating the navigation
///   on the overlay's `context.mounted` used to drop the ChatScreen push and
///   swallow failures. The push must ride the captured root navigator, and
///   errors must surface through `hermesNavigatorKey`'s context.
/// * The palette is not a route, so the Android back button used to pop the
///   route underneath while the palette stayed open. A PopScope now turns the
///   first back press into "close palette".
class _OverlaySessionStore extends SessionStore {
  _OverlaySessionStore({required super.connection, required super.chat})
    : super(requests: RequestStore());

  final List<SessionRow> rows = [
    SessionRow(id: 'session-42', title: 'Target session'),
  ];
  final Map<String, Completer<void>> resumeGates = {};
  final List<String> resumed = [];

  @override
  List<SessionRow>? get sessions => rows;

  @override
  Future<void> resumeSession(String durableId, {String? profile}) {
    resumed.add(durableId);
    return resumeGates[durableId]?.future ?? Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<
    ({
      _OverlaySessionStore sessions,
      CommandPaletteStore palette,
      ConnectionStore connection,
      ChatStore chat,
      CommandStore commands,
    })
  >
  pumpHarness(WidgetTester tester, {bool attachNavigatorKey = false}) async {
    final connection = ConnectionStore();
    final chat = ChatStore();
    final sessions = _OverlaySessionStore(connection: connection, chat: chat);
    final commands = CommandStore(connection: connection);
    final palette = CommandPaletteStore(session: sessions, commands: commands);
    addTearDown(() {
      palette.dispose();
      sessions.dispose();
      commands.dispose();
      chat.dispose();
      connection.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProxyProvider<ConnectionStore, SessionTabStore>(
            create: (_) => SessionTabStore(),
            update: (_, connection, tabs) => (tabs ?? SessionTabStore())
              ..attachRoutedEvents(
                connection.routedEvents,
                owners: connection.sessionOwners,
              ),
          ),
          ChangeNotifierProvider<SessionStore>.value(value: sessions),
          ChangeNotifierProvider<ChatStore>.value(value: chat),
          ChangeNotifierProvider<CommandPaletteStore>.value(value: palette),
          ChangeNotifierProvider.value(
            value: VoiceStore(connection: connection),
          ),
          ChangeNotifierProvider<CommandStore>.value(value: commands),
          ChangeNotifierProvider(create: (_) => ToolDismissStore()),
        ],
        child: MaterialApp(
          navigatorKey: attachNavigatorKey ? hermesNavigatorKey : null,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CommandPalette()),
        ),
      ),
    );
    return (
      sessions: sessions,
      palette: palette,
      connection: connection,
      chat: chat,
      commands: commands,
    );
  }

  testWidgets(
    'selecting a session pushes ChatScreen after the overlay unmounts',
    (tester) async {
      final harness = await pumpHarness(tester);
      final gate = Completer<void>();
      harness.sessions.resumeGates['session-42'] = gate;

      harness.palette.open();
      // Filter down to the session result: the defaults list is taller than
      // the test viewport, so an unfiltered ListView never builds the tile.
      harness.palette.setQuery('Target');
      await tester.pumpAndSettle();
      expect(find.text('Target session'), findsOneWidget);

      await tester.tap(find.text('Target session'));
      // close() unmounts the overlay State on this frame while resumeSession
      // is still in flight — the interleaving that used to kill the push.
      await tester.pump();
      expect(find.byType(CommandPaletteOverlay), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(harness.sessions.resumed, ['session-42']);
      expect(find.byType(ChatScreen), findsOneWidget);
    },
  );

  testWidgets('a failed resume surfaces an error after the overlay unmounts', (
    tester,
  ) async {
    final harness = await pumpHarness(tester, attachNavigatorKey: true);
    final gate = Completer<void>();
    harness.sessions.resumeGates['session-42'] = gate;

    harness.palette.open();
    harness.palette.setQuery('Target');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target session'));
    await tester.pump();
    expect(find.byType(CommandPaletteOverlay), findsNothing);
    gate.completeError(StateError('boom'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(harness.sessions.resumed, ['session-42']);
    expect(find.byType(ChatScreen), findsNothing);
    expect(
      find.text(AppLocalizationsZh().commonOperationFailed),
      findsOneWidget,
    );
  });

  testWidgets('system back closes the palette instead of the route below', (
    tester,
  ) async {
    final harness = await pumpHarness(tester);

    harness.palette.open();
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteOverlay), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(harness.palette.isOpen, isFalse);
    expect(find.byType(CommandPaletteOverlay), findsNothing);
    // The route underneath survived: the host page is still shown.
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
