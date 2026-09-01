import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_page_scaffold.dart';

void main() {
  testWidgets(
    'mobile page shell keeps title, safe content and actions visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(brightness: Brightness.light),
          home: const MobilePageScaffold(
            title: '功能页',
            subtitle: '状态说明',
            actions: [IconButton(onPressed: null, icon: Icon(Icons.search))],
            body: Text('页面内容'),
          ),
        ),
      );

      expect(find.text('功能页'), findsOneWidget);
      expect(find.text('状态说明'), findsOneWidget);
      expect(find.text('页面内容'), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.byIcon(Icons.search), findsOneWidget);
    },
  );

  testWidgets('mobile sheet follows the keyboard inset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showMobileSheet<void>(
                context,
                (_) => const SizedBox(height: 120, child: Text('编辑内容')),
              ),
              child: const Text('打开'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('编辑内容'), findsOneWidget);
  });
}
