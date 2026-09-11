import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/notification_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/notification_screen.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';

void main() {
  testWidgets('Liquid notifications keep header and clear confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final connection = ConnectionStore();
    final store = NotificationStore(connection: connection);
    for (var i = 0; i < 20; i++) {
      store.addExternal(
        key: 'preview-$i',
        kind: NotificationKind.info,
        title: 'Notification $i',
        message: 'Preview message',
      );
    }
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: const NotificationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NestedScrollView), findsOneWidget);
    expect(find.byType(SliverAppBar), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    final markRead = find.ancestor(
      of: find.byIcon(Icons.done_all),
      matching: find.byType(GlassButton),
    );
    expect(markRead.hitTestable(), findsOneWidget);
    await tester.tap(markRead);
    await tester.pumpAndSettle();
    expect(store.unreadCount, 0);
    expect(tester.widget<GlassButton>(markRead).onPressed, isNull);
    final clear = find.ancestor(
      of: find.byIcon(Icons.delete_sweep_outlined),
      matching: find.byType(GlassButton),
    );
    expect(clear.hitTestable(), findsOneWidget);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(store.items.length, 20);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.items.length, 20);
    store.clear();
    await tester.pumpAndSettle();
    expect(find.byType(NestedScrollView), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    connection.dispose();
  });
}
