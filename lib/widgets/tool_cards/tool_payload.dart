/// Shared payload helpers for the rich tool cards in this directory.
/// Extracted verbatim from `lib/widgets/message_bubble.dart` (formerly the
/// private `_toolResultText` / `_inlineDiff`); behavior unchanged.
library;

import 'dart:convert';

/// Best-effort plain-text rendering of a tool call's result payload.
String toolResultText(Map<String, dynamic> data) {
  final value = data['result_text'] ?? data['result'] ?? data['summary'] ?? '';
  if (value is String) return value;
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}

/// Extracts an inline unified diff from a tool call's result payload, or ''.
String inlineDiffText(Map<String, dynamic> data) {
  dynamic result = data['result'] ?? data['result_text'];
  if (result is String) {
    try {
      result = jsonDecode(result);
    } catch (_) {}
  }
  if (result is Map) {
    return (result['inline_diff'] ?? result['diff'] ?? '').toString();
  }
  return '';
}
