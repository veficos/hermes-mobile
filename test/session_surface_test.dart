import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/session_surface.dart';

void main() {
  test('deduplicates transcript projections by revision and owner', () {
    final store = SessionSurfaceStore();
    final owner = OwnerRoute(connectionId: const ConnectionId('c'));
    var notifications = 0;
    store.addListener(() => notifications++);
    store.publishTranscript(
      id: 's',
      owner: owner,
      messages: const <ChatMessage>[],
      revision: 1,
    );
    store.publishTranscript(
      id: 's',
      owner: owner,
      messages: const <ChatMessage>[],
      revision: 1,
    );
    expect(notifications, 1);
    expect(store.stateFor('s')?.transcriptRevision, 1);
  });

  test('send phases preserve session projection', () {
    final store = SessionSurfaceStore();
    final owner = OwnerRoute(connectionId: const ConnectionId('c'));
    store.updatePhase(
      's',
      owner,
      const SessionSendState(SessionSendPhase.uploading),
    );
    expect(store.stateFor('s')?.sendState.phase, SessionSendPhase.uploading);
    expect(store.stateFor('s')?.sendState.busy, isTrue);
    store.updatePhase(
      's',
      owner,
      const SessionSendState(SessionSendPhase.accepted),
    );
    expect(store.stateFor('s')?.sendState.busy, isFalse);
  });
}
