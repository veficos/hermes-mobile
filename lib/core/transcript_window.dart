library;

import 'dart:math' as math;

import 'chat_message.dart';

const int transcriptWindowBudget = 1200;
const int transcriptWindowMinMessages = 30;
const int transcriptWindowSlack = transcriptWindowBudget ~/ 2;

int chatMessageRenderWeight(ChatMessage message) {
  var weight = 1;
  for (final part in message.parts) {
    final textLength = part.text.length;
    weight += math.max(1, (textLength / 800).ceil());
    if (part.kind == 'tool') {
      final tool = part.tool ?? const <String, dynamic>{};
      final result = (tool['result_text'] ?? tool['result'] ?? '').toString();
      weight += 4 + (result.length / 500).ceil();
    } else if (part.kind == 'artifact' || part.kind == 'image') {
      weight += 20;
    } else if (part.text.contains('```')) {
      weight += 4;
    }
  }
  return weight;
}

class TranscriptWindowSelection {
  final int start;
  final int weight;
  final String? anchorId;

  const TranscriptWindowSelection({
    required this.start,
    required this.weight,
    required this.anchorId,
  });
}

TranscriptWindowSelection selectTranscriptWindow(
  List<ChatMessage> messages, {
  int budget = transcriptWindowBudget,
  int minimumMessages = transcriptWindowMinMessages,
  String? stickyAnchorId,
}) {
  if (messages.isEmpty) {
    return const TranscriptWindowSelection(start: 0, weight: 0, anchorId: null);
  }
  if (stickyAnchorId != null) {
    final sticky = messages.indexWhere((m) => m.id == stickyAnchorId);
    if (sticky >= 0) {
      final stickyWeight = messages
          .skip(sticky)
          .fold<int>(0, (sum, m) => sum + chatMessageRenderWeight(m));
      if (stickyWeight <= budget + transcriptWindowSlack) {
        return TranscriptWindowSelection(
          start: sticky,
          weight: stickyWeight,
          anchorId: stickyAnchorId,
        );
      }
    }
  }
  var start = messages.length;
  var weight = 0;
  for (var i = messages.length - 1; i >= 0; i--) {
    weight += chatMessageRenderWeight(messages[i]);
    start = i;
    if (weight >= budget && messages.length - i >= minimumMessages) break;
  }
  return TranscriptWindowSelection(
    start: start,
    weight: weight,
    anchorId: start > 0 ? messages[start].id : null,
  );
}
