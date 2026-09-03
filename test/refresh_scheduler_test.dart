import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/refresh_scheduler.dart';

void main() {
  test('coalesces bursts into active plus one trailing refresh', () async {
    var coalesced = 0;
    final scheduler = RefreshScheduler(onCoalesced: (_) => coalesced++);
    final gate = Completer<void>();
    var calls = 0;
    Future<void> action() async {
      calls++;
      if (calls == 1) await gate.future;
    }

    final first = scheduler.run('sessions', action);
    scheduler.run('sessions', action);
    scheduler.run('sessions', action);
    expect(calls, 1);
    gate.complete();
    await first;
    expect(calls, 2);
    expect(coalesced, 2);
    expect(scheduler.isRunning('sessions'), isFalse);
  });
}
