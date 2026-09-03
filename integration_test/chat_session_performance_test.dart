import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/streaming_remend.dart';
import 'package:hermes_mobile/chat/timeline/chat_timeline.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/performance_metrics.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:integration_test/integration_test.dart';

/// Profile-mode micro/macro guard for the transcript hot paths. Run on a
/// physical device with:
/// `flutter drive --profile --driver=test_driver/integration_test.dart \
///   --target=integration_test/chat_session_performance_test.dart`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('large transcript structure reads stay zero-copy', (_) async {
    final chat = ChatStore();
    addTearDown(chat.dispose);
    chat.loadHistory(
      List<ChatMessage>.generate(
        1000,
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
    for (var index = 0; index < 10000; index++) {
      expect(chat.transcriptStructure, same(first));
    }
    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(250));
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
    expect(ClientPerformanceMetrics.instance.snapshot(), isNotEmpty);
  });
}
