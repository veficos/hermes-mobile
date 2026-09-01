import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/inline_content.dart';
import 'package:hermes_mobile/chat/content/rich_link_embed.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';

void main() {
  group('::preview{file} directive', () {
    test('parses double, single and unquoted file attributes', () {
      for (final src in [
        '::preview{file="dash.html"}',
        "::preview{file='dash.html'}",
        '::preview{file=dash.html}',
      ]) {
        final node = parseInlineContent(
          src,
        ).whereType<InlinePreviewFileNode>().single;
        expect(node.file, 'dash.html');
      }
    });

    test('prose around the directive is preserved', () {
      final nodes = parseInlineContent('open ::preview{file="a.html"} now');
      expect(nodes.whereType<InlinePreviewFileNode>().single.file, 'a.html');
      final text = nodes.whereType<InlineTextNode>().map((n) => n.text).join();
      expect(text, contains('open'));
      expect(text, contains('now'));
    });

    test('parses and clamps the optional starting height', () {
      final quoted = parseInlineContent(
        '::preview{height="480" file="a.html"}',
      ).whereType<InlinePreviewFileNode>().single;
      final low = parseInlineContent(
        '::preview{file=a.html height=20}',
      ).whereType<InlinePreviewFileNode>().single;
      expect(quoted.initialHeight, 480);
      expect(low.initialHeight, 120);
    });

    test('a directive with no file attr stays literal text', () {
      final nodes = parseInlineContent('::preview{height=200}');
      expect(nodes.whereType<InlinePreviewFileNode>(), isEmpty);
    });
  });

  group('generic plugin transcript directive', () {
    test('parses a whole-line directive and quoted attributes', () {
      final node = parseInlineContent(
        'before\n::tasks{project="mobile" mode=\'compact\'}\nafter',
      ).whereType<InlinePluginDirectiveNode>().single;
      expect(node.name, 'tasks');
      expect(node.attributes, {'project': 'mobile', 'mode': 'compact'});
    });

    test('does not claim inline prose as a plugin directive', () {
      expect(
        parseInlineContent(
          'see ::tasks{id="1"} here',
        ).whereType<InlinePluginDirectiveNode>(),
        isEmpty,
      );
    });
  });

  group('rich link detection', () {
    test('recognises YouTube watch / short / shorts URLs', () {
      expect(
        detectRichLink(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        )?.youtubeId,
        'dQw4w9WgXcQ',
      );
      expect(
        detectRichLink('https://youtu.be/dQw4w9WgXcQ')?.youtubeId,
        'dQw4w9WgXcQ',
      );
      expect(
        detectRichLink('https://youtube.com/shorts/abc123xyz')?.kind,
        RichLinkKind.youtube,
      );
    });

    test('recognises maps and x.com status, ignores plain links', () {
      expect(
        detectRichLink('https://maps.app.goo.gl/abcd')?.kind,
        RichLinkKind.maps,
      );
      expect(
        detectRichLink('https://x.com/foo/status/123')?.kind,
        RichLinkKind.twitter,
      );
      expect(detectRichLink('https://example.com/page'), isNull);
    });
  });

  test('artifact registry versions by content, deduped', () {
    final chat = ChatStore();
    expect(chat.registerArtifact('html', '<h1>a</h1>'), 1);
    expect(chat.registerArtifact('html', '<h1>a</h1>'), 1); // dedup
    expect(chat.registerArtifact('html', '<h1>b</h1>'), 2);
    expect(chat.artifactVersionCount('html'), 2);
    expect(chat.artifactVersionCount('svg'), 0);
  });
}
