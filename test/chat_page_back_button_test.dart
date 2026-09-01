import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';

void main() {
  for (final width in [840.0, 1200.0]) {
    testWidgets('chat page exposes a workspace return entry at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(leading: const ChatPageBackButton()),
                    ),
                  ),
                ),
                child: const Text('打开聊天'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开聊天'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('返回工作区'), findsOneWidget);
      await tester.tap(find.byTooltip('返回工作区'));
      await tester.pumpAndSettle();
      expect(find.text('打开聊天'), findsOneWidget);
    });
  }
}
