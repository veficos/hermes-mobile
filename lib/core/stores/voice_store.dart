/// VoiceStore: recording, STT transcription and TTS playback (D3/F14/E3).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../connections/connection_registry.dart';
import '../voice_recorder.dart';
import '../voice_player.dart';
import '../../l10n/runtime_l10n.dart';
import 'connection_store.dart';
import 'wake_word_store.dart';
import 'voice_record_stub.dart'
    if (dart.library.js_interop) 'voice_record_web.dart'
    if (dart.library.io) 'voice_record_io.dart'
    as voice_record;

enum VoiceConversationPhase { idle, listening, transcribing, waiting, speaking }

/// Split only complete sentences unless [flush] is true. Keeping the remainder
/// lets mobile begin TTS while the assistant is still streaming without ever
/// speaking a half-written sentence.
({List<String> sentences, String rest}) splitSpeechSentences(
  String input, {
  bool flush = false,
}) {
  final sentences = <String>[];
  var start = 0;
  final boundary = RegExp(r'[。！？!?]+(?:[\"”’）)】》」』]*)');
  for (final match in boundary.allMatches(input)) {
    final end = match.end;
    final sentence = input.substring(start, end).trim();
    if (sentence.isNotEmpty) sentences.add(sentence);
    start = end;
  }
  var rest = input.substring(start);
  if (flush && rest.trim().isNotEmpty) {
    sentences.add(rest.trim());
    rest = '';
  }
  return (sentences: sentences, rest: rest);
}

class VoiceStore extends ChangeNotifier {
  final ConnectionStore connection;
  late final VoicePlayerAdapter _player;
  bool _recording = false;
  bool _speaking = false;
  bool _continuousConversation = false;
  bool _autoSpeak = false;
  bool _muted = false;
  bool _bargeMonitoring = false;
  double _inputLevel = 0;
  VoiceConversationPhase _phase = VoiceConversationPhase.idle;
  String? _voiceError;
  int _generation = 0;
  String? _conversationScope;
  DateTime? _playbackEndedAt;
  String? _streamingSpeechId;
  String _streamingSource = '';
  String _streamingBuffer = '';
  final List<String> _speechQueue = [];
  bool _speechPumpRunning = false;
  bool _streamingSpeechFinished = false;
  Completer<void>? _streamingSpeechDone;
  Completer<void>? _playbackGate;
  DateTime? _playbackInterruptedAt;
  late final VoiceRecorderAdapter _recorder;
  WakeWordStore? _wakeWord;
  Completer<void>? _bargeCancel;
  Completer<void>? _bargeStopped;

  VoiceStore({
    required this.connection,
    VoiceRecorderAdapter? recorder,
    VoicePlayerAdapter? player,
  }) {
    _recorder = recorder ?? voice_record.VoiceRecorder();
    _player = player ?? DeviceVoicePlayer();
    connection.addListener(_onConnectionChanged);
    _connectionId = connection.activeConnectionId;
    _connectionApi = connection.api;
    _loadPreferences();
  }

  late ConnectionId _connectionId;
  ApiClient? _connectionApi;

  void _onConnectionChanged() {
    final id = connection.activeConnectionId;
    final api = connection.api;
    if (id == _connectionId && identical(api, _connectionApi)) return;
    _connectionId = id;
    _connectionApi = api;
    unawaited(bindConversationScope('connection:${id.value}'));
  }

  bool get recording => _recording;
  bool get speaking => _speaking;
  bool get continuousConversation => _continuousConversation;
  bool get autoSpeak => _autoSpeak;
  bool get muted => _muted;
  bool get bargeMonitoring => _bargeMonitoring;
  double get inputLevel => _inputLevel;
  VoiceConversationPhase get phase => _phase;
  String? get voiceError => _voiceError;
  int get generation => _generation;
  String? get streamingSpeechId => _streamingSpeechId;
  WakeWordStore? get wakeWord => _wakeWord;
  WakeDetection? get wakeDetection => _wakeWord?.detection;

  void bindWakeWord(WakeWordStore? store) {
    if (identical(_wakeWord, store)) return;
    _wakeWord?.removeListener(_onWakeChanged);
    _wakeWord = store;
    _wakeWord?.addListener(_onWakeChanged);
    notifyListeners();
  }

  void _onWakeChanged() => notifyListeners();

  WakeDetection? takeWakeDetection() => _wakeWord?.takeDetection();

  static const _autoSpeakKey = 'hm_voice_auto_speak';

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSpeak = prefs.getBool(_autoSpeakKey) ?? false;
    notifyListeners();
  }

  Future<void> setAutoSpeak(bool enabled) async {
    if (_autoSpeak == enabled) return;
    _autoSpeak = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSpeakKey, enabled);
  }

  Future<void> toggleAutoSpeak() => setAutoSpeak(!_autoSpeak);

  void toggleMuted() {
    _muted = !_muted;
    if (_muted) {
      if (_recording) {
        // Bump the generation so any in-flight recordAndTranscribe/
        // _finishRecording call recognizes it was interrupted by muting
        // instead of silently discarding the utterance (see _finishRecording
        // and recordAndTranscribe's `operation != _generation` guards).
        _generation++;
        _voiceError = runtimeL10n.voiceRecordingDroppedMuted;
        unawaited(_recorder.stop());
      }
      if (_bargeMonitoring) unawaited(stopBargeInMonitoring());
    }
    _recording = false;
    _inputLevel = 0;
    notifyListeners();
  }

  void _reportInputLevel(double level) {
    final next = level.clamp(0.0, 1.0);
    if ((next - _inputLevel).abs() < 0.04) return;
    _inputLevel = next;
    notifyListeners();
  }

  Future<void> bindConversationScope(String? scope) async {
    if (scope == _conversationScope) return;
    _conversationScope = scope;
    _generation++;
    _continuousConversation = false;
    _phase = VoiceConversationPhase.idle;
    await _player.stop();
    if (_bargeMonitoring) await stopBargeInMonitoring();
    if (_recording) await _recorder.stop();
    _recording = false;
    _speaking = false;
    _resetStreamingSpeech();
    unawaited(_wakeWord?.resumeAfterVoice());
    notifyListeners();
  }

  void toggleContinuousConversation() {
    _continuousConversation = !_continuousConversation;
    _generation++;
    if (!_continuousConversation) {
      unawaited(_player.stop());
      if (_bargeMonitoring) unawaited(stopBargeInMonitoring());
      _resetStreamingSpeech();
      _speaking = false;
      _phase = VoiceConversationPhase.idle;
      unawaited(_wakeWord?.resumeAfterVoice());
    } else {
      unawaited(_wakeWord?.pauseForVoice());
    }
    _voiceError = null;
    notifyListeners();
  }

  Future<void> endConversation() async {
    _generation++;
    _continuousConversation = false;
    final gate = _playbackGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    await _player.stop();
    if (_bargeMonitoring) await stopBargeInMonitoring();
    if (_recording) await _recorder.stop();
    _recording = false;
    _speaking = false;
    _phase = VoiceConversationPhase.idle;
    _resetStreamingSpeech();
    _voiceError = null;
    unawaited(_wakeWord?.resumeAfterVoice());
    notifyListeners();
  }

  void markWaiting() {
    if (!_continuousConversation) return;
    _phase = VoiceConversationPhase.waiting;
    notifyListeners();
  }

  /// Record one utterance and return the transcribed text, or null.
  Future<String?> recordAndTranscribe() async {
    if (_muted) return null;
    final operation = _generation;
    final api = connection.api;
    if (api == null) {
      _voiceError = runtimeL10n.voiceServerDisconnected;
      notifyListeners();
      return null;
    }
    if (!_recorder.supported) {
      _voiceError = runtimeL10n.voiceRecordingUnsupported;
      notifyListeners();
      return null;
    }
    if (_recording) {
      return _finishRecording(api);
    }
    await _wakeWord?.pauseForVoice();
    try {
      final ended = _playbackEndedAt;
      if (ended != null) {
        final remaining =
            const Duration(milliseconds: 420) -
            DateTime.now().difference(ended);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
      if (operation != _generation) return null;
      final started = await _recorder.start();
      if (!started) {
        _voiceError = runtimeL10n.voiceMicrophoneStartFailed;
        notifyListeners();
        unawaited(_wakeWord?.resumeAfterVoice());
        return null;
      }
      _recording = true;
      _phase = VoiceConversationPhase.listening;
      _voiceError = null;
      notifyListeners();
      if (_continuousConversation) {
        await _recorder.waitForSpeechEnd(onLevel: _reportInputLevel);
        if (operation != _generation) return null;
        return await _finishRecording(api);
      }
      return null;
    } catch (e) {
      if (operation != _generation) return null;
      _recording = false;
      _voiceError = runtimeL10n.voiceRecordingFailed('$e');
      notifyListeners();
      if (!_continuousConversation) {
        unawaited(_wakeWord?.resumeAfterVoice());
      }
      return null;
    }
  }

  /// Monitor the microphone while a voice turn is generating/playing. The
  /// recorder starts immediately, preserving pre-roll; once sustained speech
  /// is detected [onDetected] cuts the active response and the captured
  /// utterance is transcribed for immediate resubmission.
  ///
  /// [stopBargeInMonitoring] cancels an in-progress call and releases the
  /// microphone promptly instead of waiting for the internal (up to 60s)
  /// speech-detection loops below to notice a state change on their own.
  Future<String?> monitorBargeIn(FutureOr<void> Function() onDetected) async {
    if (!_continuousConversation ||
        _muted ||
        _bargeMonitoring ||
        !_recorder.supported) {
      return null;
    }
    final api = connection.api;
    if (api == null) return null;
    _bargeMonitoring = true;
    final cancelled = Completer<void>();
    _bargeCancel = cancelled;
    final stopped = Completer<void>();
    _bargeStopped = stopped;
    try {
      return await Future.any<String?>([
        _runBargeInMonitor(api, onDetected, cancelled),
        cancelled.future.then((_) => null),
      ]);
    } finally {
      _bargeMonitoring = false;
      _bargeCancel = null;
      _inputLevel = 0;
      if (identical(_bargeStopped, stopped)) _bargeStopped = null;
      if (!stopped.isCompleted) stopped.complete();
      notifyListeners();
    }
  }

  Future<String?> _runBargeInMonitor(
    dynamic api,
    FutureOr<void> Function() onDetected,
    Completer<void> cancelled,
  ) async {
    final scope = _conversationScope;
    try {
      if (!await _recorder.start()) return null;
      final heard = await _raceCancelled(
        _recorder.waitForSpeechStart(onLevel: _reportInputLevel),
        cancelled,
        fallback: false,
      );
      if (!heard ||
          scope != _conversationScope ||
          _muted ||
          cancelled.isCompleted) {
        await _recorder.stop();
        return null;
      }
      await onDetected();
      await _raceCancelled(
        _recorder.waitForSpeechEnd(onLevel: _reportInputLevel),
        cancelled,
        fallback: null,
      );
      final bytes = await _recorder.stop();
      if (bytes == null ||
          bytes.isEmpty ||
          scope != _conversationScope ||
          !_continuousConversation ||
          _muted ||
          cancelled.isCompleted) {
        return null;
      }
      final mime = _recorder.mimeType;
      final text = await api.audioTranscribe(
        'data:$mime;base64,${base64Encode(bytes)}',
        mime,
      );
      if (cancelled.isCompleted) return null;
      if (isStopPhrase(text)) {
        toggleContinuousConversation();
        return null;
      }
      return text.trim().isEmpty ? null : text.trim();
    } catch (_) {
      return null;
    }
  }

  /// Race [future] against [cancel]; if cancellation wins, [fallback] is
  /// returned instead (the still-pending [future] is left to resolve in the
  /// background and is ignored).
  Future<T> _raceCancelled<T>(
    Future<T> future,
    Completer<void> cancel, {
    required T fallback,
  }) {
    return Future.any<T>([future, cancel.future.then((_) => fallback)]);
  }

  /// Cancel any in-progress [monitorBargeIn] call and stop the microphone
  /// immediately. Safe to call even when no monitoring is active.
  Future<void> stopBargeInMonitoring() async {
    if (!_bargeMonitoring) return;
    final cancel = _bargeCancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    await _recorder.stop();
    final stopped = _bargeStopped;
    if (stopped != null) await stopped.future;
  }

  Future<String?> _finishRecording(dynamic api) async {
    final operation = _generation;
    try {
      _phase = VoiceConversationPhase.transcribing;
      final bytes = await _recorder.stop();
      _recording = false;
      notifyListeners();
      if (bytes == null || bytes.isEmpty) return null;
      final mime = _recorder.mimeType;
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      final text = await api.audioTranscribe(dataUrl, mime);
      if (operation != _generation) return null;
      if (text.trim().isEmpty) {
        _voiceError = runtimeL10n.voiceNoSpeech;
        notifyListeners();
        return null;
      }
      if (isStopPhrase(text)) {
        _continuousConversation = false;
        _phase = VoiceConversationPhase.idle;
        notifyListeners();
        return null;
      }
      return text;
    } catch (e) {
      if (operation != _generation) return null;
      _recording = false;
      // 409 = STT not configured on the server; surface a friendly hint.
      _voiceError = e is ApiException && e.statusCode == 409
          ? runtimeL10n.voiceSttUnavailable
          : runtimeL10n.voiceTranscriptionFailed('$e');
      notifyListeners();
      return null;
    } finally {
      if (operation == _generation && !_recording && !_continuousConversation) {
        unawaited(_wakeWord?.resumeAfterVoice());
      }
    }
  }

  /// Speak a completed assistant reply (E3: never a half-streamed message).
  Future<void> speak(String text) async {
    final api = connection.api;
    if (api == null || text.trim().isEmpty) return;
    await _wakeWord?.pauseForVoice();
    final operation = _generation;
    try {
      _resetStreamingSpeech();
      if (_recording) {
        await _recorder.stop();
        _recording = false;
      }
      _speaking = true;
      _phase = VoiceConversationPhase.speaking;
      notifyListeners();
      final bytes = await api.audioSpeak(text);
      if (operation != _generation) return;
      await _player.stop();
      final completed = Completer<void>();
      late final StreamSubscription<void> subscription;
      subscription = _player.onComplete.listen((_) {
        if (!completed.isCompleted) completed.complete();
      });
      await _player.play(Uint8List.fromList(bytes));
      await completed.future.timeout(const Duration(minutes: 5));
      await subscription.cancel();
    } catch (e) {
      if (operation == _generation) {
        _voiceError = runtimeL10n.voiceSpeechFailed('$e');
        notifyListeners();
      }
    } finally {
      if (operation == _generation) {
        _speaking = false;
        _playbackEndedAt = DateTime.now();
        _phase = _continuousConversation
            ? VoiceConversationPhase.listening
            : VoiceConversationPhase.idle;
        notifyListeners();
        if (!_continuousConversation) {
          unawaited(_wakeWord?.resumeAfterVoice());
        }
      }
    }
  }

  Future<void> stopSpeaking() async {
    markPlaybackInterrupted();
    _generation++;
    final gate = _playbackGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    await _player.stop();
    _resetStreamingSpeech();
    _speaking = false;
    _phase = _continuousConversation
        ? VoiceConversationPhase.listening
        : VoiceConversationPhase.idle;
    notifyListeners();
    if (!_continuousConversation) {
      unawaited(_wakeWord?.resumeAfterVoice());
    }
  }

  /// Feed the latest full text of one in-progress assistant reply. Completed
  /// sentences are synthesized sequentially so playback overlaps generation.
  void appendStreamingSpeech(String replyId, String fullText) {
    if (!_continuousConversation || replyId.isEmpty) return;
    if (_streamingSpeechId != replyId) {
      _generation++;
      unawaited(_player.stop());
      _resetStreamingSpeech();
      _streamingSpeechId = replyId;
      _streamingSpeechDone = Completer<void>();
    }
    if (!fullText.startsWith(_streamingSource)) {
      // A corrected/replaced stream is safer to restart from its current text
      // than to speak an invalid substring.
      _streamingSource = '';
      _streamingBuffer = '';
      _speechQueue.clear();
    }
    final delta = fullText.substring(_streamingSource.length);
    _streamingSource = fullText;
    if (delta.isEmpty) return;
    _streamingBuffer += delta;
    final cut = splitSpeechSentences(_streamingBuffer);
    _streamingBuffer = cut.rest;
    _speechQueue.addAll(cut.sentences);
    unawaited(_pumpSpeechQueue());
  }

  /// Flush the final partial sentence and resolve once queued audio drains.
  Future<void> finishStreamingSpeech(String replyId, String fullText) async {
    appendStreamingSpeech(replyId, fullText);
    if (_streamingSpeechId != replyId) return;
    final cut = splitSpeechSentences(_streamingBuffer, flush: true);
    _streamingBuffer = cut.rest;
    _speechQueue.addAll(cut.sentences);
    _streamingSpeechFinished = true;
    unawaited(_pumpSpeechQueue());
    await _streamingSpeechDone?.future;
  }

  Future<void> _pumpSpeechQueue() async {
    if (_speechPumpRunning || _streamingSpeechId == null) return;
    final api = connection.api;
    if (api == null) {
      _completeStreamingSpeech();
      return;
    }
    _speechPumpRunning = true;
    final operation = _generation;
    try {
      while (_speechQueue.isNotEmpty && operation == _generation) {
        final sentence = _speechQueue.removeAt(0).trim();
        if (sentence.isEmpty) continue;
        final bytes = await api.audioSpeak(sentence);
        if (operation != _generation) return;
        _speaking = true;
        _phase = VoiceConversationPhase.speaking;
        notifyListeners();
        await _playBytes(bytes);
      }
    } catch (e) {
      if (operation == _generation) {
        _voiceError = runtimeL10n.voiceStreamingSpeechFailed('$e');
        notifyListeners();
        _completeStreamingSpeech();
      }
    } finally {
      _speechPumpRunning = false;
      if (operation == _generation && _speechQueue.isNotEmpty) {
        unawaited(_pumpSpeechQueue());
      } else if (operation == _generation && _streamingSpeechFinished) {
        _completeStreamingSpeech();
      }
    }
  }

  Future<void> _playBytes(List<int> bytes) async {
    final completed = Completer<void>();
    _playbackGate = completed;
    late final StreamSubscription<void> subscription;
    subscription = _player.onComplete.listen((_) {
      if (!completed.isCompleted) completed.complete();
    });
    try {
      await _player.play(Uint8List.fromList(bytes));
      await completed.future.timeout(const Duration(minutes: 2));
    } finally {
      await subscription.cancel();
      if (identical(_playbackGate, completed)) _playbackGate = null;
    }
  }

  void _completeStreamingSpeech() {
    _speaking = false;
    _playbackEndedAt = DateTime.now();
    _phase = _continuousConversation
        ? VoiceConversationPhase.listening
        : VoiceConversationPhase.idle;
    final done = _streamingSpeechDone;
    if (done != null && !done.isCompleted) done.complete();
    notifyListeners();
  }

  void _resetStreamingSpeech() {
    final gate = _playbackGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    _playbackGate = null;
    final done = _streamingSpeechDone;
    if (done != null && !done.isCompleted) done.complete();
    _streamingSpeechId = null;
    _streamingSource = '';
    _streamingBuffer = '';
    _speechQueue.clear();
    _streamingSpeechFinished = false;
    _streamingSpeechDone = null;
  }

  void markPlaybackInterrupted() {
    if (_speaking || _streamingSpeechId != null) {
      _playbackInterruptedAt = DateTime.now();
    }
  }

  bool takePlaybackInterrupted() {
    final at = _playbackInterruptedAt;
    _playbackInterruptedAt = null;
    return at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 2);
  }

  static bool isStopPhrase(String text) {
    final normalized = text.trim().toLowerCase().replaceAll(
      RegExp(r'[，。！？,.!?\s]'),
      '',
    );
    return const {
      '停止对话',
      '结束对话',
      'stopconversation',
      'stoplistening',
      'stop',
      '停止',
    }.contains(normalized);
  }

  void clearError() {
    _voiceError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    connection.removeListener(_onConnectionChanged);
    _wakeWord?.removeListener(_onWakeChanged);
    _recorder.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }
}
