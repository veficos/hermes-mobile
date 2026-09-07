import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/session_tab_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage for: the top-right history locator only ever searched
/// `ChatStore.messages` — the in-memory window — so any message not yet
/// paged in from the server (`chat.hasMoreHistory`) was invisible to it, even
/// though it genuinely exists in the transcript. `_showHistoryLocator` now
/// surfaces that gap explicitly and offers a "load all history" action that
/// pages in the rest before the user searches.
class _LocatorApi extends ApiClient {
  _LocatorApi({required this.messageCount})
    : super(baseUrl: 'http://locator.invalid', apiKey: 'test');

  final int messageCount;
  final List<(String, Map<String, String>?)> calls = [];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    calls.add((path, query));
    if (path == '/api/v1/sessions/locator-session') {
      return {'id': 'locator-session', 'message_count': messageCount};
    }
    if (path == '/api/v1/sessions/locator-session/messages') {
      final limit = int.parse(query?['limit'] ?? '50');
      final offset = int.parse(query?['offset'] ?? '0');
      final end = (offset + limit).clamp(0, messageCount);
      return {
        'messages': [
          for (var i = offset; i < end; i++)
            {
              'id': i + 1,
              'role': i.isEven ? 'user' : 'assistant',
              // Message #1 is the oldest in the transcript and only ever
              // gets fetched once every older page has been paged in.
              'content': i == 0 ? 'oldest-transcript-marker' : 'msg-${i + 1}',
            },
        ],
      };
    }
    throw StateError('unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => const {};

  @override
  Future<ProfilesPayload> listProfiles() async =>
      const ProfilesPayload(profiles: [], active: null, source: 'local');

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => const [];

  @override
  Future<String> fsDefaultCwd() async => 'D:/work/repo';

  @override
  Future<List<Map<String, dynamic>>> listProjects() async => const [];

  @override
  Future<ComposerDraft> getDraft(String sessionId, {String? profile}) async =>
      const ComposerDraft();
}

class _LocatorGateway extends GatewayClient {
  _LocatorGateway()
    : super(serverBaseUrl: 'http://locator.invalid', apiKey: 'test');

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (method == 'session.resume') {
      return {'session_id': 'runtime-locator'};
    }
    if (method == 'session.close') return {};
    throw StateError('unexpected RPC $method');
  }
}

class _LocatorConnection extends ConnectionStore {
  _LocatorConnection({
    required ApiClient apiClient,
    required GatewayClient gw,
  }) {
    api = apiClient;
    gateway = gw;
  }

  final eventController = StreamController<GatewayEvent>.broadcast();
  final reconnectController = StreamController<void>.broadcast();

  @override
  Stream<GatewayEvent> get events => eventController.stream;

  @override
  Stream<void> get reconnected => reconnectController.stream;

  @override
  Future<void> ensureConnected() async {}

  @override
  void dispose() {
    eventController.close();
    reconnectController.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'history locator flags un-paged older messages and can load them all',
    (tester) async {
      // Wide enough for hasSessionRail so the locator action is in the app
      // bar (it's rail-only real estate on phone-width layouts).
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _LocatorApi(messageCount: 130);
      final gateway = _LocatorGateway();
      final connection = _LocatorConnection(apiClient: api, gw: gateway);
      final chat = ChatStore();
      final session = SessionStore(
        connection: connection,
        chat: chat,
        requests: RequestStore(),
      );
      addTearDown(() {
        session.dispose();
        connection.dispose();
      });

      await session.resumeSession('locator-session', profile: 'default');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            ChangeNotifierProxyProvider<ConnectionStore, SessionTabStore>(
              create: (_) => SessionTabStore(),
              update: (_, connection, tabs) =>
                  (tabs ?? SessionTabStore())..attachRoutedEvents(
                    connection.routedEvents,
                    owners: connection.sessionOwners,
                  ),
            ),
            ChangeNotifierProvider<SessionStore>.value(value: session),
            ChangeNotifierProvider<ChatStore>.value(value: chat),
            ChangeNotifierProvider.value(
              value: VoiceStore(connection: connection),
            ),
            ChangeNotifierProvider.value(
              value: CommandStore(connection: connection),
            ),
            ChangeNotifierProvider(create: (_) => ToolDismissStore()),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only the newest page (50 of 130 messages) is loaded so far.
      expect(chat.hasMoreHistory, isTrue);
      expect(
        chat.messages.any(
          (m) => m.fullText.contains('oldest-transcript-marker'),
        ),
        isFalse,
      );

      final l10n = AppLocalizationsZh();
      await tester.tap(find.byIcon(Icons.travel_explore_outlined));
      await tester.pumpAndSettle();

      // The sheet must own up to the fact its search only covers what's
      // loaded so far, and offer a way to fix that.
      expect(find.text(l10n.chatHistoryLocatorPartial), findsOneWidget);
      expect(find.text(l10n.chatLoadAllHistory), findsOneWidget);

      await tester.tap(find.text(l10n.chatLoadAllHistory));
      await tester.pumpAndSettle();

      // All 130 messages, including the oldest one, are now loaded and the
      // "more history" notice is gone.
      expect(chat.hasMoreHistory, isFalse);
      expect(chat.messages.length, 130);
      expect(find.text(l10n.chatHistoryLocatorPartial), findsNothing);

      // The oldest message is now actually findable and tappable from the
      // locator's own search list — not just present in the store.
      await tester.enterText(find.byType(TextField).first, 'oldest-transcript');
      await tester.pumpAndSettle();
      expect(find.textContaining('oldest-transcript-marker'), findsOneWidget);
    },
  );
}
