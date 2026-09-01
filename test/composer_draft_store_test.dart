import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/composer_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'drafts are isolated by connection and support partial updates',
    () async {
      final first = ComposerDraftStore('https://one.example');
      final second = ComposerDraftStore('https://two.example');

      await first.save(
        'session-1',
        text: 'hello',
        files: [
          {'name': 'a.txt'},
        ],
      );
      await first.save('session-1', text: 'updated');

      expect(await first.load('session-1'), {
        'text': 'updated',
        'files': [
          {'name': 'a.txt'},
        ],
      });
      expect(await second.load('session-1'), {
        'text': '',
        'files': <dynamic>[],
      });
    },
  );

  test('empty draft is evicted and direct ApiClient never uses REST', () async {
    final store = ComposerDraftStore('https://agent.example');
    await store.save('session-1', text: 'temporary');
    await store.save('session-1', text: '', files: const []);
    expect(await store.load('session-1'), {'text': '', 'files': <dynamic>[]});

    final client = ApiClient(
      baseUrl: 'https://agent.example',
      apiKey: 'secret',
      directGateway: true,
    );
    addTearDown(client.close);
    final saved = await client.saveDraft(
      'session-2',
      text: 'local direct draft',
      files: const [],
    );
    final loaded = await client.getDraft('session-2');
    expect(saved.text, 'local direct draft');
    expect(loaded.text, 'local direct draft');
  });

  test('draft text and attachment counts are bounded', () async {
    final store = ComposerDraftStore('scope');
    final saved = await store.save(
      'session',
      text: 'x' * 60000,
      files: List.generate(60, (index) => index),
    );
    expect((saved['text'] as String).length, 50000);
    expect(saved['files'], hasLength(50));
  });
}
