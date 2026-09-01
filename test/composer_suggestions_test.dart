import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/composer_suggestions.dart';

void main() {
  group('matchRecurrence', () {
    test('matches "every day"', () {
      expect(matchRecurrence('remind me every day to check logs'), 'every day');
    });

    test('matches "every 2 hours"', () {
      expect(matchRecurrence('run this every 2 hours'), 'every 2 hours');
    });

    test('matches bare "daily"', () {
      expect(matchRecurrence('check this daily please'), 'daily');
    });

    test('matches Chinese "每天"', () {
      expect(matchRecurrence('每天早上帮我检查一下日志'), '每天早上');
    });

    test('matches Chinese "每周一"', () {
      expect(matchRecurrence('每周一发送周报'), '每周一');
    });

    test('does not match a proper noun like "Daily Prophet"', () {
      expect(matchRecurrence('I read the Daily Prophet'), isNull);
    });

    test('does not match "weekly-report.pdf"', () {
      expect(matchRecurrence('please review weekly-report.pdf'), isNull);
    });

    test('returns null for unrelated text', () {
      expect(matchRecurrence('what is the capital of France?'), isNull);
    });
  });

  group('shouldSuggestCron', () {
    test('true for a recurring-sounding draft', () {
      expect(shouldSuggestCron('email me a summary every morning'), isTrue);
    });

    test('false once already a slash command', () {
      expect(shouldSuggestCron('/cron every morning'), isFalse);
    });

    test('false once the draft already leads with the inserted prefix', () {
      expect(
        shouldSuggestCron('$cronSuggestionPrefix email me every morning'),
        isFalse,
      );
    });

    test('false for non-recurring text', () {
      expect(shouldSuggestCron('hello there'), isFalse);
    });
  });
}
