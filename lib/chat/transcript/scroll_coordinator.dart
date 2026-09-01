library;

class ChatScrollCoordinator {
  String? _sessionId;
  int _sessionEpoch = 0;
  int _lastMessageCount = -1;
  bool stuckToBottom = true;
  bool initialPositioned = false;
  bool enterSession(String sessionId) {
    if (sessionId == _sessionId) return false;
    _sessionId = sessionId;
    _sessionEpoch++;
    _lastMessageCount = -1;
    stuckToBottom = true;
    initialPositioned = false;
    return true;
  }

  bool messagesChanged(int messageCount) {
    if (messageCount == _lastMessageCount) return false;
    _lastMessageCount = messageCount;
    return stuckToBottom;
  }

  bool get allowPagination => initialPositioned;
  int get sessionEpoch => _sessionEpoch;
  bool ownsEpoch(int epoch) => epoch == _sessionEpoch;
  double restorePrependOffset({
    required double beforePixels,
    required double beforeExtent,
    required double afterExtent,
    required double minExtent,
    required double maxExtent,
  }) => (beforePixels + afterExtent - beforeExtent).clamp(minExtent, maxExtent);
  void updateStuck(bool value) => stuckToBottom = value;
  void markInitialPositioned() => initialPositioned = true;
}
