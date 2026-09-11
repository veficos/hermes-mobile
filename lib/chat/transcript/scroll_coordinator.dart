library;

enum TranscriptScrollPhase {
  initial,
  following,
  reading,
  fetchingOlder,
  restoringOlder,
}

class ChatScrollCoordinator {
  String? _sessionId;
  int _sessionEpoch = 0;
  int _lastMessageCount = -1;
  int _readingRevision = 0;
  int get readingRevision => _readingRevision;

  /// Explicit navigation supersedes any pending history-position restore.
  void followLatest() {
    _readingRevision++;
    stuckToBottom = true;
    phase = TranscriptScrollPhase.following;
  }

  bool stuckToBottom = true;
  bool initialPositioned = false;
  TranscriptScrollPhase phase = TranscriptScrollPhase.initial;
  bool get preservingHistory =>
      phase == TranscriptScrollPhase.fetchingOlder ||
      phase == TranscriptScrollPhase.restoringOlder;

  int beginOlderPage() {
    _readingRevision++;
    stuckToBottom = false;
    phase = TranscriptScrollPhase.fetchingOlder;
    return _sessionEpoch;
  }

  void restoringOlderPage(int epoch) {
    if (ownsEpoch(epoch) && preservingHistory) {
      phase = TranscriptScrollPhase.restoringOlder;
    }
  }

  void endOlderPage(int epoch) {
    if (!ownsEpoch(epoch) || !preservingHistory) return;
    phase = TranscriptScrollPhase.reading;
    stuckToBottom = false;
  }

  bool enterSession(String sessionId) {
    if (sessionId == _sessionId) return false;
    _sessionId = sessionId;
    _sessionEpoch++;
    _lastMessageCount = -1;
    stuckToBottom = true;
    initialPositioned = false;
    phase = TranscriptScrollPhase.initial;
    return true;
  }

  bool messagesChanged(int messageCount) {
    if (messageCount == _lastMessageCount) return false;
    _lastMessageCount = messageCount;
    return stuckToBottom;
  }

  bool get allowPagination => initialPositioned && !preservingHistory;
  int get sessionEpoch => _sessionEpoch;
  bool ownsEpoch(int epoch) => epoch == _sessionEpoch;
  double restorePrependOffset({
    required double beforePixels,
    required double beforeExtent,
    required double afterExtent,
    required double minExtent,
    required double maxExtent,
  }) => (beforePixels + afterExtent - beforeExtent).clamp(minExtent, maxExtent);
  void updateStuck(bool value) {
    if (preservingHistory) return;
    stuckToBottom = value;
    if (initialPositioned) {
      phase = value
          ? TranscriptScrollPhase.following
          : TranscriptScrollPhase.reading;
    }
  }

  void markInitialPositioned() {
    initialPositioned = true;
    if (!preservingHistory) {
      phase = stuckToBottom
          ? TranscriptScrollPhase.following
          : TranscriptScrollPhase.reading;
    }
  }
}
