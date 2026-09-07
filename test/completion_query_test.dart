import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/completion_query.dart';

void main() {
  test('detects slash and emoji completion ranges', () {
    expect(detectCompletionQuery('/help')?.kind, CompletionKind.slash);
    expect(detectCompletionQuery('hello :thu')?.kind, CompletionKind.emoji);
  });
}
