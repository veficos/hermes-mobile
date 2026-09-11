import 'package:flutter/foundation.dart';
import 'package:hermes_mobile/core/performance_metrics.dart';

/// Evidence metadata; pure-computation benchmarks are not device UI timings.
Map<String, dynamic> performanceEvidence(ClientPerformanceMetrics metrics) {
  final render = metrics.snapshot()['render'] as Map;
  final available = render['frame_samples_available'] == true;
  return {
    'profile_mode': kProfileMode,
    'build_mode': kReleaseMode
        ? 'release'
        : (kProfileMode ? 'profile' : 'debug'),
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'scope': 'computation_microbenchmarks_not_rendered_chat',
    'live_network_exercised': false,
    'frame_budget': {
      'frames': metrics.frames,
      'slow_frames': metrics.slowFrames,
      'frame_samples_available': available,
      'frame_sample_status': render['frame_sample_status'],
      'frame_sample_count': render['frame_sample_count'],
      'max_build_micros': available ? metrics.maxBuildMicros : null,
      'max_raster_micros': available ? metrics.maxRasterMicros : null,
      for (final key in [
        'build_p50_ms',
        'raster_p50_ms',
        'build_p95_ms',
        'raster_p95_ms',
      ])
        key: available ? render[key] : null,
    },
  };
}
