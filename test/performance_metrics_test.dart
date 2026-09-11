import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/performance_metrics.dart';

void main() {
  test(
    'frame interval reset preserves lifetime counters and clears samples',
    () {
      final metrics = ClientPerformanceMetrics.instance;
      metrics.recordFrame(
        buildMicros: 30000,
        rasterMicros: 1000,
        refreshRate: 60,
      );
      final frames = metrics.frames;
      final slow = metrics.slowFrames;
      metrics.resetFrameWindow();
      expect(metrics.frames, frames);
      expect(metrics.slowFrames, slow);
      expect(metrics.buildDurations.length, 0);
      expect(metrics.rasterDurations.percentile(.5), 0);
      final emptyRender = metrics.snapshot()['render'] as Map;
      expect(emptyRender['frame_samples_available'], false);
      expect(
        emptyRender['frame_sample_status'],
        'unavailable_no_engine_samples',
      );
      expect(emptyRender['interval_slow_frame_ratio'], isNull);
      metrics.recordFrame(
        buildMicros: 2000,
        rasterMicros: 3000,
        refreshRate: 60,
      );
      final render = metrics.snapshot()['render'] as Map;
      expect(render['interval_frames'], 1);
      expect(render['interval_slow_frames'], 0);
      expect(render['build_p50_ms'], 2);
      expect(render['frame_samples_available'], true);
      expect(render['frame_sample_status'], 'available');
      expect(render['interval_slow_frame_ratio'], 0);
    },
  );
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
    expect(samples.percentile(.5), 150);
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

  test(
    'frame export distinguishes rolling median from lifetime slow ratio',
    () {
      final metrics = ClientPerformanceMetrics.instance;
      for (var i = 1; i <= 600; i++) {
        metrics.recordFrame(
          buildMicros: i * 100,
          rasterMicros: i * 50,
          refreshRate: 60,
        );
      }
      final counters = metrics.benchmarkCounters();
      final render = metrics.snapshot()['render'] as Map;
      expect(counters['frame_sample_count'], 600);
      expect(counters['build_p50_micros'], 30000);
      expect(counters['raster_p50_micros'], 15000);
      expect(render['build_p50_ms'], 30);
      expect(render['raster_p50_ms'], 15);
      expect(
        render['slow_frame_ratio_lifetime'],
        metrics.slowFrames / metrics.frames,
      );
      expect(
        counters['slow_frame_ratio_lifetime'],
        render['slow_frame_ratio_lifetime'],
      );
    },
  );
}
