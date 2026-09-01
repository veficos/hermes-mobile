import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/wake_audio_capture.dart';
import 'package:hermes_mobile/core/stores/wake_word_store.dart';

class _FakeWakeCapture implements WakeAudioCapture {
  void Function(Uint8List bytes)? onData;
  void Function(Object error)? onError;
  int starts = 0;
  int stops = 0;
  int? frameLength;
  @override
  bool active = false;

  @override
  Future<bool> start({
    required int frameLength,
    required void Function(Uint8List bytes) onData,
    required void Function(Object error) onError,
  }) async {
    starts += 1;
    active = true;
    this.frameLength = frameLength;
    this.onData = onData;
    this.onError = onError;
    return true;
  }

  void emit(List<int> bytes) => onData?.call(Uint8List.fromList(bytes));

  @override
  Future<void> stop() async {
    stops += 1;
    active = false;
  }

  @override
  Future<void> dispose() => stop();
}

class _FakeWakeConnection extends ConnectionStore {
  final calls = <(OwnerRoute, String, Map<String, dynamic>)>[];
  final eventController = StreamController<GatewayEvent>.broadcast();
  late FutureOr<Map<String, dynamic>> Function(
    String method,
    Map<String, dynamic> params,
  )
  handler;

  @override
  Stream<GatewayEvent> get events => eventController.stream;

  @override
  Future<Map<String, dynamic>> requestForOwner(
    OwnerRoute route,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    calls.add((route, method, params));
    return await handler(method, params);
  }

  void emit(GatewayEvent event) => eventController.add(event);

  @override
  void dispose() {
    eventController.close();
    super.dispose();
  }
}

Future<void> _settle([int turns = 10]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('enable starts client capture and sends ordered 16 kHz PCM', () async {
    final connection = _FakeWakeConnection();
    final capture = _FakeWakeCapture();
    connection.handler = (method, params) => switch (method) {
      'wake.start' => {
        'started': true,
        'capture': 'client',
        'phrase': 'hey hermes',
        'frame_length': 160,
      },
      'wake.feed' => {'fed': true},
      'wake.stop' => {'stopped': true, 'disabled_persisted': true},
      _ => throw StateError('unexpected $method'),
    };
    final store = WakeWordStore(connection: connection, audioCapture: capture);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);

    await store.setEnabled(true);

    expect(store.enabled, true);
    expect(store.listening, true);
    expect(store.phrase, 'hey hermes');
    expect(capture.active, true);
    expect(capture.frameLength, 160);
    final start = connection.calls.firstWhere(
      (call) => call.$2 == 'wake.start',
    );
    expect(start.$1.connectionId, const ConnectionId('primary'));
    expect(start.$3, {
      'surface': 'gui',
      'client_capture': true,
      'persist': true,
    });

    final first = List<int>.generate(320, (index) => index % 251);
    final second = List<int>.generate(320, (index) => (index + 17) % 251);
    capture.emit([...first, ...second]);
    await _settle();

    final feedCalls = connection.calls
        .where((call) => call.$2 == 'wake.feed')
        .toList();
    expect(feedCalls, isNotEmpty);
    final sent = <int>[
      for (final call in feedCalls) ...base64Decode(call.$3['pcm'] as String),
    ];
    expect(sent, [...first, ...second]);
    expect(feedCalls.every((call) => call.$3['sample_rate'] == 16000), true);
  });

  test('wake detection stops capture and preserves profile routing', () async {
    final connection = _FakeWakeConnection();
    final capture = _FakeWakeCapture();
    connection.handler = (method, params) => switch (method) {
      'wake.start' => {
        'started': true,
        'capture': 'client',
        'frame_length': 160,
      },
      'wake.stop' => {'stopped': true},
      _ => <String, dynamic>{},
    };
    final store = WakeWordStore(connection: connection, audioCapture: capture);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    await store.setEnabled(true);

    connection.emit(
      GatewayEvent(
        type: 'wake.detected',
        payload: const {
          'phrase': 'hey researcher',
          'profile': 'researcher',
          'start_new_session': false,
        },
      ),
    );
    await _settle();

    expect(capture.active, false);
    expect(store.listening, false);
    final detection = store.takeDetection();
    expect(detection?.phrase, 'hey researcher');
    expect(detection?.profile, 'researcher');
    expect(detection?.startNewSession, false);
    expect(store.detection, isNull);
  });

  test('voice pause and resume reattach the client microphone', () async {
    final connection = _FakeWakeConnection();
    final capture = _FakeWakeCapture();
    var serverListening = false;
    connection.handler = (method, params) {
      switch (method) {
        case 'wake.start':
          serverListening = true;
          return {'started': true, 'capture': 'client', 'frame_length': 160};
        case 'wake.pause':
          serverListening = false;
          return {'paused': true};
        case 'wake.resume':
          serverListening = true;
          return {'resumed': true};
        case 'wake.status':
          return {
            'available': true,
            'enabled': true,
            'listening': serverListening,
            'capture': 'client',
            'frame_length': 160,
          };
        case 'wake.stop':
          return {'stopped': true};
        default:
          return <String, dynamic>{};
      }
    };
    final store = WakeWordStore(connection: connection, audioCapture: capture);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    await store.setEnabled(true);
    final initialStarts = capture.starts;

    await store.pauseForVoice();
    expect(capture.active, false);
    expect(connection.calls.any((call) => call.$2 == 'wake.pause'), true);

    await store.resumeAfterVoice();
    expect(store.listening, true);
    expect(capture.active, true);
    expect(capture.starts, greaterThan(initialStarts));
    expect(connection.calls.any((call) => call.$2 == 'wake.resume'), true);
  });

  test(
    'lifecycle pause yields capture and foreground resumes config truth',
    () async {
      final connection = _FakeWakeConnection();
      final capture = _FakeWakeCapture();
      var serverListening = false;
      connection.handler = (method, params) {
        if (method == 'wake.start') {
          serverListening = true;
          return {'started': true, 'capture': 'client', 'frame_length': 160};
        }
        if (method == 'wake.pause') {
          serverListening = false;
          return {'paused': true};
        }
        if (method == 'wake.resume') {
          serverListening = true;
          return {'resumed': true};
        }
        if (method == 'wake.status') {
          return {
            'available': true,
            'enabled': true,
            'listening': serverListening,
            'capture': 'client',
            'frame_length': 160,
          };
        }
        return {'stopped': true};
      };
      final store = WakeWordStore(
        connection: connection,
        audioCapture: capture,
      );
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      await store.setEnabled(true);

      store.didChangeAppLifecycleState(AppLifecycleState.paused);
      await _settle();
      expect(capture.active, false);

      store.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _settle(30);
      expect(store.listening, true);
      expect(capture.active, true);
    },
  );

  test('slash-style command persists explicit off', () async {
    final connection = _FakeWakeConnection();
    final capture = _FakeWakeCapture();
    connection.handler = (method, params) => switch (method) {
      'wake.start' => {
        'started': true,
        'capture': 'client',
        'phrase': 'hey hermes',
        'frame_length': 160,
      },
      'wake.stop' => {'stopped': true, 'disabled_persisted': true},
      _ => <String, dynamic>{},
    };
    final store = WakeWordStore(connection: connection, audioCapture: capture);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);

    expect(await store.command('on'), contains('hey hermes'));
    expect(await store.command('off'), 'Wake word off');
    final stop = connection.calls.lastWhere((call) => call.$2 == 'wake.stop');
    expect(stop.$3['persist'], true);
  });
}
