import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/session_surface.dart';

void main() {
  test('unchanged revisions skip expensive message materialization', () {
    final store = SessionSurfaceStore();
    addTearDown(store.dispose);
    final owner = OwnerRoute(connectionId: const ConnectionId('c'));
    var builds = 0;
    void publish(int revision) => store.publishTranscript(
      id: 's',
      owner: owner,
      revision: revision,
      messagesBuilder: () {
        builds++;
        return [
          ChatMessage(id: 'm', role: 'user', parts: [ChatPart.text('text')]),
        ];
      },
    );
    publish(1);
    for (var i = 0; i < 100; i++) {
      publish(1);
    }
    expect(builds, 1);
    publish(2);
    expect(builds, 2);
    expect(store.stateFor('s')!.messages.single.fullText, 'text');
  });

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

  test('phase updates reuse immutable history and isolate owners', () {
    final store = SessionSurfaceStore();
    addTearDown(store.dispose);
    final owner = OwnerRoute(connectionId: const ConnectionId('a'));
    final other = OwnerRoute(connectionId: const ConnectionId('b'));
    final input = [ChatMessage(id: 'm', role: 'user', parts: [])];
    store.publishTranscript(
      id: 's',
      owner: owner,
      messages: input,
      revision: 1,
    );
    final history = store.stateFor('s')!.messages;
    input.clear();
    expect(history, hasLength(1));
    store.updatePhase(
      's',
      owner,
      const SessionSendState(SessionSendPhase.uploading),
    );
    expect(store.stateFor('s')!.messages, same(history));
    expect(() => history.clear(), throwsUnsupportedError);
    store.updatePhase('s', other, SessionSendState.idle);
    expect(store.stateFor('s')!.owner, other);
    expect(store.stateFor('s')!.messages, isEmpty);
  });
}
