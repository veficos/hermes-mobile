import 'package:flutter/material.dart';

import '../../core/stores/voice_store.dart';
import '../../core/stores/wake_word_store.dart';
import '../../l10n/l10n.dart';

class HermesVoiceMenu extends StatelessWidget {
  final VoiceStore voice;
  final VoidCallback onDictate;
  final VoidCallback onToggleContinuous;
  final VoidCallback onToggleAutoSpeak;

  const HermesVoiceMenu({
    super.key,
    required this.voice,
    required this.onDictate,
    required this.onToggleContinuous,
    required this.onToggleAutoSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final wake = voice.wakeWord;
    // Three visually distinct states (desktop's wake-indicator overlay
    // parity, condensed into this one icon since mobile has no persistent
    // top-level indicator window): capturing (recording/speaking/continuous,
    // or the wake word just fired and a capture is about to start) beats
    // armed (wake word enabled and actively listening for it, nothing
    // captured yet) beats idle.
    final capturing =
        voice.recording ||
        voice.speaking ||
        voice.continuousConversation ||
        wake?.detection != null;
    final armed = !capturing && wake?.listening == true;
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: context.l10n.voiceMenu,
      icon: Icon(
        capturing
            ? Icons.graphic_eq
            : armed
            ? Icons.hearing
            : Icons.keyboard_voice_outlined,
        color: capturing
            ? theme.colorScheme.primary
            : armed
            ? theme.colorScheme.tertiary
            : null,
      ),
      onSelected: (value) {
        switch (value) {
          case 'dictate':
            onDictate();
          case 'continuous':
            onToggleContinuous();
          case 'auto':
            onToggleAutoSpeak();
          case 'wake':
            wake?.toggle();
          case 'stop':
            voice.stopSpeaking();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'dictate',
          child: ListTile(
            dense: true,
            leading: Icon(voice.recording ? Icons.stop : Icons.mic_none),
            title: Text(
              voice.recording
                  ? context.l10n.voiceStopRecording
                  : context.l10n.voiceDictation,
            ),
          ),
        ),
        CheckedPopupMenuItem(
          value: 'continuous',
          checked: voice.continuousConversation,
          child: Text(context.l10n.voiceContinuousConversation),
        ),
        CheckedPopupMenuItem(
          value: 'auto',
          checked: voice.autoSpeak,
          child: Text(context.l10n.voiceAutoReadReplies),
        ),
        if (wake != null && (wake.available || wake.enabled))
          CheckedPopupMenuItem(
            value: 'wake',
            checked: wake.enabled,
            enabled: !wake.pending,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hearing_outlined),
              title: Text(
                wake.phrase.isEmpty
                    ? context.l10n.voiceWakeWord
                    : context.l10n.voiceWakePhrase(wake.phrase),
              ),
              subtitle: Text(
                _wakeStatus(context, wake),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (voice.speaking)
          PopupMenuItem(
            value: 'stop',
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(context.l10n.voiceStopSpeaking),
            ),
          ),
      ],
    );
  }

  String _wakeStatus(BuildContext context, WakeWordStore wake) {
    if (wake.pending) return context.l10n.voiceWakeEnabling;
    if (wake.detection != null) return context.l10n.voiceWakeTriggered;
    if (wake.enabled && wake.listening) {
      return wake.phrase.isEmpty
          ? context.l10n.voiceWakeListening
          : context.l10n.voiceWakeListeningFor(wake.phrase);
    }
    if (wake.notice.isNotEmpty) return wake.notice;
    return wake.enabled
        ? context.l10n.voiceWakeWaiting
        : context.l10n.voiceWakeDisabled;
  }
}
