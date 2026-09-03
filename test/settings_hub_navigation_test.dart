import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/appearance_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/locale_store.dart';
import 'package:hermes_mobile/core/stores/plugin_contribution_store.dart';
import 'package:hermes_mobile/screens/settings_hub_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('wide settings can return to the page that opened it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final connection = ConnectionStore();
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppearanceStore()),
          ChangeNotifierProvider(create: (_) => LocaleStore()),
          ChangeNotifierProvider.value(value: connection),
          ChangeNotifierProvider(
            create: (_) => PluginContributionStore(connection),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsHubScreen()),
                ),
                child: const Text('打开设置'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('返回主页'), findsOneWidget);
    expect(find.text('能力管理'), findsNothing);

    await tester.tap(find.byTooltip('返回主页'));
    await tester.pumpAndSettle();
    expect(find.text('打开设置'), findsOneWidget);
    expect(find.byType(SettingsHubScreen), findsNothing);
  });
}
