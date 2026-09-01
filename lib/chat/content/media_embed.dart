import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/connection_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/web_preview.dart' show openChatLink;

enum MediaKind { audio, video, file, none }

const _audioExts = {'.mp3', '.wav', '.m4a', '.ogg', '.oga', '.aac', '.flac'};
const _videoExts = {'.mp4', '.webm', '.mov', '.mkv', '.m4v', '.avi'};

MediaKind mediaKindForUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  final dot = path.lastIndexOf('.');
  if (dot < 0) return MediaKind.none;
  final ext = path.substring(dot);
  if (_audioExts.contains(ext)) return MediaKind.audio;
  if (_videoExts.contains(ext)) return MediaKind.video;
  return MediaKind.none;
}

/// Whether [url] is a workspace file link (`file://`) — desktop offers a
/// "download / open" affordance for these rather than a broken navigation.
bool isFileUrl(String url) => url.startsWith('file://');

String _basename(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final parts = path.split('/').where((p) => p.isNotEmpty);
  return parts.isEmpty ? url : Uri.decodeComponent(parts.last);
}

/// Compact inline audio player (desktop `isInlineMediaSrc` audio branch).
class InlineAudioPlayer extends StatefulWidget {
  final String url;
  const InlineAudioPlayer({super.key, required this.url});

  @override
  State<InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<InlineAudioPlayer> {
  final _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<String> _resolvedSource() async {
    if (widget.url.startsWith('http://') || widget.url.startsWith('https://')) {
      return widget.url;
    }
    // Workspace / file path → data URL via the connection API.
    ConnectionStore? connection;
    try {
      connection = context.read<ConnectionStore>();
    } catch (_) {}
    final api = connection?.api;
    if (api == null) return widget.url;
    final path = widget.url.startsWith('file://')
        ? Uri.parse(widget.url).toFilePath()
        : widget.url;
    return api.fsReadDataUrl(path);
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    setState(() => _loading = true);
    try {
      final src = await _resolvedSource();
      if (src.startsWith('data:')) {
        final uriData = UriData.fromUri(Uri.parse(src));
        await _player.play(
          BytesSource(uriData.contentAsBytes(), mimeType: uriData.mimeType),
        );
      } else {
        await _player.play(UrlSource(src));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatAudioPlaybackFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final playing = _state == PlayerState.playing;
    final total = _duration.inMilliseconds == 0
        ? 1.0
        : _duration.inMilliseconds.toDouble();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: playing
                ? context.l10n.chatPauseAudio
                : context.l10n.chatPlayAudio,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: _loading ? null : _toggle,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _position.inMilliseconds
                    .clamp(0, total.toInt())
                    .toDouble(),
                max: total,
                onChanged: (v) =>
                    _player.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_fmt(_position)} / ${_fmt(_duration)}',
            style: TextStyle(
              fontSize: 11,
              color: palette.text3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card for a video or a `file://` link — opens externally / in the WebView,
/// since there is no bundled video decoder.
class MediaLinkCard extends StatelessWidget {
  final String url;
  final MediaKind kind;
  const MediaLinkCard({super.key, required this.url, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isVideo = kind == MediaKind.video;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          isVideo ? Icons.movie_outlined : Icons.attach_file_outlined,
        ),
        title: Text(
          _basename(url),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isVideo ? context.l10n.chatOpenVideo : context.l10n.chatOpenFile,
        ),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => openChatLink(context, url),
      ),
    );
  }
}
