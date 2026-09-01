import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/widgets/message_bubble.dart';

/// Regression coverage for a real broken session: `image_generate` returns
/// `{"success": true, "image": "<url>", ...}`, but the generated-image tool
/// card only ever looked for `image_url`/`url`/`data_url` inside
/// `data['result']` — a Map that historical/persisted tool calls never
/// populate at all (only `result_text`, a JSON string, per
/// `ChatStore._historyToolData`). So a past session's generated images
/// never resolved a URL and always fell back to the "等待图片结果"
/// placeholder, even though the call succeeded and the URL was right there.
void main() {
  testWidgets(
    'a historical image_generate call resolves its image from result_text',
    (tester) async {
      final messages = ChatStore().fromSessionMessages([
        {
          'role': 'assistant',
          'content': '',
          'tool_calls': [
            {
              'id': 'call-img',
              'type': 'function',
              'function': {
                'name': 'image_generate',
                'arguments': '{"prompt":"a cat"}',
              },
            },
          ],
        },
        {
          'role': 'tool',
          'tool_call_id': 'call-img',
          'content':
              '{"success": true, '
              '"image": "https://v3b.fal.media/files/b/0aa820c7/cat.png", '
              '"modality": "text", "upscaled": false}',
        },
      ]);
      final message = messages.singleWhere(
        (candidate) => candidate.parts.any(
          (part) =>
              part.kind == 'tool' &&
              part.tool?['name']?.toString() == 'image_generate',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(message: message, showFooter: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('等待图片结果'), findsNothing);
      expect(find.text('图片生成失败'), findsNothing);
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(
        (image.image as NetworkImage).url,
        'https://v3b.fal.media/files/b/0aa820c7/cat.png',
      );
    },
  );
}
