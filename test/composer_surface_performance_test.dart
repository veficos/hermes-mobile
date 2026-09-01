import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/billing_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/composer_status_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';

class _BillingApi extends ApiClient {
  _BillingApi({this.balance = 10})
    : super(baseUrl: 'http://example.invalid', apiKey: 'test');
  final double balance;
  int calls = 0;
  final Completer<void> gate = Completer<void>();

  @override
  Future<BillingState> billingState() async {
    calls++;
    await gate.future;
    return BillingState(balance: balance, creditLimit: 100);
  }
}

class _ImmediateBillingApi extends ApiClient {
  _ImmediateBillingApi()
    : super(baseUrl: 'http://example.invalid', apiKey: 'test');

  int calls = 0;

  @override
  Future<BillingState> billingState() async {
    calls++;
    return BillingState(balance: calls.toDouble(), creditLimit: 100);
  }
}

class _BillingConnection extends ConnectionStore {
  final routed = StreamController<RoutedGatewayEvent>.broadcast();

  @override
  Stream<RoutedGatewayEvent> get routedEvents => routed.stream;

  @override
  void dispose() {
    routed.close();
    super.dispose();
  }
}

void main() {
  test('composer surface revision ignores streaming token deltas', () async {
    final events = StreamController<GatewayEvent>();
    final chat = ChatStore()..attachEvents(events.stream);
    addTearDown(chat.dispose);
    addTearDown(events.close);
    final before = chat.composerSurfaceRevision.value;
    events.add(GatewayEvent(type: 'message.start', payload: const {}));
    await Future<void>.delayed(Duration.zero);
    final stable = chat.composerSurfaceRevision.value;
    expect(stable, before);
    events.add(
      GatewayEvent(type: 'message.delta', payload: const {'text': 'token'}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(chat.composerSurfaceRevision.value, stable);
  });

  test('composer snapshots retain identity when revision is unchanged', () {
    final store = ComposerStatusStore();
    addTearDown(store.dispose);
    store.upsertStatus(
      's1',
      const ComposerStatusItem(
        id: 'g',
        type: ComposerStatusType.goal,
        state: ComposerStatusState.running,
        title: 'Goal',
      ),
    );
    final first = store.snapshotFor('s1');
    final second = store.snapshotFor('s1');
    expect(identical(first, second), isTrue);
  });

  test('billing refresh coalesces concurrent requests', () async {
    final api = _BillingApi();
    final store = BillingStore()..bindApi(api);
    final a = store.refresh();
    final b = store.refresh();
    expect(api.calls, 1);
    api.gate.complete();
    await Future.wait([a, b]);
    expect(store.state?.balance, 10);
  });

  test('old connection billing cannot overwrite a new binding', () async {
    final oldApi = _BillingApi(balance: 1);
    final newApi = _BillingApi(balance: 20);
    final store = BillingStore()..bindApi(oldApi);
    final oldRefresh = store.refresh();

    store.bindApi(newApi);
    final newRefresh = store.refresh();
    newApi.gate.complete();
    await newRefresh;
    expect(store.state?.balance, 20);

    oldApi.gate.complete();
    await oldRefresh;
    expect(store.state?.balance, 20);
  });

  test('credits notice invalidates billing TTL immediately', () async {
    final api = _ImmediateBillingApi();
    final connection = _BillingConnection()..api = api;
    final store = BillingStore()
      ..attachConnection(connection)
      ..bindApi(api);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);

    await store.refresh();
    expect(api.calls, 1);
    connection.routed.add(
      RoutedGatewayEvent(
        route: OwnerRoute(connectionId: ConnectionId('primary')),
        socketGeneration: 1,
        event: GatewayEvent(
          type: 'notification.show',
          payload: {'key': 'credits.restored'},
        ),
      ),
    );
    await pumpEventQueue();
    expect(api.calls, 2);
  });
}
