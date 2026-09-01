import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/composer_tokens.dart';

void main() {
  test('session references are atomic tokens', () {
    final tokens = parseComposerTokens('ask @session:work/abc now');
    expect(
      tokens.where((token) => token.kind == ComposerTokenKind.session),
      hasLength(1),
    );
    expect(
      tokens
          .singleWhere((token) => token.kind == ComposerTokenKind.session)
          .value,
      '@session:work/abc',
    );
  });
  test('composer parses slash, path and URL as structured atomic tokens', () {
    const source = '/review @file:`lib/chat screen.dart` https://example.com/a';
    final tokens = parseComposerTokens(source);
    expect(tokens.where((token) => token.atomic).map((token) => token.kind), [
      ComposerTokenKind.slash,
      ComposerTokenKind.file,
      ComposerTokenKind.url,
    ]);
    expect(serializeComposerTokens(tokens), source);
  });

  test('tokenAtOffset resolves the whole atomic reference', () {
    final tokens = parseComposerTokens('看 @folder:lib/widgets/ 目录');
    final token = tokenAtOffset(tokens, 8);
    expect(token?.kind, ComposerTokenKind.folder);
    expect(token?.value, '@folder:lib/widgets/');
  });
}
