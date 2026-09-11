import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/streaming_remend.dart';
import 'package:hermes_mobile/chat/content/diff_view.dart';
import 'package:hermes_mobile/chat/timeline/chat_timeline.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/performance_metrics.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/performance_evidence.dart';

/// Profile-mode micro/macro guard for the transcript hot paths. Run on a
/// physical device with:
/// `flutter drive --profile --driver=test_driver/integration_test.dart \
///   --target=integration_test/chat_session_performance_test.dart`
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final results = <String, dynamic>{};

  tearDownAll(() {
    final metrics = ClientPerformanceMetrics.instance;
    results['runtime'] = metrics.benchmarkCounters();
    results['allocation_proxies'] = {
      'transcript_copied_rows': metrics.transcriptCopiedRows,
      'transcript_composed_copies': metrics.transcriptComposedCopies,
      'stream_materializations': metrics.streamMaterializations,
      'markdown_scanned_chars': metrics.markdownScannedChars,
    };
    results['network_bytes'] = {
      'gateway_received': metrics.gatewayReceivedBytes,
      'gateway_sent': metrics.gatewaySentBytes,
      'http_received': metrics.httpResponseBytes,
      'session_list_received': metrics.sessionResponseBytes,
    };
    results.addAll(performanceEvidence(metrics));
    binding.reportData = results;
  });

  testWidgets('10k transcript structure reads stay zero-copy', (_) async {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    chat.loadHistory(
      List<ChatMessage>.generate(
        10000,
        (index) => ChatMessage(
          id: 'message-$index',
          role: index.isEven ? 'user' : 'assistant',
          parts: [ChatPart.text('message body $index')],
        ),
      ),
      hasMore: false,
    );
    final first = chat.transcriptStructure;
    final watch = Stopwatch()..start();
    for (var index = 0; index < 2000; index++) {
      expect(chat.transcriptStructure, same(first));
    }
    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(250));
    results['transcript_structure_10000x2000_ms'] =
        watch.elapsedMicroseconds / 1000;
    final metrics = ClientPerformanceMetrics.instance;
    expect(metrics.transcriptComposedCopies, 0);
    expect(metrics.transcriptCopiedRows, 0);
  });

  testWidgets('100KB markdown is scanned incrementally', (_) async {
    final scanner = IncrementalStreamingMarkdownScanner();
    var source = '';
    final watch = Stopwatch()..start();
    for (var index = 0; index < 1000; index++) {
      source += 'paragraph $index ${'x' * 80}\n\n';
      scanner.update(source);
    }
    watch.stop();
    expect(source.length, greaterThan(90000));
    expect(scanner.tail(source).length, lessThan(7000));
    expect(watch.elapsedMilliseconds, lessThan(500));
    results['markdown_100kb_1000ticks_ms'] = watch.elapsedMicroseconds / 1000;
    results['markdown_final_tail_chars'] = scanner.tail(source).length;
  });

  testWidgets('500-message timeline projection remains bounded', (_) async {
    final messages = List<ChatMessage>.generate(
      500,
      (index) => ChatMessage(
        id: 'timeline-$index',
        role: index.isEven ? 'user' : 'assistant',
        parts: [ChatPart.text('body $index')],
      ),
    );
    final watch = Stopwatch()..start();
    final timeline = buildChatTimeline(messages);
    watch.stop();
    expect(timeline, isNotEmpty);
    expect(watch.elapsedMilliseconds, lessThan(250));
    results['timeline_500_messages_ms'] = watch.elapsedMicroseconds / 1000;
    expect(ClientPerformanceMetrics.instance.snapshot(), isNotEmpty);
  });

  testWidgets('idle microbenchmark has no session-list traffic', (_) async {
    final metrics = ClientPerformanceMetrics.instance;
    final bytesBefore = metrics.sessionResponseBytes;
    final refreshesBefore = metrics.listRefreshes;
    // No SessionStore or navigation is mounted in this computation harness.
    // This only checks isolation. The event-burst test in
    // session_profile_history_test.dart exercises actual refresh scheduling.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final refreshesDelta = metrics.listRefreshes - refreshesBefore;
    final bytesDelta = metrics.sessionResponseBytes - bytesBefore;
    expect(refreshesDelta, 0);
    expect(bytesDelta, 0);
    results['idle_profile_session_list_refreshes_250ms'] = refreshesDelta;
    results['idle_profile_session_list_bytes_250ms'] = bytesDelta;
  });

  testWidgets('large diff parsing stays bounded and cacheable', (_) async {
    clearDiffParseCache();
    final source = StringBuffer(
      '--- a/lib/example.dart\n+++ b/lib/example.dart\n',
    );
    for (var i = 0; i < 12000; i++) {
      source.writeln(
        i.isEven ? '+final value$i = $i;' : ' final value$i = $i;',
      );
    }
    final diff = source.toString();
    final watch = Stopwatch()..start();
    final stats = diffLineStats(diff);
    final parsedRows = diffParsedLineCount(diff);
    watch.stop();
    expect(stats.added, 6000);
    expect(stats.removed, 0);
    expect(parsedRows, 12000);
    expect(watch.elapsedMilliseconds, lessThan(250));
    // Building a widget is intentionally omitted here: this test is a cheap
    // profile guard for the parser path and runs on CI as well as devices.
    results['diff_12k_lines_stats_ms'] = watch.elapsedMicroseconds / 1000;
    final cachedWatch = Stopwatch()..start();
    expect(diffParsedLineCount(diff), parsedRows);
    cachedWatch.stop();
    results['diff_12k_lines_cached_ms'] =
        cachedWatch.elapsedMicroseconds / 1000;
  });
}
