import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/connect_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecrets implements ConnectionSecretStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('direct gateway OAuth cannot connect before native login', (
    tester,
  ) async {
    final connection = ConnectionStore(
      store: SettingsStore(secrets: _MemorySecrets()),
    );
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: connection,
        child: const MaterialApp(home: ConnectScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('API 密钥'), findsOneWidget);
    await tester.tap(find.text('Direct Gateway'));
    await tester.pump();
    expect(find.text('从 Hermes Cloud 发现 Agent'), findsOneWidget);
    expect(find.text('Gateway 令牌'), findsOneWidget);

    await tester.tap(find.text('OAuth'));
    await tester.pump();
    expect(find.text('尚未登录'), findsOneWidget);
    final connect = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '连接'),
    );
    expect(connect.onPressed, isNull);
  });

  testWidgets('SSH transport shows only SSH credentials and hides secrets', (
    tester,
  ) async {
    final connection = ConnectionStore(
      store: SettingsStore(secrets: _MemorySecrets()),
    );
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: connection,
        child: const MaterialApp(home: ConnectScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('SSH'));
    await tester.pump();

    expect(find.text('SSH 主机'), findsOneWidget);
    expect(find.text('SSH 用户'), findsOneWidget);
    expect(find.text('OpenSSH / PEM 私钥'), findsOneWidget);
    expect(find.text('服务器地址'), findsNothing);
    expect(find.text('API 密钥'), findsNothing);
    expect(find.text('Gateway Token'), findsNothing);

    final keyField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'OpenSSH / PEM 私钥'),
    );
    final passphraseField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, '私钥口令（可选）'),
    );
    final passwordField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'SSH 密码（可选）'),
    );
    bool isObscured(TextFormField field) => tester
        .widgetList<EditableText>(find.byType(EditableText))
        .singleWhere((editable) => editable.controller == field.controller)
        .obscureText;
    expect(isObscured(keyField), isTrue);
    expect(isObscured(passphraseField), isTrue);
    expect(isObscured(passwordField), isTrue);
  });

  testWidgets('connection form renders English and Arabic RTL', (tester) async {
    final connection = ConnectionStore(
      store: SettingsStore(secrets: _MemorySecrets()),
    );
    addTearDown(connection.dispose);

    Widget app(Locale locale) => ChangeNotifierProvider.value(
      value: connection,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ConnectScreen(),
      ),
    );

    await tester.pumpWidget(app(const Locale('en')));
    await tester.pump();
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('Server address'), findsOneWidget);
    expect(find.text('Allow public cleartext HTTP'), findsOneWidget);

    await tester.pumpWidget(app(const Locale('ar')));
    await tester.pump();
    final title = find.text('الاتصال');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    expect(find.text('عنوان الخادم'), findsOneWidget);
  });
}
