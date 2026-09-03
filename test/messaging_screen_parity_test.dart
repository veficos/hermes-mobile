import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/messaging_screen.dart';
import 'package:provider/provider.dart';

class _MessagingApi extends ApiClient {
  _MessagingApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test-key');

  bool tokenSet = false;
  bool platformEnabled = true;
  bool pairingFails = true;
  int updates = 0;
  int restarts = 0;
  String? lastProfile;
  String activeProfile = 'work';

  @override
  Future<ProfilesPayload> listProfiles() async => ProfilesPayload(
    profiles: [ProfileInfo(name: activeProfile, isActive: true)],
    active: activeProfile,
  );

  @override
  Future<List<MessagingPlatform>> messagingPlatforms({String? profile}) async {
    lastProfile = profile;
    return [
      MessagingPlatform(
        name: 'telegram',
        displayName: 'Telegram',
        enabled: platformEnabled,
        configured: tokenSet,
        envVars: [
          MessagingEnvVar(
            key: 'TELEGRAM_BOT_TOKEN',
            prompt: 'Bot token',
            required: true,
            isPassword: true,
            isSet: tokenSet,
            redactedValue: tokenSet ? '***1234' : null,
          ),
        ],
      ),
    ];
  }

  @override
  Future<MessagingPairings> messagingPairings({String? profile}) async {
    if (pairingFails) throw ApiException(404, 'pairing unsupported');
    return const MessagingPairings();
  }

  @override
  Future<Map<String, dynamic>> updateMessagingPlatform(
    String platform, {
    bool? enabled,
    Map<String, String>? env,
    List<String>? clearEnv,
    String? profile,
  }) async {
    updates++;
    lastProfile = profile;
    if (enabled != null) platformEnabled = enabled;
    tokenSet = env?['TELEGRAM_BOT_TOKEN']?.isNotEmpty == true;
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> restartGateway() async {
    restarts++;
    return {'ok': true};
  }
}

Future<void> _pump(WidgetTester tester, _MessagingApi api) async {
  final connection = ConnectionStore()..api = api;
  final scope = ProfileScopeStore()..bindApi(api);
  addTearDown(() {
    connection.dispose();
    scope.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider<ProfileScopeStore>.value(value: scope),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MessagingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'default profile reads messaging state from ambient Hermes root',
    (tester) async {
      final api = _MessagingApi()..activeProfile = 'default';
      await _pump(tester, api);

      expect(find.text('Telegram'), findsOneWidget);
      expect(api.lastProfile, isNull);
    },
  );

  testWidgets('pairing failure does not hide configurable platforms', (
    tester,
  ) async {
    final api = _MessagingApi();
    await _pump(tester, api);

    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);
    expect(find.textContaining('pairing unsupported'), findsNothing);
    expect(api.lastProfile, 'work');
  });

  testWidgets('required credentials persist, verify, and offer restart', (
    tester,
  ) async {
    final api = _MessagingApi();
    await _pump(tester, api);

    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('This field is required'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.updates, 0);

    await tester.enterText(find.byType(TextField), '123456:token');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.updates, 1);
    expect(api.tokenSet, isTrue);
    expect(api.lastProfile, 'work');
    expect(find.text('Restart Gateway?'), findsOneWidget);

    await tester.tap(find.text('Restart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.restarts, 1);
  });

  testWidgets('platform toggle persists and offers restart', (tester) async {
    final api = _MessagingApi();
    await _pump(tester, api);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.updates, 1);
    expect(api.platformEnabled, isFalse);
    expect(api.lastProfile, 'work');
    expect(find.text('Restart Gateway?'), findsOneWidget);

    await tester.tap(find.text('Restart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.restarts, 1);
  });
}
