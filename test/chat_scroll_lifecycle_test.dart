import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/transcript/scroll_coordinator.dart';

void main() {
  test('return to latest supersedes pending history restoration', () {
    final c = ChatScrollCoordinator()..enterSession('a');
    c.markInitialPositioned();
    final epoch = c.beginOlderPage();
    final revision = c.readingRevision;
    c.followLatest();
    expect(c.readingRevision, isNot(revision));
    c.restoringOlderPage(epoch);
    c.endOlderPage(epoch);
    expect(c.phase, TranscriptScrollPhase.following);
    expect(c.messagesChanged(100), isTrue);
    c.beginOlderPage();
    expect(c.readingRevision, greaterThan(revision + 1));
    expect(c.stuckToBottom, isFalse);
  });
  test('ten page lifecycles cannot re-enable tail following', () {
    final c = ChatScrollCoordinator()..enterSession('a');
    c.markInitialPositioned();
    for (var page = 1; page <= 10; page++) {
      final epoch = c.beginOlderPage();
      expect(c.phase, TranscriptScrollPhase.fetchingOlder);
      c.updateStuck(true);
      expect(c.messagesChanged(page * 50), isFalse);
      expect(c.allowPagination, isFalse);
      c.restoringOlderPage(epoch);
      c.updateStuck(true);
      expect(c.stuckToBottom, isFalse);
      c.endOlderPage(epoch);
      expect(c.phase, TranscriptScrollPhase.reading);
      expect(c.allowPagination, isTrue);
    }
    c.updateStuck(true);
    expect(c.phase, TranscriptScrollPhase.following);
  });
  test('old page completion cannot change a new session', () {
    final c = ChatScrollCoordinator()..enterSession('a');
    final old = c.beginOlderPage();
    c.enterSession('b');
    c.restoringOlderPage(old);
    c.endOlderPage(old);
    expect(c.phase, TranscriptScrollPhase.initial);
    expect(c.stuckToBottom, isTrue);
  });
}
