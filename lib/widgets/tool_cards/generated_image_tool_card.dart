import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import '../../core/clipboard.dart';
import '../../core/http_status_exception.dart';
import '../../l10n/l10n.dart';
import '../h/hermes_states.dart';
import '../h/hermes_toast.dart';
import '../web_preview.dart';
import '../h/hermes_glass.dart';

/// Rich card for `image_generate` / `generate_image` tool calls.
/// Extracted verbatim from `lib/widgets/message_bubble.dart` (formerly the
/// private `_GeneratedImageToolCard` / `_DiffusionShimmer`); behavior
/// unchanged.
class GeneratedImageToolCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const GeneratedImageToolCard({super.key, required this.data});

  String? get _imageUrl {
    // Historical/persisted tool calls only ever carry `result_text` (see
    // ChatStore._historyToolData) — `result` alone only covers the
    // still-live streaming path, so a past session's generated images never
    // resolved a URL at all without this fallback.
    dynamic result = data['result'] ?? data['result_text'];
    if (result is String) {
      try {
        result = jsonDecode(result);
      } catch (_) {
        if (result.startsWith('http') || result.startsWith('data:image/')) {
          return result;
        }
      }
    }
    if (result is Map) {
      // `image` is what image_generate actually returns server-side; the
      // other keys are kept for other providers/shapes.
      return (result['image'] ??
              result['image_url'] ??
              result['url'] ??
              result['data_url'])
          ?.toString();
    }
    return null;
  }

  /// E1: size the frame from `aspect_ratio` BEFORE the image loads so the
  /// placeholder and resolved image occupy the same box (no layout shift).
  double get _aspectRatio {
    final args = data['args'];
    final raw =
        (args is Map ? args['aspect_ratio'] ?? args['size'] : null)
            ?.toString()
            .toLowerCase()
            .trim() ??
        '';
    return switch (raw) {
      'square' || '1:1' => 1,
      'portrait' || '9:16' || '2:3' || '3:4' => 3 / 4,
      _ => 16 / 9,
    };
  }

  // Every rebuild of this StatelessWidget (a streaming turn re-renders the
  // whole timeline on each token) used to re-run `contentAsBytes()` — a full
  // base64 decode — for every `data:` URI generated image still on screen,
  // even ones the user never touched. Cached by the URI string itself (the
  // content IS the url for a data: URI, so string equality is exact),
  // capped so a very long session with many distinct generated images can't
  // grow this unbounded.
  static final Map<String, Uint8List> _dataUriCache = {};
  static const _dataUriCacheLimit = 40;

  ImageProvider _provider(String url) {
    if (url.startsWith('data:')) {
      var bytes = _dataUriCache[url];
      if (bytes == null) {
        bytes = UriData.fromUri(Uri.parse(url)).contentAsBytes();
        if (_dataUriCache.length >= _dataUriCacheLimit) {
          _dataUriCache.remove(_dataUriCache.keys.first);
        }
        _dataUriCache[url] = bytes;
      }
      return MemoryImage(bytes);
    }
    return NetworkImage(url);
  }

  ImageProvider _thumbnailProvider(String url) =>
      ResizeImage.resizeIfNeeded(1600, 1600, _provider(url));

  /// E1 / K1: save the generated image to the device gallery.
  Future<void> _saveToGallery(BuildContext context, String url) async {
    try {
      Uint8List bytes;
      if (url.startsWith('data:')) {
        bytes = UriData.fromUri(Uri.parse(url)).contentAsBytes();
      } else {
        final res = await http.get(Uri.parse(url));
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
        showHermesToast(
          context,
          message: context.l10n.imageSavedToGallery,
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        final detail = error is HttpStatusException
            ? context.l10n.httpStatusError(error.statusCode)
            : '$error';
        showHermesErrorSnackBar(
          context,
          error,
          fallback: context.l10n.messageImageSaveFailed(detail),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl;
    final running = data['running'] == true;
    final failed = data['is_error'] == true || data['error'] != null;
    if (url == null || url.isEmpty) {
      return HermesGlassCard(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        key: ValueKey(
          'image-generation-${data['tool_id'] ?? data['id'] ?? ''}',
        ),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: running
              ? DiffusionShimmer(label: context.l10n.messageGeneratingImage)
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        failed
                            ? Icons.broken_image_outlined
                            : Icons.image_outlined,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        failed
                            ? context.l10n.messageImageGenerationFailed
                            : context.l10n.messageWaitingForImage,
                      ),
                      if (data['summary']?.toString().isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(data['summary'].toString()),
                        ),
                    ],
                  ),
                ),
        ),
      );
    }
    final provider = _provider(url);
    final thumbnailProvider = _thumbnailProvider(url);
    return HermesGlassCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(context.l10n.messageGeneratedImage),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.l10n.imageCopyLink,
                  iconSize: 18,
                  onPressed: () => copyTextOrNotify(
                    context,
                    url,
                    successMessage: context.l10n.messageImageLinkCopied,
                  ),
                  icon: const Icon(Icons.link),
                ),
                IconButton(
                  tooltip: context.l10n.imageSave,
                  iconSize: 18,
                  onPressed: () => _saveToGallery(context, url),
                  icon: const Icon(Icons.save_alt),
                ),
                if (!url.startsWith('data:'))
                  IconButton(
                    tooltip: context.l10n.messageOpenInBrowser,
                    iconSize: 18,
                    onPressed: () => openChatLink(context, url),
                    icon: const Icon(Icons.open_in_new),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.92),
              builder: (_) => Dialog.fullscreen(
                backgroundColor: Colors.transparent,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        minScale: .5,
                        maxScale: 5,
                        child: Center(child: Image(image: provider)),
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
                  ],
                ),
              ),
            ),
            child: AspectRatio(
              aspectRatio: _aspectRatio,
              child: Image(
                image: thumbnailProvider,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(url),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// E1: an animated shimmer stand-in while an image generates (desktop
/// `DiffusionCanvas`).
class DiffusionShimmer extends StatefulWidget {
  final String label;
  const DiffusionShimmer({super.key, required this.label});

  @override
  State<DiffusionShimmer> createState() => _DiffusionShimmerState();
}

class _DiffusionShimmerState extends State<DiffusionShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (MediaQuery.disableAnimationsOf(context)) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(child: Text(widget.label)),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -1),
              end: Alignment(1 + 2 * t, 1),
              colors: [
                scheme.surfaceContainerHigh,
                scheme.surfaceContainerHighest,
                scheme.primary.withValues(alpha: 0.12),
                scheme.surfaceContainerHighest,
                scheme.surfaceContainerHigh,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: scheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
