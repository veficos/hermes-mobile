import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/notifications_service.dart';
import 'package:hermes_mobile/core/remote_push.dart';
import 'package:hermes_mobile/core/stores/bot_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/locale_store.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/core/stores/pet_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/bot_routines_screen.dart';
import 'package:hermes_mobile/screens/file_editor_screen.dart';
import 'package:hermes_mobile/screens/onboarding_screen.dart';
import 'package:hermes_mobile/screens/pet_generate_screen.dart';
import 'package:hermes_mobile/screens/push_settings_screen.dart';
import 'package:hermes_mobile/screens/skill_hub_screen.dart';
import 'package:provider/provider.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('zh'),
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding renders localized first-launch flow', (tester) async {
    await tester.pumpWidget(_app(const OnboardingScreen()));
    expect(find.text('与 Hermes 对话'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('file editor shows an offline error instead of loading forever', (
    tester,
  ) async {
    final connection = ConnectionStore();
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: _app(
          const FileEditorScreen(path: '/tmp/example.txt', name: 'example.txt'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('后端未连接'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('skill hub has a direct offline state', (tester) async {
    final connection = ConnectionStore();
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: _app(const SkillHubScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('后端未连接'), findsOneWidget);
  });

  testWidgets('pet generation screen renders its input flow', (tester) async {
    final connection = ConnectionStore();
    final pet = PetStore(connection: connection);
    addTearDown(pet.dispose);
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<PetStore>.value(value: pet),
        ],
        child: _app(const PetGenerateScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('描述你想要的宠物'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('pet draft picker is semantic and fits Arabic 320px at 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final connection = ConnectionStore()..api = _PetGenerateApi();
    final pet = PetStore(connection: connection);
    addTearDown(pet.dispose);
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<PetStore>.value(value: pet),
        ],
        child: _app(
          const PetGenerateScreen(),
          locale: const Locale('ar'),
          textScaler: const TextScaler.linear(2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'cat');
    final generate = find.byKey(const ValueKey('pet-generate-action'));
    await tester.scrollUntilVisible(
      generate,
      160,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pump();
    await tester.tap(generate);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('المسودة 1'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('المسودة 1'));
    expect(
      node.flagsCollection.isImage.toString().toLowerCase(),
      contains('true'),
    );
    expect(
      node.flagsCollection.isButton.toString().toLowerCase(),
      contains('true'),
    );
    expect(
      node.flagsCollection.isSelected.toString().toLowerCase(),
      contains('true'),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('bot routines screen renders an empty state', (tester) async {
    final connection = ConnectionStore();
    final bots = _EmptyBotStore(connection);
    addTearDown(bots.dispose);
    addTearDown(connection.dispose);
    const bot = BotIdentity(
      route: OwnerRoute(connectionId: ConnectionId('primary')),
      profile: 'default',
      displayName: 'Hermes',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<BotStore>.value(
        value: bots,
        child: _app(const BotRoutinesScreen(bot: bot)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('还没有 Cronjob'), findsOneWidget);
  });

  testWidgets('file editor and bot routines support Arabic RTL at 320px/2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final connection = ConnectionStore();
    final bots = _EmptyBotStore(connection);
    addTearDown(bots.dispose);
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<BotStore>.value(value: bots),
        ],
        child: _app(
          const FileEditorScreen(path: '/tmp/example.txt', name: 'example.txt'),
          locale: const Locale('ar'),
          textScaler: const TextScaler.linear(2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );

    const bot = BotIdentity(
      route: OwnerRoute(connectionId: ConnectionId('primary')),
      profile: 'default',
      displayName: 'Hermes',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<BotStore>.value(
        value: bots,
        child: _app(
          const BotRoutinesScreen(bot: bot),
          locale: const Locale('ar'),
          textScaler: const TextScaler.linear(2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
    semantics.dispose();
  });

  testWidgets('push settings renders registration and provider status', (
    tester,
  ) async {
    final connection = ConnectionStore();
    final chat = ChatStore();
    final requests = RequestStore();
    final session = SessionStore(
      connection: connection,
      chat: chat,
      requests: requests,
    );
    final notificationStore = NotificationStore(connection: connection);
    final notifications = NotificationsService(store: notificationStore);
    final push = RemotePushService(
      connection: connection,
      session: session,
      locale: LocaleStore(),
      notifications: notifications,
    );
    addTearDown(push.dispose);
    addTearDown(notifications.dispose);
    addTearDown(notificationStore.dispose);
    addTearDown(session.dispose);
    addTearDown(requests.dispose);
    addTearDown(chat.dispose);
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RemotePushService>.value(value: push),
          Provider<NotificationsService>.value(value: notifications),
        ],
        child: _app(const PushSettingsScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('设备注册'), findsOneWidget);
    expect(find.text('投递服务'), findsOneWidget);
  });
}

class _PetGenerateApi extends ApiClient {
  _PetGenerateApi()
    : super(baseUrl: 'http://pet-generate.invalid', apiKey: 'test');

  static const _pixel =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR42mNk+M/wHwAF/gL+X4Y5WQAAAABJRU5ErkJggg==';

  @override
  Future<Map<String, dynamic>> petGenerateStatus() async => const {};

  @override
  Future<Map<String, dynamic>> petGenerate(Map<String, dynamic> args) async => {
    'ok': true,
    'token': 'job-1',
    'drafts': [
      for (var index = 0; index < 4; index++)
        {'index': index, 'dataUri': _pixel},
    ],
  };
}

class _EmptyBotStore extends BotStore {
  _EmptyBotStore(super.connection);

  @override
  Future<List<BotRoutine>> listBotRoutines(BotIdentity bot) async => const [];
}
