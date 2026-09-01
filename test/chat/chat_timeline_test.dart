import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/timeline/chat_timeline.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/core/chat_message.dart';

ChatPart tool(
  String id, {
  bool running = false,
  bool error = false,
  String name = 'terminal',
}) => ChatPart.toolCall({
  'tool_id': id,
  'name': name,
  'running': running,
  'is_error': error,
});

void main() {
  test('groups adjacent tools and preserves non-tool boundaries', () {
    final message = ChatMessage(
      id: 'm',
      role: 'assistant',
      parts: [
        ChatPart.text('before'),
        tool('a'),
        tool('b', running: true),
        ChatPart.reasoning('after'),
      ],
    );
    final items = buildChatTimeline([message]);
    expect(items.whereType<ChatTimelineToolGroup>(), hasLength(1));
    final group = items.whereType<ChatTimelineToolGroup>().single;
    expect(group.tools, hasLength(2));
    expect(group.running, isTrue);
  });

  // A "使用了 X 个工具" rollup must not fragment a turn's tool activity into
  // several sibling cards — every consecutive tool call joins the same
  // group regardless of whether it has its own rich standalone presentation
  // (a diff, an image preview, a delegated subagent, …). Reaching that rich
  // presentation for a merged call happens by tapping its row instead (see
  // `ToolGroupCard`'s `detailBuilder`).
  test(
    'a dedicated tool call between two generic ones still merges into one group',
    () {
      final message = ChatMessage(
        id: 'm',
        role: 'assistant',
        parts: [
          tool('a', name: 'read_file'),
          tool('b', name: 'list_files'),
          tool('c', name: 'patch'),
          tool('d', name: 'terminal'),
          tool('e', name: 'web_search'),
        ],
      );
      final items = buildChatTimeline([message]);

      final groups = items.whereType<ChatTimelineToolGroup>().toList();
      expect(
        groups,
        hasLength(1),
        reason: 'the whole run merges into one rollup',
      );
      expect(groups.single.tools.map((p) => p.tool?['tool_id']), [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]);
      // No standalone card breaks out for the dedicated `patch` call.
      expect(items.whereType<ChatTimelineMessage>(), isEmpty);
    },
  );

  // A run of length 1 still isn't worth a "使用了 1 个工具" wrapper — it's
  // unwrapped back to a plain, full-detail `ChatTimelineMessage`, regardless
  // of whether the lone call is exploratory or dedicated.
  test('a lone tool call never becomes a one-item group', () {
    final message = ChatMessage(
      id: 'm',
      role: 'assistant',
      parts: [tool('a', name: 'generate_image')],
    );
    final items = buildChatTimeline([message]);

    expect(items.whereType<ChatTimelineToolGroup>(), isEmpty);
    expect(items.whereType<ChatTimelineMessage>(), hasLength(1));
  });

  test('tool group reports failures and running state', () {
    final message = ChatMessage(
      id: 'm',
      role: 'assistant',
      parts: [tool('a'), tool('b', error: true)],
    );
    final items = buildChatTimeline([message]);
    final group = items.whereType<ChatTimelineToolGroup>().single;
    expect(group.failed, isTrue);
    expect(group.running, isFalse);
  });

  test('dismiss store never dismisses running or interactive rows', () {
    final store = ToolDismissStore();
    store.dismiss('running', running: true);
    store.dismiss('interactive', interactive: true);
    store.dismiss('done');
    expect(store.isDismissed('running'), isFalse);
    expect(store.isDismissed('interactive'), isFalse);
    expect(store.isDismissed('done'), isTrue);
  });
}
