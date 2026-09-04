import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/kanban/api.dart';

class _RecordingClient extends ApiClient {
  _RecordingClient() : super(baseUrl: 'http://kanban-api.invalid', apiKey: 'k');

  final calls = <(String path, Duration? timeout)>[];

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Duration? timeout,
    Map<String, String>? query,
    bool allowExplicitFailure = false,
  }) async {
    calls.add((path, timeout));
    return <String, dynamic>{};
  }
}

void main() {
  // estimate() and decompose() ask the agent's model to actually reason
  // about the task rather than just mutate state — they need the same
  // longer timeout as other single-shot model calls (audioSpeak /
  // audioTranscribe), not the API's default 30s HTTP timeout, or a normal
  // response takes long enough to surface as a client-side timeout error.
  test('estimate uses the model-call timeout, not the default 30s', () async {
    final client = _RecordingClient();
    final api = KanbanApi(client);
    await api.estimate('task-1');
    expect(client.calls, hasLength(1));
    expect(client.calls.single.$1, contains('/task-1/estimate'));
    expect(client.calls.single.$2, const Duration(minutes: 2));
  });

  test('decompose uses the model-call timeout, not the default 30s', () async {
    final client = _RecordingClient();
    final api = KanbanApi(client);
    await api.decompose('task-1');
    expect(client.calls, hasLength(1));
    expect(client.calls.single.$1, contains('/task-1/decompose'));
    expect(client.calls.single.$2, const Duration(minutes: 2));
  });
}
