import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/preview_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/screens/mcp_logs_screen.dart';
import 'package:hermes_mobile/widgets/right_sidebar/right_sidebar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SidebarApi extends ApiClient {
  _SidebarApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int logCalls = 0;

  @override
  Future<List<ArtifactItem>> artifacts({
    String? sessionId,
    int limit = 50,
    int offset = 0,
  }) async => const [];

  @override
  Future<dynamic> getLogs({
    String file = 'agent',
    int lines = 200,
    String? level,
    String? component,
    String? search,
  }) async {
    logCalls++;
    return {
      'lines': ['real server log line'],
    };
  }
}

class _SidebarSession extends SessionStore {
  _SidebarSession({
    required super.connection,
    required super.chat,
    required super.requests,
  });

  @override
  String? get durableId => 'session-1';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final mode in ['classic', 'liquid', 'opaque', 'nested', 'scaled']) {
    testWidgets('right sidebar material and real server logs: $mode', (
      tester,
    ) async {
      final api = _SidebarApi();
      final connection = ConnectionStore()..api = api;
      final chat = ChatStore();
      final requests = RequestStore();
      final session = _SidebarSession(
        connection: connection,
        chat: chat,
        requests: requests,
      );
      final preview = PreviewStore(connection);
      addTearDown(() {
        preview.dispose();
        session.dispose();
        requests.dispose();
        chat.dispose();
        connection.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            ChangeNotifierProvider<SessionStore>.value(value: session),
            ChangeNotifierProvider<PreviewStore>.value(value: preview),
          ],
          child: MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: mode == 'classic'
                  ? HermesVisualStyle.classic
                  : HermesVisualStyle.liquid,
              reduceTransparency: mode == 'opaque',
            ),
            locale: Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(mode == 'scaled' ? 2 : 1),
              ),
              child: child!,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.centerRight,
                child: mode == 'nested'
                    ? const GlassSurface(
                        child: RightSidebar(
                          initialTab: RightSidebarTab.artifacts,
                        ),
                      )
                    : const RightSidebar(initialTab: RightSidebarTab.artifacts),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(BackdropFilter),
        mode != 'classic' && mode != 'opaque' ? findsOneWidget : findsNothing,
      );
      if (mode != 'classic') {
        final tabs = tester.widget<TabBar>(find.byType(TabBar));
        expect(
          (tabs.indicator! as ShapeDecoration).shape,
          isA<StadiumBorder>(),
        );
        expect((tabs.indicator! as ShapeDecoration).color!.a, 1);
        final collapse = find.widgetWithIcon(IconButton, Icons.chevron_right);
        expect(tester.getSize(collapse).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(collapse).height, greaterThanOrEqualTo(44));
      }

      expect(find.text('Artifacts'), findsOneWidget);
      expect(find.text('No artifacts yet'), findsOneWidget);
      if (mode != 'classic') {
        final filter = find.byKey(const ValueKey('artifact-filter-code'));
        await tester.ensureVisible(filter);
        await tester.pumpAndSettle();
        expect(tester.getSize(filter).height, greaterThanOrEqualTo(44));
        Focus.of(
          tester.element(
            find.descendant(of: filter, matching: find.byType(Text)),
          ),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final button = tester.widget<TextButton>(filter);
        expect(button.style!.shape!.resolve({}), isA<StadiumBorder>());
        expect(button.style!.backgroundColor!.resolve({})!.a, 1);
        expect(tester.takeException(), isNull);
      }

      await tester.drag(find.byType(TabBar), const Offset(-220, 0));
      await tester.pump();
      await tester.ensureVisible(find.text('Logs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(McpLogsScreen), findsOneWidget);
      expect(api.logCalls, greaterThan(0));
      expect(find.textContaining('real server log line'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('right-sidebar-collapsed')),
        findsOneWidget,
      );
      final selected = find.byKey(const ValueKey('right-sidebar-rail-logs'));
      if (mode != 'classic') {
        final button = tester.widget<IconButton>(selected);
        expect(button.style!.shape!.resolve({}), isA<StadiumBorder>());
        expect(button.style!.backgroundColor!.resolve({})!.a, 1);
        expect(tester.getSize(selected).height, greaterThanOrEqualTo(44));
        expect(tester.getSize(selected).width, greaterThanOrEqualTo(44));
      }
      // Short desktop windows keep navigation scrollable and expansion pinned.
      await tester.binding.setSurfaceSize(const Size(800, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithIcon(IconButton, Icons.chevron_left).hitTestable(),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        selected,
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('right-sidebar-rail-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(selected.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(selected);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('right-sidebar-expanded')),
        findsOneWidget,
      );
      expect(find.byType(McpLogsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
