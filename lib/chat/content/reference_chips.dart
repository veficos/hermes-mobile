import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../core/stores/connection_store.dart';
import '../../widgets/web_preview.dart' show openChatLink;
import 'rich_link_embed.dart';
import 'zoomable_markdown_image.dart';

/// Inline `@image:` / `@url:` / `@file:` / `@folder:` references the composer
/// weaves into an outgoing message. Desktop renders these as reference chips /
/// thumbnails (`DirectiveContent`); mobile used to leave the raw
/// `@image:/abs/path` text in the bubble.
enum ReferenceKind { image, url, file, folder }

class MessageReference {
  final ReferenceKind kind;
  final String value;
  const MessageReference(this.kind, this.value);
}

final _refPattern = RegExp(
  r'''(?:^|\s)@(image|url|file|folder):(`[^`]+`|'[^']+'|"[^"]+"|[^\s]+)''',
  multiLine: true,
);

String _unquote(String v) =>
    v.replaceAll(RegExp(r'''^[`'"]|[`'"]$'''), '').trim();

List<MessageReference> extractMessageReferences(String text) {
  final out = <MessageReference>[];
  final seen = <String>{};
  for (final match in _refPattern.allMatches(text)) {
    final kind = switch (match.group(1)) {
      'image' => ReferenceKind.image,
      'url' => ReferenceKind.url,
      'file' => ReferenceKind.file,
      _ => ReferenceKind.folder,
    };
    final value = _unquote(match.group(2)!);
    if (value.isEmpty || !seen.add('${kind.name}:$value')) continue;
    out.add(MessageReference(kind, value));
  }
  return out;
}

/// [text] with the `@kind:value` tokens removed, so the bubble body shows the
/// user's prose and the chips carry the references.
String stripMessageReferences(String text) {
  return text
      .replaceAll(_refPattern, ' ')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class MessageReferenceChips extends StatelessWidget {
  final List<MessageReference> references;
  const MessageReferenceChips({super.key, required this.references});

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final ref in references) _RefChip(reference: ref)],
      ),
    );
  }
}

class _RefChip extends StatelessWidget {
  final MessageReference reference;
  const _RefChip({required this.reference});

  bool get _isNetwork =>
      reference.value.startsWith('http://') ||
      reference.value.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (reference.kind == ReferenceKind.image) {
      return _ImageThumb(path: reference.value, isNetwork: _isNetwork);
    }
    if (reference.kind == ReferenceKind.url) {
      final rich = detectRichLink(reference.value);
      if (rich != null) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: RichLinkEmbed(info: rich),
        );
      }
    }
    final (IconData icon, String label) = switch (reference.kind) {
      ReferenceKind.url => (Icons.link, _shortUrl(reference.value)),
      ReferenceKind.folder => (
        Icons.folder_outlined,
        _basename(reference.value),
      ),
      _ => (Icons.insert_drive_file_outlined, _basename(reference.value)),
    };
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
      tooltip: reference.value,
      onPressed: reference.kind == ReferenceKind.url
          ? () => openChatLink(context, reference.value)
          : null,
    );
  }

  static String _basename(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  static String _shortUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return '${uri.host}${uri.path.length > 1 ? uri.path : ''}';
  }
}

class _ImageThumb extends StatefulWidget {
  final String path;
  final bool isNetwork;
  const _ImageThumb({required this.path, required this.isNetwork});

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  Future<String>? _future;
  String? _futurePath;

  String get _name => widget.path.split(RegExp(r'[\\/]')).last;

  Widget _framed(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(width: 140, height: 100, child: child),
  );

  Widget _fallback() => Chip(
    avatar: const Icon(Icons.image_outlined, size: 16),
    label: Text(_name, overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.isNetwork) {
      return _framed(
        Image.network(
          widget.path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    ConnectionStore? connection;
    try {
      connection = context.read<ConnectionStore>();
    } catch (_) {
      connection = null;
    }
    final api = connection?.api;
    if (api == null) return _fallback();
    if (_futurePath != widget.path) {
      _futurePath = widget.path;
      _future = api.fsReadDataUrl(widget.path);
    }
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _framed(
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final dataUrl = snap.data;
        if (dataUrl == null || dataUrl.isEmpty || snap.hasError) {
          return _fallback();
        }
        return _framed(
          hermesMarkdownImageBuilder(
            MarkdownImageConfig(uri: Uri.parse(dataUrl), alt: _name),
          ),
        );
      },
    );
  }
}
