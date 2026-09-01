import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/mermaid_view.dart';
import 'package:hermes_mobile/chat/content/pretty_links.dart';
import 'package:hermes_mobile/widgets/h/hermes_thinking.dart';

void main() {
  group('separateGluedReasoningBlocks (H6)', () {
    test('splits a glued heading run', () {
      expect(
        separateGluedReasoningBlocks('**One****Two**'),
        '**One**\n\n**Two**',
      );
    });

    test('breaks a heading glued onto prose', () {
      expect(
        separateGluedReasoningBlocks('done!**Next step**'),
        'done!\n\n**Next step**',
      );
    });

    test('leaves well-separated text alone', () {
      const ok = '**One**\n\nsome prose\n\n**Two**';
      expect(separateGluedReasoningBlocks(ok), ok);
    });
  });

  group('prettifyBareLinks (G5)', () {
    test('shortens a long bare URL to a labelled link', () {
      final out = prettifyBareLinks(
        'see https://example.com/very/long/path/segment?a=1&b=2&c=3 here',
      );
      expect(out, contains('](https://example.com/very/long/path'));
      expect(out, startsWith('see ['));
    });

    test('leaves short URLs and code spans untouched', () {
      expect(prettifyBareLinks('go to https://x.dev'), 'go to https://x.dev');
      const code =
          'run `curl https://example.com/very/long/thing/that/is/long`';
      expect(prettifyBareLinks(code), code);
    });

    test('does not double-wrap an existing markdown link', () {
      const link = '[docs](https://example.com/very/long/path/here/now/ok)';
      expect(prettifyBareLinks(link), link);
    });
  });

  group('upgradeImageLinks', () {
    // Regression fixture: a real image_generate reply linked its own
    // generated pictures with plain `[label](url)` link syntax instead of
    // `![label](url)`, so the transcript showed three tappable text links
    // instead of the actual images.
    test('upgrades a plain link pointing at an image file to image syntax', () {
      const text =
          '给你生成了 3 张不同风格的成年美女写真：\n\n'
          '1. [都市白色西装人像](https://v3b.fal.media/files/b/0aa820c7/S9Swy2xhQiRPLbcNrET69_Tg3xaMpy.png)\n'
          '2. [夕阳花园长裙写真](https://v3b.fal.media/files/b/0aa820dd/reZyQ4sPiRAslg8hwDjpD_L6hNUxIF.png)\n'
          '3. [霓虹都市潮流街拍](https://v3b.fal.media/files/b/0aa820c8/soA6xM6ttmDjasjgGGpAE_Jtw4qvSy.png)';

      final out = upgradeImageLinks(text);

      expect(
        out,
        contains(
          '![都市白色西装人像](https://v3b.fal.media/files/b/0aa820c7/S9Swy2xhQiRPLbcNrET69_Tg3xaMpy.png)',
        ),
      );
      expect(
        out,
        contains(
          '![夕阳花园长裙写真](https://v3b.fal.media/files/b/0aa820dd/reZyQ4sPiRAslg8hwDjpD_L6hNUxIF.png)',
        ),
      );
      expect(
        out,
        contains(
          '![霓虹都市潮流街拍](https://v3b.fal.media/files/b/0aa820c8/soA6xM6ttmDjasjgGGpAE_Jtw4qvSy.png)',
        ),
      );
    });

    test('leaves an already-real image link untouched (no double bang)', () {
      const image = '![cat](https://example.com/cat.png)';
      expect(upgradeImageLinks(image), image);
    });

    test('leaves a link to a non-image page untouched', () {
      const link = '[docs](https://example.com/docs/page)';
      expect(upgradeImageLinks(link), link);
    });

    test('leaves an image-link example inside a code span untouched', () {
      const code = 'use `[alt](https://x.dev/pic.png)` for markdown images';
      expect(upgradeImageLinks(code), code);
    });
  });

  group('MermaidGraph (3.8, now public)', () {
    test('parses direction, labels and shapes', () {
      final g = MermaidGraph.parse(
        'flowchart LR\n  A[Start] --> B{Decide}\n  B -->|yes| C(Done)',
      );
      expect(g.horizontal, isTrue);
      expect(
        g.nodes.map((n) => n.label),
        containsAll(['Start', 'Decide', 'Done']),
      );
      expect(g.nodes.firstWhere((n) => n.id == 'B').shape, 'diamond');
      expect(g.edges.any((e) => e.label == 'yes'), isTrue);
    });

    test('non-flowchart source yields no nodes', () {
      expect(MermaidGraph.parse('sequenceDiagram\n A->>B: hi').nodes, isEmpty);
    });
  });
}
