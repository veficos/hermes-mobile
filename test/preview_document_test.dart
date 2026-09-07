import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/preview_document.dart';

void main() {
  test('infers renderable preview kinds', () {
    expect(
      PreviewDocument.infer(path: 'README.md'),
      PreviewDocumentKind.markdown,
    );
    expect(PreviewDocument.infer(path: 'diagram.svg'), PreviewDocumentKind.svg);
    expect(
      PreviewDocument.infer(mimeType: 'application/pdf'),
      PreviewDocumentKind.pdf,
    );
  });

  test('exposes only modes backed by document data', () {
    const document = PreviewDocument(
      id: 'a',
      title: 'README',
      kind: PreviewDocumentKind.markdown,
      source: '# Hi',
      diff: '+Hi',
    );
    expect(document.modes, {
      PreviewDocumentMode.source,
      PreviewDocumentMode.rendered,
      PreviewDocumentMode.diff,
    });
  });
}
