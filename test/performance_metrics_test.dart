import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/performance_metrics.dart';

void main() {
  test(
    'frame diagnostics respect pipeline stages and display refresh rate',
    () {
      final metrics = ClientPerformanceMetrics.instance;
      final before = metrics.slowFrames;
      metrics.recordFrame(
        buildMicros: 10000,
        rasterMicros: 10000,
        refreshRate: 60,
      );
      expect(metrics.slowFrames, before);
      metrics.recordFrame(
        buildMicros: 9000,
        rasterMicros: 1000,
        refreshRate: 120,
      );
      expect(metrics.slowFrames, before + 1);
      metrics.recordFrame(
        buildMicros: 1000,
        rasterMicros: 9000,
        refreshRate: 120,
      );
      expect(metrics.slowFrames, before + 2);
      metrics.recordFrame(
        buildMicros: 10000,
        rasterMicros: 10000,
        refreshRate: double.nan,
      );
      expect(metrics.slowFrames, before + 2);
      expect(metrics.frameBudgetMicros, closeTo(16666.67, .01));
    },
  );

  test('frame percentiles retain only the most recent bounded samples', () {
    final samples = FrameDurationWindow(capacity: 100);
    expect(samples.percentile(.95), 0);
    for (var i = 1; i <= 200; i++) {
      samples.add(i);
    }
    expect(samples.length, 100);
    expect(samples.percentile(.95), 195);
    expect(samples.percentile(.99), 199);
    expect(samples.percentile(1), 200);
  });

  test('client performance snapshot exposes bounded diagnostic groups', () {
    final metrics = ClientPerformanceMetrics.instance;
    final before = metrics.rpcCompleted;
    metrics.rpcStarted++;
    metrics.recordRpc(const Duration(milliseconds: 25));
    metrics.gatewayFrames++;
    metrics.recordJsonDecode(70 * 1024, const Duration(milliseconds: 4));

    final snapshot = metrics.snapshot();
    expect(
      snapshot.keys,
      containsAll([
        'uptime_seconds',
        'gateway',
        'json',
        'rpc',
        'refresh',
        'render',
      ]),
    );
    expect((snapshot['rpc'] as Map)['completed'], before + 1);
    expect((snapshot['rpc'] as Map), containsPair('failed', isA<int>()));
    expect((snapshot['gateway'] as Map)['frames'], greaterThan(0));
    expect((snapshot['gateway'] as Map), contains('received_bytes'));
    expect((snapshot['gateway'] as Map), contains('sent_bytes'));
    expect((snapshot['json'] as Map)['large_decodes'], greaterThan(0));
    expect(
      (snapshot['render'] as Map).keys,
      containsAll([
        'frames',
        'slow_frames',
        'max_build_ms',
        'max_raster_ms',
        'transcript_structure_reads',
        'markdown_scanned_chars',
        'max_timeline_build_ms',
      ]),
    );
    expect(
      (snapshot['refresh'] as Map).keys,
      containsAll([
        'session_list_completed',
        'session_list_failed',
        'session_list_suppressed',
        'http_response_bytes',
      ]),
    );
    expect(
      metrics.benchmarkCounters().keys,
      containsAll([
        'frames',
        'slow_frames',
        'gateway_received_bytes',
        'http_response_bytes',
        'transcript_copied_rows',
        'stream_materializations',
        'markdown_scanned_chars',
      ]),
    );
  });
}
