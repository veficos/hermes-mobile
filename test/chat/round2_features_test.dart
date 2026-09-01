import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/ansi_text.dart';
import 'package:hermes_mobile/chat/content/diff_view.dart';
import 'package:hermes_mobile/chat/content/media_embed.dart';
import 'package:hermes_mobile/chat/content/reference_chips.dart';
import 'package:hermes_mobile/core/clarify_choice.dart';

void main() {
  group('ANSI (A1)', () {
    test('detects an SGR escape', () {
      expect(AnsiText.contains('plain'), isFalse);
      expect(AnsiText.contains('\x1B[31mred\x1B[0m'), isTrue);
    });

    test('splits coloured runs into styled spans and drops the escapes', () {
      final spans = parseAnsi('a\x1B[1;32mb\x1B[0mc', const TextStyle(), false);
      final text = spans.whereType<TextSpan>().map((s) => s.text ?? '').join();
      expect(text, 'abc');
      final green = spans.whereType<TextSpan>().firstWhere(
        (s) => s.text == 'b',
      );
      expect(green.style?.fontWeight, FontWeight.bold);
      expect(green.style?.color, isNotNull);
    });

    test('strips non-SGR control sequences', () {
      final spans = parseAnsi('x\x1B[2Ky\x1B[Hz', const TextStyle(), true);
      expect(spans.whereType<TextSpan>().map((s) => s.text).join(), 'xyz');
    });
  });

  group('diff stats + language (A2/A8)', () {
    test('counts add/remove lines, ignoring headers', () {
      const diff = '--- a\n+++ b\n@@ -1 +1,2 @@\n-old\n+new\n+extra\n ctx';
      final stats = diffLineStats(diff);
      expect(stats.added, 2);
      expect(stats.removed, 1);
    });
  });

  group('clarify encoding (B1/B3)', () {
    test('multi-select answers encode as a JSON array of bare choices', () {
      final encoded = encodeClarifyAnswer([
        'Apples (Recommended)',
        'Bananas',
      ], multiSelect: true);
      expect(encoded, '["Apples","Bananas"]');
    });

    test('single-select answer is the bare first choice', () {
      expect(
        encodeClarifyAnswer(['Yes (Recommended)'], multiSelect: false),
        'Yes',
      );
    });

    test('recommended detection + ordering + key badges', () {
      expect(isRecommendedChoice('Do it (Recommended)'), isTrue);
      expect(bareChoice('Do it (Recommended)'), 'Do it');
      expect(orderChoices(['a', 'b (Recommended)', 'c']), [
        'b (Recommended)',
        'a',
        'c',
      ]);
      expect(choiceKeyBadge(0), 'A');
      expect(choiceKeyBadge(2), 'C');
    });
  });

  group('message references (C1)', () {
    test(
      'extracts @image / @url / @file refs and strips them from the body',
      () {
        const text = 'look at this @image:/tmp/a.png and @url:https://x.dev ok';
        final refs = extractMessageReferences(text);
        expect(refs.map((r) => r.kind), [
          ReferenceKind.image,
          ReferenceKind.url,
        ]);
        expect(refs[0].value, '/tmp/a.png');
        final stripped = stripMessageReferences(text);
        expect(stripped, isNot(contains('@image:')));
        expect(stripped, contains('look at this'));
        expect(stripped, contains('ok'));
      },
    );

    test('quoted values survive', () {
      final refs = extractMessageReferences('@file:"/a b/c.txt"');
      expect(refs.single.value, '/a b/c.txt');
    });
  });

  group('media kind (C2)', () {
    test('classifies audio / video / other', () {
      expect(mediaKindForUrl('https://x.dev/a.mp3'), MediaKind.audio);
      expect(mediaKindForUrl('https://x.dev/a.mp4'), MediaKind.video);
      expect(mediaKindForUrl('https://x.dev/a.png'), MediaKind.none);
      expect(isFileUrl('file:///tmp/a.txt'), isTrue);
    });
  });
}
