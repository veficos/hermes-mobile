import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/performance_metrics.dart';

void main() {
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
  });
}
