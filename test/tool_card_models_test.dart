import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/tool_card_models.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_ar.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_en.dart';
import 'package:hermes_mobile/l10n/runtime_l10n.dart';

void main() {
  setUp(() => RuntimeL10n.use(AppLocalizationsEn()));
  test('terminal model normalizes exit metadata and failure', () {
    final run = TerminalRunModel.from(const {
      'args': {'command': 'flutter test'},
      'result': {'stdout': 'ok', 'exit_code': 1, 'duration_ms': 240},
    });
    expect(run.command, 'flutter test');
    expect(run.output, 'ok');
    expect(run.exitCode, 1);
    expect(run.durationMs, 240);
    expect(run.failed, isTrue);
  });

  test('changed files retain status and diff counts', () {
    final files = parseChangedFiles(const {
      'files': [
        {
          'path': 'lib/a.dart',
          'status': 'modified',
          'additions': 4,
          'deletions': 2,
        },
      ],
    });
    expect(files.single.path, 'lib/a.dart');
    expect(files.single.additions, 4);
    expect(files.single.deletions, 2);
  });

  test('changed files aggregate across all edit tools in a turn', () {
    final files = deriveTurnChangedFiles([
      ChatPart.toolCall({
        'name': 'apply_patch',
        'args': {'path': 'lib/a.dart'},
        'result': {'inline_diff': '--- a\n+++ b\n-old\n+new\n+more'},
      }),
      ChatPart.toolCall({
        'name': 'write_file',
        'args': {'path': 'lib/b.dart'},
        'result': {'diff': '+created'},
      }),
      ChatPart.toolCall({
        'name': 'edit_file',
        'args': {'path': 'lib/a.dart'},
        'result': {'inline_diff': '-again\n+done'},
      }),
    ]);
    expect(files.map((file) => file.path), ['lib/a.dart', 'lib/b.dart']);
    expect(files.first.additions, 3);
    expect(files.first.deletions, 2);
  });

  test('running failed and diff-less edits are not landed changes', () {
    final files = deriveTurnChangedFiles([
      ChatPart.toolCall({
        'name': 'write_file',
        'running': true,
        'args': {'path': 'running.dart'},
        'result': {'inline_diff': '+x'},
      }),
      ChatPart.toolCall({
        'name': 'edit_file',
        'is_error': true,
        'args': {'path': 'failed.dart'},
        'result': {'inline_diff': '+x'},
      }),
      ChatPart.toolCall({
        'name': 'patch',
        'args': {'path': 'opaque.dart'},
        'result': {'output': 'ok'},
      }),
    ]);
    expect(files, isEmpty);
  });

  test('web results normalize title URL and snippet', () {
    final results = parseWebResults(const {
      'result': {
        'results': [
          {'title': 'Hermes', 'url': 'https://example.com', 'snippet': 'Agent'},
        ],
      },
    });
    expect(results.single.title, 'Hermes');
    expect(results.single.url, 'https://example.com');
  });

  test('fallback model labels follow the active locale', () {
    RuntimeL10n.use(AppLocalizationsAr());
    final result = parseWebResults(const {
      'results': [
        {'url': null},
      ],
    });
    final delegate = DelegateRunModel.from(const {});
    expect(result.single.title, 'نتيجة بلا عنوان');
    expect(delegate.task, 'مهمة مفوضة');
  });
}
