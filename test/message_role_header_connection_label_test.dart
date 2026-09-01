import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/widgets/message_bubble.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecrets implements ConnectionSecretStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// "在聊天对话框hermes的头像隔壁加上当前连接的备注" — the assistant role
/// header's Hermes avatar should be accompanied by a short label for the
/// active connection, so a multi-server setup shows at a glance which
/// backend answered.
ChatMessage _assistant() => ChatMessage(
  id: 'a1',
  role: 'assistant',
  parts: [ChatPart.text('这是一段回答。')],
  timestamp: DateTime(2026, 8, 16, 10),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the saved profile name next to the avatar when it matches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hermes_mobile_server_profiles':
          '[{"name":"办公室服务器","serverUrl":"http://10.0.0.5:9001","apiKey":"k"}]',
    });
    final connection =
        ConnectionStore(store: SettingsStore(secrets: _MemorySecrets()))
          ..settings = const ConnectionSettings(
            serverUrl: 'http://10.0.0.5:9001',
            apiKey: 'k',
          );
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: MaterialApp(
          home: Scaffold(body: MessageBubble(message: _assistant())),
        ),
      ),
    );
    // Matching against the saved-profile list is a background lookup (see
    // ConnectionStore._resolveActiveProfileLabel) — not the full load(),
    // which would also attempt a real connect() and leave pending timers.
    await connection.refreshActiveConnectionLabel();
    await tester.pump();

    final label = find.byKey(const ValueKey('assistant-connection-label'));
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).data, '办公室服务器');
  });

  testWidgets('falls back to the host when no saved profile matches', (
    tester,
  ) async {
    final connection = ConnectionStore()
      ..settings = const ConnectionSettings(
        serverUrl: 'http://127.0.0.1:9001',
        apiKey: 'k',
      );
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: MaterialApp(
          home: Scaffold(body: MessageBubble(message: _assistant())),
        ),
      ),
    );
    await tester.pump();

    final label = find.byKey(const ValueKey('assistant-connection-label'));
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).data, '127.0.0.1:9001');
  });

  testWidgets('renders with no crash and no label when unconfigured', (
    tester,
  ) async {
    final connection = ConnectionStore();
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: MaterialApp(
          home: Scaffold(body: MessageBubble(message: _assistant())),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('assistant-connection-label')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('assistant-avatar-icon')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders fine with no ConnectionStore in the tree at all (bare tests)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MessageBubble(message: _assistant())),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('assistant-connection-label')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('assistant-avatar-icon')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
