import 'package:flutter/foundation.dart';

import 'chat_message.dart';
import 'connections/connection_registry.dart';

enum SessionSendPhase {
  draft,
  uploading,
  submitting,
  queued,
  steering,
  accepted,
  failed,
  uncertain,
}

@immutable
class SessionSendState {
  final SessionSendPhase phase;
  final String? error;
  const SessionSendState(this.phase, {this.error});
  static const idle = SessionSendState(SessionSendPhase.draft);
  bool get busy =>
      phase == SessionSendPhase.uploading ||
      phase == SessionSendPhase.submitting ||
      phase == SessionSendPhase.steering;
}

/// Session-scoped projection consumed by chat surfaces. Keeping this value
/// immutable makes it safe to cache and prevents background sessions leaking
/// into the foreground view.
@immutable
class SessionSurfaceState {
  final String sessionId;
  final OwnerRoute owner;
  final List<ChatMessage> messages;
  final SessionSendState sendState;
  final bool awaitingInput;
  final int transcriptRevision;
  final int projectionRevision;

  SessionSurfaceState({
    required this.sessionId,
    required this.owner,
    List<ChatMessage> messages = const [],
    this.sendState = SessionSendState.idle,
    this.awaitingInput = false,
    this.transcriptRevision = 0,
    this.projectionRevision = 0,
  }) : messages = List.unmodifiable(messages);

  const SessionSurfaceState._immutable({
    required this.sessionId,
    required this.owner,
    required this.messages,
    required this.sendState,
    required this.awaitingInput,
    required this.transcriptRevision,
    required this.projectionRevision,
  });

  SessionSurfaceState copyWith({
    List<ChatMessage>? messages,
    SessionSendState? sendState,
    bool? awaitingInput,
    int? transcriptRevision,
    int? projectionRevision,
  }) => SessionSurfaceState._immutable(
    sessionId: sessionId,
    owner: owner,
    messages: messages == null ? this.messages : List.unmodifiable(messages),
    sendState: sendState ?? this.sendState,
    awaitingInput: awaitingInput ?? this.awaitingInput,
    transcriptRevision: transcriptRevision ?? this.transcriptRevision,
    projectionRevision: projectionRevision ?? this.projectionRevision,
  );
}

/// Lightweight registry for session-scoped chat projections. UI surfaces can
/// subscribe to one session without rebuilding for unrelated conversations.
class SessionSurfaceStore extends ChangeNotifier {
  final Map<String, SessionSurfaceState> _states = {};
  SessionSurfaceState? stateFor(String id) => _states[id];

  void upsert(SessionSurfaceState state) {
    if (state.sessionId.isEmpty) return;
    _states[state.sessionId] = state;
    notifyListeners();
  }

  void updatePhase(String id, OwnerRoute owner, SessionSendState phase) {
    final current = _states[id];
    final next = current == null || current.owner != owner
        ? SessionSurfaceState(sessionId: id, owner: owner, sendState: phase)
        : current.copyWith(sendState: phase);
    _states[id] = next;
    notifyListeners();
  }

  void remove(String id) {
    if (_states.remove(id) != null) notifyListeners();
  }

  /// Publish a transcript snapshot only when its revision or identity changes.
  /// Callers keep message ownership in ChatStore; this registry stores the
  /// immutable projection consumed by secondary mobile surfaces.
  void publishTranscript({
    required String id,
    required OwnerRoute owner,
    List<ChatMessage>? messages,
    List<ChatMessage> Function()? messagesBuilder,
    required int revision,
    bool awaitingInput = false,
  }) {
    assert((messages == null) != (messagesBuilder == null));
    final current = _states[id];
    if (current != null &&
        current.transcriptRevision == revision &&
        current.awaitingInput == awaitingInput &&
        current.owner == owner) {
      return;
    }
    _states[id] = SessionSurfaceState(
      sessionId: id,
      owner: owner,
      // Delay streaming materialization until revision deduplication passes.
      messages: messages ?? messagesBuilder!(),
      sendState: current?.owner == owner
          ? current!.sendState
          : SessionSendState.idle,
      awaitingInput: awaitingInput,
      transcriptRevision: revision,
      projectionRevision: current?.projectionRevision ?? 0,
    );
    notifyListeners();
  }
}
