/// VoiceStore: recording, STT transcription and TTS playback (D3/F14/E3).
library;

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
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
  final AudioPlayer _player = AudioPlayer();
  bool _recording = false;
  bool _speaking = false;
  bool _continuousConversation = false;
  bool _autoSpeak = false;
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
  final voice_record.VoiceRecorder _recorder = voice_record.VoiceRecorder();
  WakeWordStore? _wakeWord;

  VoiceStore({required this.connection}) {
    _loadPreferences();
  }

  bool get recording => _recording;
  bool get speaking => _speaking;
  bool get continuousConversation => _continuousConversation;
  bool get autoSpeak => _autoSpeak;
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

  Future<void> bindConversationScope(String? scope) async {
    if (scope == _conversationScope) return;
    _conversationScope = scope;
    _generation++;
    _continuousConversation = false;
    _phase = VoiceConversationPhase.idle;
    await _player.stop();
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

  void markWaiting() {
    if (!_continuousConversation) return;
    _phase = VoiceConversationPhase.waiting;
    notifyListeners();
  }

  /// Record one utterance and return the transcribed text, or null.
  Future<String?> recordAndTranscribe() async {
    final operation = _generation;
    final api = connection.api;
    if (api == null) {
      _voiceError = runtimeL10n.voiceServerDisconnected;
      notifyListeners();
      return null;
    }
    if (!voice_record.isSupported) {
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
        await _recorder.waitForSpeechEnd();
        if (operation != _generation) return null;
        return await _finishRecording(api);
      }
      return null;
    } catch (e) {
      _recording = false;
      _voiceError = runtimeL10n.voiceRecordingFailed('$e');
      notifyListeners();
      if (!_continuousConversation) {
        unawaited(_wakeWord?.resumeAfterVoice());
      }
      return null;
    }
  }

  Future<String?> _finishRecording(dynamic api) async {
    final operation = _generation;
    try {
      _phase = VoiceConversationPhase.transcribing;
      final bytes = await _recorder.stop();
      _recording = false;
      notifyListeners();
      if (bytes == null || bytes.isEmpty) return null;
      final mime = voice_record.mimeType;
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      final text = await api.audioTranscribe(dataUrl, mime);
      if (operation != _generation) return null;
      if (text.trim().isEmpty) {
        _voiceError = runtimeL10n.voiceNoSpeech;
        notifyListeners();
        return null;
      }
      if (_isStopPhrase(text)) {
        _continuousConversation = false;
        _phase = VoiceConversationPhase.idle;
        notifyListeners();
        return null;
      }
      return text;
    } catch (e) {
      _recording = false;
      // 409 = STT not configured on the server; surface a friendly hint.
      _voiceError = e is ApiException && e.statusCode == 409
          ? runtimeL10n.voiceSttUnavailable
          : runtimeL10n.voiceTranscriptionFailed('$e');
      notifyListeners();
      return null;
    } finally {
      if (!_recording && !_continuousConversation) {
        unawaited(_wakeWord?.resumeAfterVoice());
      }
    }
  }

  /// Speak a completed assistant reply (E3: never a half-streamed message).
  Future<void> speak(String text) async {
    final api = connection.api;
    if (api == null || text.trim().isEmpty) return;
    await _wakeWord?.pauseForVoice();
    try {
      final operation = _generation;
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
      subscription = _player.onPlayerComplete.listen((_) {
        if (!completed.isCompleted) completed.complete();
      });
      await _player.play(
        BytesSource(Uint8List.fromList(bytes), mimeType: 'audio/mpeg'),
      );
      await completed.future.timeout(const Duration(minutes: 5));
      await subscription.cancel();
    } catch (e) {
      _voiceError = runtimeL10n.voiceSpeechFailed('$e');
      notifyListeners();
    } finally {
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
    subscription = _player.onPlayerComplete.listen((_) {
      if (!completed.isCompleted) completed.complete();
    });
    try {
      await _player.play(
        BytesSource(Uint8List.fromList(bytes), mimeType: 'audio/mpeg'),
      );
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

  static bool _isStopPhrase(String text) {
    final normalized = text.trim().toLowerCase().replaceAll(
      RegExp(r'[，。！？,.!?\s]'),
      '',
    );
    return const {
      '停止对话',
      '结束对话',
      'stopconversation',
      'stoplistening',
    }.contains(normalized);
  }

  void clearError() {
    _voiceError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _wakeWord?.removeListener(_onWakeChanged);
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
