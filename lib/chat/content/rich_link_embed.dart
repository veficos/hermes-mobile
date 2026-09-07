import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/embed_consent_store.dart';
import '../../core/stores/embed_runtime_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/web_preview.dart'
    show WebPreviewPane, openChatLink, webViewSupported;

/// Desktop parity (subset): `embeds/` rich media cards. Mobile renders a
/// compact tappable card for a handful of well-known providers (YouTube,
/// Vimeo, Spotify, Google Maps, X/Twitter); everything else keeps the plain
/// link chip. Tapping opens the URL externally.
enum RichLinkKind {
  youtube,
  vimeo,
  spotify,
  maps,
  openStreetMap,
  twitter,
  instagram,
  pinterest,
  tiktok,
}

extension RichLinkKindProvider on RichLinkKind {
  String get provider => name;
}

class RichLinkInfo {
  final RichLinkKind kind;
  final String url;

  /// YouTube video id when [kind] is youtube — drives the thumbnail.
  final String? youtubeId;
  final String? embedUrl;
  final double? aspectRatio;
  final double? height;
  final double maxWidth;
  const RichLinkInfo(
    this.kind,
    this.url, {
    this.youtubeId,
    this.embedUrl,
    this.aspectRatio,
    this.height,
    this.maxWidth = 640,
  });
}

int? _youtubeStart(String? value) {
  if (value == null || value.isEmpty) return null;
  final seconds = int.tryParse(value);
  if (seconds != null) return seconds > 0 ? seconds : null;
  final match = RegExp(
    r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$',
  ).firstMatch(value);
  if (match == null || match.group(0)!.isEmpty) return null;
  final total =
      (int.tryParse(match.group(1) ?? '') ?? 0) * 3600 +
      (int.tryParse(match.group(2) ?? '') ?? 0) * 60 +
      (int.tryParse(match.group(3) ?? '') ?? 0);
  return total > 0 ? total : null;
}

String _bareHost(Uri uri) {
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  return host;
}

/// True when [host] is exactly [rootDomain] or a proper subdomain of it
/// (e.g. `maps.google.com` matches `google.com`, but `google.evil.com` and
/// `notgoogle.com` do not). Used instead of `startsWith`/`contains` for
/// brand-domain checks, which are spoofable by attacker-chosen hosts like
/// `google.evil.com` or `notpinterest.phish.net`.
bool _isHostOrSubdomain(String host, String rootDomain) =>
    host == rootDomain || host.endsWith('.$rootDomain');

RichLinkInfo? detectRichLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) return null;
  final host = _bareHost(uri);
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();

  String youtubeId = '';
  if (host == 'youtu.be') {
    youtubeId = segments.firstOrNull ?? '';
  } else if (const {
    'youtube.com',
    'm.youtube.com',
    'youtube-nocookie.com',
  }.contains(host)) {
    if (segments.firstOrNull == 'watch') {
      youtubeId = uri.queryParameters['v'] ?? '';
    } else if (const {
      'embed',
      'shorts',
      'live',
      'v',
    }.contains(segments.firstOrNull)) {
      youtubeId = segments.length > 1 ? segments[1] : '';
    }
  }
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(youtubeId)) {
    final params = <String, String>{'modestbranding': '1', 'rel': '0'};
    final start = _youtubeStart(
      uri.queryParameters['t'] ?? uri.queryParameters['start'],
    );
    if (start != null) params['start'] = '$start';
    return RichLinkInfo(
      RichLinkKind.youtube,
      raw,
      youtubeId: youtubeId,
      embedUrl: Uri.https(
        'www.youtube-nocookie.com',
        '/embed/$youtubeId',
        params,
      ).toString(),
      aspectRatio: 16 / 9,
    );
  }
  if (host == 'vimeo.com' || host == 'player.vimeo.com') {
    final id = segments.reversed
        .where((part) => RegExp(r'^\d+$').hasMatch(part))
        .firstOrNull;
    if (id != null) {
      return RichLinkInfo(
        RichLinkKind.vimeo,
        raw,
        embedUrl: 'https://player.vimeo.com/video/$id',
        aspectRatio: 16 / 9,
      );
    }
  }
  if (host == 'open.spotify.com') {
    final start = segments.firstOrNull?.startsWith('intl-') == true ? 1 : 0;
    final type = segments.length > start ? segments[start] : '';
    final id = segments.length > start + 1 ? segments[start + 1] : '';
    if (const {
          'album',
          'artist',
          'episode',
          'playlist',
          'show',
          'track',
        }.contains(type) &&
        RegExp(r'^[A-Za-z0-9]+$').hasMatch(id)) {
      return RichLinkInfo(
        RichLinkKind.spotify,
        raw,
        embedUrl: 'https://open.spotify.com/embed/$type/$id',
        height: 152,
        maxWidth: 480,
      );
    }
  }
  final isGoogleMapsHost = _isHostOrSubdomain(host, 'google.com');
  final isGoogleMapsUrl =
      (isGoogleMapsHost && uri.path.startsWith('/maps')) ||
      host == 'maps.google.com' ||
      (host == 'goo.gl' && uri.path.startsWith('/maps'));
  if (isGoogleMapsUrl) {
    final coords = RegExp(
      r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)(?:,(\d+(?:\.\d+)?)z)?',
    ).firstMatch(uri.path);
    final place = RegExp(r'/place/([^/@]+)').firstMatch(uri.path);
    final q = coords != null
        ? '${coords.group(1)},${coords.group(2)}'
        : uri.queryParameters['q'] ??
              uri.queryParameters['query'] ??
              (place == null
                  ? ''
                  : Uri.decodeComponent(place.group(1)!.replaceAll('+', ' ')));
    if (q.isNotEmpty) {
      final params = <String, String>{'output': 'embed', 'q': q};
      if (coords?.group(3) != null) {
        params['z'] = '${double.parse(coords!.group(3)!).round()}';
      }
      return RichLinkInfo(
        RichLinkKind.maps,
        raw,
        embedUrl: Uri.https('maps.google.com', '/maps', params).toString(),
        aspectRatio: 16 / 10,
      );
    }
  }
  // maps.app.goo.gl cannot be expanded safely without a network request, but
  // it is still an unambiguous Google Maps link and remains a static card.
  if (host == 'maps.app.goo.gl' && segments.isNotEmpty) {
    return RichLinkInfo(RichLinkKind.maps, raw);
  }
  if (host == 'twitter.com' || host == 'x.com') {
    if (RegExp(r'/status/\d+').hasMatch(uri.path)) {
      return RichLinkInfo(RichLinkKind.twitter, raw);
    }
  }
  if ((host == 'instagram.com' || host == 'instagr.am') &&
      RegExp(r'^/(p|reel|reels|tv)/[^/]+').hasMatch(uri.path)) {
    final match = RegExp(r'^/(p|reel|reels|tv)/([^/]+)').firstMatch(uri.path)!;
    final type = match.group(1) == 'reels' ? 'reel' : match.group(1);
    return RichLinkInfo(
      RichLinkKind.instagram,
      raw,
      embedUrl: 'https://www.instagram.com/$type/${match.group(2)}/embed',
      height: 450,
      maxWidth: 400,
    );
  }
  if (_isHostOrSubdomain(host, 'pinterest.com')) {
    final match = RegExp(r'^/pin/(\d+)').firstMatch(uri.path);
    if (match != null) {
      return RichLinkInfo(
        RichLinkKind.pinterest,
        raw,
        embedUrl:
            'https://assets.pinterest.com/ext/embed.html?id=${match.group(1)}',
        height: 380,
        maxWidth: 236,
      );
    }
  }
  if (host == 'tiktok.com') {
    final index = segments.indexOf('video');
    final id = index >= 0 && segments.length > index + 1
        ? segments[index + 1]
        : '';
    if (RegExp(r'^\d+$').hasMatch(id)) {
      return RichLinkInfo(
        RichLinkKind.tiktok,
        raw,
        embedUrl: 'https://www.tiktok.com/player/v1/$id',
        aspectRatio: 9 / 16,
        maxWidth: 365,
      );
    }
  }
  if (host == 'openstreetmap.org') {
    final match = RegExp(
      r'map=(\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)',
    ).firstMatch(uri.fragment);
    if (match != null) {
      final zoom = double.parse(match.group(1)!);
      final lat = double.parse(match.group(2)!);
      final lng = double.parse(match.group(3)!);
      final lonDelta = 360 / (1 << zoom.round());
      final latDelta = lonDelta / 2;
      final bbox = [
        lng - lonDelta / 2,
        lat - latDelta / 2,
        lng + lonDelta / 2,
        lat + latDelta / 2,
      ].map((v) => v.toStringAsFixed(5)).join(',');
      final embed = Uri.https('www.openstreetmap.org', '/export/embed.html', {
        'bbox': bbox,
        'layer': 'mapnik',
        'marker': '$lat,$lng',
      }).toString();
      return RichLinkInfo(
        RichLinkKind.openStreetMap,
        raw,
        embedUrl: embed,
        aspectRatio: 16 / 10,
      );
    }
  }
  return null;
}

class RichLinkEmbed extends StatefulWidget {
  final RichLinkInfo info;
  const RichLinkEmbed({super.key, required this.info});

  @override
  State<RichLinkEmbed> createState() => _RichLinkEmbedState();
}

class _RichLinkEmbedState extends State<RichLinkEmbed>
    with WidgetsBindingObserver {
  bool _allowedOnce = false;
  bool _activated = false;
  bool _consentGranted = false;
  EmbedRuntimeStore? _runtime;
  late final String _runtimeId = '${identityHashCode(this)}';
  ScrollPosition? _scrollPosition;
  bool _visibilityCheckQueued = false;

  /// Cooldown gate for the "budget exhausted" SnackBar. Without it, a card
  /// that stays >=20% visible while the 2-embed runtime cap is in use would
  /// re-enter [_activate] on every scroll-triggered visibility check (since
  /// a failed acquire never sets [_activated]) and stack a new SnackBar each
  /// time.
  DateTime? _lastBudgetSnackbarAt;

  RichLinkInfo get info => widget.info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _queueVisibilityCheck());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(next, _scrollPosition)) {
      _scrollPosition?.removeListener(_queueVisibilityCheck);
      _scrollPosition = next;
      _scrollPosition?.addListener(_queueVisibilityCheck);
    }
    _queueVisibilityCheck();
  }

  void _queueVisibilityCheck() {
    if (_visibilityCheckQueued || !mounted) return;
    _visibilityCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckQueued = false;
      if (mounted) _updateVisibility();
    });
  }

  void _updateVisibility() {
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final topLeft = render.localToGlobal(Offset.zero);
    final bottomRight = render.localToGlobal(render.size.bottomRight(Offset.zero));
    final screen = MediaQuery.sizeOf(context);
    final visible = (bottomRight.dy.clamp(0.0, screen.height) -
            topLeft.dy.clamp(0.0, screen.height)) /
        render.size.height.clamp(1.0, double.infinity);
    if (_consentGranted && visible >= .2 && !_activated) {
      _activate();
    } else if (visible < .05 && _activated) {
      _runtime?.release(_runtimeId);
      _runtime = null;
      setState(() => _activated = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || !_activated) return;
    _runtime?.release(_runtimeId);
    _runtime = null;
    if (mounted) setState(() => _activated = false);
  }

  void _activate() {
    EmbedRuntimeStore? runtime;
    try {
      runtime = context.read<EmbedRuntimeStore>();
    } on ProviderNotFoundException {
      // Standalone/test hosts may not install the global runtime budget.
    }
    if (runtime != null && !runtime.acquire(_runtimeId)) {
      final now = DateTime.now();
      if (_lastBudgetSnackbarAt == null ||
          now.difference(_lastBudgetSnackbarAt!) > const Duration(seconds: 4)) {
        _lastBudgetSnackbarAt = now;
        showHermesToast(
          context,
          message: context.l10n.richLinkCloseAnotherPreview,
        );
      }
      return;
    }
    _runtime = runtime;
    setState(() => _activated = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_queueVisibilityCheck);
    _runtime?.release(_runtimeId);
    super.dispose();
  }

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
      case RichLinkKind.instagram:
        return (
          label: 'Instagram',
          icon: Icons.camera_alt_outlined,
          color: const Color(0xFFE1306C),
        );
      case RichLinkKind.pinterest:
        return (
          label: 'Pinterest',
          icon: Icons.push_pin_outlined,
          color: const Color(0xFFE60023),
        );
      case RichLinkKind.tiktok:
        return (label: 'TikTok', icon: Icons.music_note, color: Colors.black);
      case RichLinkKind.openStreetMap:
        return (
          label: 'OpenStreetMap',
          icon: Icons.map_outlined,
          color: const Color(0xFF7EBC6F),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    EmbedConsentStore? consent;
    try {
      consent = context.watch<EmbedConsentStore>();
    } on ProviderNotFoundException {
      // Isolated embeds (tests/plugin hosts) stay privacy-safe when the app
      // root has not supplied policy yet.
    }
    if (consent == null) return _unmanagedConsentCard(context);
    final allowed = _allowedOnce || consent.allows(info.kind.provider);
    _consentGranted = allowed;
    if (consent.mode == EmbedMode.off) {
      return _plainLink(context);
    }
    if (!allowed) return _consentCard(context, consent);
    return _loadedCard(context);
  }

  Widget _unmanagedConsentCard(BuildContext context) {
    final meta = _meta(context);
    return Card(
      key: ValueKey('rich-link-consent-${info.kind.name}'),
      child: ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: Text(context.l10n.richLinkPrivacyTitle(meta.label)),
        subtitle: Text(context.l10n.richLinkPrivacyDescription),
        trailing: TextButton(
          onPressed: () {
            _allowedOnce = true;
            _activate();
          },
          child: Text(context.l10n.richLinkLoadOnce),
        ),
      ),
    );
  }

  Widget _plainLink(BuildContext context) {
    final meta = _meta(context);
    return Card(
      key: ValueKey('rich-link-disabled-${info.kind.name}'),
      child: ListTile(
        leading: Icon(meta.icon, color: meta.color),
        title: Text(meta.label),
        subtitle: Text(info.url, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => openChatLink(context, info.url),
      ),
    );
  }

  Widget _consentCard(BuildContext context, EmbedConsentStore consent) {
    final meta = _meta(context);
    return Card(
      key: ValueKey('rich-link-consent-${info.kind.name}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip_outlined, color: meta.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.richLinkPrivacyTitle(meta.label),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.richLinkPrivacyDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  key: const ValueKey('rich-link-load-once'),
                  onPressed: () {
                    _allowedOnce = true;
                    _activate();
                  },
                  child: Text(context.l10n.richLinkLoadOnce),
                ),
                TextButton(
                  key: const ValueKey('rich-link-always-allow'),
                  onPressed: () => consent.allowProvider(info.kind.provider),
                  child: Text(context.l10n.richLinkAlwaysAllow(meta.label)),
                ),
                TextButton(
                  onPressed: () => openChatLink(context, info.url),
                  child: Text(context.l10n.richLinkOpenOnly),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadedCard(BuildContext context) {
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
            if (_activated && info.embedUrl != null && webViewSupported)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: info.maxWidth),
                child: info.aspectRatio != null
                    ? AspectRatio(
                        aspectRatio: info.aspectRatio!,
                        child: WebPreviewPane(
                          key: ValueKey('rich-frame-${info.embedUrl}'),
                          url: info.embedUrl,
                          showHtmlTools: false,
                        ),
                      )
                    : SizedBox(
                        height: info.height ?? 280,
                        child: WebPreviewPane(
                          key: ValueKey('rich-frame-${info.embedUrl}'),
                          url: info.embedUrl,
                          showHtmlTools: false,
                        ),
                      ),
              )
            else if (_activated &&
                info.kind == RichLinkKind.youtube &&
                info.youtubeId != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  'https://img.youtube.com/vi/${info.youtubeId}/hqdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: scheme.surfaceContainerHighest),
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
            if (!_activated)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: FilledButton.tonalIcon(
                  onPressed: _activate,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(context.l10n.richLinkLoadOnce),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
