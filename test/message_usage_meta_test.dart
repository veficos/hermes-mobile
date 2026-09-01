import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/widgets/message_bubble.dart';

ChatMessage _assistant({
  Map<String, dynamic>? usage,
  String? model,
  DateTime? timestamp,
}) {
  return ChatMessage(
    id: 'a1',
    role: 'assistant',
    parts: [ChatPart.text('这是一段回答。')],
    model: model ?? 'openai/gpt-4o',
    usage: usage,
    timestamp: timestamp ?? DateTime.now(),
  );
}

Future<void> _pump(WidgetTester tester, ChatMessage message) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MessageBubble(message: message)),
    ),
  );
  await tester.pump();
}

/// The B8 footnote leads with a relative-time string ("刚刚"/"3分钟前"/…)
/// that depends on wall-clock `DateTime.now()` at render time, so tests
/// assert with `contains`/`endsWith` on the deterministic tail instead of
/// exact equality on the whole line.
void main() {
  testWidgets('footnote combines time, model and real usage values', (
    tester,
  ) async {
    await _pump(
      tester,
      _assistant(
        usage: const {
          'input_tokens': 1234,
          'output_tokens': 356,
          'tps': 42.3,
          'duration_ms': 3400,
        },
      ),
    );

    final meta = find.byKey(const ValueKey('msg-footnote'));
    expect(meta, findsOneWidget);
    final text = tester.widget<Text>(meta).data!;
    expect(text, contains('gpt-4o'));
    expect(text, endsWith('gpt-4o · 1.2k/356 tok · 42 tok/s · 3.4s'));
  });

  testWidgets('actually-used model replaces the header model, not duplicated', (
    tester,
  ) async {
    await _pump(
      tester,
      _assistant(
        model: 'openai/gpt-4o',
        usage: const {'output_tokens': 64, 'used_model': 'openai/gpt-4o-mini'},
      ),
    );

    final meta = find.byKey(const ValueKey('msg-footnote'));
    expect(meta, findsOneWidget);
    final text = tester.widget<Text>(meta).data!;
    // The gateway routed to gpt-4o-mini instead of the requested gpt-4o —
    // the footnote shows the model that actually answered exactly once,
    // not both the header model and the used model back to back.
    expect(text, endsWith('gpt-4o-mini · 64 tok out'));
    expect('gpt-4o'.allMatches(text).length, 1);
  });

  testWidgets('no usage data still shows the time/model line, no fake usage', (
    tester,
  ) async {
    await _pump(tester, _assistant());
    final meta = find.byKey(const ValueKey('msg-footnote'));
    expect(meta, findsOneWidget);
    expect(tester.widget<Text>(meta).data, endsWith('gpt-4o'));
    // 复制/重生成按钮行仍然保留。
    expect(find.byTooltip('复制文本'), findsOneWidget);
  });

  testWidgets('empty usage map renders time/model with no usage segment', (
    tester,
  ) async {
    await _pump(tester, _assistant(usage: const {}));
    final meta = find.byKey(const ValueKey('msg-footnote'));
    expect(meta, findsOneWidget);
    expect(tester.widget<Text>(meta).data, endsWith('gpt-4o'));
  });

  testWidgets('partial usage renders only the segments that exist', (
    tester,
  ) async {
    await _pump(tester, _assistant(usage: const {'tokens_per_second': 8.25}));
    final meta = find.byKey(const ValueKey('msg-footnote'));
    expect(meta, findsOneWidget);
    expect(tester.widget<Text>(meta).data, endsWith('gpt-4o · 8.3 tok/s'));
  });

  testWidgets('no timestamp and no model renders no footnote at all', (
    tester,
  ) async {
    await _pump(
      tester,
      ChatMessage(
        id: 'a2',
        role: 'assistant',
        parts: [ChatPart.text('无元数据的回答')],
      ),
    );
    expect(find.byKey(const ValueKey('msg-footnote')), findsNothing);
  });
}
