import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/core/voice_activity.dart';
import 'package:hermes_mobile/core/voice_recorder.dart';
import 'package:hermes_mobile/core/voice_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _VoiceApi extends ApiClient {
  _VoiceApi() : super(baseUrl: 'http://voice.invalid', apiKey: 'test');

  int transcriptions = 0;

  @override
  Future<String> audioTranscribe(String dataUrl, String mimeType) async {
    transcriptions++;
    expect(mimeType, 'audio/test');
    expect(dataUrl, startsWith('data:audio/test;base64,'));
    return 'new question';
  }
}

final class _VoiceRecorder extends VoiceRecorderBase {
  bool startResult = true;
  bool heard = true;
  Uint8List? bytes = Uint8List.fromList([1, 2, 3]);
  int starts = 0;
  int stops = 0;
  int waitsForStart = 0;
  int waitsForEnd = 0;
  Completer<bool>? startGate;
  Completer<bool>? speechStartGate;
  Completer<void>? speechEndGate;

  @override
  bool get supported => true;
  @override
  String get mimeType => 'audio/test';

  @override
  Future<bool> start() async {
    starts++;
    return startGate == null ? startResult : startGate!.future;
  }

  @override
  Future<Uint8List?> stop() async {
    stops++;
    return bytes;
  }

  @override
  Future<bool> waitForSpeechStart({
    void Function(double level)? onLevel,
  }) async {
    waitsForStart++;
    onLevel?.call(.8);
    return speechStartGate == null ? heard : speechStartGate!.future;
  }

  @override
  Future<void> waitForSpeechEnd({void Function(double level)? onLevel}) async {
    waitsForEnd++;
    onLevel?.call(.1);
    if (speechEndGate != null) return speechEndGate!.future;
  }

  @override
  void dispose() {}
}

final class _VoicePlayer implements VoicePlayerAdapter {
  final StreamController<void> _completed = StreamController<void>.broadcast();

  @override
  Stream<void> get onComplete => _completed.stream;
  @override
  Future<void> play(Uint8List bytes) async => _completed.add(null);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() => _completed.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('streaming speech cuts complete Chinese and Latin sentences', () {
    final cut = splitSpeechSentences('你好。How are you? 还没说完');

    expect(cut.sentences, ['你好。', 'How are you?']);
    expect(cut.rest, ' 还没说完');
  });

  test('streaming speech keeps an incomplete sentence until flush', () {
    final pending = splitSpeechSentences('still generating');
    expect(pending.sentences, isEmpty);
    expect(pending.rest, 'still generating');

    final flushed = splitSpeechSentences(pending.rest, flush: true);
    expect(flushed.sentences, ['still generating']);
    expect(flushed.rest, isEmpty);
  });

  test(
    'voice activity calibrates room noise and requires sustained speech',
    () {
      final detector = VoiceActivityDetector();
      final start = DateTime(2026);
      for (var ms = 0; ms <= 480; ms += 80) {
        expect(
          detector.add(-48, start.add(Duration(milliseconds: ms))),
          isFalse,
        );
      }
      expect(detector.noiseFloorDb, closeTo(-48, 1));
      expect(
        detector.add(-27, start.add(const Duration(milliseconds: 560))),
        isFalse,
      );
      expect(
        detector.add(-27, start.add(const Duration(milliseconds: 720))),
        isFalse,
      );
      expect(
        detector.add(-27, start.add(const Duration(milliseconds: 880))),
        isTrue,
      );
    },
  );

  test('voice activity rejects a short loud speaker echo', () {
    final detector = VoiceActivityDetector();
    final start = DateTime(2026);
    for (var ms = 0; ms <= 480; ms += 80) {
      detector.add(-52, start.add(Duration(milliseconds: ms)));
    }
    expect(
      detector.add(-20, start.add(const Duration(milliseconds: 560))),
      isFalse,
    );
    expect(
      detector.add(-52, start.add(const Duration(milliseconds: 720))),
      isFalse,
    );
    expect(
      detector.add(-20, start.add(const Duration(milliseconds: 800))),
      isFalse,
    );
  });

  test(
    'barge-in interrupts, waits for the utterance, and transcribes',
    () async {
      final api = _VoiceApi();
      final connection = ConnectionStore()..api = api;
      final recorder = _VoiceRecorder();
      final store = VoiceStore(
        connection: connection,
        recorder: recorder,
        player: _VoicePlayer(),
      );
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      store.toggleContinuousConversation();
      await store.bindConversationScope('session-a');
      store.toggleContinuousConversation();
      var interruptions = 0;

      final text = await store.monitorBargeIn(() => interruptions++);

      expect(text, 'new question');
      expect(interruptions, 1);
      expect(recorder.starts, 1);
      expect(recorder.waitsForStart, 1);
      expect(recorder.waitsForEnd, 1);
      expect(recorder.stops, 1);
      expect(api.transcriptions, 1);
      expect(store.bargeMonitoring, isFalse);
    },
  );

  test('scope switch discards a stale barge-in capture', () async {
    final api = _VoiceApi();
    final connection = ConnectionStore()..api = api;
    final recorder = _VoiceRecorder()..startGate = Completer<bool>();
    final store = VoiceStore(
      connection: connection,
      recorder: recorder,
      player: _VoicePlayer(),
    );
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    await store.bindConversationScope('session-a');
    store.toggleContinuousConversation();

    final monitoring = store.monitorBargeIn(() {});
    await Future<void>.delayed(Duration.zero);
    final switching = store.bindConversationScope('session-b');
    recorder.startGate!.complete(true);

    expect(await monitoring, isNull);
    await switching;
    expect(api.transcriptions, 0);
    expect(recorder.waitsForEnd, 0);
    expect(store.bargeMonitoring, isFalse);
  });

  test('barge-in is single-flight and muted monitoring is inert', () async {
    final api = _VoiceApi();
    final connection = ConnectionStore()..api = api;
    final recorder = _VoiceRecorder()..startGate = Completer<bool>();
    final store = VoiceStore(
      connection: connection,
      recorder: recorder,
      player: _VoicePlayer(),
    );
    addTearDown(store.dispose);
    addTearDown(connection.dispose);
    await store.bindConversationScope('session-a');
    store.toggleContinuousConversation();

    final first = store.monitorBargeIn(() {});
    await Future<void>.delayed(Duration.zero);
    expect(await store.monitorBargeIn(() {}), isNull);
    expect(recorder.starts, 1);
    recorder.startGate!.complete(false);
    expect(await first, isNull);

    store.toggleMuted();
    expect(await store.monitorBargeIn(() {}), isNull);
    expect(recorder.starts, 1);
  });

  test(
    'toggleMuted stops an in-progress barge-in monitor mid waitForSpeechStart',
    () async {
      final api = _VoiceApi();
      final connection = ConnectionStore()..api = api;
      final recorder = _VoiceRecorder()..speechStartGate = Completer<bool>();
      final store = VoiceStore(
        connection: connection,
        recorder: recorder,
        player: _VoicePlayer(),
      );
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      await store.bindConversationScope('session-a');
      store.toggleContinuousConversation();

      final monitoring = store.monitorBargeIn(() {});
      await Future<void>.delayed(Duration.zero);
      expect(store.bargeMonitoring, isTrue);

      store.toggleMuted();

      expect(await monitoring, isNull);
      expect(store.bargeMonitoring, isFalse);
      expect(recorder.stops, greaterThan(0));
    },
  );

  test(
    'endConversation stops an in-progress barge-in monitor mid waitForSpeechStart',
    () async {
      final api = _VoiceApi();
      final connection = ConnectionStore()..api = api;
      final recorder = _VoiceRecorder()..speechStartGate = Completer<bool>();
      final store = VoiceStore(
        connection: connection,
        recorder: recorder,
        player: _VoicePlayer(),
      );
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      await store.bindConversationScope('session-a');
      store.toggleContinuousConversation();

      final monitoring = store.monitorBargeIn(() {});
      await Future<void>.delayed(Duration.zero);
      expect(store.bargeMonitoring, isTrue);

      await store.endConversation();

      expect(await monitoring, isNull);
      expect(store.bargeMonitoring, isFalse);
      expect(recorder.stops, greaterThan(0));
    },
  );

  test(
    'bindConversationScope stops an in-progress barge-in monitor mid '
    'waitForSpeechStart',
    () async {
      final api = _VoiceApi();
      final connection = ConnectionStore()..api = api;
      final recorder = _VoiceRecorder()..speechStartGate = Completer<bool>();
      final store = VoiceStore(
        connection: connection,
        recorder: recorder,
        player: _VoicePlayer(),
      );
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      await store.bindConversationScope('session-a');
      store.toggleContinuousConversation();

      final monitoring = store.monitorBargeIn(() {});
      await Future<void>.delayed(Duration.zero);
      expect(store.bargeMonitoring, isTrue);

      await store.bindConversationScope('session-b');

      expect(await monitoring, isNull);
      expect(store.bargeMonitoring, isFalse);
      expect(recorder.stops, greaterThan(0));
    },
  );

  test(
    'muting mid-recording drops the utterance and surfaces an error instead '
    'of silently vanishing',
    () async {
      final api = _VoiceApi();
      final connection = ConnectionStore()..api = api;
      final recorder = _VoiceRecorder()..speechEndGate = Completer<void>();
      final store = VoiceStore(
        connection: connection,
        recorder: recorder,
        player: _VoicePlayer(),
      );
      addTearDown(store.dispose);
      addTearDown(connection.dispose);
      await store.bindConversationScope('session-a');
      store.toggleContinuousConversation();

      final recording = store.recordAndTranscribe();
      await Future<void>.delayed(Duration.zero);
      expect(store.recording, isTrue);

      store.toggleMuted();
      // Simulate the recorder's stream naturally ending once the hardware is
      // stopped, as it would for the real record-package-backed recorder.
      recorder.speechEndGate!.complete();

      final text = await recording;

      expect(text, isNull);
      expect(store.voiceError, isNotNull);
      expect(api.transcriptions, 0);
      // Only toggleMuted's stop() should have fired; _finishRecording must
      // not race a second stop() call against it.
      expect(recorder.stops, 1);
    },
  );
}
