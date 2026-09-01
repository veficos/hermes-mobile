import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/widgets/right_sidebar/git_review_panel.dart';
import 'package:provider/provider.dart';

class _Connection extends ConnectionStore {
  void exposeApi(ApiClient value) {
    api = value;
    notifyListeners();
  }
}

class _GitApi extends ApiClient {
  _GitApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  var diffCalls = 0;

  @override
  Future<Map<String, dynamic>> gitStatus(String path) async => {
    'current': 'main',
    'files': [
      {'path': 'lib/main.dart', 'working_status': 'M', 'index_status': ' '},
    ],
  };

  @override
  Future<Map<String, dynamic>> gitShipInfo(String path) async => {};

  @override
  Future<String> gitFileDiff(String path, String file) async {
    diffCalls++;
    if (diffCalls == 1) throw StateError('diff unavailable');
    return '+ fixed';
  }
}

class _DeferredGitApi extends _GitApi {
  final statusResult = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> gitStatus(String path) => statusResult.future;
}

class _NamedGitApi extends _GitApi {
  _NamedGitApi(this.file);

  final String file;

  @override
  Future<Map<String, dynamic>> gitStatus(String path) async => {
    'current': 'main',
    'files': [
      {'path': file, 'working_status': 'M', 'index_status': ' '},
    ],
  };
}

Future<void> _pump(
  WidgetTester tester,
  _Connection connection, {
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) async {
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
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: GitReviewPanel(initialPath: '/workspace')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offline panel recovers when a connection becomes available', (
    tester,
  ) async {
    final connection = _Connection();
    addTearDown(connection.dispose);
    await _pump(tester, connection);

    expect(find.text('后端未连接'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    connection.exposeApi(_GitApi());
    await tester.pumpAndSettle();
    expect(find.text('lib/main.dart'), findsOneWidget);
  });

  testWidgets('diff failure has a retry path', (tester) async {
    final connection = _Connection();
    final api = _GitApi();
    connection.exposeApi(api);
    addTearDown(connection.dispose);
    await _pump(tester, connection);

    await tester.tap(find.text('lib/main.dart'));
    await tester.pumpAndSettle();
    expect(find.textContaining('diff unavailable'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('+ fixed'), findsOneWidget);
    expect(api.diffCalls, 2);
  });

  testWidgets('late status cannot overwrite a reconnected repository', (
    tester,
  ) async {
    final stale = _DeferredGitApi();
    final connection = _Connection()..exposeApi(stale);
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: const MaterialApp(
          home: Scaffold(body: GitReviewPanel(initialPath: '/workspace')),
        ),
      ),
    );
    await tester.pump();

    connection.exposeApi(_NamedGitApi('current.dart'));
    await tester.pumpAndSettle();
    expect(find.text('current.dart'), findsOneWidget);

    stale.statusResult.complete({
      'current': 'old',
      'files': [
        {'path': 'stale.dart', 'working_status': 'M', 'index_status': ' '},
      ],
    });
    await tester.pumpAndSettle();

    expect(find.text('current.dart'), findsOneWidget);
    expect(find.text('stale.dart'), findsNothing);
  });

  testWidgets('panel renders at 320px Arabic RTL and 2x', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final connection = _Connection()..exposeApi(_GitApi());
    addTearDown(connection.dispose);

    await _pump(tester, connection, locale: const Locale('ar'), textScale: 2);

    expect(find.text('lib/main.dart'), findsOneWidget);
    expect(find.byTooltip('التزام'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
