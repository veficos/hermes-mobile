import 'package:flutter/scheduler.dart';

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
  Duration totalRpcLatency = Duration.zero;
  Duration totalListRefreshLatency = Duration.zero;

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
    for (final timing in timings) {
      final build = timing.buildDuration.inMicroseconds;
      final raster = timing.rasterDuration.inMicroseconds;
      metrics.frames++;
      if (build + raster > 16667) metrics.slowFrames++;
      if (build > metrics.maxBuildMicros) metrics.maxBuildMicros = build;
      if (raster > metrics.maxRasterMicros) metrics.maxRasterMicros = raster;
    }
  }
}
