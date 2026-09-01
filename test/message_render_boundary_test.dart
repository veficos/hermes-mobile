import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/message_bubble.dart';

void main() {
  testWidgets('one broken message renders a local fallback', (tester) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            MessageRenderBoundary(
              messageId: 'broken',
              builder: (_) => throw StateError('bad part'),
            ),
            const Text('healthy sibling'),
          ],
        ),
      ),
    );
    expect(find.byKey(const ValueKey('message-render-error-broken')), findsOne);
    expect(find.text('healthy sibling'), findsOneWidget);
  });
}
