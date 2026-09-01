import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/widgets/session/session_detail_panel.dart';

void main() {
  test('SessionRow parses rich history metadata', () {
    final row = SessionRow.fromJson({
      'id': 's1',
      'started_at': 1700000000,
      'ended_at': 1700003600,
      'last_activity_at': 1700003600,
      'end_reason': 'completed',
      'tool_call_count': 8,
      'api_call_count': 12,
      'input_tokens': 100,
      'output_tokens': 20,
      'cache_read_tokens': 50,
      'cache_write_tokens': 5,
      'reasoning_tokens': 7,
      'estimated_cost_usd': 0.25,
      'billing_provider': 'nous',
      'source': 'weixin',
      'display_name': 'Alice',
      'chat_type': 'dm',
      'handoff_state': 'complete',
      'handoff_platform': 'weixin',
      'rewind_count': 2,
    });

    expect(row.toolCallCount, 8);
    expect(row.apiCallCount, 12);
    expect(row.totalTokens, 175);
    expect(row.duration, const Duration(hours: 1));
    expect(row.estimatedCostUsd, 0.25);
    expect(row.displayName, 'Alice');
    expect(row.handoffPlatform, 'weixin');
    expect(row.rewindCount, 2);
    expect(SessionRow.fromJson(row.toJson()).totalTokens, 175);
  });

  testWidgets('detail panel renders usage, channel and lifecycle data', (
    tester,
  ) async {
    final row = SessionRow(
      id: 's1',
      title: '丰富会话',
      messageCount: 26,
      source: 'weixin',
      displayName: 'Alice',
      chatType: 'dm',
      model: 'hy3',
      provider: 'tencent',
      toolCallCount: 8,
      apiCallCount: 12,
      inputTokens: 1000,
      outputTokens: 200,
      estimatedCostUsd: .02,
      startedAt: DateTime(2026),
      endedAt: DateTime(2026, 1, 1, 1),
      endReason: 'completed',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SessionDetailPanel(row: row)),
      ),
    );
    expect(find.text('丰富会话'), findsOneWidget);
    expect(find.text('26 消息'), findsOneWidget);
    expect(find.text('8 工具'), findsOneWidget);
    expect(find.text('12 API'), findsOneWidget);
    expect(find.textContaining('weixin'), findsOneWidget);
    expect(find.text('结束原因'), findsOneWidget);
  });
}
