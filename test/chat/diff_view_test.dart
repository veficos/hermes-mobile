import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/diff_view.dart';

void main() {
  test('diffLineStats ignores file headers', () {
    const diff =
        '--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -1,2 +1,3 @@\n old\n-new\n+new\n+extra';
    expect(diffLineStats(diff), (added: 2, removed: 1));
  });

  test('diff parser cache can be cleared without affecting stats', () {
    const diff = '@@ -1 +1 @@\n-old\n+new';
    expect(diffLineStats(diff), (added: 1, removed: 1));
    clearDiffParseCache();
    expect(diffLineStats(diff), (added: 1, removed: 1));
  });
}
