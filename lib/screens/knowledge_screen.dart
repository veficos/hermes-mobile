/// Knowledge (spec §96–100, degraded): backend learning graph (`/api/learning/graph`)
/// rendered as searchable/filterable node list with detail edit + delete.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_reload_mixin.dart';
import '../core/api_client.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen>
    with ConnectionReloadMixin<KnowledgeScreen> {
  Map<String, dynamic>? _graph;
  String? _error;
  bool _busy = false;
  String _query = '';
  String? _kindFilter; // null = all, 'skill' | 'memory'
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _load);
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
    if (mounted) setState(() => _busy = true);
    try {
      final graph = await api.knowledgeGraph();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _graph = graph;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  List<Map<String, dynamic>> get _nodes {
    final nodes = (_graph?['nodes'] as List?) ?? [];
    final q = _query.trim().toLowerCase();
    return nodes.map((e) => (e as Map).cast<String, dynamic>()).where((n) {
      if (_kindFilter != null && n['kind'] != _kindFilter) return false;
      if (q.isEmpty) return true;
      final label = (n['label'] ?? '').toString().toLowerCase();
      final category = (n['category'] ?? '').toString().toLowerCase();
      return label.contains(q) || category.contains(q);
    }).toList();
  }

  Future<void> _openNode(Map<String, dynamic> node) async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    try {
      final detail = await api.knowledgeNode(node['id'].toString());
      if (!mounted || !identical(api, connection.api)) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(HermesRadius.sheet),
          ),
        ),
        builder: (_) => _NodeDetailSheet(
          node: node,
          detail: detail,
          ownerApi: api,
          onChanged: _load,
        ),
      );
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        showHermesToast(context, message: l10n.knowledgeLoadDetailFailed('$e'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.configCenterKnowledgeTab),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_graph == null && _error == null) {
      return HermesLoadingState(label: context.l10n.knowledgeLoading);
    }
    if (_error != null && _graph == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    if (_graph == null) {
      return HermesEmptyState(
        icon: Icons.psychology_outlined,
        title: context.l10n.knowledgeNoData,
      );
    }
    final nodes = _nodes;
    final memoryCards = (_graph?['memory'] as List?) ?? [];
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HermesSpacing.md,
                HermesSpacing.md,
                HermesSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    HermesNoticeBar(
                      message: _error == connectionOfflineErrorCode
                          ? context.l10n.backendDisconnected
                          : _error!,
                      color: HermesSemantic.red,
                      icon: Icons.error_outline,
                      onTap: _load,
                    ),
                    const SizedBox(height: HermesSpacing.sm),
                  ],
                  // ── Search ───────────────────────────────────────
                  TextField(
                    decoration: InputDecoration(
                      hintText: context.l10n.knowledgeSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HermesRadius.card),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: HermesSpacing.md),
                  // ── Kind filter chips ────────────────────────────
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip(context.l10n.commonAll, null),
                      _filterChip(context.l10n.starmapSkillLegend, 'skill'),
                      _filterChip(context.l10n.starmapMemoryLegend, 'memory'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (memoryCards.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                HermesSpacing.md,
                HermesSpacing.lg,
                HermesSpacing.md,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HermesSectionHeader(
                      title: context.l10n.knowledgeMemorySummary(
                        memoryCards.length,
                      ),
                    ),
                    for (final m in memoryCards)
                      _memoryCard(context, (m as Map).cast<String, dynamic>()),
                  ],
                ),
              ),
            ),
          if (nodes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: HermesEmptyState(
                icon: Icons.search_off,
                title: context.l10n.knowledgeNoMatches,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(HermesSpacing.md),
              sliver: SliverList.separated(
                itemCount: nodes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: HermesSpacing.sm),
                itemBuilder: (context, i) => _nodeRow(context, nodes[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _kindFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _kindFilter = value),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _nodeRow(BuildContext context, Map<String, dynamic> node) {
    final kind = (node['kind'] ?? '').toString();
    final color = kind == 'skill' ? HermesSemantic.blue : HermesSemantic.purple;
    final category = (node['category'] ?? '').toString();
    final useCount =
        int.tryParse((node['useCount'] ?? node['use_count'] ?? 0).toString()) ??
        0;
    final state = (node['state'] ?? '').toString();
    final stateLabel = switch (state) {
      'active' => context.l10n.knowledgeStateActive,
      'inactive' => context.l10n.knowledgeStateInactive,
      'archived' => context.l10n.taskStatusArchived,
      _ => state,
    };
    final meta = category.isNotEmpty
        ? context.l10n.knowledgeNodeMeta(category, useCount, stateLabel)
        : context.l10n.knowledgeNodeMetaNoCategory(useCount, stateLabel);
    return HermesGlassCard(
      radius: HermesRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            kind == 'skill' ? Icons.lightbulb_outline : Icons.bookmark_outline,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          (node['label'] ?? '').toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          meta,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _openNode(node),
      ),
    );
  }

  Widget _memoryCard(BuildContext context, Map<String, dynamic> m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.sm),
      child: HermesGlassCard(
        radius: HermesRadius.card,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (m['title'] ?? '').toString(),
              style: HermesType.onSurface(
                HermesType.headline,
                Theme.of(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              (m['body'] ?? '').toString(),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: node detail (content) + edit inline + delete.
class _NodeDetailSheet extends StatefulWidget {
  final Map<String, dynamic> node;
  final Map<String, dynamic> detail;
  final ApiClient ownerApi;
  final VoidCallback onChanged;

  const _NodeDetailSheet({
    required this.node,
    required this.detail,
    required this.ownerApi,
    required this.onChanged,
  });

  @override
  State<_NodeDetailSheet> createState() => _NodeDetailSheetState();
}

class _NodeDetailSheetState extends State<_NodeDetailSheet> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.detail['content'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    setState(() => _saving = true);
    try {
      requireActiveApi(context, connection, api);
      await api.knowledgeNodeUpdate(
        widget.node['id'].toString(),
        _controller.text,
      );
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.knowledgeSaved)));
        widget.onChanged();
      }
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        showHermesToast(context, message: l10n.knowledgeSaveFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.knowledgeDeleteQuestion),
        content: Text(
          l10n.knowledgeDeleteDescription(
            (widget.node['label'] ?? '').toString(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      requireActiveApi(context, connection, api);
      await api.knowledgeNodeDelete(widget.node['id'].toString());
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.knowledgeDeleted)));
        widget.onChanged();
      }
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        showHermesToast(context, message: l10n.knowledgeDeleteFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = (widget.node['kind'] ?? '').toString();
    final color = kind == 'skill' ? HermesSemantic.blue : HermesSemantic.purple;
    final safeArea = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.35,
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    kind == 'skill'
                        ? Icons.lightbulb_outline
                        : Icons.bookmark_outline,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (widget.node['label'] ?? '').toString(),
                    style: HermesType.onSurface(
                      HermesType.headline,
                      Theme.of(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: _editing
                      ? l10n.knowledgeCancelEditing
                      : l10n.commonEdit,
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          if (_editing) {
                            _controller.text = (widget.detail['content'] ?? '')
                                .toString();
                          }
                          _editing = !_editing;
                        }),
                  icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: l10n.commonDelete,
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: HermesSemantic.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HermesSpacing.md),
            if (_editing)
              TextField(
                controller: _controller,
                maxLines: 8,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.starmapContent,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              )
            else
              Container(
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
                      ? l10n.skillsNoContent
                      : _controller.text,
                  style: HermesType.onSurface(
                    HermesType.code,
                    Theme.of(context),
                  ),
                ),
              ),
            const SizedBox(height: HermesSpacing.md),
            if (_editing)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? l10n.starmapSaving : l10n.commonSave),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
