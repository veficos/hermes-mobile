import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MutableConnection extends ConnectionStore {
  void replaceApi(ApiClient next) {
    api = next;
    notifyListeners();
  }
}

class _DelayedSessionsApi extends ApiClient {
  _DelayedSessionsApi(this.id)
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  final String id;
  final gate = Completer<void>();
  int calls = 0;

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    calls++;
    await gate.future;
    return SessionPage(
      sessions: [
        SessionRow.fromJson({'id': id, 'title': id}),
      ],
      offset: 0,
      hasMore: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'late session list from an old API cannot overwrite a new API',
    () async {
      SharedPreferences.setMockInitialValues({});
      final oldApi = _DelayedSessionsApi('old');
      final newApi = _DelayedSessionsApi('new');
      final connection = _MutableConnection()..api = oldApi;
      final chat = ChatStore();
      final requests = RequestStore();
      final store = SessionStore(
        connection: connection,
        chat: chat,
        requests: requests,
        persistLastSession: false,
      );
      addTearDown(() {
        store.dispose();
        chat.dispose();
        requests.dispose();
        connection.dispose();
      });

      final oldRefresh = store.refreshList();
      connection.replaceApi(newApi);
      while (newApi.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      newApi.gate.complete();
      while (store.sessions?.singleOrNull?.id != 'new') {
        await Future<void>.delayed(Duration.zero);
      }

      oldApi.gate.complete();
      await oldRefresh;
      expect(store.sessions?.single.id, 'new');
    },
  );
}
