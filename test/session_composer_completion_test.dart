import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/session_composer_completion.dart';
import 'package:hermes_mobile/core/models.dart';

void main() {
  test('session completion searches title and preserves profile routing', () {
    final results = SessionComposerCompletion.suggestions(
      text: 'compare @session:release',
      sessions: [
        SessionRow(id: 's1', title: 'Release audit', profile: 'work'),
        SessionRow(id: 's2', title: 'Other', profile: 'personal'),
      ],
      activeProfile: 'personal',
    );
    expect(results.single.sessionId, 's1');
    expect(results.single.profile, 'work');
    expect(SessionComposerCompletion.queryFor('plain text'), isNull);
  });
}
