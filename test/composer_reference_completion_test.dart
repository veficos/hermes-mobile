import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/composer_reference_completion.dart';
import 'package:hermes_mobile/core/models.dart';

void main() {
  test('typed starter taxonomy matches desktop contract', () {
    expect(
      composerReferenceStarters('').map((item) => item.insertText).toSet(),
      containsAll(<String>{
        '@file:',
        '@folder:',
        '@url:',
        '@image:',
        '@tool:',
        '@git:',
        '@diff',
        '@staged',
      }),
    );
  });

  test('query tracks a typed reference in the middle of a draft', () {
    const source = 'before @folder:lib/w after';
    final caret = source.indexOf(' after');
    final query = composerReferenceQuery(source, caret: caret);
    expect(query?.kind, ComposerReferenceKind.folder);
    expect(query?.query, 'lib/w');
    expect(query?.raw, '@folder:lib/w');
  });

  test('gateway wire text is preserved when converting a path row', () {
    final query = composerReferenceQuery('@file:lib')!;
    final suggestion = referenceSuggestionFromPath(
      PathSuggestion(
        path: 'lib/main.dart',
        name: 'main.dart',
        text: '@file:lib/main.dart',
        display: 'main.dart',
        meta: 'lib/main.dart',
      ),
      query,
    );
    expect(suggestion.insertText, '@file:lib/main.dart');
    expect(suggestion.display, 'main.dart');
  });

  test('folder descent and ascent preserve the typed kind', () {
    final query = composerReferenceQuery('use @folder:lib/w')!;
    const suggestion = ComposerReferenceSuggestion(
      id: 'folder',
      kind: ComposerReferenceKind.folder,
      insertText: '@folder:lib/widgets',
      display: 'widgets',
      isContainer: true,
    );
    final descended = replaceComposerReference(
      'use @folder:lib/w',
      query,
      suggestion,
      descend: true,
    );
    expect(descended, 'use @folder:lib/widgets/');
    expect(
      ascendComposerReference(descended, composerReferenceQuery(descended)!),
      'use @folder:lib/',
    );
  });

  test('selecting a starter opens its scope without slash or space', () {
    final query = composerReferenceQuery('use @fi')!;
    final starter = composerReferenceStarters('fi').single;
    expect(
      replaceComposerReference('use @fi', query, starter, descend: true),
      'use @file:',
    );
  });

  test('emoji completion ranks prefix and replaces only shortcode', () {
    final query = composerEmojiQuery('ok :joy')!;
    final items = composerEmojiSuggestions(query.query);
    expect(items.first.shortcode, 'joy');
    expect(
      'ok :joy'.replaceRange(query.start, query.end, items.first.emoji),
      'ok 😂',
    );
  });
}
