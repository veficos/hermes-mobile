import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/preview_store.dart';

class _TourConnection extends ConnectionStore {
  final controller = StreamController<RoutedGatewayEvent>.broadcast();
  final calls = <(String, Map<String, dynamic>)>[];

  @override
  Stream<RoutedGatewayEvent> get routedEvents => controller.stream;

  @override
  Future<Map<String, dynamic>> requestForOwner(
    OwnerRoute route,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((method, params));
    return {};
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

class _TourDriver implements PreviewDriver {
  final tours = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> act(Map<String, dynamic> action) async => {};

  @override
  Future<Map<String, dynamic>> read({int? start, int? count}) async => {};

  @override
  Future<Map<String, dynamic>> tour(Map<String, dynamic> action) async {
    tours.add(action);
    return {'success': true, 'targets': const []};
  }
}

void main() {
  test(
    'preview tabs dedupe, activate and close without breaking active getters',
    () {
      final connection = ConnectionStore();
      final store = PreviewStore(connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);

      store.openUrl('https://example.com', title: 'Web');
      store.openHtml('<h1>One</h1>', title: 'HTML', sessionId: 's1');
      store.openUrl('https://example.com', title: 'Web updated');

      expect(store.tabs, hasLength(2));
      expect(store.title, 'Web updated');
      expect(store.url, 'https://example.com');

      final html = store.tabs.singleWhere((tab) => tab.html != null);
      store.activate(html.id);
      expect(store.html, '<h1>One</h1>');
      store.closeTab(html.id);
      expect(store.tabs, hasLength(1));
      expect(store.url, 'https://example.com');

      store.clear();
      expect(store.tabs, isEmpty);
      expect(store.hasContent, isFalse);
    },
  );

  test(
    'tour request drives the active preview and answers its request id',
    () async {
      final connection = _TourConnection();
      final store = PreviewStore(connection);
      final driver = _TourDriver();
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      const route = OwnerRoute(connectionId: ConnectionId('remote'));
      store
        ..openUrl('https://example.com', sessionId: 'runtime-a', owner: route)
        ..attachDriver(driver);

      connection.controller.add(
        RoutedGatewayEvent(
          route: route,
          socketGeneration: 1,
          event: GatewayEvent(
            type: 'tour.request',
            sessionId: 'runtime-a',
            payload: const {
              'request_id': 'tour-1',
              'surface': 'preview',
              'action': 'targets',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(driver.tours, hasLength(1));
      expect(connection.calls.single.$1, 'tour.respond');
      expect(connection.calls.single.$2['request_id'], 'tour-1');
      expect(
        jsonDecode(connection.calls.single.$2['text'] as String)['success'],
        isTrue,
      );
    },
  );

  test(
    'native app tour fails closed without driving the preview page',
    () async {
      final connection = _TourConnection();
      final store = PreviewStore(connection);
      final driver = _TourDriver();
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      const route = OwnerRoute(connectionId: ConnectionId('remote'));
      store
        ..openUrl('https://example.com', owner: route)
        ..attachDriver(driver);

      connection.controller.add(
        RoutedGatewayEvent(
          route: route,
          socketGeneration: 1,
          event: GatewayEvent(
            type: 'tour.request',
            payload: const {
              'request_id': 'tour-2',
              'surface': 'app',
              'action': 'targets',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(driver.tours, isEmpty);
      final result = jsonDecode(connection.calls.single.$2['text'] as String);
      expect(result['success'], isFalse);
      expect(result['error'], contains('native app surface'));
    },
  );

  test('tab-scoped drivers route requests to the owning session', () async {
    final connection = _TourConnection();
    final store = PreviewStore(connection);
    final first = _TourDriver();
    final second = _TourDriver();
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    const route = OwnerRoute(connectionId: ConnectionId('remote'));
    store.openUrl('https://one.example', sessionId: 'runtime-a', owner: route);
    final firstTab = store.activeTab!;
    store.openUrl('https://two.example', sessionId: 'runtime-b', owner: route);
    final secondTab = store.activeTab!;
    store
      ..attachDriver(first, tabId: firstTab.id)
      ..attachDriver(second, tabId: secondTab.id);

    connection.controller.add(
      RoutedGatewayEvent(
        route: route,
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'tour.request',
          sessionId: 'runtime-a',
          payload: const {
            'request_id': 'tour-scoped',
            'surface': 'preview',
            'action': 'targets',
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(first.tours, hasLength(1));
    expect(second.tours, isEmpty);
  });
}
