import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/tool_presentation.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_ar.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_en.dart';
import 'package:hermes_mobile/l10n/runtime_l10n.dart';

void main() {
  setUp(() => RuntimeL10n.use(AppLocalizationsEn()));
  test('resolveToolKind recognizes terminal aliases and arg heuristics', () {
    expect(resolveToolKind('bash', {}), ToolPresentationKind.terminal);
    expect(
      resolveToolKind('custom_tool', {'command': 'pwd'}),
      ToolPresentationKind.terminal,
    );
    expect(
      resolveToolKind('web_search', {'search_term': 'flutter'}),
      ToolPresentationKind.webSearch,
    );
  });

  test('resolveToolKind distinguishes the prototype tool icon families', () {
    expect(
      resolveToolKind('execute_code', {}),
      ToolPresentationKind.executeCode,
    );
    expect(resolveToolKind('web_extract', {}), ToolPresentationKind.webExtract);
    expect(resolveToolKind('read_file', {}), ToolPresentationKind.readFile);
    expect(resolveToolKind('write_file', {}), ToolPresentationKind.writeFile);
    expect(resolveToolKind('patch', {}), ToolPresentationKind.patch);
    expect(resolveToolKind('list_files', {}), ToolPresentationKind.listFiles);
    expect(
      resolveToolKind('generate_image', {}),
      ToolPresentationKind.generateImage,
    );
  });

  test('toolParseTerminalStreams splits stdout and stderr JSON', () {
    final streams = toolParseTerminalStreams({
      'stdout': 'hello world',
      'stderr': 'warning',
      'exit_code': 0,
    }, '');
    expect(streams.stdout, 'hello world');
    expect(streams.stderr, 'warning');
    expect(streams.exitCode, 0);
  });

  test('toolExtractSearchHits unwraps nested results arrays', () {
    final hits = toolExtractSearchHits({
      'results': [
        {
          'title': 'Flutter docs',
          'url': 'https://docs.flutter.dev',
          'snippet': 'Build apps',
        },
      ],
    });
    expect(hits, hasLength(1));
    expect(hits.first.title, 'Flutter docs');
    expect(hits.first.url, contains('flutter.dev'));
  });

  group('toolRunSummary', () {
    test('collapses a mixed run into fixed-order clauses', () {
      final summary = toolRunSummary([
        {'name': 'read_file', 'args': {}},
        {'name': 'read_file', 'args': {}},
        {'name': 'list_files', 'args': {}},
        {'name': 'terminal', 'args': {}},
        {'name': 'patch', 'args': {}},
      ], live: false);
      expect(summary, 'Edited 1 file, Explored 3 files, Ran 1 command');
    });

    test('uses present tense while the run is live', () {
      final summary = toolRunSummary([
        {'name': 'terminal', 'args': {}},
        {'name': 'terminal', 'args': {}},
      ], live: true);
      expect(summary, 'Running 2 commands');
    });

    test('counts delegate_task calls under their own category', () {
      final summary = toolRunSummary([
        {'name': 'delegate_task', 'args': {}},
        {'name': 'read_file', 'args': {}},
      ], live: false);
      expect(summary, 'Explored 1 file, Delegated 1 task');
    });

    test('falls back to a generic count for an empty run', () {
      expect(toolRunSummary([], live: false), 'Used 0 tools');
    });

    test('uses Arabic copy and list punctuation', () {
      RuntimeL10n.use(AppLocalizationsAr());
      final summary = toolRunSummary([
        {'name': 'read_file', 'args': {}},
        {'name': 'terminal', 'args': {}},
      ], live: false);
      expect(summary, contains('، '));
      expect(summary, isNot(contains(RegExp(r'[\u4e00-\u9fff]'))));
    });
  });
}
