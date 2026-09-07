library;

enum PreviewDocumentKind { web, text, markdown, image, pdf, html, svg, binary }

enum PreviewDocumentMode { source, rendered, diff }

class PreviewDocument {
  const PreviewDocument({
    required this.id,
    required this.title,
    required this.kind,
    this.path,
    this.url,
    this.mimeType,
    this.byteSize,
    this.repositoryRoot,
    this.revision,
    this.source,
    this.diff,
    this.large = false,
    this.binary = false,
    this.editable = false,
    this.stale = false,
  });

  final String id;
  final String title;
  final PreviewDocumentKind kind;
  final String? path;
  final String? url;
  final String? mimeType;
  final int? byteSize;
  final String? repositoryRoot;
  final String? revision;
  final String? source;
  final String? diff;
  final bool large;
  final bool binary;
  final bool editable;
  final bool stale;

  PreviewDocument copyWith({
    String? source,
    String? url,
    String? diff,
    String? revision,
    int? byteSize,
    String? mimeType,
    bool? stale,
  }) => PreviewDocument(
    id: id,
    title: title,
    kind: kind,
    path: path,
    url: url ?? this.url,
    mimeType: mimeType ?? this.mimeType,
    byteSize: byteSize ?? this.byteSize,
    repositoryRoot: repositoryRoot,
    revision: revision ?? this.revision,
    source: source ?? this.source,
    diff: diff ?? this.diff,
    large: large,
    binary: binary,
    editable: editable,
    stale: stale ?? this.stale,
  );

  Set<PreviewDocumentMode> get modes => {
    if (!binary && source != null) PreviewDocumentMode.source,
    if ({
      PreviewDocumentKind.web,
      PreviewDocumentKind.markdown,
      PreviewDocumentKind.image,
      PreviewDocumentKind.pdf,
      PreviewDocumentKind.html,
      PreviewDocumentKind.svg,
    }.contains(kind))
      PreviewDocumentMode.rendered,
    if (diff?.isNotEmpty == true) PreviewDocumentMode.diff,
  };

  static PreviewDocumentKind infer({String? path, String? mimeType}) {
    final mime = mimeType?.toLowerCase() ?? '';
    final extension = (path ?? '').split('.').last.toLowerCase();
    if (mime.startsWith('image/svg') || extension == 'svg') {
      return PreviewDocumentKind.svg;
    }
    if (mime.startsWith('image/') ||
        const {
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'bmp',
          'avif',
          'heic',
          'heif',
        }.contains(extension)) {
      return PreviewDocumentKind.image;
    }
    if (mime == 'application/pdf' || extension == 'pdf') {
      return PreviewDocumentKind.pdf;
    }
    if (mime.contains('html') || {'html', 'htm'}.contains(extension)) {
      return PreviewDocumentKind.html;
    }
    if (mime.contains('markdown') || {'md', 'mdx'}.contains(extension)) {
      return PreviewDocumentKind.markdown;
    }
    if (mime.startsWith('text/') || mime.isEmpty) {
      return PreviewDocumentKind.text;
    }
    return PreviewDocumentKind.binary;
  }
}
