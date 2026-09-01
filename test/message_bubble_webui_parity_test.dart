import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/widgets/h/hermes_logo.dart';
import 'package:hermes_mobile/widgets/message_bubble.dart';

ChatMessage _assistant({
  bool pending = false,
  String text = '这是一段回答。',
  List<ChatPart>? parts,
  String model = 'openai/gpt-4o',
}) {
  return ChatMessage(
    id: 'a1',
    role: 'assistant',
    parts: parts ?? [ChatPart.text(text, streaming: pending)],
    pending: pending,
    model: model,
    timestamp: DateTime(2026, 8, 16, 10),
  );
}

Future<void> _pump(
  WidgetTester tester,
  ChatMessage message, {
  Future<void> Function(ChatMessage message)? onSpeak,
  VoidCallback? onJumpToQuestion,
  VoidCallback? onMore,
  bool showRoleHeader = true,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MessageBubble(
            message: message,
            onSpeak: onSpeak,
            onJumpToQuestion: onJumpToQuestion,
            onMore: onMore,
            showRoleHeader: showRoleHeader,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('transcript 视觉行为', () {
    testWidgets('手机 user 气泡约占可用宽度 78% 且支持 fenced code block', (tester) async {
      await _pump(
        tester,
        ChatMessage(
          id: 'u-code',
          role: 'user',
          parts: [ChatPart.text('```dart\nvoid main() {}\n```')],
        ),
      );

      final bubble = tester.widget<Container>(
        find.byKey(const ValueKey('user-message-bubble')),
      );
      expect(bubble.constraints!.maxWidth, closeTo(312, 0.1));
      expect(find.text('DART'), findsOneWidget);
      expect(find.byTooltip('复制'), findsOneWidget);
    });

    testWidgets('showRoleHeader=false 隐藏连续 assistant 的重复角色头', (tester) async {
      await _pump(tester, _assistant(), showRoleHeader: false);
      expect(find.byKey(const ValueKey('assistant-role-header')), findsNothing);
      expect(find.text('这是一段回答。'), findsOneWidget);
    });

    testWidgets('assistant 角色头只展示 HermesLogo 翼标头像', (tester) async {
      const model = 'hy3:free/model';
      await _pump(tester, _assistant(model: model));

      final roleHeader = find.byKey(const ValueKey('assistant-role-header'));
      final avatar = find.descendant(
        of: roleHeader,
        matching: find.byKey(const ValueKey('assistant-avatar-icon')),
      );
      expect(roleHeader, findsOneWidget);
      expect(avatar, findsOneWidget);
      expect(
        find.descendant(of: avatar, matching: find.byType(HermesLogo)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: roleHeader, matching: find.text('Hermes')),
        findsNothing,
      );
      expect(
        find.descendant(of: roleHeader, matching: find.text('H')),
        findsNothing,
      );
      expect(
        find.descendant(of: roleHeader, matching: find.text(model)),
        findsNothing,
      );
    });

    testWidgets('assistant footer 操作触摸目标至少 40dp 且窄屏不溢出', (tester) async {
      await _pump(tester, _assistant(), width: 280);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('msg-speak-btn'))).width,
        greaterThanOrEqualTo(40),
      );
      expect(
        tester.getSize(find.byTooltip('复制文本')).height,
        greaterThanOrEqualTo(40),
      );
    });

    testWidgets('用户和 assistant 消息都提供可见的更多操作入口', (tester) async {
      var taps = 0;
      final moreTooltip = AppLocalizationsZh().commonMore;
      await _pump(tester, _assistant(), onMore: () => taps++);
      await tester.tap(find.byTooltip(moreTooltip));
      expect(taps, 1);

      await _pump(
        tester,
        ChatMessage(id: 'u-more', role: 'user', parts: [ChatPart.text('消息')]),
        onMore: () => taps++,
      );
      await tester.tap(find.byTooltip(moreTooltip));
      expect(taps, 2);
    });

    testWidgets('回到话题按钮与富文本脚注各自独立渲染', (tester) async {
      // B8: model/time/usage now live in one combined footnote line
      // (`msg-footnote`) below the action-icon row, decoupled from the
      // "回到话题" jump button — the two used to be nested in the same Row,
      // so the model only ever showed when a jump target existed.
      await _pump(
        tester,
        _assistant(model: 'openai/gpt-5.6'),
        onJumpToQuestion: () {},
      );

      final footnote = find.byKey(const ValueKey('msg-footnote'));
      final jump = find.byKey(const ValueKey('msg-question-jump-btn'));
      expect(footnote, findsOneWidget);
      expect(jump, findsOneWidget);
      expect(tester.widget<Text>(footnote).data, contains('gpt-5.6'));
    });

    testWidgets('富文本脚注不依赖是否能跳回提问也会显示', (tester) async {
      // Regression: the model used to be nested inside the "回到话题" jump
      // button's own Row, so it only ever appeared when onJumpToQuestion
      // was wired — hiding which model answered for most messages in
      // practice. The footnote and the jump button are unrelated and must
      // render independently.
      await _pump(tester, _assistant(model: 'openai/gpt-5.6'));

      final footnote = find.byKey(const ValueKey('msg-footnote'));
      expect(footnote, findsOneWidget);
      expect(tester.widget<Text>(footnote).data, contains('gpt-5.6'));
      expect(find.byKey(const ValueKey('msg-question-jump-btn')), findsNothing);
    });
  });

  group('B14 流式光标', () {
    testWidgets('pending assistant 消息在正文末尾显示闪烁光标', (tester) async {
      await _pump(tester, _assistant(pending: true, text: '正在生成'));
      expect(find.byKey(const ValueKey('streaming-cursor')), findsOneWidget);
    });

    testWidgets('完成后（pending=false）光标消失', (tester) async {
      await _pump(tester, _assistant());
      expect(find.byKey(const ValueKey('streaming-cursor')), findsNothing);
    });

    testWidgets('user 消息 pending 时不显示光标（仅 assistant）', (tester) async {
      await _pump(
        tester,
        ChatMessage(
          id: 'u1',
          role: 'user',
          parts: [ChatPart.text('你好')],
          pending: true,
        ),
      );
      expect(find.byKey(const ValueKey('streaming-cursor')), findsNothing);
    });
  });

  group('B18 单条消息 TTS', () {
    testWidgets('assistant footer 存在朗读按钮', (tester) async {
      await _pump(tester, _assistant());
      expect(find.byKey(const ValueKey('msg-speak-btn')), findsOneWidget);
      expect(find.byTooltip('朗读'), findsOneWidget);
    });

    testWidgets('点击朗读按钮回调携带去除 markdown 的纯文本', (tester) async {
      ChatMessage? spoken;
      await _pump(
        tester,
        _assistant(text: '**加粗** 和 `code`，见 [链接](https://x.com)'),
        onSpeak: (m) async => spoken = m,
      );
      await tester.tap(find.byKey(const ValueKey('msg-speak-btn')));
      await tester.pump();
      expect(spoken, isNotNull);
      expect(spoken!.plainText, '加粗 和 code，见 链接');
    });

    testWidgets('pending 流式消息不渲染 footer（含朗读按钮）', (tester) async {
      await _pump(tester, _assistant(pending: true));
      expect(find.byKey(const ValueKey('msg-speak-btn')), findsNothing);
    });
  });

  group('activity 直接展示', () {
    testWidgets('思考与正文按顺序直接渲染，无工作记录分组', (tester) async {
      await _pump(
        tester,
        _assistant(
          parts: [
            ChatPart.reasoning('思考内容', streaming: true),
            ChatPart.text('最终回答'),
          ],
        ),
      );

      expect(find.text('思考内容'), findsOneWidget);
      expect(find.text('最终回答'), findsOneWidget);
      expect(find.textContaining('工作记录'), findsNothing);
      expect(find.textContaining('正在工作'), findsNothing);
    });
  });

  group('B11 思考显隐', () {
    Future<void> pumpReasoning(WidgetTester tester) async {
      await _pump(
        tester,
        _assistant(
          parts: [ChatPart.reasoning('思考内容全文'), ChatPart.text('最终回答')],
        ),
      );
    }

    testWidgets('默认展开显示全文，点击卡片标题可隐藏', (tester) async {
      await pumpReasoning(tester);

      expect(find.text('思考内容全文'), findsOneWidget);
      expect(find.text('思考过程'), findsOneWidget);

      // Prototype parity (`.toolhead`/`.chevicon`): no separate toggle
      // control — the whole header is the tap target, matching every other
      // process card (HermesToolCard/ToolGroupCard) in the transcript.
      await tester.tap(find.text('思考过程'));
      await tester.pumpAndSettle();
      expect(find.text('思考内容全文'), findsNothing);

      await tester.tap(find.text('思考过程'));
      await tester.pumpAndSettle();
      expect(find.text('思考内容全文'), findsOneWidget);
    });
  });
}
