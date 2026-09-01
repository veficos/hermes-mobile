import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_ar.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/screens/credentials_screen.dart';
import 'package:provider/provider.dart';

class _CredentialsApi extends ApiClient {
  _CredentialsApi()
    : super(baseUrl: 'http://credentials.invalid', apiKey: 'test');

  String? savedSlug;
  String? savedKey;
  final List<String> disconnected = [];
  bool azureAuthenticated = true;

  @override
  Future<List<CredentialProvider>> credentialProviders() async => [
    CredentialProvider(
      slug: 'azure',
      name: 'Azure',
      authenticated: azureAuthenticated,
    ),
    CredentialProvider(slug: 'openai', name: 'OpenAI'),
    CredentialProvider(slug: 'github', name: 'GitHub'),
    CredentialProvider(
      slug: 'bedrock',
      name: 'AWS Bedrock',
      authType: 'aws_sdk',
    ),
  ];

  @override
  Future<Map<String, dynamic>> saveCredentialKey(
    String slug,
    String apiKey,
  ) async {
    savedSlug = slug;
    savedKey = apiKey;
    return const {};
  }

  @override
  Future<void> disconnectCredential(String slug) async {
    disconnected.add(slug);
    if (slug == 'azure') azureAuthenticated = false;
  }
}

Future<_CredentialsApi> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
  TextScaler textScaler = TextScaler.noScaling,
  Size size = const Size(800, 700),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = _CredentialsApi();
  final connection = ConnectionStore()..api = api;
  addTearDown(connection.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ConnectionStore>.value(
      value: connection,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const CredentialsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  final l10n = AppLocalizationsZh();

  testWidgets('groups provider rows by their category identifiers', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text(l10n.credentialsGroupCloud), findsOneWidget);
    expect(find.text(l10n.credentialsGroupModelProviders), findsOneWidget);
    expect(find.text(l10n.credentialsGroupThirdParty), findsOneWidget);
    expect(find.text('Azure'), findsWidgets);
    expect(find.text('AWS Bedrock'), findsNothing);
    expect(find.text('OpenAI'), findsWidgets);
    expect(find.text('GitHub'), findsWidgets);
  });

  testWidgets(
    'credential editor submits the supported provider and key fields',
    (tester) async {
      final api = await _pump(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.credentialsAddTitle), findsOneWidget);
      expect(find.textContaining('Secret Access Key'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'new-secret',
      );
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonSave));
      await tester.pumpAndSettle();

      expect(api.savedSlug, 'azure');
      expect(api.savedKey, 'new-secret');
    },
  );

  testWidgets('supports narrow Arabic RTL, 2x text, and button semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final ar = AppLocalizationsAr();

    await _pump(
      tester,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(2),
      size: const Size(320, 700),
    );

    expect(find.text(ar.credentialsGroupCloud), findsOneWidget);
    expect(find.bySemanticsLabel(ar.credentialsAddTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('disconnects a configured credential after confirmation', (
    tester,
  ) async {
    final api = await _pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDisconnect));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.credentialsDisconnectQuestion('Azure')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonDisconnect));
    await tester.pumpAndSettle();

    expect(api.disconnected, ['azure']);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
