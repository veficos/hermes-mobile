import 'package:flutter/scheduler.dart';
import 'dart:ui' show PlatformDispatcher;

/// A bounded rolling window; sorting is deferred until diagnostics are read.
class FrameDurationWindow {
  FrameDurationWindow({this.capacity = 600}) : assert(capacity > 0);
  final int capacity;
  final List<int> _samples = [];
  int _next = 0;
  int get length => _samples.length;

  void add(int micros) {
    if (_samples.length < capacity) {
      _samples.add(micros);
    } else {
      _samples[_next] = micros;
    }
    _next = (_next + 1) % capacity;
  }

  int percentile(double fraction) {
    assert(fraction > 0 && fraction <= 1);
    if (_samples.isEmpty) return 0;
    final sorted = List<int>.of(_samples)..sort();
    return sorted[(sorted.length * fraction).ceil() - 1];
  }
}

/// Lightweight in-process client performance counters. Values are cheap to
/// update on hot paths and can be exported to diagnostics without a logging
/// dependency.
class ClientPerformanceMetrics {
  ClientPerformanceMetrics._();
  static final instance = ClientPerformanceMetrics._();

  final DateTime startedAt = DateTime.now();
  int gatewayFrames = 0;
  int gatewayEvents = 0;
  int gatewayResponses = 0;
  int gatewayDecodeErrors = 0;
  int jsonDecodes = 0;
  int largeJsonDecodes = 0;
  int maxJsonBytes = 0;
  int maxJsonDecodeMicros = 0;
  int rpcStarted = 0;
  int rpcCompleted = 0;
  int rpcFailed = 0;
  int rpcTimedOut = 0;
  int listRefreshes = 0;
  int listRefreshesCompleted = 0;
  int listRefreshesFailed = 0;
  int listRefreshesSuppressed = 0;
  int transcriptRefreshes = 0;
  int markdownPrepares = 0;
  int streamingTicks = 0;
  int uiNotifications = 0;
  int maxPendingRpc = 0;
  int maxTranscriptMessages = 0;
  int maxSessionRows = 0;
  int unreadBatchLoads = 0;
  int unreadRowsEvaluated = 0;
  int unreadPersistenceWrites = 0;
  int sessionProjectionBuilds = 0;
  int sessionProjectionRows = 0;
  int historyProjectionBuilds = 0;
  int historyVisibleRows = 0;
  int streamMaterializations = 0;
  int streamingStablePrefixChars = 0;
  int transcriptStructureReads = 0;
  int transcriptComposedCopies = 0;
  int transcriptCopiedRows = 0;
  int markdownScannedChars = 0;
  int markdownTailChars = 0;
  int sessionResponseBytes = 0;
  int httpResponseBytes = 0;
  int gatewayReceivedBytes = 0;
  int gatewaySentBytes = 0;
  int sessionRowsReceived = 0;
  int adaptivePollBackoffs = 0;
  int maxSessionProjectionMicros = 0;
  int maxHistoryProjectionMicros = 0;
  int maxTimelineBuildMicros = 0;
  int frames = 0;
  int slowFrames = 0;
  int maxBuildMicros = 0;
  int maxRasterMicros = 0;
  final buildDurations = FrameDurationWindow();
  final rasterDurations = FrameDurationWindow();
  double frameBudgetMicros = 1000000 / 60;

  /// UI and raster are pipelined: their sum is not a dropped-frame count.
  /// This measures frames with at least one stage exceeding the budget.
  void recordFrame({
    required int buildMicros,
    required int rasterMicros,
    required double refreshRate,
  }) {
    final rate = refreshRate.isFinite && refreshRate > 0 ? refreshRate : 60.0;
    frameBudgetMicros = 1000000 / rate;
    frames++;
    if (buildMicros > frameBudgetMicros || rasterMicros > frameBudgetMicros) {
      slowFrames++;
    }
    if (buildMicros > maxBuildMicros) maxBuildMicros = buildMicros;
    if (rasterMicros > maxRasterMicros) maxRasterMicros = rasterMicros;
    buildDurations.add(buildMicros);
    rasterDurations.add(rasterMicros);
  }

  Duration totalRpcLatency = Duration.zero;
  Duration totalListRefreshLatency = Duration.zero;

  Map<String, num> benchmarkCounters() => {
    'frames': frames,
    'slow_frames': slowFrames,
    'max_build_micros': maxBuildMicros,
    'max_raster_micros': maxRasterMicros,
    'frame_budget_micros': frameBudgetMicros,
    'build_p95_micros': buildDurations.percentile(.95),
    'build_p99_micros': buildDurations.percentile(.99),
    'raster_p95_micros': rasterDurations.percentile(.95),
    'raster_p99_micros': rasterDurations.percentile(.99),
    'gateway_received_bytes': gatewayReceivedBytes,
    'gateway_sent_bytes': gatewaySentBytes,
    'http_response_bytes': httpResponseBytes,
    'session_response_bytes': sessionResponseBytes,
    'transcript_composed_copies': transcriptComposedCopies,
    'transcript_copied_rows': transcriptCopiedRows,
    'stream_materializations': streamMaterializations,
    'markdown_scanned_chars': markdownScannedChars,
    'markdown_tail_chars': markdownTailChars,
  };

  void recordJsonDecode(int bytes, Duration elapsed) {
    jsonDecodes++;
    if (bytes >= 64 * 1024) largeJsonDecodes++;
    if (bytes > maxJsonBytes) maxJsonBytes = bytes;
    if (elapsed.inMicroseconds > maxJsonDecodeMicros) {
      maxJsonDecodeMicros = elapsed.inMicroseconds;
    }
  }

  void recordRpc(Duration elapsed) {
    rpcCompleted++;
    totalRpcLatency += elapsed;
  }

  Map<String, dynamic> snapshot() => {
    'uptime_seconds': DateTime.now().difference(startedAt).inSeconds,
    'gateway': {
      'frames': gatewayFrames,
      'events': gatewayEvents,
      'responses': gatewayResponses,
      'decode_errors': gatewayDecodeErrors,
      'received_bytes': gatewayReceivedBytes,
      'sent_bytes': gatewaySentBytes,
    },
    'json': {
      'decodes': jsonDecodes,
      'large_decodes': largeJsonDecodes,
      'max_bytes': maxJsonBytes,
      'max_decode_ms': maxJsonDecodeMicros / 1000,
    },
    'rpc': {
      'started': rpcStarted,
      'completed': rpcCompleted,
      'failed': rpcFailed,
      'timed_out': rpcTimedOut,
      'max_pending': maxPendingRpc,
      'average_latency_ms': rpcCompleted == 0
          ? 0
          : totalRpcLatency.inMicroseconds ~/ rpcCompleted ~/ 1000,
    },
    'refresh': {
      'session_list': listRefreshes,
      'session_list_completed': listRefreshesCompleted,
      'session_list_failed': listRefreshesFailed,
      'session_list_suppressed': listRefreshesSuppressed,
      'transcript': transcriptRefreshes,
      'average_list_latency_ms': listRefreshesCompleted == 0
          ? 0
          : totalListRefreshLatency.inMicroseconds ~/
                listRefreshesCompleted ~/
                1000,
      'session_response_bytes': sessionResponseBytes,
      'session_rows_received': sessionRowsReceived,
      'adaptive_poll_backoffs': adaptivePollBackoffs,
      'http_response_bytes': httpResponseBytes,
    },
    'render': {
      'markdown_prepares': markdownPrepares,
      'streaming_ticks': streamingTicks,
      'ui_notifications': uiNotifications,
      'max_transcript_messages': maxTranscriptMessages,
      'max_session_rows': maxSessionRows,
      'unread_batch_loads': unreadBatchLoads,
      'unread_rows_evaluated': unreadRowsEvaluated,
      'unread_persistence_writes': unreadPersistenceWrites,
      'session_projection_builds': sessionProjectionBuilds,
      'session_projection_rows': sessionProjectionRows,
      'history_projection_builds': historyProjectionBuilds,
      'history_visible_rows': historyVisibleRows,
      'stream_materializations': streamMaterializations,
      'streaming_stable_prefix_chars': streamingStablePrefixChars,
      'transcript_structure_reads': transcriptStructureReads,
      'transcript_composed_copies': transcriptComposedCopies,
      'transcript_copied_rows': transcriptCopiedRows,
      'markdown_scanned_chars': markdownScannedChars,
      'markdown_tail_chars': markdownTailChars,
      'max_session_projection_ms': maxSessionProjectionMicros / 1000,
      'max_history_projection_ms': maxHistoryProjectionMicros / 1000,
      'max_timeline_build_ms': maxTimelineBuildMicros / 1000,
      'frames': frames,
      'slow_frames': slowFrames,
      'max_build_ms': maxBuildMicros / 1000,
      'max_raster_ms': maxRasterMicros / 1000,
      'frame_budget_ms': frameBudgetMicros / 1000,
      'frame_sample_count': buildDurations.length,
      'build_p95_ms': buildDurations.percentile(.95) / 1000,
      'build_p99_ms': buildDurations.percentile(.99) / 1000,
      'raster_p95_ms': rasterDurations.percentile(.95) / 1000,
      'raster_p99_ms': rasterDurations.percentile(.99) / 1000,
    },
  };
}

class ClientFrameMetricsBinding {
  ClientFrameMetricsBinding._();
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_record);
  }

  static void _record(List<FrameTiming> timings) {
    final metrics = ClientPerformanceMetrics.instance;
    // Timings are engine-wide. Use the strictest active display budget when
    // multiple views exist, rather than assuming every device runs at 60 Hz.
    final views = PlatformDispatcher.instance.views;
    var refreshRate = 0.0;
    for (final view in views) {
      final rate = view.display.refreshRate;
      if (rate.isFinite && rate > refreshRate) refreshRate = rate;
    }
    for (final timing in timings) {
      metrics.recordFrame(
        buildMicros: timing.buildDuration.inMicroseconds,
        rasterMicros: timing.rasterDuration.inMicroseconds,
        refreshRate: refreshRate,
      );
    }
  }
}
