import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/pet_store.dart';

class _PetApi extends ApiClient {
  _PetApi(this.slug) : super(baseUrl: 'http://pet.invalid', apiKey: 'test');

  final String slug;
  final infoCompleter = Completer<PetInfo>();

  @override
  Future<PetInfo> petInfo() => infoCompleter.future;
}

class _PetConnection extends ConnectionStore {
  final controller = StreamController<GatewayEvent>.broadcast();

  @override
  Stream<GatewayEvent> get events => controller.stream;

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

void main() {
  test('pet mutations never report success while disconnected', () async {
    final connection = ConnectionStore();
    final store = PetStore(connection: connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);

    await expectLater(store.select('pet'), throwsStateError);
    await expectLater(store.disable(), throwsStateError);
    await expectLater(store.generate(const {}), throwsStateError);
    await expectLater(store.generateStatus(), throwsStateError);
    await expectLater(store.hatch(const {}), throwsStateError);
    await expectLater(store.cancelJob('token'), throwsStateError);
    await expectLater(store.remove('pet'), throwsStateError);
  });

  test('an old connection response cannot overwrite the active pet', () async {
    final oldApi = _PetApi('old');
    final newApi = _PetApi('new');
    final connection = ConnectionStore()..api = oldApi;
    final store = PetStore(connection: connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);

    final oldLoad = store.refresh();
    connection.api = newApi;
    connection.notifyListeners();
    oldApi.infoCompleter.complete(
      PetInfo.fromJson(const {'slug': 'old', 'enabled': true}),
    );
    newApi.infoCompleter.complete(
      PetInfo.fromJson(const {'slug': 'new', 'enabled': true}),
    );

    await oldLoad;
    await Future<void>.delayed(Duration.zero);
    expect(store.info?.slug, 'new');
    expect(store.loading, isFalse);
  });

  test(
    'pet leaves waiting on resumed output and handles terminal errors',
    () async {
      final connection = _PetConnection();
      final store = PetStore(connection: connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);

      connection.controller.add(
        GatewayEvent(type: 'approval.request', payload: {}),
      );
      await pumpEventQueue();
      expect(store.state, PetState.waiting);

      connection.controller.add(
        GatewayEvent(type: 'message.delta', payload: {'text': 'resumed'}),
      );
      await pumpEventQueue();
      expect(store.state, PetState.run);

      connection.controller.add(GatewayEvent(type: 'error', payload: {}));
      await pumpEventQueue();
      expect(store.state, PetState.failed);

      connection.controller.add(
        GatewayEvent(type: 'interactive.expired', payload: {}),
      );
      await pumpEventQueue();
      expect(store.state, PetState.idle);
    },
  );
}
