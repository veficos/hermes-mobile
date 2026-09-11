import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/performance_metrics.dart';
import 'support/performance_evidence.dart';

void main() {
  test(
    'benchmark evidence does not claim profile mode or unsampled timings',
    () {
      final metrics = ClientPerformanceMetrics.instance;
      metrics.resetFrameWindow();
      final report = performanceEvidence(metrics);
      expect(report['profile_mode'], kProfileMode);
      expect(report['build_mode'], 'debug');
      expect(report['live_network_exercised'], false);
      final frames = report['frame_budget'] as Map;
      expect(frames['frame_samples_available'], false);
      expect(frames['frame_sample_count'], 0);
      expect(frames['max_build_micros'], isNull);
      expect(frames['build_p95_ms'], isNull);
      expect(frames['raster_p50_ms'], isNull);
    },
  );

  test('sampled timings retain scope and availability metadata', () {
    final metrics = ClientPerformanceMetrics.instance;
    metrics.resetFrameWindow();
    metrics.recordFrame(buildMicros: 2000, rasterMicros: 3000, refreshRate: 60);
    final report = performanceEvidence(metrics);
    expect(report['scope'], 'computation_microbenchmarks_not_rendered_chat');
    final frames = report['frame_budget'] as Map;
    expect(frames['frame_samples_available'], true);
    expect(frames['frame_sample_count'], 1);
    expect(frames['build_p95_ms'], 2);
    expect(frames['raster_p50_ms'], 3);
    metrics.resetFrameWindow();
  });
}
