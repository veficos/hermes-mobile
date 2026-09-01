/// ArtifactsScreen: 工件列表屏幕
///
/// - 从 API 获取真实工件数据；失败时明确显示错误，不伪造内容
/// - 搜索框 + 过滤器芯片（全部 / code / file / image / audio / url 等 artifact_kind）
/// - 两列视图：卡片显示 artifact_kind 图标、标题、大小、提取时间、会话引用
/// - 点击卡片：工件详情页（完整内容、预览、复制、保存、共享）
/// - 图片内容支持：URL 网络图片、base64 数据、本地文件路径
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../core/clipboard.dart';
import '../core/connection_reload_mixin.dart';
import '../core/http_status_exception.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';

class ArtifactsScreen extends StatefulWidget {
  const ArtifactsScreen({super.key});

  @override
  State<ArtifactsScreen> createState() => _ArtifactsScreenState();
}

class _ArtifactsScreenState extends State<ArtifactsScreen>
    with ConnectionReloadMixin<ArtifactsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = 'all';
  bool _loading = true;
  String? _error;
  List<ArtifactItem> _artifacts = const [];
  int _loadGeneration = 0;
  // Keyed by the raw artifact value (content-addressed, so it stays correct
  // even if `_artifacts` is reloaded wholesale) — every filter-chip tap used
  // to re-run base64Decode on every visible image artifact's full value via
  // `setState(() => _filter = ...)` rebuilding the grid.
  final Map<String, Uint8List> _imageDecodeCache = {};

  @override
  void initState() {
    super.initState();
    _loadArtifacts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _loadArtifacts);
  }

  Future<void> _loadArtifacts() async {
    final generation = ++_loadGeneration;
    final api = context.read<ConnectionStore>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (api == null) throw StateError(context.l10n.backendDisconnected);
      final list = await api.artifacts(limit: 200);
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _artifacts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _artifacts = const [];
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ArtifactItem> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _artifacts.where((a) {
      if (_filter != 'all' && a.kind != _filter) return false;
      if (q.isEmpty) return true;
      final label = (a.label ?? '').toLowerCase();
      final sessionTitle = (a.sessionTitle ?? '').toLowerCase();
      final value = a.value.toLowerCase();
      return label.contains(q) || sessionTitle.contains(q) || value.contains(q);
    }).toList();
  }

  void _openDetail(ArtifactItem a) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ArtifactDetailScreen(artifact: a)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.artifactsTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _loadArtifacts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HermesSpacing.md,
              HermesSpacing.xs,
              HermesSpacing.md,
              HermesSpacing.sm,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.l10n.artifactsSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(
                    'all',
                    context.l10n.commonAll,
                    Icons.inventory_2_outlined,
                  ),
                  _filterChip(
                    'code',
                    context.l10n.artifactsKindCode,
                    Icons.code,
                  ),
                  _filterChip(
                    'image',
                    context.l10n.artifactsKindImage,
                    Icons.image_outlined,
                  ),
                  _filterChip(
                    'file',
                    context.l10n.commonFile,
                    Icons.insert_drive_file_outlined,
                  ),
                  _filterChip(
                    'link',
                    context.l10n.artifactsKindLink,
                    Icons.link,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HermesSpacing.sm),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null
                      ? HermesErrorState(
                          description: _error,
                          onRetry: _loadArtifacts,
                        )
                      : _filtered.isEmpty
                      ? HermesEmptyState(
                          icon: Icons.inbox_outlined,
                          title: _artifacts.isEmpty
                              ? context.l10n.artifactsEmpty
                              : context.l10n.artifactsNoMatches,
                          description: _artifacts.isEmpty
                              ? context.l10n.artifactsEmptyDescription
                              : context.l10n.artifactsNoMatchesDescription,
                        )
                      : RefreshIndicator(
                          onRefresh: _loadArtifacts,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              HermesSpacing.md,
                              0,
                              HermesSpacing.md,
                              100,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: switch (MediaQuery.sizeOf(
                                    context,
                                  ).width) {
                                    < 480 => 1,
                                    < 600 => 2,
                                    < 840 => 3,
                                    < 1200 => 3,
                                    _ => 4,
                                  },
                                  crossAxisSpacing: HermesSpacing.sm,
                                  mainAxisSpacing: HermesSpacing.sm,
                                  childAspectRatio: 0.88,
                                ),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) =>
                                _artifactCard(_filtered[i]),
                          ),
                        )),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String kind, String label, IconData icon) {
    final selected = _filter == kind;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: HermesSpacing.xs),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => setState(() => _filter = kind),
        avatar: Icon(icon, size: 16),
        label: Text(label),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }

  Widget _artifactCard(ArtifactItem a) {
    final theme = Theme.of(context);
    final (icon, color) = _kindInfo(a.kind);
    final title = a.label ?? a.value.split('\n').first;
    final hasImagePreview = a.kind == 'image' && _isImageRenderable(a.value);

    return Semantics(
      button: true,
      label: context.l10n.artifactsOpen(title),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => _openDetail(a),
          child: HermesGlassCard(
            radius: HermesRadius.card,
            padding: const EdgeInsets.all(HermesSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImagePreview)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(HermesRadius.smallCard),
                    child: SizedBox(
                      height: 80,
                      width: double.infinity,
                      child: _buildImageFromValue(a.value),
                    ),
                  ),
                Row(
                  children: [
                    if (!hasImagePreview)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            HermesRadius.smallCard,
                          ),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                    const Spacer(),
                    HermesStatusChip(color: color, label: _kindLabel(a.kind)),
                  ],
                ),
                const SizedBox(height: HermesSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: HermesType.onSurface(HermesType.headline, theme),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: HermesSpacing.xs),
                Text(
                  a.value.length > 200
                      ? '${a.value.substring(0, 200)}…'
                      : a.value,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: HermesSpacing.xs),
                if (a.sessionTitle != null && a.sessionTitle!.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          a.sessionTitle!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
    'code' => context.l10n.artifactsKindCode,
    'image' => context.l10n.artifactsKindImage,
    'file' => context.l10n.commonFile,
    'link' => context.l10n.artifactsKindLink,
    _ => kind,
  };

  (IconData, Color) _kindInfo(String kind) {
    switch (kind) {
      case 'file':
        return (Icons.insert_drive_file_outlined, HermesSemantic.blue);
      case 'image':
        return (Icons.image_outlined, HermesSemantic.green);
      case 'link':
        return (Icons.link, Theme.of(context).colorScheme.primary);
      default:
        return (Icons.inventory_2_outlined, HermesSemantic.gray);
    }
  }

  bool _isImageRenderable(String value) {
    if (value.startsWith('data:image')) return true;
    if (value.startsWith('http')) return true;
    if (RegExp(
      r'\.(png|jpe?g|gif|webp|bmp|svg)(\?|$)',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }
    if (value.length > 20 && _looksLikeBase64(value)) return true;
    return false;
  }

  bool _looksLikeBase64(String value) {
    return RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(value) &&
        value.length % 4 == 0;
  }

  Uint8List? _decodeCached(String value, String base64Str) {
    final cached = _imageDecodeCache[value];
    if (cached != null) return cached;
    final bytes = base64Decode(base64Str);
    _imageDecodeCache[value] = bytes;
    return bytes;
  }

  Widget _buildImageFromValue(String value) {
    if (value.startsWith('data:image')) {
      try {
        final base64Str = value.contains(',')
            ? value.substring(value.indexOf(',') + 1)
            : value;
        final bytes = _decodeCached(value, base64Str);
        return Image.memory(
          bytes!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _imageErrorPlaceholder(),
        );
      } catch (_) {
        return _imageErrorPlaceholder();
      }
    }
    if (value.startsWith('http')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, _, _) => _imageErrorPlaceholder(),
      );
    }
    if (RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(value) && value.length > 20) {
      try {
        final bytes = _decodeCached(value, value);
        return Image.memory(
          bytes!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _imageErrorPlaceholder(),
        );
      } catch (_) {
        // fall through
      }
    }
    if (RegExp(
      r'\.(png|jpe?g|gif|webp|bmp)(\?|$)',
      caseSensitive: false,
    ).hasMatch(value)) {
      if (kIsWeb) {
        return _imageErrorPlaceholder();
      }
      // ignore: avoid_web_libraries_in_flutter
      return Image.network(
        value.startsWith('http') ? value : 'file://$value',
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _imageErrorPlaceholder(),
      );
    }
    return _imageErrorPlaceholder();
  }

  Widget _imageErrorPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
      ),
    );
  }
}

/// Resolves an [ArtifactItem]'s raw bytes + a reasonable filename so it can
/// be saved to the device — mirrors the value-shape sniffing
/// `_tryBuildImage` already does for preview rendering (data URI / plain
/// base64 / http URL / local file path), plus a plain-text fallback for
/// non-image kinds.
class ResolvedArtifactFile {
  final Uint8List bytes;
  final String name;
  final String? mimeType;

  const ResolvedArtifactFile({
    required this.bytes,
    required this.name,
    this.mimeType,
  });
}

String sanitizedArtifactFileStem(ArtifactItem artifact) {
  final base =
      (artifact.label?.trim().isNotEmpty == true
              ? artifact.label!
              : artifact.value.split('\n').first)
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
  return base.isEmpty ? artifact.kind : base;
}

Future<ResolvedArtifactFile> resolveArtifactFile(ArtifactItem artifact) async {
  final stem = sanitizedArtifactFileStem(artifact);
  final value = artifact.value;

  if (artifact.kind == 'image') {
    if (value.startsWith('data:image')) {
      final mimeMatch = RegExp(
        r'^data:(image/[a-zA-Z0-9.+-]+)',
      ).firstMatch(value);
      final mime = mimeMatch?.group(1) ?? 'image/png';
      final ext = mime.split('/').last;
      final base64Str = value.contains(',')
          ? value.substring(value.indexOf(',') + 1)
          : value;
      return ResolvedArtifactFile(
        bytes: base64Decode(base64Str),
        name: stem.toLowerCase().endsWith('.$ext') ? stem : '$stem.$ext',
        mimeType: mime,
      );
    }
    if (value.startsWith('http')) {
      final response = await http.get(Uri.parse(value));
      if (response.statusCode >= 400) {
        throw HttpStatusException(response.statusCode);
      }
      final contentType = response.headers['content-type'];
      final urlExt = RegExp(
        r'\.([a-zA-Z0-9]+)(?:\?|$)',
      ).firstMatch(value)?.group(1);
      final ext =
          urlExt ??
          (contentType?.contains('/') == true
              ? contentType!.split('/').last
              : 'png');
      return ResolvedArtifactFile(
        bytes: response.bodyBytes,
        name: stem.toLowerCase().endsWith('.$ext') ? stem : '$stem.$ext',
        mimeType: contentType,
      );
    }
    if (!kIsWeb && (value.startsWith('/') || value.startsWith('file://'))) {
      final path = value.startsWith('file://') ? value.substring(7) : value;
      final bytes = await File(path).readAsBytes();
      final ext = path.contains('.') ? path.split('.').last : 'png';
      return ResolvedArtifactFile(
        bytes: bytes,
        name: stem.toLowerCase().endsWith('.$ext') ? stem : '$stem.$ext',
        mimeType: 'image/$ext',
      );
    }
    // Plain base64 with no other signal — decode as-is, default to PNG.
    return ResolvedArtifactFile(
      bytes: base64Decode(value),
      name: stem.toLowerCase().endsWith('.png') ? stem : '$stem.png',
      mimeType: 'image/png',
    );
  }

  // file / link / code / anything else: share the raw text content.
  return ResolvedArtifactFile(
    bytes: Uint8List.fromList(utf8.encode(value)),
    name: stem.toLowerCase().endsWith('.txt') ? stem : '$stem.txt',
    mimeType: 'text/plain',
  );
}

class _ArtifactDetailScreen extends StatefulWidget {
  final ArtifactItem artifact;

  const _ArtifactDetailScreen({required this.artifact});

  @override
  State<_ArtifactDetailScreen> createState() => _ArtifactDetailScreenState();
}

class _ArtifactDetailScreenState extends State<_ArtifactDetailScreen> {
  bool _saving = false;

  ArtifactItem get artifact => widget.artifact;

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final file = await resolveArtifactFile(artifact);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              file.bytes,
              name: file.name,
              mimeType: file.mimeType,
            ),
          ],
        ),
      );
      if (mounted && result.status == ShareResultStatus.success) {
        showHermesToast(
          context,
          message: l10n.artifactsSaved,
          kind: HermesToastKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        final detail = e is HttpStatusException
            ? l10n.httpStatusError(e.statusCode)
            : '$e';
        showHermesToast(context, message: l10n.artifactsSaveFailed(detail));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _kindInfo(artifact.kind);
    final title = artifact.label ?? artifact.value.split('\n').first;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: context.l10n.artifactsSaveToDevice,
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: context.l10n.artifactsCopy,
            onPressed: () => copyTextOrNotify(
              context,
              artifact.value,
              successMessage: context.l10n.commonCopied,
            ),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          if (artifact.kind == 'link' && artifact.value.startsWith('http'))
            IconButton(
              tooltip: context.l10n.artifactsOpenLink,
              onPressed: () async {
                final uri = Uri.parse(artifact.value);
                if (await canLaunchUrl(uri)) {
                  final launched = await launchUrl(uri);
                  if (launched || !context.mounted) return;
                }
                if (context.mounted) {
                  showHermesToast(
                    context,
                    message: context.l10n.artifactsOpenLinkFailed,
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(HermesSpacing.md),
        children: [
          HermesGlassCard(
            radius: HermesRadius.largeCard,
            padding: const EdgeInsets.all(HermesSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(HermesRadius.card),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: HermesSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: HermesType.onSurface(
                              HermesType.title,
                              theme,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              HermesStatusChip(
                                color: color,
                                label: _kindLabel(artifact.kind),
                              ),
                              if (artifact.sessionTitle != null)
                                Text(
                                  artifact.sessionTitle!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HermesSpacing.md),
                _buildArtifactContent(artifact, theme, color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _kindInfo(String kind) {
    switch (kind) {
      case 'file':
        return (Icons.insert_drive_file_outlined, HermesSemantic.blue);
      case 'image':
        return (Icons.image_outlined, HermesSemantic.green);
      case 'link':
        return (Icons.link, HermesSemantic.orange);
      default:
        return (Icons.inventory_2_outlined, HermesSemantic.gray);
    }
  }

  String _kindLabel(String kind) => switch (kind) {
    'code' => context.l10n.artifactsKindCode,
    'image' => context.l10n.artifactsKindImage,
    'file' => context.l10n.commonFile,
    'link' => context.l10n.artifactsKindLink,
    _ => kind,
  };

  Widget _buildArtifactContent(
    ArtifactItem artifact,
    ThemeData theme,
    Color color,
  ) {
    if (artifact.kind == 'image') {
      return _tryBuildImage(artifact.value, theme, color);
    }
    if (artifact.kind == 'link' && artifact.value.startsWith('http')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(HermesRadius.smallCard),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                link: true,
                child: GestureDetector(
                  onTap: () async {
                    final failureMessage = context.l10n.artifactsOpenLinkFailed;
                    final uri = Uri.parse(artifact.value);
                    if (await canLaunchUrl(uri) && await launchUrl(uri)) return;
                    if (!mounted) return;
                    showHermesToast(context, message: failureMessage);
                  },
                  child: Text(
                    artifact.value,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SelectableText(
      artifact.value,
      style: HermesType.onSurface(HermesType.code, theme),
    );
  }

  Widget _tryBuildImage(String value, ThemeData theme, Color color) {
    // 1. data:image URI
    if (value.startsWith('data:image')) {
      try {
        final base64Str = value.contains(',')
            ? value.substring(value.indexOf(',') + 1)
            : value;
        final bytes = base64Decode(base64Str);
        return _imageContainer(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _imageErrorPlaceholder(theme, color),
          ),
          theme: theme,
        );
      } catch (_) {
        // fall through
      }
    }

    // 2. Plain base64 (no data URI prefix)
    if (value.length > 100 && _looksLikeBase64(value)) {
      try {
        final bytes = base64Decode(value);
        return _imageContainer(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _imageErrorPlaceholder(theme, color),
          ),
          theme: theme,
        );
      } catch (_) {
        // fall through
      }
    }

    // 3. HTTP URL
    if (value.startsWith('http')) {
      return _imageContainer(
        child: Image.network(
          value,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, _, _) => _imageErrorPlaceholder(theme, color),
        ),
        theme: theme,
      );
    }

    // 4. File path with image extension
    if (RegExp(
      r'\.(png|jpe?g|gif|webp|bmp)(\?|$)',
      caseSensitive: false,
    ).hasMatch(value)) {
      if (kIsWeb) {
        return _imageErrorPlaceholder(theme, color);
      }
      return _imageContainer(
        child: Image.network(
          value.startsWith('http') ? value : 'file://$value',
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _imageErrorPlaceholder(theme, color),
        ),
        theme: theme,
      );
    }

    // 5. Placeholder
    return _imageErrorPlaceholder(theme, color);
  }

  bool _looksLikeBase64(String value) {
    return RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(value) &&
        value.length % 4 == 0;
  }

  Widget _imageContainer({required Widget child, required ThemeData theme}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(HermesRadius.smallCard),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HermesRadius.smallCard),
        child: child,
      ),
    );
  }

  Widget _imageErrorPlaceholder(ThemeData theme, Color color) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(HermesRadius.smallCard),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              context.l10n.artifactsImageLoadFailed,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
