import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/widgets/preview/artifact_preview.dart';
import 'package:provider/provider.dart';

class _ArtifactApi extends ApiClient {
  _ArtifactApi({this.error})
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final Object? error;

  @override
  Future<List<ArtifactItem>> artifacts({
    String? sessionId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (error != null) throw error!;
    return const [];
  }
}

class _ArtifactSession extends SessionStore {
  _ArtifactSession({
    required super.connection,
    required super.chat,
    required super.requests,
    this.testDurableId,
  });

  final String? testDurableId;

  @override
  String? get durableId => testDurableId;
}

Future<void> _pump(
  WidgetTester tester, {
  ApiClient? api,
  String? durableId,
}) async {
  final connection = ConnectionStore()..api = api;
  final chat = ChatStore();
  final requests = RequestStore();
  final session = _ArtifactSession(
    connection: connection,
    chat: chat,
    requests: requests,
    testDurableId: durableId,
  );
  addTearDown(() {
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
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ArtifactListView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offline is not rendered as an empty artifact list', (
    tester,
  ) async {
    await _pump(tester, durableId: 'session-1');
    expect(find.text('后端未连接'), findsOneWidget);
    expect(find.text('暂无工件'), findsNothing);
  });

  testWidgets('artifact API failures expose a retryable error', (tester) async {
    await _pump(
      tester,
      api: _ArtifactApi(error: StateError('artifact unavailable')),
      durableId: 'session-1',
    );
    expect(find.textContaining('artifact unavailable'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('暂无工件'), findsNothing);
  });

  testWidgets('an unsaved session has a distinct pending state', (
    tester,
  ) async {
    await _pump(tester, api: _ArtifactApi());
    expect(find.text('开始会话后查看工件'), findsOneWidget);
    expect(find.text('暂无工件'), findsNothing);
  });

  testWidgets('a successful empty response remains an honest empty state', (
    tester,
  ) async {
    await _pump(tester, api: _ArtifactApi(), durableId: 'session-1');
    expect(find.text('暂无工件'), findsOneWidget);
  });
}
