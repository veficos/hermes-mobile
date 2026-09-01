/// Skills (spec §90–91, Q5 decision): grouped list + search + enable toggles
/// over `/api/v1/skills` (106 skills with optional category grouping), plus
/// detail/edit/archive for learned skills and a hub marketplace entry point.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../theme/hermes_tokens.dart';
import '../l10n/l10n.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/profile_scope_selector.dart';
import 'skill_hub_screen.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen>
    with ConnectionReloadMixin<SkillsScreen> {
  List<SkillInfo>? _skills;
  String? _error;
  String _query = '';
  final Set<String> _busy = {};
  bool _bulkBusy = false;
  ProfileScopeStore? _scopeStore;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;

  String? get _profile => _scopeStore?.override;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForTarget);
    final scope = context.read<ProfileScopeStore>();
    if (identical(scope, _scopeStore)) return;
    _scopeStore?.removeListener(_onScopeChanged);
    _scopeStore = scope..addListener(_onScopeChanged);
    scope.ensureLoaded();
  }

  void _onScopeChanged() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _skills = null;
      _error = null;
      _busy.clear();
      _bulkBusy = false;
    });
    _load();
  }

  void _reloadForTarget() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _skills = null;
      _error = null;
      _busy.clear();
      _bulkBusy = false;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _scopeStore?.removeListener(_onScopeChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final profile = _profile;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    try {
      final skills = await api.skills(profile: profile);
      if (mounted &&
          generation == _loadGeneration &&
          profile == _profile &&
          identical(api, connection.api)) {
        setState(() {
          _skills = skills;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          profile == _profile &&
          identical(api, connection.api)) {
        setState(() => _error = '$e');
      }
    }
  }

  Future<void> _toggle(SkillInfo s, bool enabled) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    final generation = _mutationGeneration;
    setState(() => _busy.add(s.name));
    try {
      await api.toggleSkill(s.name, enabled, profile: profile);
      if (mounted &&
          generation == _mutationGeneration &&
          profile == _profile &&
          identical(api, connection.api)) {
        setState(() {
          _skills = [
            for (final x in _skills ?? <SkillInfo>[])
              x.name == s.name ? x.copyWith(enabled: enabled) : x,
          ];
        });
      }
    } catch (e) {
      if (mounted && generation == _mutationGeneration) {
        showHermesToast(
          context,
          message: context.l10n.skillsToggleFailed('$e'),
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busy.remove(s.name));
      }
    }
  }

  Future<void> _toggleAll(bool enabled) async {
    final skills = _skills;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null || skills == null) return;
    final profile = _profile;
    final generation = _mutationGeneration;
    final targets = skills.where((s) => s.enabled != enabled).toList();
    if (targets.isEmpty) return;
    setState(() => _bulkBusy = true);
    var failed = 0;
    for (final s in targets) {
      try {
        await api.toggleSkill(s.name, enabled, profile: profile);
        if (generation != _mutationGeneration ||
            profile != _profile ||
            !identical(api, connection.api)) {
          return;
        }
      } catch (_) {
        failed++;
      }
    }
    if (generation == _mutationGeneration &&
        profile == _profile &&
        identical(api, connection.api)) {
      await _load();
    }
    if (mounted && generation == _mutationGeneration) {
      setState(() => _bulkBusy = false);
      if (failed > 0) {
        showHermesToast(
          context,
          message: context.l10n.skillsBulkFailed(failed, targets.length),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _openDetail(SkillInfo s) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null || !mounted) return;
    final profile = _profile;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HermesRadius.sheet),
        ),
      ),
      builder: (_) => _SkillDetailSheet(
        skill: s,
        ownerApi: api,
        profile: profile,
        onChanged: _load,
      ),
    );
  }

  Future<void> _openHub() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SkillHubScreen()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final skills = _skills;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.skillsTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.skillsMarketplace,
            onPressed: _openHub,
            icon: const Icon(Icons.storefront_outlined),
          ),
          PopupMenuButton<String>(
            enabled: !_bulkBusy && skills != null && skills.isNotEmpty,
            onSelected: (v) => _toggleAll(v == 'enable'),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'enable',
                child: Text(context.l10n.skillsEnableAll),
              ),
              PopupMenuItem(
                value: 'disable',
                child: Text(context.l10n.skillsDisableAll),
              ),
            ],
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
          const ProfileScopeDropdown(),
          Expanded(child: _buildBody(context, skills)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<SkillInfo>? skills) {
    final enabledCount = skills?.where((s) => s.enabled).length ?? 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HermesSpacing.md,
            HermesSpacing.xs,
            HermesSpacing.md,
            0,
          ),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: context.l10n.skillsSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: skills == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Text(
                          context.l10n.skillsEnabledCount(
                            enabledCount,
                            skills.length,
                          ),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        Expanded(child: _buildList(context, skills)),
      ],
    );
  }

  Widget _buildList(BuildContext context, List<SkillInfo>? skills) {
    if (skills == null && _error == null) {
      return HermesLoadingState(label: context.l10n.skillsLoading);
    }
    if (_error != null && (skills == null || skills.isEmpty)) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    if (skills == null || skills.isEmpty) {
      return HermesEmptyState(
        icon: Icons.extension_outlined,
        title: context.l10n.skillsEmptyTitle,
        description: context.l10n.skillsEmptyDescription,
      );
    }
    final filtered = skills
        .where(
          (s) =>
              _query.isEmpty ||
              s.name.toLowerCase().contains(_query) ||
              (s.description?.toLowerCase().contains(_query) ?? false),
        )
        .toList();
    const uncategorized = '';
    final groups = <String, List<SkillInfo>>{};
    for (final s in filtered) {
      groups.putIfAbsent(s.category ?? uncategorized, () => []).add(s);
    }
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) {
        if (a.key == uncategorized) return 1;
        if (b.key == uncategorized) return -1;
        return a.key.compareTo(b.key);
      });
    if (filtered.isEmpty) {
      return HermesEmptyState(
        icon: Icons.search_off,
        title: context.l10n.skillsNoMatches,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      children: [
        for (final g in sortedGroups) ...[
          HermesMobileSectionLabel(
            title: g.key.isEmpty ? context.l10n.skillsUncategorized : g.key,
          ),
          HermesMobileGroup(
            children: [for (final s in g.value) _row(context, s)],
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, SkillInfo s) {
    final subtitleParts = <String>[
      if (s.description?.isNotEmpty == true) s.description!,
      if (s.usage != null && s.usage! > 0)
        context.l10n.skillsUsageCount(s.usage!),
    ];
    return HermesMobileRow(
      icon: Icons.auto_awesome,
      tone: HermesSemantic.purple,
      title: s.name,
      subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
      onTap: () => _openDetail(s),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _provenanceBadge(s.provenance),
          const SizedBox(width: 8),
          Switch(
            value: s.enabled,
            onChanged: _busy.contains(s.name) ? null : (v) => _toggle(s, v),
          ),
        ],
      ),
    );
  }

  Widget _provenanceBadge(String? provenance) {
    switch (provenance) {
      case 'agent':
        return HermesMobileStatusChip(
          color: HermesSemantic.blue,
          label: context.l10n.skillsLearned,
        );
      case 'hub':
        return HermesMobileStatusChip(
          color: HermesSemantic.green,
          label: context.l10n.skillsProvenanceMarketplace,
        );
      case 'bundled':
        return HermesMobileStatusChip(
          color: HermesSemantic.gray,
          label: context.l10n.skillsBuiltIn,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Bottom sheet: skill content view, with edit + archive for learned
/// (`provenance == 'agent'`) skills — reuses the same generic learning-graph
/// node endpoints the knowledge screen uses, since a learned skill IS a
/// learning-graph node server-side (id == skill name, see
/// `agent/learning_graph.py`'s `build_learning_graph`).
class _SkillDetailSheet extends StatefulWidget {
  final SkillInfo skill;
  final ApiClient ownerApi;
  final String? profile;
  final VoidCallback onChanged;

  const _SkillDetailSheet({
    required this.skill,
    required this.ownerApi,
    required this.profile,
    required this.onChanged,
  });

  @override
  State<_SkillDetailSheet> createState() => _SkillDetailSheetState();
}

class _SkillDetailSheetState extends State<_SkillDetailSheet> {
  late final TextEditingController _controller;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String? _error;
  int _loadGeneration = 0;

  bool _ownsTarget(ConnectionStore connection) {
    return identical(widget.ownerApi, connection.api) &&
        widget.profile == context.read<ProfileScopeStore>().override;
  }

  void _requireTarget(ConnectionStore connection) {
    requireActiveApi(context, connection, widget.ownerApi);
    if (widget.profile != context.read<ProfileScopeStore>().override) {
      throw StateError(context.l10n.backendDisconnected);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadContent();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    final generation = ++_loadGeneration;
    if (!_ownsTarget(connection)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = connectionOfflineErrorCode;
        });
      }
      return;
    }
    try {
      final content = widget.skill.isLearned
          ? (await api.knowledgeNode(
                  widget.skill.name,
                ))['content']?.toString() ??
                ''
          : await api.skillContent(widget.skill.name);
      if (mounted && generation == _loadGeneration && _ownsTarget(connection)) {
        setState(() {
          _controller.text = content;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration && _ownsTarget(connection)) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted && generation == _loadGeneration && _ownsTarget(connection)) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    setState(() => _saving = true);
    try {
      _requireTarget(connection);
      await api.knowledgeNodeUpdate(widget.skill.name, _controller.text);
      if (mounted) {
        _requireTarget(connection);
        setState(() => _editing = false);
        showHermesToast(context, message: context.l10n.skillsSaved);
        widget.onChanged();
      }
    } catch (e) {
      if (mounted && _ownsTarget(connection)) {
        showHermesToast(context, message: context.l10n.skillsSaveFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.skillsArchiveQuestion),
        content: Text(ctx.l10n.skillsArchivePrompt(widget.skill.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.skillsArchive),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      _requireTarget(connection);
      await api.knowledgeNodeDelete(widget.skill.name);
      if (mounted) {
        _requireTarget(connection);
        Navigator.of(context).pop();
        showHermesToast(context, message: context.l10n.skillsArchived);
        widget.onChanged();
      }
    } catch (e) {
      if (mounted && _ownsTarget(connection)) {
        showHermesToast(
          context,
          message: context.l10n.skillsArchiveFailed('$e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.of(context).viewInsets.bottom;
    final isLearned = widget.skill.isLearned;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        HermesSpacing.lg,
        HermesSpacing.md,
        HermesSpacing.lg,
        HermesSpacing.lg + safeArea,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: HermesSemantic.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.auto_awesome,
                  color: HermesSemantic.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.skill.name,
                  style: HermesType.onSurface(
                    HermesType.headline,
                    Theme.of(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLearned)
                IconButton(
                  tooltip: context.l10n.skillsArchive,
                  onPressed: _saving ? null : _archive,
                  icon: const Icon(
                    Icons.archive_outlined,
                    color: HermesSemantic.red,
                  ),
                ),
            ],
          ),
          if (widget.skill.description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              widget.skill.description!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: HermesSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              _error == connectionOfflineErrorCode
                  ? context.l10n.backendDisconnected
                  : _error!,
              style: const TextStyle(color: HermesSemantic.red),
            )
          else if (_editing)
            TextField(
              controller: _controller,
              maxLines: 10,
              minLines: 5,
              decoration: InputDecoration(
                hintText: context.l10n.skillsContent,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
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
                    _controller.text.isEmpty
                        ? context.l10n.skillsNoContent
                        : _controller.text,
                    style: HermesType.onSurface(
                      HermesType.code,
                      Theme.of(context),
                    ),
                  ),
                ),
              ),
            ),
          if (isLearned && !_loading && _error == null) ...[
            const SizedBox(height: HermesSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _editing
                      ? OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _editing = false),
                          child: Text(context.l10n.skillsCancelEdit),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => setState(() => _editing = true),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(context.l10n.commonEdit),
                        ),
                ),
                const SizedBox(width: HermesSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _editing ? (_saving ? null : _save) : null,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _saving
                          ? context.l10n.skillsSaving
                          : context.l10n.commonSave,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
