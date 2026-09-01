/// Insights (spec §107–108): token usage, cost, sessions and tool/skill
/// breakdown over 7/30/90 days — served by `/api/v1/analytics/usage` and
/// `/api/v1/analytics/models`.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with ConnectionReloadMixin<InsightsScreen> {
  static const _ranges = [7, 30, 90];
  int _days = 30;
  Map<String, dynamic>? _usage;
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  ApiClient? get _api => context.read<ConnectionStore>().api;

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
    setState(() {
      _usage = null;
      _loading = true;
      _error = null;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = _api;
    final days = _days;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) {
        setState(() {
          _error = connectionOfflineErrorCode;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final usage = await api.get(
        '/api/v1/analytics/usage',
        query: {'days': '$days'},
      );
      if (mounted &&
          generation == _loadGeneration &&
          days == _days &&
          identical(api, connection.api)) {
        setState(() {
          _usage = (usage as Map).cast<String, dynamic>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          days == _days &&
          identical(api, connection.api)) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.insightsTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Time range ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HermesSpacing.md,
              HermesSpacing.sm,
              HermesSpacing.md,
              0,
            ),
            child: SegmentedButton<int>(
              segments: [
                for (final d in _ranges)
                  ButtonSegment(
                    value: d,
                    label: Text(context.l10n.insightsDays(d)),
                  ),
              ],
              selected: {_days},
              onSelectionChanged: (s) {
                setState(() => _days = s.first);
                _load();
              },
              showSelectedIcon: false,
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return HermesLoadingState(label: context.l10n.insightsLoading(_days));
    }
    if (_error != null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    final usage = _usage;
    if (usage == null) {
      return HermesEmptyState(
        icon: Icons.query_stats,
        title: context.l10n.insightsNoData,
      );
    }
    final totals = (usage['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final daily = (usage['daily'] as List?)?.toList() ?? [];
    final byModel = (usage['by_model'] as List?)?.toList() ?? [];
    // Backend returns tools as a List of {tool, count, percentage} — NOT a Map.
    final tools = (usage['tools'] as List?)?.toList() ?? <dynamic>[];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Totals ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(HermesSpacing.md),
            child: HermesGlassCard(
              radius: HermesRadius.largeCard,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HermesSectionHeader(title: context.l10n.insightsOverview),
                  Row(
                    children: [
                      _stat(
                        context,
                        'Token',
                        _fmtNum(_tokenTotal(totals)),
                        HermesSemantic.purple,
                      ),
                      _stat(
                        context,
                        context.l10n.insightsSessions,
                        _fmtNum(totals['total_sessions'] ?? 0),
                        HermesSemantic.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat(
                        context,
                        context.l10n.insightsApiCalls,
                        _fmtNum(totals['total_api_calls'] ?? 0),
                        HermesSemantic.green,
                      ),
                      _stat(
                        context,
                        context.l10n.insightsCost,
                        '\$${_fmtCost(totals['total_estimated_cost'] ?? 0)}',
                        HermesSemantic.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ── Daily bar chart ──────────────────────────────────────
          if (daily.isNotEmpty) ...[
            HermesSectionHeader(title: context.l10n.insightsDailyUsage),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
              child: HermesGlassCard(
                radius: HermesRadius.card,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: _DailyBarChart(daily: daily),
              ),
            ),
          ],
          // ── By model ─────────────────────────────────────────────
          if (byModel.isNotEmpty) ...[
            HermesSectionHeader(title: context.l10n.insightsModelUsage),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
              child: HermesGlassCard(
                radius: HermesRadius.card,
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (final m in byModel.take(8)) _modelRow(context, m),
                  ],
                ),
              ),
            ),
          ],
          // ── Tools ────────────────────────────────────────────────
          if (tools.isNotEmpty) ...[
            HermesSectionHeader(title: context.l10n.insightsToolCalls),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tools.take(12))
                    _chip(
                      context,
                      (t is Map ? (t['tool'] ?? t['name'] ?? '?') : '?')
                          .toString(),
                      t is Map ? (t['count'] ?? 0) : 0,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _tokenTotal(Map<String, dynamic> totals) {
    final input = (totals['total_input'] ?? 0) as num;
    final output = (totals['total_output'] ?? 0) as num;
    final cache = (totals['total_cache_read'] ?? 0) as num;
    return (input + output + cache).toInt();
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: HermesType.headline.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _modelRow(BuildContext context, dynamic m) {
    final map = (m as Map).cast<String, dynamic>();
    final name = (map['model'] ?? 'unknown').toString();
    final provider = (map['billing_provider'] ?? '').toString();
    final input = (map['input_tokens'] ?? 0) as num;
    final output = (map['output_tokens'] ?? 0) as num;
    final cost = (map['estimated_cost'] ?? 0) as num;
    final sessions = (map['sessions'] ?? 0) as num;
    final providerLabel = provider.isNotEmpty
        ? provider
        : context.l10n.insightsUnknownProvider;
    return ListTile(
      dense: true,
      leading: const Icon(
        Icons.smart_toy_outlined,
        size: 20,
        color: HermesSemantic.purple,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(providerLabel, style: Theme.of(context).textTheme.labelSmall),
          Text(
            context.l10n.insightsModelSummary(
              _fmtNum((input + output).toInt()),
              sessions.toInt(),
              _fmtCost(cost),
            ),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String name, dynamic count) {
    return Tooltip(
      message: name,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - (HermesSpacing.md * 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: HermesSemantic.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.build_outlined,
              size: 14,
              color: HermesSemantic.blue,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${count ?? 0}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: HermesSemantic.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(num? n) {
    final v = (n ?? 0).toInt();
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  String _fmtCost(num n) {
    if (n <= 0) return '0';
    if (n < 0.01) return n.toStringAsExponential(1);
    return n.toStringAsFixed(2);
  }
}

/// Minimal vertical bar chart for the daily token series (no chart dep).
class _DailyBarChart extends StatelessWidget {
  final List<dynamic> daily;

  const _DailyBarChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    final values = <(String, double)>[
      for (final d in daily)
        (
          (d as Map)['day']?.toString() ?? '',
          ((((d['input_tokens'] ?? 0) as num) +
                  ((d['output_tokens'] ?? 0) as num))
              .toDouble()),
        ),
    ];
    final maxV = values.fold<double>(0, (m, v) => v.$2 > m ? v.$2 : m);
    final shown = values.length > 14
        ? values.sublist(values.length - 14)
        : values;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return SizedBox(
      height: 105 + (18 * textScale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (day, v) in shown)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      day.length > 5 ? day.substring(5) : day, // MM-DD
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(fontSize: 9),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: maxV <= 0 ? 2 : (v / maxV) * 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
