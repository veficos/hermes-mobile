import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gateway extends GatewayClient {
  _Gateway() : super(serverBaseUrl: 'http://reaction.invalid', apiKey: 'x');
  bool reject = true;

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (method == 'session.create') {
      return {'session_id': 'rt', 'stored_session_id': 'sid'};
    }
    if (method == 'message.react') {
      if (reject) throw GatewayException(-32601, 'unsupported');
      return {
        'row_id': 7,
        'reactions': [
          {'emoji': '👍', 'author': 'user', 'at': 1},
        ],
      };
    }
    return {};
  }
}

class _Connection extends ConnectionStore {
  _Connection(GatewayClient client) {
    gateway = client;
  }

  @override
  Future<void> ensureConnected() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reaction write rolls back on unsupported backend and commits on success',
    () async {
      final gateway = _Gateway();
      final connection = _Connection(gateway);
      final chat = ChatStore();
      final session = SessionStore(
        connection: connection,
        chat: chat,
        requests: RequestStore(),
      );
      addTearDown(session.dispose);
      addTearDown(chat.dispose);
      addTearDown(connection.dispose);
      await session.openNewSession();
      final message = ChatMessage(
        id: 'm',
        role: 'assistant',
        rowId: 7,
        parts: [ChatPart.text('done')],
      );
      chat.loadHistory([message], hasMore: false);

      await expectLater(
        session.reactToMessage(message, '👍'),
        throwsA(isA<GatewayException>()),
      );
      expect(chat.messages.single.reactions, isEmpty);

      gateway.reject = false;
      await session.reactToMessage(chat.messages.single, '👍');
      expect(chat.messages.single.reactions.single.emoji, '👍');
    },
  );
}
