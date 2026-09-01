/// Command center: live status, usage analytics, and maintenance actions.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/clipboard.dart';
import '../core/connection_reload_mixin.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';

class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen>
    with
        SingleTickerProviderStateMixin,
        ConnectionReloadMixin<CommandCenterScreen> {
  late final TabController _tabController;

  Map<String, dynamic>? _status;
  dynamic _logs;
  bool _loading = true;
  bool _restarting = false;
  String? _error;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      _load();
    }
  }

  void _reloadForConnection() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _status = null;
      _logs = null;
      _loading = true;
      _restarting = false;
      _error = null;
    });
    _load();
  }

  Future<void> _load() async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final generation = ++_loadGeneration;
    if (api == null) {
      setState(() {
        _loading = false;
        _error = connectionOfflineErrorCode;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    Map<String, dynamic>? status;
    dynamic logs;
    String? error;
    try {
      status = await api.status();
    } catch (e) {
      error = l10n.commandStatusLoadFailed('$e');
    }
    if (api.capabilities.serverLogs) {
      try {
        logs = await api.getLogs();
      } catch (e) {
        error = [
          error,
          l10n.commandLogsLoadFailed('$e'),
        ].whereType<String>().join('\n');
      }
    }
    if (!mounted ||
        generation != _loadGeneration ||
        !identical(api, connection.api)) {
      return;
    }
    setState(() {
      _status = status;
      _logs = logs;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _restart() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final generation = _mutationGeneration;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsRestartBackend),
        content: Text(context.l10n.commandRestartWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonRestart),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _restarting = true);
    try {
      requireActiveApi(context, connection, api);
      final result = await api.restartBackend();
      if (!mounted) return;
      if (generation != _mutationGeneration) return;
      requireActiveApi(context, connection, api);
      showHermesToast(
        context,
        message: context.l10n.commandRestartResult(
          '${result['status'] ?? result}',
        ),
        kind: HermesToastKind.success,
      );
      await _load();
    } catch (e) {
      if (!mounted || generation != _mutationGeneration) return;
      showHermesToast(
        context,
        message: context.l10n.settingsBackendRestartFailed('$e'),
        kind: HermesToastKind.error,
      );
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _restarting = false);
      }
    }
  }

  String _formatLogs(dynamic data) {
    final empty = context.l10n.commandNoLogs;
    if (data == null) return empty;
    if (data is String) return data.isEmpty ? empty : data;
    if (data is List) {
      return data.isEmpty ? empty : data.map((e) => '$e').join('\n');
    }
    if (data is Map) {
      final lines =
          data['lines'] ?? data['content'] ?? data['log'] ?? data['logs'];
      if (lines is List) {
        return lines.isEmpty ? empty : lines.map((e) => '$e').join('\n');
      }
      if (lines is String) return lines.isEmpty ? empty : lines;
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return '$data';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.commandCenterTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.commandStatusTab),
            Tab(text: context.l10n.commandUsageTab),
            Tab(text: context.l10n.commandMaintenanceTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatusTab(context),
          const _UsagePanel(),
          const _MaintenancePanel(),
        ],
      ),
    );
  }

  Widget _buildStatusTab(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final backend =
        (_status?['backend'] as Map?)?.cast<String, dynamic>() ?? {};
    final runtime =
        (_status?['runtime'] as Map?)?.cast<String, dynamic>() ?? {};
    final running = backend['running'] == true || _status?['status'] == 'ok';
    final statusColor = running
        ? hermesSemantic(
            context,
            HermesSemantic.green,
            HermesSemanticDark.green,
          )
        : theme.colorScheme.error;
    final capabilities = context.watch<ConnectionStore>().api?.capabilities;
    final canReadLogs = capabilities?.serverLogs == true;
    final canRestart = capabilities?.backendRestart == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        HermesMobileCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.commandBackendProcess,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                            runtime['kind']?.toString(),
                            backend['hermes_version']?.toString(),
                          ]
                          .whereType<String>()
                          .where((v) => v.isNotEmpty)
                          .join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              HermesMobileStatusChip(
                label: running
                    ? context.l10n.commonRunning
                    : context.l10n.commandStopped,
                color: statusColor,
              ),
            ],
          ),
        ),
        if (canReadLogs) ...[
          HermesMobileSectionLabel(title: context.l10n.commandLiveLogs),
          Container(
            height: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HermesPalette.of(context).codeBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HermesPalette.of(context).border),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _formatLogs(_logs),
                style: HermesType.code.copyWith(
                  color: HermesPalette.of(context).text2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (canRestart)
          OutlinedButton.icon(
            onPressed: _restarting ? null : _restart,
            icon: _restarting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restart_alt),
            label: Text(
              _restarting
                  ? context.l10n.agentRestarting
                  : context.l10n.settingsRestartBackend,
            ),
          ),
        HermesMobileSectionLabel(title: context.l10n.commandDiagnostics),
        HermesMobileGroup(
          children: [
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                leading: const Icon(Icons.monitor_heart_outlined, size: 20),
                title: Text(context.l10n.commandSystemStatus),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: SelectableText(
                      _status == null
                          ? context.l10n.commandNoStatusData
                          : const JsonEncoder.withIndent(' ').convert(_status),
                      style: HermesType.code,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Usage tab — period-selectable analytics (stat tiles, a daily stacked bar
/// chart, and top-models / top-skills lists), mirroring desktop's
/// `UsagePanel` (apps/desktop/src/app/command-center/index.tsx).
class _UsagePanel extends StatefulWidget {
  const _UsagePanel();

  @override
  State<_UsagePanel> createState() => _UsagePanelState();
}

class _UsagePanelState extends State<_UsagePanel>
    with AutomaticKeepAliveClientMixin, ConnectionReloadMixin<_UsagePanel> {
  static const _periods = [7, 30, 90];

  int _days = 30;
  AnalyticsUsage? _usage;
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;
  bool _didInitialLoad = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _load);
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      _load();
    }
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
      setState(() {
        _loading = false;
        _error = connectionOfflineErrorCode;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final usage = await api.analyticsUsageTyped(days: _days);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _usage = usage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = context.l10n.commandUsageLoadFailed('$e');
        _loading = false;
      });
    }
  }

  static String _compactNumber(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final palette = HermesPalette.of(context);
    final usage = _usage;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final p in _periods)
                ChoiceChip(
                  label: Text(context.l10n.commandDays(p)),
                  selected: _days == p,
                  onSelected: (sel) {
                    if (!sel || _days == p) return;
                    setState(() => _days = p);
                    _load();
                  },
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (usage != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _UsageStat(
                    label: context.l10n.commandSessions,
                    value: '${usage.totals?.totalSessions ?? 0}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _UsageStat(
                    label: context.l10n.commandApiCalls,
                    value: usage.totals?.totalApiCalls != null
                        ? _compactNumber(usage.totals!.totalApiCalls!)
                        : '—',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _UsageStat(
                    label: context.l10n.commandTokensInOut,
                    value:
                        '${usage.totals?.totalInput != null ? _compactNumber(usage.totals!.totalInput!) : '—'}'
                        ' / '
                        '${usage.totals?.totalOutput != null ? _compactNumber(usage.totals!.totalOutput!) : '—'}',
                  ),
                ),
              ],
            ),
            HermesMobileSectionLabel(title: context.l10n.commandDailyUsage),
            HermesMobileCard(
              child: usage.daily.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(context.l10n.commandNoUsageData),
                      ),
                    )
                  : _DailyUsageChart(daily: usage.daily),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TopList(
                    title: context.l10n.commandTopModels,
                    empty: context.l10n.agentNoData,
                    items: (() {
                      final sorted = [...usage.byModel]
                        ..sort(
                          (a, b) => (b.inputTokens + b.outputTokens).compareTo(
                            a.inputTokens + a.outputTokens,
                          ),
                        );
                      return sorted
                          .take(6)
                          .map(
                            (m) => (
                              m.model.isEmpty
                                  ? context.l10n.commonUnknownError
                                  : m.model,
                              _compactNumber(m.inputTokens + m.outputTokens),
                            ),
                          )
                          .toList();
                    })(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TopList(
                    title: context.l10n.commandTopSkills,
                    empty: context.l10n.agentNoData,
                    items: usage.topSkills
                        .take(6)
                        .map(
                          (s) => (
                            s.skill.isEmpty
                                ? context.l10n.commonUnknownError
                                : s.skill,
                            context.l10n.commandUseCount(s.totalCount),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  context.l10n.commandNoUsageData,
                  style: TextStyle(color: palette.text3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UsageStat extends StatelessWidget {
  const _UsageStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return HermesMobileCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, color: palette.text3)),
        ],
      ),
    );
  }
}

class _DailyUsageChart extends StatelessWidget {
  const _DailyUsageChart({required this.daily});

  final List<AnalyticsDailyEntry> daily;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final maxTotal = daily
        .map((d) => d.inputTokens + d.outputTokens)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final inputColor = hermesSemantic(
      context,
      HermesSemantic.blue,
      HermesSemanticDark.blue,
    );
    final outputColor = hermesSemantic(
      context,
      HermesSemantic.purple,
      HermesSemanticDark.purple,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in daily)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: context.l10n.commandChartTooltip(
                        d.day,
                        d.inputTokens,
                        d.outputTokens,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (maxTotal > 0 && d.outputTokens > 0)
                            Container(
                              height: (110 * d.outputTokens / maxTotal).clamp(
                                0,
                                110,
                              ),
                              color: outputColor,
                            ),
                          if (maxTotal > 0 && d.inputTokens > 0)
                            Container(
                              height: (110 * d.inputTokens / maxTotal).clamp(
                                0,
                                110,
                              ),
                              color: inputColor,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              daily.isNotEmpty ? daily.first.day : '',
              style: TextStyle(fontSize: 10.5, color: palette.text3),
            ),
            Text(
              daily.isNotEmpty ? daily.last.day : '',
              style: TextStyle(fontSize: 10.5, color: palette.text3),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _LegendDot(
              color: inputColor,
              label: context.l10n.commandInputTokens,
            ),
            const SizedBox(width: 14),
            _LegendDot(
              color: outputColor,
              label: context.l10n.commandOutputTokens,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, color: palette.text3)),
      ],
    );
  }
}

class _TopList extends StatelessWidget {
  const _TopList({
    required this.title,
    required this.items,
    required this.empty,
  });

  final String title;
  final List<(String, String)> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HermesMobileSectionLabel(title: title, top: 0),
          HermesMobileCard(
            child: items.isEmpty
                ? Text(
                    empty,
                    style: TextStyle(color: palette.text3, fontSize: 12.5),
                  )
                : Column(
                    children: [
                      for (final (name, value) in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: palette.text3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Maintenance tab — doctor / security audit / backup (spawned background
/// actions tailed via `actionStatus`) and debug share (synchronous, returns
/// shareable paste URLs). Mirrors desktop's maintenance.tsx, minus the
/// memory status/reset controls which mobile already exposes via its
/// dedicated memory screen.
class _MaintenancePanel extends StatefulWidget {
  const _MaintenancePanel();

  @override
  State<_MaintenancePanel> createState() => _MaintenancePanelState();
}

class _MaintenancePanelState extends State<_MaintenancePanel> {
  String? _busyAction;
  int _actionGeneration = 0;

  /// Writes to [logNotifier] can outlive it: the log sheet may be closed
  /// (and the notifier disposed with it) by the user while this polling
  /// loop is still running. A disposed `ValueNotifier` throws on `.value =`,
  /// so swallow that one case rather than crash on an already-dismissed sheet.
  void _setLog(ValueNotifier<String> logNotifier, String value) {
    try {
      logNotifier.value = value;
    } catch (_) {}
  }

  Future<void> _runSpawned(
    String actionId,
    String label,
    Future<Map<String, dynamic>> Function(ApiClient api) start,
  ) async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final generation = ++_actionGeneration;
    setState(() => _busyAction = actionId);
    final logNotifier = ValueNotifier<String>(l10n.commandStarting(label));
    // The log sheet can still be open long after this action settles (that's
    // the point of a live tail), so the sheet's own close — not this
    // method's finally — owns disposal; disposing early would crash
    // ValueListenableBuilder when the sheet is eventually dismissed.
    unawaited(
      _showLogSheet(
        context,
        label,
        logNotifier,
      ).whenComplete(logNotifier.dispose),
    );
    try {
      requireActiveApi(context, connection, api);
      final result = await start(api);
      if (!mounted || generation != _actionGeneration) return;
      requireActiveApi(context, connection, api);
      final name = result['name']?.toString();
      if (name == null || name.isEmpty) {
        throw StateError(l10n.commandMissingActionName);
      }
      Map<String, dynamic> status = const {};
      while (mounted) {
        if (!mounted || generation != _actionGeneration) return;
        requireActiveApi(context, connection, api);
        status = await api.actionStatus(name, lines: 80);
        if (!mounted || generation != _actionGeneration) return;
        requireActiveApi(context, connection, api);
        final lines = (status['lines'] as List?)?.join('\n') ?? '';
        _setLog(logNotifier, lines.isEmpty ? l10n.commandNoOutput : lines);
        if (status['running'] != true) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      final exitCode = (status['exit_code'] as num?)?.toInt();
      if (!mounted || generation != _actionGeneration) return;
      requireActiveApi(context, connection, api);
      if (exitCode != null && exitCode != 0) {
        showHermesToast(
          context,
          message: context.l10n.commandActionExitFailed(label, exitCode),
          kind: HermesToastKind.error,
        );
      } else {
        showHermesToast(
          context,
          message: context.l10n.commandActionComplete(label),
          kind: HermesToastKind.success,
        );
      }
    } catch (e) {
      _setLog(logNotifier, l10n.commandLogError(logNotifier.value, '$e'));
      if (mounted && generation == _actionGeneration) {
        showHermesToast(
          context,
          message: context.l10n.commandActionFailed(label, '$e'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _actionGeneration) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _runDebugShare() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final generation = ++_actionGeneration;
    setState(() => _busyAction = 'debug-share');
    Map<String, dynamic>? result;
    Object? error;
    try {
      requireActiveApi(context, connection, api);
      result = await api.runDebugShare();
      if (!mounted || generation != _actionGeneration) return;
      requireActiveApi(context, connection, api);
    } catch (e) {
      error = e;
    }
    if (!mounted || generation != _actionGeneration) return;
    setState(() => _busyAction = null);
    if (error != null) {
      showHermesToast(
        context,
        message: context.l10n.commandDebugShareFailed('$error'),
        kind: HermesToastKind.error,
      );
      return;
    }
    await _showDebugShareResult(result!);
  }

  Future<void> _showDebugShareResult(Map<String, dynamic> result) {
    final urls = (result['urls'] as Map?)?.cast<String, dynamic>() ?? {};
    final failures =
        (result['failures'] as Map?)?.cast<String, dynamic>() ?? {};
    final redacted = result['redacted'] == true;
    final autoDelete = (result['auto_delete_seconds'] as num?)?.toInt();
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.commandDebugShare),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  redacted
                      ? context.l10n.commandLogsRedacted
                      : context.l10n.commandLogsNotRedacted,
                ),
                if (autoDelete != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.commandAutoDeleteHours(
                      (autoDelete / 3600).toStringAsFixed(1),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                for (final entry in urls.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SelectableText(
                                '${entry.value}',
                                style: HermesType.code,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.profilesCopy,
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () => copyTextOrNotify(
                            ctx,
                            '${entry.value}',
                            successMessage: ctx.l10n.commonCopied,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (failures.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.commandPartialUploadFailed,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                  for (final entry in failures.entries)
                    Text(
                      '${entry.key}: ${entry.value}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogSheet(
    BuildContext context,
    String label,
    ValueNotifier<String> logNotifier,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(context.l10n.commonClose),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: logNotifier,
                  builder: (ctx, value, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HermesPalette.of(ctx).codeBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HermesPalette.of(ctx).border),
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: SelectableText(
                        value,
                        style: HermesType.code.copyWith(
                          color: HermesPalette.of(ctx).text2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busyAction != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        HermesMobileSectionLabel(
          title: context.l10n.commandDiagnosticsMaintenance,
          top: 0,
        ),
        HermesMobileGroup(
          children: [
            _ActionRow(
              icon: Icons.medical_services_outlined,
              title: context.l10n.commandRunDoctor,
              subtitle: context.l10n.commandRunDoctorDescription,
              busy: _busyAction == 'doctor',
              disabled: busy,
              onTap: () => _runSpawned(
                'doctor',
                context.l10n.commandDoctor,
                (api) => api.runDoctor(),
              ),
            ),
            _ActionRow(
              icon: Icons.security_outlined,
              title: context.l10n.commandSecurityAudit,
              subtitle: context.l10n.commandSecurityAuditDescription,
              busy: _busyAction == 'security-audit',
              disabled: busy,
              onTap: () => _runSpawned(
                'security-audit',
                context.l10n.commandSecurityAudit,
                (api) => api.runSecurityAudit(),
              ),
            ),
            _ActionRow(
              icon: Icons.archive_outlined,
              title: context.l10n.commandBackupNow,
              subtitle: context.l10n.commandBackupDescription,
              busy: _busyAction == 'backup',
              disabled: busy,
              onTap: () => _runSpawned(
                'backup',
                context.l10n.commandBackup,
                (api) => api.runBackup(),
              ),
            ),
            _ActionRow(
              icon: Icons.bug_report_outlined,
              title: context.l10n.commandDebugShare,
              subtitle: context.l10n.commandDebugShareDescription,
              busy: _busyAction == 'debug-share',
              disabled: busy,
              onTap: _runDebugShare,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: palette.text3),
        ),
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right, size: 18),
        enabled: !disabled,
        onTap: disabled ? null : onTap,
      ),
    );
  }
}
