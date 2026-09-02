import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/screens/command_center_screen.dart';
import 'package:provider/provider.dart';

/// Desktop's Command Center has a 状态/用量/维护 tab layout; mobile previously
/// dumped raw JSON for the usage panel and had no maintenance actions at all
/// (doctor / security audit / backup / debug share). This covers the ported
/// 3-tab structure end to end against a fake ApiClient contract double.
class _CommandCenterApi extends ApiClient {
  _CommandCenterApi()
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  int? lastUsageDays;
  final List<String> opsCalls = [];
  final Map<String, List<Map<String, dynamic>>> actionStatusSequence = {};
  final Map<String, int> _actionStatusCallCount = {};

  @override
  Future<Map<String, dynamic>> status() async => {
    'status': 'ok',
    'backend': {'running': true, 'hermes_version': '9.9.9'},
    'runtime': {'kind': 'local'},
  };

  @override
  Future<dynamic> getLogs({
    String file = 'agent',
    int lines = 200,
    String? level,
    String? component,
    String? search,
  }) async => 'hello from the log tail';

  @override
  Future<Map<String, dynamic>> restartBackend() async => {
    'status': 'restarted',
  };

  @override
  Future<AnalyticsUsage> analyticsUsageTyped({int days = 30}) async {
    lastUsageDays = days;
    return AnalyticsUsage(
      daily: const [
        AnalyticsDailyEntry(day: '08-27', inputTokens: 100, outputTokens: 50),
        AnalyticsDailyEntry(day: '08-28', inputTokens: 200, outputTokens: 80),
      ],
      byModel: const [
        AnalyticsModelEntry(
          model: 'nous-hermes-4',
          inputTokens: 250,
          outputTokens: 100,
        ),
      ],
      topSkills: const [
        AnalyticsSkillEntry(skill: 'web-search', totalCount: 7),
      ],
      totals: const AnalyticsTotals(
        totalSessions: 12,
        totalApiCalls: 340,
        totalInput: 300,
        totalOutput: 130,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> runDoctor() async {
    opsCalls.add('doctor');
    return {'ok': true, 'pid': 1, 'name': 'doctor'};
  }

  @override
  Future<Map<String, dynamic>> runSecurityAudit() async {
    opsCalls.add('security-audit');
    return {'ok': true, 'pid': 2, 'name': 'security-audit'};
  }

  @override
  Future<Map<String, dynamic>> runBackup() async {
    opsCalls.add('backup');
    return {'ok': true, 'pid': 3, 'name': 'backup'};
  }

  @override
  Future<Map<String, dynamic>> runDebugShare() async {
    opsCalls.add('debug-share');
    return {
      'ok': true,
      'urls': {'summary': 'https://paste.example/abc123'},
      'failures': <String, dynamic>{},
      'redacted': true,
      'auto_delete_seconds': 21600,
    };
  }

  @override
  Future<Map<String, dynamic>> actionStatus(
    String name, {
    int lines = 200,
    String? profile,
  }) async {
    final seq = actionStatusSequence[name];
    if (seq == null || seq.isEmpty) {
      return {
        'name': name,
        'running': false,
        'exit_code': 0,
        'lines': <String>[],
      };
    }
    final i = (_actionStatusCallCount[name] ?? 0).clamp(0, seq.length - 1);
    _actionStatusCallCount[name] = i + 1;
    return seq[i];
  }
}

Future<_CommandCenterApi> _pump(WidgetTester tester) async {
  final api = _CommandCenterApi();
  final connection = ConnectionStore()..api = api;
  final session = SessionStore(
    connection: connection,
    chat: ChatStore(),
    requests: RequestStore(),
  );
  addTearDown(() {
    session.dispose();
    connection.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider<SessionStore>.value(value: session),
      ],
      child: const MaterialApp(home: CommandCenterScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('状态 tab shows running status and log tail', (tester) async {
    await _pump(tester);
    expect(find.text('运行中'), findsOneWidget);
    expect(find.text('hello from the log tail'), findsOneWidget);
  });

  testWidgets('用量 tab renders stat tiles and top lists from AnalyticsUsage', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(Tab, '用量'));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget); // sessions
    expect(find.text('nous-hermes-4'), findsOneWidget);
    expect(find.text('web-search'), findsOneWidget);
    expect(find.text('7 次'), findsOneWidget);
  });

  testWidgets('switching the usage period re-fetches with the new day count', (
    tester,
  ) async {
    final api = await _pump(tester);
    await tester.tap(find.widgetWithText(Tab, '用量'));
    await tester.pumpAndSettle();
    expect(api.lastUsageDays, 30);

    await tester.tap(find.widgetWithText(ChoiceChip, '7 天'));
    await tester.pumpAndSettle();

    expect(api.lastUsageDays, 7);
  });

  testWidgets('维护 tab runs doctor, polls to completion, and reports success', (
    tester,
  ) async {
    final api = await _pump(tester);
    api.actionStatusSequence['doctor'] = [
      {
        'name': 'doctor',
        'running': true,
        'exit_code': null,
        'lines': ['starting doctor…'],
      },
      {
        'name': 'doctor',
        'running': false,
        'exit_code': 0,
        'lines': ['starting doctor…', 'all checks passed'],
      },
    ];

    await tester.tap(find.widgetWithText(Tab, '维护'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('运行诊断'));
    await tester.pump();
    // Let the poll loop's 1s delay between actionStatus calls elapse.
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    await tester.pumpAndSettle();

    expect(api.opsCalls, contains('doctor'));
    expect(find.text('诊断 完成'), findsOneWidget);

    // Let the success toast's auto-dismiss timer fire before teardown.
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('维护 tab debug share shows the returned share URL', (
    tester,
  ) async {
    final api = await _pump(tester);
    await tester.tap(find.widgetWithText(Tab, '维护'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成调试分享'));
    await tester.pumpAndSettle();

    expect(api.opsCalls, contains('debug-share'));
    expect(find.text('已对日志进行脱敏处理。'), findsOneWidget);
    expect(find.textContaining('https://paste.example/abc123'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
  });
}
