import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/starmap_share_code.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/screens/starmap_screen.dart';
import 'package:provider/provider.dart';

StarmapGraph _sampleGraph() => StarmapGraph(
  nodes: [
    StarmapNode(
      id: 'skill-a',
      label: 'skill-a',
      kind: 'skill',
      category: 'devops',
      timestamp: 1699900000,
      useCount: 7,
      state: 'active',
      createdBy: 'agent',
      pinned: true,
    ),
    StarmapNode(
      id: 'skill-b',
      label: 'skill-b',
      kind: 'skill',
      category: 'devops',
      timestamp: 1699950000,
    ),
    StarmapNode(
      id: 'memory:profile:0',
      label: 'A fact',
      kind: 'memory',
      category: 'memory',
      memorySource: 'profile',
      timestamp: 1700000000,
    ),
  ],
  edges: [StarmapEdge(source: 'skill-a', target: 'skill-b')],
  memory: [
    StarmapMemoryCard(
      source: 'profile',
      timestamp: 1700000000,
      title: 'A fact',
      body: 'Some remembered fact.',
    ),
  ],
);

class _StarmapApi extends ApiClient {
  _StarmapApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  StarmapGraph graph = _sampleGraph();

  @override
  Future<StarmapGraph> starmapGraph() async => graph;

  @override
  Future<Map<String, dynamic>> starmapNode(String id) async => {'content': ''};
}

Future<ConnectionStore> _pump(
  WidgetTester tester, {
  ApiClient? api,
  Locale locale = const Locale('zh'),
  double textScaleFactor = 1,
}) async {
  final connection = ConnectionStore()..api = api ?? _StarmapApi();
  addTearDown(connection.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ConnectionStore>.value(
      value: connection,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
        home: const StarmapScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return connection;
}

void main() {
  final zh = AppLocalizationsZh();

  testWidgets('loads and renders skill and memory nodes without crashing', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('skill-a'), findsOneWidget);
    expect(find.text('skill-b'), findsOneWidget);
    expect(find.text('A fact'), findsOneWidget);
    expect(
      find.text(zh.starmapSkillLegend, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(zh.starmapMemoryLegend, skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty graph shows the empty state', (tester) async {
    final api = _StarmapApi()..graph = StarmapGraph();
    await _pump(tester, api: api);
    expect(find.text(zh.starmapEmpty), findsOneWidget);
  });

  testWidgets('a failed load shows a retryable error state', (tester) async {
    final api = _FailingStarmapApi();
    await _pump(tester, api: api);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('play button starts a reveal sweep and can be paused', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Advance partway through the 15s sweep — reveal should have moved off
    // the idle default (1.0) without finishing.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    // Let any in-flight animation ticks settle before teardown.
    await tester.pumpAndSettle();
  });

  testWidgets('share dialog shows a copyable HML-prefixed code', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text']?.toString();
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(tester);
    await tester.tap(find.byTooltip(zh.starmapShareImport));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, startsWith('HML'));

    await tester.tap(find.widgetWithText(TextButton, zh.starmapCopy));
    await tester.pump();
    expect(clipboardText, field.controller!.text);

    // Let the success toast's auto-dismiss timer fire before teardown.
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets(
    'loading a pasted share code swaps in the imported graph and offers reset',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip(zh.starmapShareImport));
      await tester.pumpAndSettle();

      // A different graph than the live map, encoded through the real codec
      // so pasting it exercises the actual decode path, not a stub.
      final otherCode = encodeStarmapShareCode(
        StarmapGraph(
          nodes: [
            StarmapNode(id: 'only-node', label: 'Only Node', kind: 'skill'),
          ],
        ),
      );
      await tester.enterText(find.byType(TextField), otherCode);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, zh.starmapLoad));
      await tester.pumpAndSettle();

      // The dialog closed, the imported graph's node is now shown, and the
      // app bar offers a way back to the live map.
      expect(find.text('Only Node'), findsOneWidget);
      expect(find.text('skill-a'), findsNothing);
      expect(find.byTooltip(zh.starmapRestoreMine), findsOneWidget);

      await tester.tap(find.byTooltip(zh.starmapRestoreMine));
      await tester.pumpAndSettle();
      expect(find.text('skill-a'), findsOneWidget);
      expect(find.byTooltip(zh.starmapRestoreMine), findsNothing);
    },
  );

  testWidgets('pasting an invalid code shows an inline error, not a crash', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byTooltip(zh.starmapShareImport));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not a real share code');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, zh.starmapLoad));
    await tester.pumpAndSettle();

    // Dialog stays open with an error, no exception escapes to the tester.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320px Arabic RTL at 2x has no overflow and exposes node actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      await _pump(tester, locale: const Locale('ar'), textScaleFactor: 2);

      expect(find.bySemanticsLabel(RegExp('skill-a')), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}

class _FailingStarmapApi extends ApiClient {
  _FailingStarmapApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<StarmapGraph> starmapGraph() async => throw StateError('boom');
}
