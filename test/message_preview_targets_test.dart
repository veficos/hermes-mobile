import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/message_preview_targets.dart';

void main() {
  test('extracts and deduplicates session URL and file previews', () {
    final targets = extractMessagePreviewTargets(
      'See @session:work/s1 and https://example.com/a then '
      'file:///tmp/report.md and https://example.com/a',
    );
    expect(targets.map((target) => target.kind), [
      MessagePreviewKind.session,
      MessagePreviewKind.url,
      MessagePreviewKind.file,
    ]);
    expect(targets.first.value, 'work/s1');
  });
}
