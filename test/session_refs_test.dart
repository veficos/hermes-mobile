import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/session_refs.dart';

void main() {
  test('session refs become internal links with resolved titles', () {
    final linked = linkifySessionRefs(
      'See @session:abc and @session:`profile/def`.',
      titleOf: (id) => id == 'abc' ? 'Build log' : null,
    );
    expect(linked, contains('[Build log](hermes-session:abc)'));
    expect(linked, contains('hermes-session:profile%2Fdef'));
    expect(sessionIdFromHref('hermes-session:profile%2Fdef'), 'profile/def');
  });

  test('profile and durable id remain separate', () {
    expect(parseSessionReference('work/abc').profile, 'work');
    expect(parseSessionReference('work/abc').sessionId, 'abc');
    expect(formatSessionReference('abc', profile: 'work'), 'work/abc');
  });
}
