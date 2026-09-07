import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/session_tab_store.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'dart:async';

void main() {
  final owner = OwnerRoute(connectionId: const ConnectionId('test'));
  test('opens, activates and closes session tabs', () {
    final store = SessionTabStore();
    store.open(SessionTab(id: 'a', title: 'A', owner: owner));
    store.open(SessionTab(id: 'b', title: 'B', owner: owner));
    expect(store.activeId, 'b');
    store.activate('a');
    store.close('a');
    expect(store.activeId, 'b');
  });
  test('close others and right preserve ordering', () {
    final store = SessionTabStore();
    for (final id in ['a', 'b', 'c']) {
      store.open(SessionTab(id: id, title: id, owner: owner), activate: false);
    }
    store.closeToRight('a');
    expect(store.tabs.map((t) => t.id), ['a']);
  });

  test('routes background lifecycle to running and unread state', () async {
    final events = StreamController<RoutedGatewayEvent>();
    final store = SessionTabStore()..attachRoutedEvents(events.stream);
    store.open(SessionTab(id: 'a', title: 'A', owner: owner));
    store.open(SessionTab(id: 'b', title: 'B', owner: owner), activate: false);
    events.add(
      RoutedGatewayEvent(
        route: owner,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'message.start',
          payload: const {},
          sessionId: 'b',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.tabs.singleWhere((t) => t.id == 'b').running, isTrue);
    events.add(
      RoutedGatewayEvent(
        route: owner,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'message.complete',
          payload: const {},
          sessionId: 'b',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final tab = store.tabs.singleWhere((t) => t.id == 'b');
    expect(tab.running, isFalse);
    expect(tab.unread, isTrue);
    await events.close();
    store.dispose();
  });

  test('maps runtime ids through the owner index', () async {
    final events = StreamController<RoutedGatewayEvent>();
    final owners = SessionOwnerIndex();
    owners.remember(
      SessionOwner(
        durableId: 'durable-a',
        runtimeId: 'runtime-a',
        route: owner,
      ),
    );
    final store = SessionTabStore()
      ..attachRoutedEvents(events.stream, owners: owners)
      ..open(SessionTab(id: 'durable-a', title: 'A', owner: owner));
    events.add(
      RoutedGatewayEvent(
        route: owner,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'message.start',
          payload: const {},
          sessionId: 'runtime-a',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.active?.running, isTrue);
    await events.close();
    store.dispose();
  });
}
