import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/chat/transcript/chat_message_list.dart';
import 'package:hermes_mobile/chat/content/inline_content_renderer.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets('Chinese reveal respects reduce motion: $reduceMotion', (tester) async {
      Widget app(String text) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: StreamingInlineContentRenderer(text: text)),
        ),
      );
      String visible() => tester.widgetList<InlineContentRenderer>(
          find.byType(InlineContentRenderer)).map((w) => w.text).join();
      await tester.pumpWidget(app('你好'));
      expect(visible(), '你好');
      const full = '你好正在逐字回复';
      await tester.pumpWidget(app(full));
      if (reduceMotion) {
        expect(visible(), full);
      } else {
        expect(visible(), '你好');
        await tester.pump(const Duration(milliseconds: 42));
        expect(visible(), '你好正');
        for (var i = 0; i < 14; i++) {
          await tester.pump(const Duration(milliseconds: 42));
        }
        expect(visible(), full);
      }
      await tester.pumpWidget(app('替换后的正文'));
      expect(visible(), '替换后的正文');
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('live bubble shows deltas before completion', (tester) async {
    final events = StreamController<GatewayEvent>();
    final chat = ChatStore()..attachEvents(events.stream);
    events.add(GatewayEvent(type: 'message.start', payload: {}));
    await tester.pump();
    final placeholder = chat.messages.last;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: chat,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: StreamingBubble(fallback: placeholder,
            showRoleHeader: false, onTick: (_) {})),
      ),
    ));
    for (final text in ['你好', '，正在逐字回复']) {
      events.add(GatewayEvent(type: 'message.delta',
          payload: {text == '你好' ? 'text' : 'delta': text}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 600));
      final rendered = tester.widgetList<InlineContentRenderer>(
          find.byType(InlineContentRenderer)).map((w) => w.text).join();
      expect(rendered, contains(text));
      expect(chat.isStreaming, isTrue);
    }
    await tester.pumpWidget(const SizedBox());
    chat.dispose();
    unawaited(events.close());
  });
}
