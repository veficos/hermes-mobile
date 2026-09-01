import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../widgets/web_preview.dart' show openChatLink;

/// Desktop parity (subset): `embeds/` rich media cards. Mobile renders a
/// compact tappable card for a handful of well-known providers (YouTube,
/// Vimeo, Spotify, Google Maps, X/Twitter); everything else keeps the plain
/// link chip. Tapping opens the URL externally.
enum RichLinkKind { youtube, vimeo, spotify, maps, twitter }

class RichLinkInfo {
  final RichLinkKind kind;
  final String url;

  /// YouTube video id when [kind] is youtube — drives the thumbnail.
  final String? youtubeId;
  const RichLinkInfo(this.kind, this.url, {this.youtubeId});
}

RichLinkInfo? detectRichLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');

  if (host == 'youtube.com' || host == 'm.youtube.com') {
    final id = uri.queryParameters['v'];
    if (id != null && id.isNotEmpty) {
      return RichLinkInfo(RichLinkKind.youtube, raw, youtubeId: id);
    }
    final shorts = RegExp(r'/shorts/([\w-]{6,})').firstMatch(uri.path);
    if (shorts != null) {
      return RichLinkInfo(
        RichLinkKind.youtube,
        raw,
        youtubeId: shorts.group(1),
      );
    }
  }
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return RichLinkInfo(
      RichLinkKind.youtube,
      raw,
      youtubeId: uri.pathSegments.first,
    );
  }
  if (host == 'vimeo.com') return RichLinkInfo(RichLinkKind.vimeo, raw);
  if (host == 'open.spotify.com') {
    return RichLinkInfo(RichLinkKind.spotify, raw);
  }
  if (host == 'google.com' && uri.path.startsWith('/maps') ||
      host == 'maps.google.com' ||
      host == 'goo.gl' && uri.path.startsWith('/maps') ||
      host == 'maps.app.goo.gl') {
    return RichLinkInfo(RichLinkKind.maps, raw);
  }
  if (host == 'twitter.com' || host == 'x.com') {
    if (RegExp(r'/status/\d+').hasMatch(uri.path)) {
      return RichLinkInfo(RichLinkKind.twitter, raw);
    }
  }
  return null;
}

class RichLinkEmbed extends StatelessWidget {
  final RichLinkInfo info;
  const RichLinkEmbed({super.key, required this.info});

  ({String label, IconData icon, Color color}) _meta(BuildContext context) {
    switch (info.kind) {
      case RichLinkKind.youtube:
        return (
          label: 'YouTube',
          icon: Icons.smart_display_outlined,
          color: const Color(0xFFFF0000),
        );
      case RichLinkKind.vimeo:
        return (
          label: 'Vimeo',
          icon: Icons.ondemand_video_outlined,
          color: const Color(0xFF1AB7EA),
        );
      case RichLinkKind.spotify:
        return (
          label: 'Spotify',
          icon: Icons.library_music_outlined,
          color: const Color(0xFF1DB954),
        );
      case RichLinkKind.maps:
        return (
          label: context.l10n.richLinkMaps,
          icon: Icons.map_outlined,
          color: const Color(0xFF34A853),
        );
      case RichLinkKind.twitter:
        return (label: 'X', icon: Icons.tag, color: const Color(0xFF1D9BF0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('rich-link-${info.kind.name}'),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => openChatLink(context, info.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info.kind == RichLinkKind.youtube && info.youtubeId != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://img.youtube.com/vi/${info.youtubeId}/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: scheme.surfaceContainerHighest),
                    ),
                    const Center(
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(meta.icon, size: 18, color: meta.color),
                  const SizedBox(width: 8),
                  Text(
                    meta.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      info.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
