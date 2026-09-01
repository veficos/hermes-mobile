import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import '../../core/clipboard.dart';
import '../../core/http_status_exception.dart';
import '../../l10n/l10n.dart';

/// Desktop parity: `chat/zoomable-image.tsx`. Any image inside a rendered
/// message becomes tap-to-open in a fullscreen pan/zoom viewer.
///
/// Pass as `MarkdownBody(sizedImageBuilder: hermesMarkdownImageBuilder)`.
Widget hermesMarkdownImageBuilder(MarkdownImageConfig config) {
  return _ZoomableInlineImage(
    uri: config.uri,
    semanticLabel: config.alt ?? config.title,
  );
}

class _ZoomableInlineImage extends StatelessWidget {
  final Uri uri;
  final String? semanticLabel;

  const _ZoomableInlineImage({required this.uri, this.semanticLabel});

  ImageProvider? _provider() {
    if (uri.scheme == 'data') {
      // LLM-authored markdown can carry a malformed/truncated data URI
      // (missing comma, invalid base64 padding) — `UriData.fromUri` and
      // `contentAsBytes` throw FormatException on those, which would
      // otherwise crash this build() instead of falling back to text.
      try {
        final data = UriData.fromUri(uri);
        if (data.isBase64) return MemoryImage(data.contentAsBytes());
        return MemoryImage(Uint8List.fromList(utf8.encode(data.contentText)));
      } catch (_) {
        return null;
      }
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return NetworkImage(uri.toString());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider();
    if (provider == null) {
      // Unsupported scheme (file://, resource:, …) — show the reference text.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SelectableText(
          semanticLabel?.isNotEmpty == true
              ? '$semanticLabel（$uri）'
              : uri.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () => _openViewer(context, provider),
        onLongPress: () => _showActions(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Image(
              image: provider,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
              errorBuilder: (_, _, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(uri.toString()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, ImageProvider provider) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) =>
          _ImageZoomDialog(provider: provider, label: semanticLabel),
    );
  }

  /// Long-press action sheet — desktop's right-click "Save image
  /// as…"/"Copy image link" on any rendered `<img>`, adapted to a bottom
  /// sheet since mobile has no context menu.
  void _showActions(BuildContext context) {
    final isNetwork = uri.scheme == 'http' || uri.scheme == 'https';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(context.l10n.imageSave),
              onTap: () {
                Navigator.pop(sheetContext);
                _saveToGallery(context);
              },
            ),
            if (isNetwork)
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(context.l10n.imageCopyLink),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await copyTextOrNotify(
                    context,
                    uri.toString(),
                    successMessage: context.l10n.commonCopied,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final savedMessage = context.l10n.imageSavedToGallery;
    try {
      Uint8List bytes;
      if (uri.scheme == 'data') {
        bytes = UriData.fromUri(uri).contentAsBytes();
      } else {
        final res = await http.get(uri);
        if (res.statusCode != 200) {
          throw HttpStatusException(res.statusCode);
        }
        bytes = res.bodyBytes;
      }
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(
        bytes,
        name: 'hermes-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(savedMessage)));
      }
    } catch (error) {
      if (context.mounted) {
        final detail = error is HttpStatusException
            ? context.l10n.httpStatusError(error.statusCode)
            : '$error';
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.imageSaveFailed(detail))),
        );
      }
    }
  }
}

class _ImageZoomDialog extends StatelessWidget {
  final ImageProvider provider;
  final String? label;

  const _ImageZoomDialog({required this.provider, this.label});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6,
              child: Center(
                child: Image(image: provider, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              tooltip: context.l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          if (label?.trim().isNotEmpty == true)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                label!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
