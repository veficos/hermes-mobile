import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/composer/background_process_sheet.dart';
import 'package:hermes_mobile/core/stores/composer_status_store.dart';
import 'package:provider/provider.dart';

/// Tapping a background-process row in the composer status stack must open
/// a viewer showing THAT process's own command/output/exit code — not a
/// generic, unrelated terminal screen.
class _FakeRpc implements ComposerStatusRpc {
  final List<String> killed = [];

  @override
  Future<List<Map<String, dynamic>>> listBackgroundProcesses(
    String sessionId,
  ) async => const [];

  @override
  Future<void> killBackgroundProcess(String sessionId, String processId) async {
    killed.add(processId);
  }
}

void main() {
  Future<ComposerStatusStore> seed({
    required String sessionId,
    required String processId,
    String command = 'npm run build',
    String output = 'compiling...\n42 modules',
    String status = 'running',
  }) async {
    final composer = ComposerStatusStore();
    composer.reconcileBackgroundProcesses(sessionId, [
      GatewayProcessEntry(
        sessionId: processId,
        command: command,
        status: status,
        outputTail: output,
      ),
    ]);
    return composer;
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    ComposerStatusStore composer, {
    required String sessionId,
    required String processId,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ComposerStatusStore>.value(
        value: composer,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showBackgroundProcessSheet(
                  context,
                  sessionId: sessionId,
                  processId: processId,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Not pumpAndSettle: the status chip's running-state pulse dot repeats
    // forever, so settling would never terminate. A bounded pump is enough
    // for the sheet's route transition to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the command and output for the tapped process', (
    tester,
  ) async {
    final composer = await seed(sessionId: 'sid', processId: 'proc-1');
    addTearDown(composer.dispose);

    await pumpSheet(tester, composer, sessionId: 'sid', processId: 'proc-1');

    expect(find.text('npm run build'), findsOneWidget);
    expect(find.textContaining('compiling...'), findsOneWidget);
    expect(find.text('运行中'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '停止进程'), findsOneWidget);
  });

  testWidgets('stopping the process calls the rpc and dismisses the row', (
    tester,
  ) async {
    final composer = await seed(sessionId: 'sid', processId: 'proc-1');
    addTearDown(composer.dispose);
    final rpc = _FakeRpc();
    composer.bindRpc(rpc);

    await pumpSheet(tester, composer, sessionId: 'sid', processId: 'proc-1');
    await tester.tap(find.widgetWithText(OutlinedButton, '停止进程'));
    await tester.pumpAndSettle();

    expect(rpc.killed, ['proc-1']);
    // The row is gone from the store — the sheet reactively falls back to
    // the "process no longer exists" state instead of showing stale data.
    expect(find.text('该进程已结束并被移除'), findsOneWidget);
  });

  testWidgets('a finished process shows its exit code and a dismiss action', (
    tester,
  ) async {
    final composer = await seed(
      sessionId: 'sid',
      processId: 'proc-1',
      status: 'exited',
    );

    await pumpSheet(tester, composer, sessionId: 'sid', processId: 'proc-1');

    expect(find.text('已完成'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '关闭并隐藏'), findsOneWidget);
    // A finished item schedules its own auto-clear timer — dispose here
    // (rather than via addTearDown, which runs after Flutter's own pending-
    // timer check) so it doesn't outlive the test.
    composer.dispose();
  });
}
