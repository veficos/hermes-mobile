import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_palette_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/core/stores/pet_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_appearance_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/app_shell.dart';
import 'package:hermes_mobile/screens/home_screen.dart';
import 'package:hermes_mobile/screens/request_sheet.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';
import 'package:hermes_mobile/widgets/glass/glass_search_field.dart';
import 'package:hermes_mobile/screens/more_screen.dart';
import 'package:hermes_mobile/screens/agent_screen.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/core/stores/session_tab_store.dart';
import 'package:hermes_mobile/screens/kanban_canonical_screen.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:http/testing.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/kanban/models.dart';
import 'package:hermes_mobile/kanban/store.dart';
import 'package:hermes_mobile/core/stores/bot_store.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_selection_row.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/review_capture.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_mobile_surfaces.dart';

class _ShellBots extends BotStore {
  _ShellBots(super.connection);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> refreshBotAttention(List<BotIdentity> targets) async {}
}

class _EntryApi extends ApiClient {
  _EntryApi()
    : super(
        baseUrl: 'http://entry.invalid',
        apiKey: 'test',
        client: MockClient(
          (request) async =>
              throw StateError('Unexpected HTTP ${request.url.path}'),
        ),
      );
  final reads = <String>[];
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    reads.add(path);
    if (path == '/api/v1/sessions') {
      return {
        'sessions': [
          {'id': 'entry', 'title': '入口验收会话', 'message_count': 2},
        ],
      };
    }
    if (path == '/api/v1/sessions/entry/messages') {
      return {
        'total': 2,
        'messages': [
          {'id': 1, 'role': 'user', 'content': '从首页进入已有会话'},
          {'id': 2, 'role': 'assistant', 'content': '历史回复已经载入，继续检查导航与输入区。'},
        ],
      };
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<ProfilesPayload> listProfiles() async =>
      const ProfilesPayload(profiles: [], active: null, source: 'local');
  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => {};
  @override
  Future<List<SavedPrompt>> savedPrompts() async => [];
  @override
  Future<Map<String, dynamic>> providerQuota({
    String? provider,
    bool refresh = false,
  }) async => {};
  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [];
  @override
  Future<List<Map<String, dynamic>>> listProjects() async => [];
  @override
  Future<ComposerDraft> getDraft(String sessionId, {String? profile}) async =>
      const ComposerDraft();
  @override
  Future<String> fsDefaultCwd() async => '/workspace';
  @override
  Future<Map<String, dynamic>> fsEntries(String path, {String? root}) async => {
    'entries': [],
  };
}

class _EntryGateway extends GatewayClient {
  _EntryGateway()
    : super(serverBaseUrl: 'http://entry.invalid', apiKey: 'test');
  var resume = Completer<Map<String, dynamic>>();
  int calls = 0;
  @override
  bool get isConnected => true;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    if (method != 'session.resume' || params['session_id'] != 'entry') {
      throw StateError('Unexpected RPC $method');
    }
    calls++;
    return resume.future;
  }
}

class _ShellConnection extends ConnectionStore {
  @override
  Future<void> ensureConnected() async {
    if (api is _EntryApi) return;
    await super.ensureConnected();
  }
}

class _ShellSession extends SessionStore {
  _ShellSession({
    required super.connection,
    required super.chat,
    required super.requests,
  });
  SessionInfoView? fixtureInfo;
  @override
  SessionInfoView? get info => fixtureInfo ?? super.info;
}

class _ShellStores {
  _ShellStores() {
    connection.settings = const ConnectionSettings(
      serverUrl: 'https://shell.invalid',
      apiKey: 'test',
    );
  }

  final ConnectionStore connection = _ShellConnection();
  final ChatStore chat = ChatStore();
  final ToolDismissStore toolDismiss = ToolDismissStore();
  final SessionTabStore sessionTabs = SessionTabStore();
  late final BotStore bots = _ShellBots(connection);
  final KanbanStore tasks = KanbanStore(
    KanbanApi(ApiClient(baseUrl: 'http://shell.invalid', apiKey: 'test')),
  );
  final RequestStore requests = RequestStore();
  late final _ShellSession sessions = _ShellSession(
    connection: connection,
    chat: chat,
    requests: requests,
  );
  late final NotificationStore notifications = NotificationStore(
    connection: connection,
  );
  late final PetStore pet = PetStore(connection: connection);
  late final VoiceStore voice = VoiceStore(connection: connection);
  late final CommandStore commands = CommandStore(connection: connection);
  late final CommandPaletteStore palette = CommandPaletteStore(
    session: sessions,
    commands: commands,
  );
  final SessionAppearanceStore sessionAppearance = SessionAppearanceStore();

  List<SingleChildWidget> get providers => [
    ChangeNotifierProvider<ConnectionStore>.value(value: connection),
    ChangeNotifierProvider<ChatStore>.value(value: chat),
    ChangeNotifierProvider<ToolDismissStore>.value(value: toolDismiss),
    ChangeNotifierProvider<SessionTabStore>.value(value: sessionTabs),
    ChangeNotifierProvider<BotStore>.value(value: bots),
    ChangeNotifierProvider<KanbanStore>.value(value: tasks),
    ChangeNotifierProvider<RequestStore>.value(value: requests),
    ChangeNotifierProvider<SessionStore>.value(value: sessions),
    ChangeNotifierProvider<NotificationStore>.value(value: notifications),
    ChangeNotifierProvider<PetStore>.value(value: pet),
    ChangeNotifierProvider<VoiceStore>.value(value: voice),
    ChangeNotifierProvider<CommandStore>.value(value: commands),
    ChangeNotifierProvider<CommandPaletteStore>.value(value: palette),
    ChangeNotifierProvider<SessionAppearanceStore>.value(
      value: sessionAppearance,
    ),
  ];

  void dispose() {
    toolDismiss.dispose();
    sessionTabs.dispose();
    tasks.dispose();
    bots.dispose();
    sessionAppearance.dispose();
    voice.dispose();
    pet.dispose();
    notifications.dispose();
    sessions.dispose();
    requests.dispose();
    chat.dispose();
    commands.dispose();
    palette.dispose();
    connection.dispose();
  }
}

Widget _app(
  _ShellStores stores, {
  required TextScaler textScaler,
  HermesVisualStyle style = HermesVisualStyle.classic,
  bool accessibleNavigation = false,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('ar'),
}) {
  return MultiProvider(
    providers: stores.providers,
    child: MaterialApp(
      theme: buildHermesTheme(brightness: brightness, visualStyle: style),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          accessibleNavigation: accessibleNavigation,
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: const AppShell(),
    ),
  );
}

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final language in ['zh', 'en', 'ar']) {
      for (final failFirst in [false, true]) {
        testWidgets(
          'Liquid home session entry waits for resume and returns $width retry=$failFirst $language',
          (tester) async {
            SharedPreferences.setMockInitialValues({
              'hm_onboarding_seen_v1': true,
            });
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final stores = _ShellStores();
            final api = _EntryApi();
            final gateway = _EntryGateway();
            stores.connection
              ..api = api
              ..gateway = gateway;
            Future<void> captureEntry(String state) async {
              const dir = String.fromEnvironment('ENTRY_REVIEW_DIR');
              if (dir.isEmpty) return;
              await captureReview(
                tester,
                find.byKey(const ValueKey('entry-review')),
                '$dir/shell-feedback-$state-$language-${width.toInt()}-${failFirst ? 'dark' : 'light'}-2.0.png',
              );
            }

            await tester.pumpWidget(
              RepaintBoundary(
                key: const ValueKey('entry-review'),
                child: _app(
                  stores,
                  textScaler: TextScaler.linear(2),
                  style: HermesVisualStyle.liquid,
                  brightness: failFirst ? Brightness.dark : Brightness.light,
                  locale: Locale(language),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              stores.sessions.sessions?.map((row) => row.id),
              contains('entry'),
            );
            final entry = find.text('入口验收会话').first;
            await tester.scrollUntilVisible(
              find.text('入口验收会话'),
              300,
              scrollable: find
                  .descendant(
                    of: find.byType(HomeScreen),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.ensureVisible(entry);
            await Scrollable.ensureVisible(
              tester.element(entry),
              alignment: 0.4,
            );
            await tester.pumpAndSettle();
            expect(entry.hitTestable(), findsOneWidget);
            await tester.tap(entry);
            await tester.pump(const Duration(milliseconds: 100));
            expect(gateway.calls, 1);
            expect(find.byType(ChatScreen), findsNothing);
            final opening = find.byKey(
              const ValueKey('home-session-opening-entry'),
            );
            expect(opening, findsOneWidget);
            expect(
              tester.widget<Semantics>(opening).properties.liveRegion,
              isTrue,
            );
            final openingRect = tester.getRect(opening);
            expect(openingRect.left, greaterThanOrEqualTo(0));
            expect(openingRect.right, lessThanOrEqualTo(width));
            expect(openingRect.top, greaterThan(tester.getRect(entry).bottom));
            expect(tester.takeException(), isNull);
            await captureEntry('pending');
            await tester.tap(entry);
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              gateway.calls,
              1,
              reason: 'Pending entry does not resume twice',
            );
            if (failFirst) {
              gateway.resume.completeError(
                StateError('Resume temporarily unavailable'),
              );
              await tester.pumpAndSettle();
              expect(find.byType(ChatScreen), findsNothing);
              expect(stores.sessions.durableId, isNull);
              expect(opening, findsNothing);
              expect(
                find.textContaining('Resume temporarily unavailable'),
                findsWidgets,
              );
              gateway.resume = Completer<Map<String, dynamic>>();
              final retry = find.descendant(
                of: find.byType(SnackBar),
                matching: find.text(
                  AppLocalizations.of(
                    tester.element(find.byType(HomeScreen)),
                  ).commonRetry,
                ),
              );
              expect(retry.hitTestable(), findsOneWidget);
              await captureEntry('failed');
              await tester.tap(retry);
              await tester.pump(const Duration(milliseconds: 100));
              expect(gateway.calls, 2);
              expect(find.byType(ChatScreen), findsNothing);
            }
            gateway.resume.complete({
              'session_id': 'entry-runtime',
              'info': {'message_count': 2},
            });
            await tester.pumpAndSettle();
            expect(find.byType(ChatScreen), findsOneWidget);
            expect(stores.sessions.durableId, 'entry');
            expect(api.reads, contains('/api/v1/sessions/entry/messages'));
            expect(find.textContaining('历史回复已经载入'), findsWidgets);
            expect(tester.takeException(), isNull);
            await captureEntry('loaded');
            await tester.tap(find.byIcon(Icons.arrow_back).first);
            await tester.pumpAndSettle();
            expect(find.byType(ChatScreen), findsNothing);
            expect(find.text('入口验收会话'), findsWidgets);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            stores.dispose();
          },
        );
      }
    }
  }
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'desktop status shares navigation material and readable text $scale',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final stores = _ShellStores();
        const model = 'provider/long-context-reasoning-model-production-2026';
        const workspace =
            '/workspace/projects/mobile/client/ui-redesign/验证长路径和大字号/feature-liquid-glass';
        stores.sessions.fixtureInfo = SessionInfoView(
          model: model,
          cwd: workspace,
        );
        await tester.pumpWidget(
          _app(
            stores,
            textScaler: TextScaler.linear(scale),
            style: HermesVisualStyle.liquid,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final status = find.byKey(const ValueKey('app-shell-xl-status-glass'));
        expect(
          tester.widget<GlassSurface>(status).role,
          HermesGlassRole.navigation,
        );
        final palette = HermesPalette.of(tester.element(status));
        final bounds = tester.getRect(status);
        expect(bounds.bottom, lessThanOrEqualTo(800));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(
          find.descendant(of: status, matching: find.textContaining(model)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: status, matching: find.textContaining(workspace)),
          findsOneWidget,
        );
        for (final text
            in find
                .descendant(of: status, matching: find.byType(Text))
                .evaluate()) {
          final rect = tester.getRect(find.byWidget(text.widget));
          expect(rect.top, greaterThanOrEqualTo(bounds.top));
          expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
          expect(rect.left, greaterThanOrEqualTo(bounds.left));
          expect(rect.right, lessThanOrEqualTo(bounds.right));
        }
        for (final text in tester.widgetList<Text>(
          find.descendant(of: status, matching: find.byType(Text)),
        )) {
          expect(text.style!.color, palette.text2);
        }
        final nav = find.byKey(const ValueKey('app-shell-xl-navigation'));
        final labels = AppLocalizations.of(tester.element(nav));
        final lastDestination = find.descendant(
          of: nav,
          matching: find.text(labels.commonDisconnected),
        );
        await tester.ensureVisible(lastDestination);
        await tester.pumpAndSettle();
        expect(lastDestination.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        stores.dispose();
        await tester.pumpAndSettle();
      },
    );
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'hm_onboarding_seen_v1': true});
    // Capture uses real async scheduling, which also initializes VoiceStore's
    // audio channels. No native audio plugin exists in the VM test runner.
    const capture = String.fromEnvironment('SHELL_REVIEW_PNG');
    const captureDir = String.fromEnvironment('SHELL_REVIEW_DIR');
    const entryCaptureDir = String.fromEnvironment('ENTRY_REVIEW_DIR');
    if (capture.isNotEmpty ||
        captureDir.isNotEmpty ||
        entryCaptureDir.isNotEmpty) {
      for (final name in [
        'xyz.luan/audioplayers.global',
        'xyz.luan/audioplayers.global/events',
        'xyz.luan/audioplayers',
        'com.llfbandit.record/messages',
      ]) {
        final channel = MethodChannel(name);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (name == 'xyz.luan/audioplayers' && call.method == 'create') {
                final id = (call.arguments as Map)['playerId'];
                final events = MethodChannel(
                  'xyz.luan/audioplayers/events/$id',
                );
                TestDefaultBinaryMessengerBinding
                    .instance
                    .defaultBinaryMessenger
                    .setMockMethodCallHandler(events, (_) async => null);
                addTearDown(() {
                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .setMockMethodCallHandler(events, null);
                });
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
      }
    }
  });

  for (final width in [320.0, 390.0, 430.0, 768.0, 900.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'Liquid populated shell Bot More roundtrip $width $brightness scale=$scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final stores = _ShellStores();
            stores.tasks.boardData = KanbanBoard.fromJson({
              'columns': [
                {
                  'name': 'todo',
                  'tasks': [
                    {
                      'id': 'shell-task',
                      'title': '验收液态玻璃与历史分页',
                      'status': 'todo',
                    },
                  ],
                },
                {'name': 'done', 'tasks': []},
                if (width > 430) ...[
                  {'name': 'review', 'tasks': []},
                  {'name': 'blocked', 'tasks': []},
                  {'name': 'archived', 'tasks': []},
                ],
              ],
            });
            stores.bots.bots = [
              BotIdentity(
                route: OwnerRoute(
                  connectionId: ConnectionStore.primaryConnectionId,
                ),
                profile: 'review',
                displayName: '审查助手',
                description: '保留在离线目录中的工作助手',
              ),
            ];
            await tester.pumpWidget(
              RepaintBoundary(
                key: const ValueKey('populated-shell-review'),
                child: _app(
                  stores,
                  textScaler: TextScaler.linear(scale),
                  style: HermesVisualStyle.liquid,
                  brightness: brightness,
                  locale: const Locale('zh'),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final nav = find.byKey(
              ValueKey(
                width >= 1200
                    ? 'app-shell-xl-navigation'
                    : width >= 840
                    ? 'app-shell-tablet-navigation'
                    : 'app-shell-phone-navigation',
              ),
            );
            Future<void> select(int index) async {
              if (width >= 840) {
                final labels = AppLocalizations.of(
                  tester.element(find.byType(AppShell)),
                );
                final label = [
                  labels.navHome,
                  labels.navSessions,
                  labels.navTasks,
                  labels.featureAgent,
                  labels.navMore,
                ][index];
                final destination = find.descendant(
                  of: nav,
                  matching: find.text(label),
                );
                await tester.ensureVisible(destination);
                await tester.tap(destination);
              } else {
                await tester.tap(
                  find
                      .descendant(
                        of: nav,
                        matching: find.byType(NavigationDestination),
                      )
                      .at(index),
                );
              }
              await tester.pumpAndSettle();
              if (width < 840) {
                expect(tester.widget<NavigationBar>(nav).selectedIndex, index);
              } else if (width < 1200) {
                expect(tester.widget<NavigationRail>(nav).selectedIndex, index);
              }
              expect(nav.hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
            }

            await select(3);
            expect(find.byType(AgentScreen), findsOneWidget);
            expect(find.text('审查助手'), findsOneWidget);
            const dir = String.fromEnvironment('SHELL_REVIEW_DIR');
            if (dir.isNotEmpty) {
              await captureReview(
                tester,
                find.byKey(const ValueKey('populated-shell-review')),
                '$dir/shell-bots-${width.toInt()}-${brightness.name}-$scale.png',
              );
            }
            final manage = find.byKey(const ValueKey('bot-directory-manage'));
            await tester.ensureVisible(manage);
            await tester.tap(manage);
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsOneWidget);
            expect(tester.takeException(), isNull);
            if (dir.isNotEmpty) {
              await captureReview(
                tester,
                find.byKey(const ValueKey('populated-shell-review')),
                '$dir/shell-bots-sheet-${width.toInt()}-${brightness.name}-$scale.png',
              );
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
            expect(find.text('审查助手'), findsOneWidget);
            await select(4);
            expect(find.byType(MoreScreen), findsOneWidget);
            if (dir.isNotEmpty) {
              await captureReview(
                tester,
                find.byKey(const ValueKey('populated-shell-review')),
                '$dir/shell-more-${width.toInt()}-${brightness.name}-$scale.png',
              );
            }
            await select(3);
            expect(find.text('审查助手'), findsOneWidget);
            await select(0);
            await select(2);
            expect(find.byType(KanbanCanonicalScreen), findsOneWidget);
            expect(find.text('验收液态玻璃与历史分页'), findsOneWidget);
            final l10n = AppLocalizations.of(
              tester.element(find.byType(KanbanCanonicalScreen)),
            );
            for (final board in [false, true]) {
              if (board) {
                await tester.tap(find.text(l10n.taskBoardView));
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull);
              expect(nav.hitTestable(), findsOneWidget);
              if (dir.isNotEmpty) {
                await captureReview(
                  tester,
                  find.byKey(const ValueKey('populated-shell-review')),
                  '$dir/shell-tasks-${board ? 'board' : 'list'}-${width.toInt()}-${brightness.name}-$scale.png',
                );
              }
            }
            final horizontal = find.byKey(
              const PageStorageKey('task-board-horizontal'),
            );
            final horizontalScrollable = find
                .descendant(of: horizontal, matching: find.byType(Scrollable))
                .first;
            await tester.drag(horizontal, const Offset(-240, 0));
            await tester.pumpAndSettle();
            final boardOffset = tester
                .state<ScrollableState>(horizontalScrollable)
                .position
                .pixels;
            expect(boardOffset, greaterThan(0));
            await tester.tap(find.text(l10n.taskListView));
            await tester.pumpAndSettle();
            expect(horizontal, findsNothing);
            await tester.tap(find.text(l10n.taskBoardView));
            await tester.pumpAndSettle();
            expect(
              tester
                  .state<ScrollableState>(horizontalScrollable)
                  .position
                  .pixels,
              closeTo(boardOffset, 1),
            );
            await select(4);
            await select(2);
            expect(horizontal, findsOneWidget);
            // Different boards must not inherit the previous horizontal offset.
            final originalSlug = stores.tasks.api.boardSlug;
            stores.tasks.api.boardSlug = 'second-board';
            stores.tasks.notifyListeners();
            await tester.pumpAndSettle();
            expect(
              tester
                  .state<ScrollableState>(horizontalScrollable)
                  .position
                  .pixels,
              0,
            );
            stores.tasks.api.boardSlug = originalSlug;
            stores.tasks.notifyListeners();
            await tester.pumpAndSettle();
            expect(
              tester
                  .state<ScrollableState>(horizontalScrollable)
                  .position
                  .pixels,
              closeTo(boardOffset, 1),
            );
            expect(find.text('验收液态玻璃与历史分页'), findsOneWidget);
            await select(0);
            stores.chat.loadHistory([
              ChatMessage(
                id: 'shell-user',
                role: 'user',
                parts: [
                  ChatPart.text(
                    '# 检查 **页面层级**\n\n> 引用说明：保留清楚的阅读顺序。\n\n- 对齐列表与正文\n- 保留 *强调文字*\n\n[查看文档](https://example.com/docs)',
                  ),
                ],
              ),
              ChatMessage(
                id: 'shell-ai',
                role: 'assistant',
                parts: [
                  ChatPart.text(
                    '## 布局 **检查结果**\n\n聊天内容与操作层应保持清楚的视觉层级。\n\n- 正文与标题采用一致的字号规则\n- 链接与引用应清楚可辨',
                  ),
                ],
              ),
            ], hasMore: false);
            final navigator = Navigator.of(
              tester.element(find.byType(AppShell)),
            );
            // Chat is a pushed route, not the session-list navigation tab.
            navigator.push(
              MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
            );
            await tester.pumpAndSettle();
            expect(find.byType(ChatScreen), findsOneWidget);
            expect(find.textContaining('聊天内容与操作层'), findsWidgets);
            expect(nav.hitTestable(), findsNothing);
            expect(tester.takeException(), isNull);
            if (dir.isNotEmpty) {
              await captureReview(
                tester,
                find.byKey(const ValueKey('populated-shell-review')),
                '$dir/shell-chat-rich-tail-${width.toInt()}-${brightness.name}-$scale.png',
              );
            }
            final transcript = find
                .descendant(
                  of: find.byType(ChatScreen),
                  matching: find.byType(Scrollable),
                )
                .first;
            final readingPosition = tester
                .state<ScrollableState>(transcript)
                .position;
            readingPosition.jumpTo(readingPosition.minScrollExtent);
            await tester.pumpAndSettle();
            expect(
              find.textContaining('页面层级', findRichText: true).hitTestable(),
              findsWidgets,
            );
            expect(tester.takeException(), isNull);
            if (dir.isNotEmpty) {
              await captureReview(
                tester,
                find.byKey(const ValueKey('populated-shell-review')),
                '$dir/shell-chat-rich-top-${width.toInt()}-${brightness.name}-$scale.png',
              );
            }
            await navigator.maybePop();
            await tester.pumpAndSettle();
            expect(find.byType(ChatScreen), findsNothing);
            expect(nav.hitTestable(), findsOneWidget);
            if (width < 840) {
              expect(tester.widget<NavigationBar>(nav).selectedIndex, 0);
            }
            await tester.pumpWidget(const SizedBox());
            stores.dispose();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Liquid whole shell $width $brightness scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final stores = _ShellStores();
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('whole-shell-review'),
              child: _app(
                stores,
                textScaler: TextScaler.linear(scale),
                style: HermesVisualStyle.liquid,
                brightness: brightness,
                locale: const Locale('zh'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AppShell), findsOneWidget);
          expect(tester.takeException(), isNull);
          const dir = String.fromEnvironment('SHELL_REVIEW_DIR');
          if (dir.isNotEmpty) {
            await captureReview(
              tester,
              find.byKey(const ValueKey('whole-shell-review')),
              '$dir/shell-home-${width.toInt()}-${brightness.name}-$scale.png',
            );
          }
          await tester.pumpWidget(const SizedBox());
          stores.dispose();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('Liquid phone home owns one pinned scroll header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stores = _ShellStores();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shell-review-capture'),
        child: _app(
          stores,
          textScaler: TextScaler.noScaling,
          style: HermesVisualStyle.liquid,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Opt-in review artifact, never a golden baseline or an acceptance gate.
    const capture = String.fromEnvironment('SHELL_REVIEW_PNG');
    if (capture.isNotEmpty) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('shell-review-capture')),
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File(capture).writeAsBytes(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        picture.dispose();
      });
    }
    expect(find.byType(NestedScrollView), findsOneWidget);
    final hero = find.byKey(const ValueKey('home-continue-hero'));
    final decoration =
        tester.widget<Container>(hero).decoration as ShapeDecoration;
    expect(decoration.shape, isA<RoundedSuperellipseBorder>());
    expect(decoration.shadows, isNull);
    final action = tester.widget<FilledButton>(
      find.descendant(of: hero, matching: find.byType(FilledButton)),
    );
    expect(action.style!.shape!.resolve({}), isA<StadiumBorder>());
    expect(find.byType(SliverAppBar), findsOneWidget);
    final toolbar = find.byType(SliverAppBar);
    expect(
      find.descendant(of: toolbar, matching: find.byType(GlassButton)),
      findsNWidgets(3),
    );
    for (final key in ['home-settings-avatar', 'home-reconnect']) {
      final button = find.byKey(ValueKey(key));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    }
    expect(find.text('Hermes').hitTestable(), findsOneWidget);
    final phoneNavigation = find.byKey(
      const ValueKey('app-shell-phone-navigation'),
    );
    expect(
      find.descendant(of: phoneNavigation, matching: find.byIcon(Icons.home)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: phoneNavigation,
        matching: find.byIcon(Icons.chat_bubble_outline),
      ),
      findsOneWidget,
    );
    final refresh = find.byType(RefreshIndicator).first;
    await tester.drag(refresh, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('Hermes').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-settings-avatar')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-reconnect')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app-shell-phone-navigation')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(NavigationDestination).last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: phoneNavigation,
        matching: find.byIcon(Icons.home_outlined),
      ),
      findsOneWidget,
    );
    expect(tester.widget<NavigationBar>(phoneNavigation).selectedIndex, 4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    stores.dispose();
  });

  testWidgets('More Liquid directory search clears and reopens focused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stores = _ShellStores();
    await tester.pumpWidget(
      _app(
        stores,
        textScaler: const TextScaler.linear(2),
        style: HermesVisualStyle.liquid,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).last);
    await tester.pumpAndSettle();
    final page = find.byType(MoreScreen);
    final action = find
        .descendant(of: page, matching: find.byType(GlassButton))
        .first;
    await tester.tap(action);
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: page,
      matching: find.byType(GlassSearchField),
    );
    expect(field, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'no-matching-feature-xyz');
    await tester.pumpAndSettle();
    // Aliases stay searchable even when the page locale is Arabic.
    final labels = AppLocalizations.of(tester.element(page));
    Finder entryLabel(String title) => find.descendant(
      of: find.descendant(of: page, matching: find.byType(HermesMobileRow)),
      matching: find.text(title),
    );
    await tester.enterText(find.byType(TextField), '工作区 workspace');
    await tester.pumpAndSettle();
    expect(entryLabel(labels.workspaceTitle), findsOneWidget);
    expect(entryLabel(labels.featureAgent), findsNothing);
    await tester.enterText(find.byType(TextField), 'BOT');
    await tester.pumpAndSettle();
    expect(entryLabel(labels.featureAgent), findsOneWidget);
    expect(entryLabel(labels.workspaceTitle), findsNothing);
    await tester.tap(
      find.descendant(of: field, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<GlassSearchField>(field).controller.text, isEmpty);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(tester.widget<GlassSearchField>(field).controller.text, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    stores.dispose();
  });

  testWidgets('Liquid desktop uses shared accessible selection rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stores = _ShellStores();
    await tester.pumpWidget(
      _app(
        stores,
        textScaler: const TextScaler.linear(2),
        style: HermesVisualStyle.liquid,
      ),
    );
    await tester.pumpAndSettle();
    final nav = find.byKey(const ValueKey('app-shell-xl-navigation'));
    final rows = find.descendant(
      of: nav,
      matching: find.byType(GlassSelectionRow),
    );
    expect(rows, findsWidgets);
    final selected = rows.evaluate().where(
      (e) => (e.widget as GlassSelectionRow).selected,
    );
    expect(selected, hasLength(1));
    expect(tester.getSize(rows.first).height, greaterThanOrEqualTo(56));
    final action = find.descendant(
      of: rows.first,
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(action).onTap, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    stores.dispose();
  });

  for (final accessible in [false, true]) {
    testWidgets('phone navigation motion accessible=$accessible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stores = _ShellStores();
      await tester.pumpWidget(
        _app(
          stores,
          textScaler: TextScaler.noScaling,
          style: HermesVisualStyle.liquid,
          accessibleNavigation: accessible,
        ),
      );
      await tester.pumpAndSettle();
      final nav = find.byKey(const ValueKey('app-shell-phone-navigation'));
      expect(
        tester.widget<NavigationBar>(nav).animationDuration,
        accessible ? Duration.zero : HermesGlassTokens.feedbackDuration,
      );
      final destinations = find.descendant(
        of: nav,
        matching: find.byType(NavigationDestination),
      );
      await tester.tap(destinations.last);
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationBar>(nav).selectedIndex, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      stores.dispose();
    });
    testWidgets(
      'wide navigation respects reduced motion accessible=$accessible',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final stores = _ShellStores();
        await tester.pumpWidget(
          _app(
            stores,
            textScaler: TextScaler.noScaling,
            style: HermesVisualStyle.liquid,
            accessibleNavigation: accessible,
            disableAnimations: !accessible,
          ),
        );
        await tester.pumpAndSettle();
        final nav = find.byKey(const ValueKey('app-shell-xl-navigation'));
        expect(tester.widget<AnimatedContainer>(nav).duration, Duration.zero);
        final before = tester.getSize(nav).width;
        await tester.tap(
          find.descendant(of: nav, matching: find.byType(IconButton)).first,
        );
        await tester.pump();
        await tester.pump();
        expect(tester.getSize(nav).width, before == 240 ? 64 : 240);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        stores.dispose();
      },
    );
  }

  testWidgets(
    'Liquid desktop toolbar search opens and escapes command palette',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stores = _ShellStores();
      await tester.pumpWidget(
        _app(
          stores,
          textScaler: const TextScaler.linear(1.6),
          style: HermesVisualStyle.liquid,
        ),
      );
      await tester.pumpAndSettle();
      final toolbar = find.byKey(const ValueKey('app-shell-xl-toolbar-glass'));
      final search = find
          .descendant(of: toolbar, matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(search).height, greaterThanOrEqualTo(44));
      expect(search.hitTestable(), findsOneWidget);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(stores.palette.isOpen, isTrue);
      final paletteGlass = find.byKey(const ValueKey('command-palette-glass'));
      expect(paletteGlass, findsOneWidget);
      expect(
        find.descendant(
          of: paletteGlass,
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(stores.palette.isOpen, isFalse);
      expect(search.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      stores.dispose();
    },
  );

  testWidgets('short Liquid rail scrolls to its last destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stores = _ShellStores();
    stores.requests.enqueue(
      PendingRequest(
        kind: RequestKind.approval,
        requestId: 'short-rail-approval',
        command: 'echo preview',
      ),
    );
    await tester.pumpWidget(
      _app(
        stores,
        textScaler: const TextScaler.linear(2),
        style: HermesVisualStyle.liquid,
      ),
    );
    await tester.pumpAndSettle();
    final rail = find.byType(NavigationRail);
    expect(tester.widget<NavigationRail>(rail).scrollable, isTrue);
    final railContext = tester.element(rail);
    expect(
      NavigationRailTheme.of(railContext).indicatorShape,
      Theme.of(railContext).navigationBarTheme.indicatorShape,
    );
    expect(
      NavigationRailTheme.of(railContext).indicatorShape,
      isA<StadiumBorder>(),
    );
    final last = find.descendant(
      of: rail,
      matching: find.byIcon(Icons.more_horiz),
    );
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    expect(last.hitTestable(), findsOneWidget);
    final approval = find.descendant(
      of: rail,
      matching: find.byIcon(Icons.rule),
    );
    await tester.ensureVisible(approval);
    await tester.pumpAndSettle();
    final approvalButton = find.ancestor(
      of: approval,
      matching: find.byType(IconButton),
    );
    expect(approvalButton.hitTestable(), findsOneWidget);
    expect(
      find.ancestor(of: approval, matching: find.byType(GlassButton)),
      findsOneWidget,
    );
    await tester.tap(approvalButton);
    await tester.pumpAndSettle();
    expect(find.byType(RequestSheet), findsOneWidget);
    expect(stores.requests.pendingCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    stores.dispose();
  });

  testWidgets('Liquid tablet search shares glass feedback and opens palette', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stores = _ShellStores();
    await tester.pumpWidget(
      _app(
        stores,
        textScaler: const TextScaler.linear(2),
        style: HermesVisualStyle.liquid,
      ),
    );
    await tester.pumpAndSettle();
    final search = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.byType(GlassButton),
    );
    expect(search, findsOneWidget);
    expect(tester.getSize(search).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(search).width, greaterThanOrEqualTo(44));
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(stores.palette.isOpen, isTrue);
    expect(find.byKey(const ValueKey('command-palette-glass')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(stores.palette.isOpen, isFalse);
    expect(search.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    stores.dispose();
  });

  testWidgets('AppShell supports Arabic RTL, responsive widths, and scaling', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cases = <({Size size, TextScaler scaler, String navigationKey})>[
      (
        size: const Size(320, 640),
        scaler: const TextScaler.linear(2),
        navigationKey: 'app-shell-phone-navigation',
      ),
      (
        size: const Size(900, 700),
        scaler: const TextScaler.linear(1.6),
        navigationKey: 'app-shell-tablet-navigation',
      ),
      (
        size: const Size(900, 480),
        scaler: const TextScaler.linear(2),
        navigationKey: 'app-shell-tablet-navigation',
      ),
      (
        size: const Size(1280, 800),
        scaler: const TextScaler.linear(1.6),
        navigationKey: 'app-shell-xl-navigation',
      ),
    ];

    for (final style in HermesVisualStyle.values) {
      for (final testCase in cases) {
        tester.view.physicalSize = testCase.size;
        tester.view.devicePixelRatio = 1;
        final stores = _ShellStores();

        await tester.pumpWidget(
          _app(stores, textScaler: testCase.scaler, style: style),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(ValueKey(testCase.navigationKey)), findsOneWidget);
        final toolbar = find.byKey(
          const ValueKey('app-shell-xl-toolbar-glass'),
        );
        if (style == HermesVisualStyle.liquid && testCase.size.width >= 1280) {
          expect(toolbar, findsOneWidget);
          final bounds = tester.getRect(toolbar);
          expect(bounds.left, 12);
          expect(bounds.right, testCase.size.width - 12);
          expect(bounds.top, 12);
          expect(bounds.height, 56);
        } else {
          expect(toolbar, findsNothing);
        }
        final wideGlass = find.byKey(
          const ValueKey('app-shell-wide-navigation-glass'),
        );
        if (style == HermesVisualStyle.liquid && testCase.size.width >= 900) {
          expect(wideGlass, findsOneWidget);
          final panel = tester.getRect(wideGlass);
          expect(panel.left, greaterThanOrEqualTo(12));
          expect(panel.right, lessThanOrEqualTo(testCase.size.width - 12));
          expect(panel.top, greaterThanOrEqualTo(12));
          expect(panel.bottom, lessThanOrEqualTo(testCase.size.height - 12));
        } else {
          expect(wideGlass, findsNothing);
        }
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).first)),
          TextDirection.rtl,
        );
        expect(find.text('الرئيسية'), findsWidgets);
        expect(
          tester.takeException(),
          isNull,
          reason: 'unexpected layout error at ${testCase.size}',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        stores.dispose();
      }
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    semantics.dispose();
  });

  testWidgets('reconnecting no longer inserts a global top banner', (
    tester,
  ) async {
    final stores = _ShellStores();
    stores.connection.phase = ConnectionPhase.reconnecting;
    addTearDown(stores.dispose);

    await tester.pumpWidget(_app(stores, textScaler: TextScaler.noScaling));
    await tester.pump();

    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)));
    expect(find.text(l10n.shellReconnecting), findsNothing);
    expect(find.byKey(const ValueKey('home-reconnect')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
