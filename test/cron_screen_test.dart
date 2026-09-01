import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/screens/cron_screen.dart';
import 'package:provider/provider.dart';

class _CronContractApi extends ApiClient {
  _CronContractApi({this.jobs = const []})
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  List<CronJob> jobs;
  Map<String, dynamic>? instantiated;
  Map<String, dynamic>? updated;

  @override
  Future<List<CronJob>> cronJobs() async => jobs;

  @override
  Future<List<ModelInfo>> modelOptions() async => const [
    ModelInfo(
      slug: 'nous',
      name: 'Nous',
      isCurrent: true,
      models: ['hermes-4'],
    ),
  ];

  @override
  Future<Map<String, dynamic>> cronUpdate(
    String id,
    Map<String, dynamic> updates,
  ) async {
    updated = updates;
    return {'id': id, ...updates};
  }

  @override
  Future<List<CronDeliveryTarget>> cronDeliveryTargets() async => const [
    CronDeliveryTarget(id: 'local', name: 'Local', homeTargetSet: true),
    CronDeliveryTarget(id: 'weixin', name: 'Weixin', homeTargetSet: true),
  ];

  @override
  Future<List<CronBlueprint>> cronBlueprints() async => [
    CronBlueprint.fromJson({
      'key': 'morning-brief',
      'title': 'Morning briefing',
      'description': 'A short daily briefing.',
      'category': 'daily',
      'tags': ['daily'],
      'fields': [
        {
          'name': 'time',
          'type': 'time',
          'label': 'What time?',
          'default': '08:00',
          'options': [],
        },
        {
          'name': 'deliver',
          'type': 'enum',
          'label': 'Where to deliver?',
          'default': 'origin',
          'options': ['origin', 'local'],
          'strict': false,
        },
      ],
    }),
  ];

  @override
  Future<Map<String, dynamic>> instantiateCronBlueprint(
    Map<String, dynamic> payload,
  ) async {
    instantiated = payload;
    return {'id': 'job-1'};
  }
}

class _CronRunsFailureApi extends _CronContractApi {
  _CronRunsFailureApi({required super.jobs});

  @override
  Future<List<Map<String, dynamic>>> cronRuns(
    String id, {
    int limit = 50,
  }) async {
    throw StateError('runs unavailable');
  }
}

void main() {
  testWidgets('Cron editor renders and submits the real blueprint contract', (
    tester,
  ) async {
    final api = _CronContractApi();
    final connection = ConnectionStore()..api = api;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: connection,
        child: const MaterialApp(home: CronScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('从模板开始'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Morning briefing'), findsOneWidget);
    await tester.tap(find.text('Morning briefing').last);
    await tester.pumpAndSettle();

    expect(find.text('A short daily briefing.'), findsOneWidget);
    expect(find.text('What time?'), findsOneWidget);
    expect(find.text('Where to deliver?'), findsOneWidget);
    expect(find.text('此设备'), findsOneWidget);

    final submit = find.widgetWithText(FilledButton, '安排此自动化');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(api.instantiated, {
      'blueprint': 'morning-brief',
      'values': {'time': '08:00', 'deliver': 'local'},
    });
    connection.dispose();
  });

  testWidgets(
    'Cron edit clears a saved model override when default is selected',
    (tester) async {
      final api = _CronContractApi(
        jobs: [
          CronJob(
            id: 'job-1',
            name: 'Daily brief',
            schedule: '0 9 * * *',
            prompt: 'Summarize today',
            enabled: true,
            provider: 'nous',
            model: 'hermes-4',
          ),
        ],
      );
      final connection = ConnectionStore()..api = api;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: connection,
          child: const MaterialApp(home: CronScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily brief'));
      await tester.pumpAndSettle();

      final modelPicker = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(modelPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('跟随全局默认').last);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, '保存');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(api.updated?['model'], isNull);
      expect(api.updated?['provider'], isNull);
      connection.dispose();
    },
  );

  testWidgets(
    'Script-only Cron edit preserves script prompt and model fields',
    (tester) async {
      final api = _CronContractApi(
        jobs: [
          CronJob(
            id: 'script-1',
            name: 'Backup',
            schedule: '0 2 * * *',
            enabled: true,
            noAgent: true,
            script: 'backup.ps1',
            provider: 'nous',
            model: 'hermes-4',
          ),
        ],
      );
      final connection = ConnectionStore()..api = api;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: connection,
          child: const MaterialApp(home: CronScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('仅脚本任务'), findsOneWidget);
      expect(find.text('任务模型'), findsNothing);
      final save = find.widgetWithText(FilledButton, '保存');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(api.updated, isNot(contains('prompt')));
      expect(api.updated, isNot(contains('model')));
      expect(api.updated, isNot(contains('provider')));
      connection.dispose();
    },
  );

  group('effectiveState', () {
    test('an explicit backend state wins over the enabled flag', () {
      final job = CronJob(id: 'j', enabled: true, state: 'error');
      expect(job.effectiveState, 'error');
    });

    test('falls back to scheduled/disabled from the enabled flag', () {
      expect(CronJob(id: 'a', enabled: true).effectiveState, 'scheduled');
      expect(CronJob(id: 'b', enabled: false).effectiveState, 'disabled');
    });

    test('an empty/whitespace state string also falls back', () {
      expect(
        CronJob(id: 'c', enabled: true, state: '  ').effectiveState,
        'scheduled',
      );
    });
  });

  testWidgets(
    'the job row shows a state badge distinct from the enabled switch',
    (tester) async {
      final api = _CronContractApi(
        jobs: [
          CronJob(
            id: 'job-1',
            name: 'Nightly sync',
            schedule: '0 2 * * *',
            enabled: true,
            state: 'error',
          ),
        ],
      );
      final connection = ConnectionStore()..api = api;
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: connection,
          child: const MaterialApp(home: CronScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Enabled (the switch is on) but the last run errored — the badge must
      // reflect the real state, not just the boolean toggle.
      expect(find.text('出错'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    },
  );

  testWidgets(
    'the job list silently polls for status updates without a manual refresh',
    (tester) async {
      final api = _CronContractApi(
        jobs: [
          CronJob(id: 'job-1', name: 'Sync', enabled: true, state: 'running'),
        ],
      );
      final connection = ConnectionStore()..api = api;
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: connection,
          child: const MaterialApp(home: CronScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('运行中'), findsOneWidget);

      // The job "finishes" server-side; nothing in the UI triggers a reload —
      // only the background poll should pick this up.
      api.jobs = [
        CronJob(id: 'job-1', name: 'Sync', enabled: true, state: 'completed'),
      ];

      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();

      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('运行中'), findsNothing);
    },
  );

  testWidgets('run history failure is not rendered as an empty history', (
    tester,
  ) async {
    final api = _CronRunsFailureApi(
      jobs: [CronJob(id: 'job-1', name: 'Failing history', enabled: true)],
    );
    final connection = ConnectionStore()..api = api;
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: connection,
        child: const MaterialApp(home: CronScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Failing history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('运行记录'));
    await tester.pumpAndSettle();

    expect(find.textContaining('runs unavailable'), findsOneWidget);
    expect(find.text('暂无运行记录'), findsNothing);
  });
}
