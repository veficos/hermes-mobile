library;

import 'dart:convert';

import 'chat_message.dart';
import '../l10n/runtime_l10n.dart';

Map<String, dynamic> _jsonObject(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is! String || value.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  } catch (_) {
    return const {};
  }
}

class TerminalRunModel {
  final String command;
  final String output;
  final int? exitCode;
  final int? durationMs;
  final bool running;
  final bool failed;

  const TerminalRunModel({
    required this.command,
    required this.output,
    this.exitCode,
    this.durationMs,
    required this.running,
    required this.failed,
  });

  factory TerminalRunModel.from(Map<String, dynamic> data) {
    final result = data['result'];
    final map = result is Map ? result : const {};
    final args = _jsonObject(data['args'] ?? data['args_text']);
    return TerminalRunModel(
      command: (data['command'] ?? args['command'] ?? '').toString(),
      output:
          (data['result_text'] ??
                  map['output'] ??
                  map['stdout'] ??
                  result ??
                  '')
              .toString(),
      exitCode: (data['exit_code'] ?? map['exit_code']) is num
          ? (data['exit_code'] ?? map['exit_code'] as num).toInt()
          : null,
      durationMs: (data['duration_ms'] ?? map['duration_ms']) is num
          ? (data['duration_ms'] ?? map['duration_ms'] as num).toInt()
          : null,
      running: data['running'] == true,
      failed:
          data['is_error'] == true ||
          data['error'] != null ||
          ((data['exit_code'] ?? map['exit_code']) is num &&
              (data['exit_code'] ?? map['exit_code']) != 0),
    );
  }
}

class ChangedFileModel {
  final String path;
  final String status;
  final int additions;
  final int deletions;
  const ChangedFileModel({
    required this.path,
    required this.status,
    required this.additions,
    required this.deletions,
  });
}

List<ChangedFileModel> parseChangedFiles(Map<String, dynamic> data) {
  final result = data['result'];
  final raw = data['files'] ?? (result is Map ? result['files'] : null);
  if (raw is! List) return const [];
  return raw
      .map((item) {
        if (item is! Map) {
          return ChangedFileModel(
            path: item.toString(),
            status: 'modified',
            additions: 0,
            deletions: 0,
          );
        }
        return ChangedFileModel(
          path: (item['path'] ?? item['name'] ?? '').toString(),
          status: (item['status'] ?? item['change'] ?? 'modified').toString(),
          additions: (item['additions'] as num?)?.toInt() ?? 0,
          deletions: (item['deletions'] as num?)?.toInt() ?? 0,
        );
      })
      .where((item) => item.path.isNotEmpty)
      .toList(growable: false);
}

/// Desktop-compatible changed-files derivation: only settled, successful file
/// edit tools whose result contains a concrete inline diff count as landed.
/// Derive changed files across adjacent assistant/interim message segments.
/// A single gateway turn can be split by message.start/message.complete, so
/// callers should pass the assistant segment window rather than only its last
/// message.
List<ChangedFileModel> deriveTurnChangedFilesAcrossMessages(
  Iterable<ChatMessage> messages,
) {
  return deriveTurnChangedFiles(messages.expand((message) => message.parts));
}

List<ChangedFileModel> deriveTurnChangedFiles(Iterable<ChatPart> parts) {
  final byPath = <String, ChangedFileModel>{};

  void merge(ChangedFileModel file) {
    final path = file.path.trim();
    if (path.isEmpty) return;
    final previous = byPath[path];
    byPath[path] = ChangedFileModel(
      path: path,
      status: file.status,
      additions: (previous?.additions ?? 0) + file.additions,
      deletions: (previous?.deletions ?? 0) + file.deletions,
    );
  }

  for (final part in parts) {
    if (part.kind != 'tool' || part.tool == null) continue;
    final tool = part.tool!;
    final name = (tool['name'] ?? tool['tool_name'] ?? '').toString();
    const editTools = {'write_file', 'edit_file', 'patch', 'apply_patch'};
    if (!editTools.contains(name) ||
        tool['running'] == true ||
        tool['is_error'] == true ||
        tool['error'] != null) {
      continue;
    }

    final args = _jsonObject(tool['args'] ?? tool['args_text']);
    final result = _jsonObject(tool['result'] ?? tool['result_text']);
    final diff = (result['inline_diff'] ?? result['diff'])?.toString() ?? '';
    if (diff.trim().isEmpty) continue;
    final path =
        (tool['path'] ??
                tool['file_path'] ??
                args['path'] ??
                args['file_path'] ??
                args['file'] ??
                args['filepath'] ??
                result['path'] ??
                result['file'] ??
                result['filepath'] ??
                result['resolved_path'])
            ?.toString();
    if (path == null || path.trim().isEmpty) continue;
    var additions = 0;
    var deletions = 0;
    for (final line in diff.split('\n')) {
      if (line.startsWith('+') && !line.startsWith('+++')) additions++;
      if (line.startsWith('-') && !line.startsWith('---')) deletions++;
    }
    merge(
      ChangedFileModel(
        path: path,
        status: 'modified',
        additions: additions,
        deletions: deletions,
      ),
    );
  }
  return byPath.values.toList(growable: false);
}

class WebResultModel {
  final String title;
  final String url;
  final String snippet;
  const WebResultModel({
    required this.title,
    required this.url,
    required this.snippet,
  });
}

List<WebResultModel> parseWebResults(Map<String, dynamic> data) {
  final result = data['result'] ?? data['result_text'];
  final decoded = _jsonObject(result);
  final raw =
      data['results'] ??
      (decoded.isNotEmpty
          ? decoded['results']
          : (result is Map ? result['results'] : result));
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) => WebResultModel(
          title:
              (item['title'] ??
                      item['name'] ??
                      item['url'] ??
                      runtimeL10n.toolUntitledResult)
                  .toString(),
          url: (item['url'] ?? item['href'] ?? '').toString(),
          snippet:
              (item['snippet'] ?? item['text'] ?? item['description'] ?? '')
                  .toString(),
        ),
      )
      .toList(growable: false);
}

class DelegateRunModel {
  final String id;
  final String task;
  final String status;
  final String? model;
  final int? durationMs;
  const DelegateRunModel({
    required this.id,
    required this.task,
    required this.status,
    this.model,
    this.durationMs,
  });

  factory DelegateRunModel.from(Map<String, dynamic> data) => DelegateRunModel(
    id:
        (data['subagent_id'] ??
                data['child_session_id'] ??
                data['tool_id'] ??
                '')
            .toString(),
    task:
        (data['task'] ??
                (data['args'] is Map ? (data['args'] as Map)['task'] : null) ??
                data['summary'] ??
                runtimeL10n.toolDelegateTask)
            .toString(),
    status:
        (data['status'] ?? (data['running'] == true ? 'running' : 'completed'))
            .toString(),
    model: data['model']?.toString(),
    durationMs: (data['duration_ms'] as num?)?.toInt(),
  );

  /// Desktop parity: `delegateRowsFromCall` — a `delegate_task` call fans
  /// out to N children when its args carry a `tasks` array; each gets its
  /// own row instead of the call folding into one generic card. Falls back
  /// to the single-task shape [DelegateRunModel.from] already handles when
  /// there is no `tasks` array, so existing single-delegate rendering is
  /// unaffected.
  static List<DelegateRunModel> listFrom(Map<String, dynamic> data) {
    final args = data['args'];
    final rawTasks = args is Map ? args['tasks'] : null;
    if (rawTasks is! List || rawTasks.isEmpty) {
      return [DelegateRunModel.from(data)];
    }
    final toolId = (data['tool_id'] ?? data['id'] ?? '').toString();
    final rawResults = data['result'] is Map
        ? (data['result'] as Map)['results']
        : (data['results']);
    final results = rawResults is List ? rawResults : const [];
    final running = data['running'] == true;
    return [
      for (var i = 0; i < rawTasks.length; i++)
        _rowFromTask(
          rawTasks[i],
          i,
          toolId: toolId,
          result: i < results.length ? results[i] : null,
          stillRunning: running,
        ),
    ];
  }

  static DelegateRunModel _rowFromTask(
    dynamic rawTask,
    int index, {
    required String toolId,
    dynamic result,
    required bool stillRunning,
  }) {
    final task = rawTask is Map ? rawTask.cast<String, dynamic>() : const {};
    final entry = result is Map ? result.cast<String, dynamic>() : const {};
    final goal =
        (task['goal'] ?? task['task'] ?? runtimeL10n.toolTask(index + 1))
            .toString();
    final hasResult = entry.isNotEmpty;
    final entryStatus = (entry['status'] ?? '').toString();
    final status = hasResult
        ? (entryStatus.isEmpty ||
                  entryStatus == 'ok' ||
                  entryStatus == 'completed'
              ? 'completed'
              : 'failed')
        : (stillRunning ? 'running' : 'dispatched');
    return DelegateRunModel(
      id: '$toolId:$index',
      task: goal,
      status: status,
      model: entry['model']?.toString(),
      durationMs: entry['duration_seconds'] is num
          ? ((entry['duration_seconds'] as num) * 1000).round()
          : (entry['duration_ms'] as num?)?.toInt(),
    );
  }
}
