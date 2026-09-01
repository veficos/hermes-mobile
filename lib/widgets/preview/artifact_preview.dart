library;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models.dart';
import '../../core/clipboard.dart';
import '../../core/connection_reload_mixin.dart';
import '../../core/http_status_exception.dart';
import '../../core/stores/connection_store.dart';
import '../../core/stores/session_store.dart';
import '../../screens/artifacts_screen.dart' show resolveArtifactFile;
import '../../theme/hermes_tokens.dart';
import '../h/hermes_glass.dart';
import '../h/hermes_states.dart';
import '../web_preview.dart';

/// Whether an artifact's raw text is HTML/SVG worth rendering live rather
/// than as a code dump — same signal `code_block.dart`'s inline artifact
/// cards use (`_promotesToArtifact`'s language check), applied here to
/// content instead of a fenced-code-block's language tag since this
/// artifact source (`GET /api/artifacts`) carries no language field.
bool _looksLikeWebArtifact(ArtifactItem a) {
  if (a.kind != 'code' && a.kind != 'file') return false;
  final head = a.value.trimLeft().toLowerCase();
  return head.startsWith('<!doctype html') ||
      head.startsWith('<html') ||
      head.startsWith('<svg');
}

String _asHtmlDocument(ArtifactItem a) {
  final trimmed = a.value.trimLeft();
  if (trimmed.toLowerCase().startsWith('<svg')) {
    return '<!doctype html><html><body>${a.value}</body></html>';
  }
  return a.value;
}

class ArtifactListView extends StatefulWidget {
  const ArtifactListView({super.key});

  @override
  State<ArtifactListView> createState() => _ArtifactListViewState();
}

class _ArtifactListViewState extends State<ArtifactListView>
    with ConnectionReloadMixin<ArtifactListView> {
  List<ArtifactItem>? _artifacts;
  String _filter = 'all';
  bool _loading = true;
  String? _error;
  SessionStore? _session;
  String? _lastSessionId;
  int _loadGeneration = 0;

  static const List<String> _kinds = ['all', 'code', 'file', 'url', 'image'];

  @override
  void initState() {
    super.initState();
    _loadArtifacts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
    final session = context.read<SessionStore>();
    if (identical(session, _session)) return;
    _session?.removeListener(_onSessionChanged);
    _session = session..addListener(_onSessionChanged);
    _lastSessionId = session.durableId;
  }

  void _onSessionChanged() {
    final next = _session?.durableId;
    if (next == _lastSessionId) return;
    _lastSessionId = next;
    _loadArtifacts();
  }

  void _reloadForConnection() {
    if (!mounted) return;
    setState(() {
      _artifacts = null;
      _loading = true;
      _error = null;
    });
    _loadArtifacts();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _session?.removeListener(_onSessionChanged);
    super.dispose();
  }

  Future<void> _loadArtifacts() async {
    if (mounted) setState(() => _loading = true);
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final session = context.read<SessionStore>();
    final sid = session.durableId;
    final generation = ++_loadGeneration;

    if (api == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = connectionOfflineErrorCode;
          _artifacts = null;
        });
      }
      return;
    }
    if (sid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _artifacts = null;
        });
      }
      return;
    }
    try {
      final artifacts = await api.artifacts(sessionId: sid);
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, connection.api) &&
          sid == context.read<SessionStore>().durableId) {
        setState(() {
          _artifacts = artifacts;
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, connection.api) &&
          sid == context.read<SessionStore>().durableId) {
        setState(() {
          _error = '$error';
          _artifacts = null;
          _loading = false;
        });
      }
    }
  }

  List<ArtifactItem> get _filtered {
    final artifacts = _artifacts ?? const <ArtifactItem>[];
    if (_filter == 'all') return artifacts;
    return artifacts.where((a) => a.kind == _filter).toList();
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'code':
        return Icons.code_outlined;
      case 'file':
        return Icons.insert_drive_file_outlined;
      case 'url':
        return Icons.link_outlined;
      case 'image':
        return Icons.image_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Color _kindColor(String kind, ThemeData theme) {
    switch (kind) {
      case 'code':
        return HermesSemantic.purple;
      case 'file':
        return HermesSemantic.blue;
      case 'url':
        return HermesSemantic.green;
      case 'image':
        return HermesSemantic.orange;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}...';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kinds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final k = _kinds[i];
                final selected = _filter == k;
                final label = k == 'all'
                    ? context.l10n.commonAll
                    : k.toUpperCase();
                return GestureDetector(
                  onTap: () => setState(() => _filter = k),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : (theme.brightness == Brightness.dark
                                ? HermesBackground.darkTertiary
                                : HermesBackground.lightTertiary),
                      borderRadius: BorderRadius.circular(HermesRadius.capsule),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : (theme.brightness == Brightness.dark
                                  ? HermesBackground.darkBorder
                                  : HermesBackground.lightBorder),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? HermesErrorState(
                  description: _error == connectionOfflineErrorCode
                      ? context.l10n.backendDisconnected
                      : _error,
                  onRetry: _loadArtifacts,
                )
              : _artifacts == null
              ? HermesEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: context.l10n.artifactSessionPendingTitle,
                  description: context.l10n.artifactSessionPendingDescription,
                )
              : filtered.isEmpty
              ? _EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: context.l10n.artifactEmptyTitle,
                  subtitle: context.l10n.artifactEmptyDescription,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final a = filtered[i];
                    final summary = a.value.trim().replaceAll(
                      RegExp(r'\s+'),
                      ' ',
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: HermesGlassCard(
                        radius: HermesRadius.card,
                        padding: const EdgeInsets.all(12),
                        onTap: () => _showDetail(a),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _kindColor(
                                      a.kind,
                                      theme,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      HermesRadius.smallCard,
                                    ),
                                  ),
                                  child: Icon(
                                    _kindIcon(a.kind),
                                    size: 16,
                                    color: _kindColor(a.kind, theme),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    a.label?.isNotEmpty == true
                                        ? a.label!
                                        : context.l10n.artifactFallbackLabel(
                                            '${a.rowId ?? a.id}',
                                          ),
                                    style: HermesType.onSurface(
                                      HermesType.headline,
                                      theme,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _truncate(summary, 120),
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  a.kind.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _kindColor(a.kind, theme),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.copy_outlined,
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => _copyContent(a.value),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.open_in_new_outlined,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    onPressed: () => _showDetail(a),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _copyContent(String text) => copyTextOrNotify(
    context,
    text,
    successMessage: context.l10n.commonCopied,
  );

  Future<void> _showDetail(ArtifactItem a) async {
    await showDialog(
      context: context,
      builder: (ctx) => ArtifactDetailDialog(artifact: a),
    );
  }
}

class ArtifactDetailDialog extends StatefulWidget {
  final ArtifactItem artifact;

  const ArtifactDetailDialog({super.key, required this.artifact});

  @override
  State<ArtifactDetailDialog> createState() => _ArtifactDetailDialogState();
}

class _ArtifactDetailDialogState extends State<ArtifactDetailDialog> {
  Future<void> _copy() async {
    await copyTextOrNotify(
      context,
      widget.artifact.value,
      successMessage: context.l10n.commonCopied,
    );
  }

  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await resolveArtifactFile(widget.artifact);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.commonCompleted)));
      }
    } catch (e) {
      if (mounted) {
        final detail = e is HttpStatusException
            ? context.l10n.httpStatusError(e.statusCode)
            : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.artifactExportFailed(detail))),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.artifact;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 520),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(HermesRadius.sheet),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? HermesBackground.darkBorder
                : HermesBackground.lightBorder,
          ),
          boxShadow: hermesShadow(context, HermesShadowTier.lg),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.label?.isNotEmpty == true
                              ? a.label!
                              : context.l10n.artifactDetailTitle,
                          style: HermesType.onSurface(HermesType.title, theme),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.artifactSessionMeta(
                            a.kind.toUpperCase(),
                            a.sessionId.length > 8
                                ? a.sessionId.substring(0, 8)
                                : a.sessionId,
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_looksLikeWebArtifact(a))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(HermesRadius.card),
                        child: SizedBox(
                          height: 320,
                          child: WebPreviewPane(html: _asHtmlDocument(a)),
                        ),
                      )
                    else
                      HermesGlassCard(
                        radius: HermesRadius.card,
                        tint: theme.brightness == Brightness.dark
                            ? HermesBackground.darkTertiary
                            : HermesBackground.lightTertiary,
                        child: SelectableText(
                          a.value,
                          style: HermesType.code.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.artifactMetadata,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ..._metadataEntries(a).map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                e.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined, size: 18),
                      label: Text(context.l10n.artifactSaveAs),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: Text(context.l10n.artifactCopyContent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, String>> _metadataEntries(ArtifactItem a) => [
    MapEntry('ID', a.id),
    MapEntry(context.l10n.artifactType, a.kind),
    MapEntry(context.l10n.artifactSession, a.sessionId),
    if (a.sessionTitle != null)
      MapEntry(context.l10n.artifactSessionTitle, a.sessionTitle!),
    if (a.rowId != null)
      MapEntry(context.l10n.artifactMessageRow, '#${a.rowId}'),
  ];
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.brightness == Brightness.dark
                  ? HermesText.darkQuaternary
                  : HermesText.lightQuaternary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: HermesType.onSurface(HermesType.headline, theme),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
