import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/transcript/transcript_search_index.dart';
import 'package:hermes_mobile/core/chat_message.dart';

ChatMessage message(
  String id,
  List<ChatPart> parts, {
  String role = 'assistant',
  List<String> attachments = const [],
}) =>
    ChatMessage(id: id, role: role, parts: parts, attachmentRefs: attachments);

void main() {
  test('indexes text reasoning tool metadata and attachment paths', () {
    final index = TranscriptSearchIndex();
    final messages = [
      message('user', [ChatPart.text('Ship the release')], role: 'user'),
      message('reasoning', [ChatPart.reasoning('inspect the scheduler')]),
      message('tool', [
        ChatPart.toolCall({
          'name': 'read_file',
          'arguments': {'path': 'lib/private/engine.dart'},
          'result': {'summary': 'artifact lighthouse'},
        }),
      ]),
      message('attachment', const [], attachments: ['docs/roadmap.pdf']),
    ];
    index.synchronize(messages, 1);

    expect(index.query('release').single.message.id, 'user');
    expect(index.query('scheduler').single.message.id, 'reasoning');
    expect(index.query('engine.dart').single.message.id, 'tool');
    expect(index.query('lighthouse').single.message.id, 'tool');
    expect(index.query('roadmap.pdf').single.message.id, 'attachment');
  });

  test('preserves order and refreshes changed documents', () {
    final index = TranscriptSearchIndex();
    final first = message('a', [ChatPart.text('alpha')]);
    final second = message('b', [ChatPart.text('beta')]);
    index.synchronize([first, second], 1);
    expect(index.query('').map((hit) => hit.message.id), ['a', 'b']);

    final changed = message('b', [ChatPart.text('gamma')]);
    index.synchronize([first, changed], 2);
    expect(index.query('beta'), isEmpty);
    expect(index.query('gamma').single.message, same(changed));
  });

  test('does not index data URI payloads', () {
    final index = TranscriptSearchIndex();
    index.synchronize([
      message('image', [
        ChatPart.toolCall({'result': 'data:image/png;base64,secretpayload'}),
      ]),
    ], 1);
    expect(index.query('secretpayload'), isEmpty);
  });
}
