/// Skill hub marketplace: browse/search external skill sources, preview a
/// candidate's SKILL.md before installing, and install/uninstall/update via
/// `/api/v1/skills/hub/*` — backed by the same background-action + polling
/// convention `mcp_screen.dart` uses for its catalog installs.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';

class SkillHubScreen extends StatefulWidget {
  const SkillHubScreen({super.key});

  @override
  State<SkillHubScreen> createState() => _SkillHubScreenState();
}

class _SkillHubScreenState extends State<SkillHubScreen>
    with ConnectionReloadMixin<SkillHubScreen> {
  SkillHubSources? _sources;
  SkillHubSearchResult? _searchResult;
  String? _error;
  String _query = '';
  bool _searching = false;
  String _busyKey = '';
  int _loadGeneration = 0;
  int _searchGeneration = 0;
  int _actionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    _searchGeneration++;
    _actionGeneration++;
    setState(() {
      _sources = null;
      _searchResult = null;
      _error = null;
      _searching = false;
      _busyKey = '';
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<ConnectionStore>().api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    try {
      final sources = await api.skillHubSources();
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<ConnectionStore>().api)) {
        setState(() {
          _sources = sources;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<ConnectionStore>().api)) {
        setState(() => _error = '$e');
      }
    }
  }

  Future<void> _search(String query) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final generation = ++_searchGeneration;
    final l10n = context.l10n;
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchResult = null);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await api.searchSkillsHub(q);
      if (mounted &&
          generation == _searchGeneration &&
          q == _query.trim() &&
          identical(api, connection.api)) {
        setState(() => _searchResult = result);
      }
    } catch (e) {
      if (mounted &&
          generation == _searchGeneration &&
          identical(api, connection.api)) {
        showHermesToast(context, message: l10n.skillHubSearchFailed('$e'));
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  Map<String, SkillHubInstalledEntry> get _installedMap => {
    ...?_sources?.installed,
    ...?_searchResult?.installed,
  };

  Future<void> _runAction(
    String key,
    Future<Map<String, dynamic>> Function(ApiClient api) spawn, {
    ApiClient? expectedApi,
  }) async {
    final connection = context.read<ConnectionStore>();
    final api = expectedApi ?? connectedApiOrNotify(context, connection);
    if (api == null) return;
    final generation = ++_actionGeneration;
    final l10n = context.l10n;
    setState(() => _busyKey = key);
    try {
      if (generation != _actionGeneration) return;
      requireActiveApi(context, connection, api);
      final result = await spawn(api);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      final actionName = result['name']?.toString();
      if (actionName != null && actionName.isNotEmpty) {
        const maxPolls = 300;
        var polls = 0;
        while (mounted) {
          final status = await api.actionStatus(actionName, lines: 50);
          if (!mounted) return;
          if (generation != _actionGeneration) return;
          requireActiveApi(context, connection, api);
          if (status['running'] != true) {
            final exitCode = (status['exit_code'] as num?)?.toInt();
            if (exitCode != null && exitCode != 0) {
              final lines = (status['lines'] as List?) ?? const [];
              final tail = lines.isEmpty ? null : lines.last.toString();
              throw StateError(tail ?? l10n.skillHubExitCode(exitCode));
            }
            break;
          }
          if (++polls >= maxPolls) {
            throw TimeoutException(l10n.skillHubActionTimeout);
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (!mounted) return;
      if (generation != _actionGeneration) return;
      requireActiveApi(context, connection, api);
      await _load();
      if (_query.isNotEmpty) await _search(_query);
      if (mounted && generation == _actionGeneration) {
        showHermesToast(context, message: l10n.skillHubActionDone);
      }
    } catch (e) {
      if (mounted && generation == _actionGeneration) {
        showHermesToast(context, message: l10n.skillHubActionFailed('$e'));
      }
    } finally {
      if (mounted && generation == _actionGeneration) {
        setState(() => _busyKey = '');
      }
    }
  }

  Future<void> _install(SkillHubResult r, {ApiClient? expectedApi}) =>
      _runAction(
        r.identifier,
        (api) => api.installSkillFromHub(r.identifier),
        expectedApi: expectedApi,
      );

  Future<void> _uninstall(
    String identifier,
    String name, {
    ApiClient? expectedApi,
  }) async {
    final l10n = context.l10n;
    final api =
        expectedApi ??
        connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.skillHubUninstallQuestion(name)),
        content: Text(l10n.skillHubUninstallDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.skillHubUninstall),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(
      identifier,
      (api) => api.uninstallSkillFromHub(name),
      expectedApi: api,
    );
  }

  Future<void> _updateAll() =>
      _runAction('__update_all__', (api) => api.updateSkillsFromHub());

  Future<void> _openPreview(SkillHubResult r) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    SkillHubPreview? preview;
    String? error;
    try {
      preview = await api.previewSkillHub(r.identifier);
    } catch (e) {
      error = '$e';
    }
    if (!mounted || !identical(api, connection.api)) return;
    final installed = _installedMap[r.identifier];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HermesRadius.sheet),
        ),
      ),
      builder: (sheetCtx) => _SkillPreviewSheet(
        result: r,
        preview: preview,
        error: error,
        installed: installed != null,
        busy: _busyKey == r.identifier,
        onInstall: () {
          Navigator.of(sheetCtx).pop();
          _install(r, expectedApi: api);
        },
        onUninstall: () {
          Navigator.of(sheetCtx).pop();
          _uninstall(r.identifier, installed?.name ?? r.name, expectedApi: api);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInstalled = _installedMap.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.skillsMarketplace),
        actions: [
          IconButton(
            tooltip: context.l10n.skillHubUpdateInstalled,
            onPressed: (_busyKey.isEmpty && hasInstalled) ? _updateAll : null,
            icon: _busyKey == '__update_all__'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt_outlined),
          ),
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _load,
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
              0,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: context.l10n.skillHubSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => _search(_query),
                      ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_sources == null && _error == null) {
      return HermesLoadingState(label: context.l10n.skillHubLoading);
    }
    if (_error != null && _sources == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    final searchResult = _searchResult;
    if (searchResult != null) {
      return _buildSearchResults(context, searchResult);
    }
    return _buildSourcesView(context, _sources);
  }

  Widget _buildSearchResults(BuildContext context, SkillHubSearchResult r) {
    if (r.results.isEmpty) {
      return HermesEmptyState(
        icon: Icons.search_off,
        title: context.l10n.skillsNoMatches,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
      children: [
        if (r.timedOut.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.skillHubSourcesTimedOut(r.timedOut.join(', ')),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: HermesSemantic.orange),
            ),
          ),
        HermesMobileGroup(
          children: [for (final res in r.results) _resultRow(context, res)],
        ),
      ],
    );
  }

  Widget _buildSourcesView(BuildContext context, SkillHubSources? sources) {
    if (sources == null) {
      return HermesEmptyState(
        icon: Icons.storefront_outlined,
        title: context.l10n.skillHubNoData,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
      children: [
        if (sources.sources.isNotEmpty) ...[
          HermesMobileSectionLabel(title: context.l10n.skillHubSources),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sources.sources)
                HermesMobileStatusChip(
                  color: s.available
                      ? HermesSemantic.green
                      : HermesSemantic.gray,
                  label: s.rateLimited
                      ? context.l10n.skillHubRateLimited(s.label)
                      : s.label,
                ),
            ],
          ),
          const SizedBox(height: HermesSpacing.lg),
        ],
        if (!sources.indexAvailable)
          Padding(
            padding: const EdgeInsets.only(bottom: HermesSpacing.md),
            child: Text(
              context.l10n.skillHubIndexUnavailable,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: HermesSemantic.orange),
            ),
          ),
        if (sources.featured.isNotEmpty) ...[
          HermesMobileSectionLabel(title: context.l10n.skillHubFeatured),
          HermesMobileGroup(
            children: [
              for (final res in sources.featured) _resultRow(context, res),
            ],
          ),
        ] else
          HermesEmptyState(
            icon: Icons.storefront_outlined,
            title: context.l10n.skillHubSearchPrompt,
          ),
      ],
    );
  }

  Widget _resultRow(BuildContext context, SkillHubResult r) {
    final installed = _installedMap.containsKey(r.identifier);
    return HermesMobileRow(
      icon: Icons.extension_outlined,
      tone: HermesSemantic.green,
      title: r.name,
      subtitle: r.description.isNotEmpty ? r.description : r.source,
      onTap: () => _openPreview(r),
      trailing: installed
          ? HermesMobileStatusChip(
              color: HermesSemantic.blue,
              label: context.l10n.skillHubInstalled,
            )
          : _busyKey == r.identifier
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.chevron_right,
              size: 18,
              color: HermesPalette.of(context).text4,
            ),
    );
  }
}

class _SkillPreviewSheet extends StatelessWidget {
  final SkillHubResult result;
  final SkillHubPreview? preview;
  final String? error;
  final bool installed;
  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;

  const _SkillPreviewSheet({
    required this.result,
    required this.preview,
    required this.error,
    required this.installed,
    required this.busy,
    required this.onInstall,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final safeArea = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          HermesSpacing.lg,
          HermesSpacing.md,
          HermesSpacing.lg,
          HermesSpacing.lg + safeArea,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.name,
                    style: HermesType.onSurface(
                      HermesType.headline,
                      Theme.of(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                HermesMobileStatusChip(
                  color: _trustColor(result.trustLevel),
                  label: _trustLabel(context, result.trustLevel),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${result.source} · ${result.identifier}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (result.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in result.tags)
                    Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
            const SizedBox(height: HermesSpacing.md),
            if (error != null)
              Text(error!, style: const TextStyle(color: HermesSemantic.red))
            else if (preview == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? HermesBackground.darkSecondary
                          : HermesBackground.lightTertiary,
                      borderRadius: BorderRadius.circular(HermesRadius.card),
                    ),
                    child: Text(
                      preview!.skillMd.isEmpty
                          ? context.l10n.skillsNoContent
                          : preview!.skillMd,
                      style: HermesType.onSurface(
                        HermesType.code,
                        Theme.of(context),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: HermesSpacing.md),
            SizedBox(
              width: double.infinity,
              child: installed
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HermesSemantic.red,
                        side: const BorderSide(color: HermesSemantic.red),
                      ),
                      onPressed: busy ? null : onUninstall,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(l10n.skillHubUninstall),
                    )
                  : FilledButton.icon(
                      onPressed: busy ? null : onInstall,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(l10n.configCenterInstall),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _trustLabel(BuildContext context, String level) {
    return switch (level.toLowerCase()) {
      'official' => context.l10n.skillHubTrustOfficial,
      'trusted' => context.l10n.skillHubTrustTrusted,
      'community' => context.l10n.skillHubTrustCommunity,
      'unverified' => context.l10n.skillHubTrustUnverified,
      'untrusted' => context.l10n.skillHubTrustUntrusted,
      _ => context.l10n.skillHubTrustUnknown,
    };
  }

  Color _trustColor(String level) {
    switch (level.toLowerCase()) {
      case 'official':
      case 'trusted':
        return HermesSemantic.green;
      case 'community':
        return HermesSemantic.blue;
      case 'unverified':
      case 'untrusted':
        return HermesSemantic.orange;
      default:
        return HermesSemantic.gray;
    }
  }
}
