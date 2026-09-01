/// Scheduler (spec §82–84, Phase 6 style): cron job list + create/edit editor
/// with a Cron Builder (frequency presets + raw expression) + run history.
/// Backed by `/api/v1/cron` CRUD.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';

// Desktop refreshes the job list on a live `$cronChangeTick` gateway event;
// mobile has no equivalent event wired yet, so this polls instead — same
// practical outcome (a running/paused/errored job's status catches up
// without a manual pull-to-refresh) via a much simpler mechanism.
const _autoRefreshInterval = Duration(seconds: 20);

// Status-pip color per job state — mirrors desktop's STATE_DOT
// (app/cron/job-state.ts) so the same seven states read the same way.
const Map<String, Color> _cronStateColor = {
  'completed': HermesSemantic.gray,
  'disabled': HermesSemantic.gray,
  'enabled': HermesSemantic.blue,
  'error': HermesSemantic.red,
  'paused': HermesSemantic.orange,
  'running': HermesSemantic.blue,
  'scheduled': HermesSemantic.blue,
};

String _cronStateLabel(BuildContext context, String state) => switch (state) {
  'completed' => context.l10n.cronStateCompleted,
  'disabled' => context.l10n.cronStateDisabled,
  'enabled' => context.l10n.cronStateEnabled,
  'error' => context.l10n.cronStateError,
  'paused' => context.l10n.cronStatePaused,
  'running' => context.l10n.cronStateRunning,
  'scheduled' => context.l10n.cronStateScheduled,
  _ => state,
};

class CronScreen extends StatefulWidget {
  const CronScreen({super.key});

  @override
  State<CronScreen> createState() => _CronScreenState();
}

class _CronScreenState extends State<CronScreen>
    with ConnectionReloadMixin<CronScreen> {
  List<CronJob>? _jobs;
  String? _error;
  Timer? _refreshTimer;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  ApiClient? _loadedApi;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(_autoRefreshInterval, (_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _jobs = null;
      _loadedApi = null;
      _error = null;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) {
        setState(() {
          _jobs = null;
          _loadedApi = null;
          _error = connectionOfflineErrorCode;
        });
      }
      return;
    }
    try {
      final jobs = await api.cronJobs();
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() {
        _jobs = jobs;
        _loadedApi = api;
        _error = null;
      });
    } catch (e) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, connection.api)) {
        return;
      }
      // A background poll failing (e.g. a transient network blip) shouldn't
      // blank an already-populated list with an error screen.
      if (_jobs == null) setState(() => _error = '$e');
    }
  }

  Future<void> _toggle(CronJob job, bool enabled) async {
    final connection = context.read<ConnectionStore>();
    final api = _loadedApi;
    if (api == null || !identical(connection.api, api)) {
      showHermesToast(
        context,
        message: context.l10n.backendDisconnected,
        kind: HermesToastKind.error,
      );
      return;
    }
    final generation = _mutationGeneration;
    try {
      await api.setCronEnabled(job.id, enabled);
      if (mounted &&
          generation == _mutationGeneration &&
          identical(connection.api, api)) {
        _load();
      }
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          identical(connection.api, api)) {
        showHermesToast(
          context,
          message: context.l10n.cronUpdateFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _openEditor([CronJob? job, ApiClient? ownerApi]) async {
    final connection = context.read<ConnectionStore>();
    final api = ownerApi ?? (job == null ? connection.api : _loadedApi);
    if (api == null || !identical(connection.api, api)) {
      showHermesToast(
        context,
        message: context.l10n.backendDisconnected,
        kind: HermesToastKind.error,
      );
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (_) => _CronEditorSheet(job: job, ownerApi: api),
    );
    if (saved == true && mounted && identical(connection.api, api)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _jobs;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cronTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'new-cron',
        onPressed: () => _openEditor(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context, jobs),
    );
  }

  Widget _buildBody(BuildContext context, List<CronJob>? jobs) {
    if (_error != null && (jobs == null || jobs.isEmpty)) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    if (jobs == null) {
      return HermesLoadingState(label: context.l10n.cronLoading);
    }
    if (jobs.isEmpty) {
      return HermesEmptyState(
        icon: Icons.schedule_outlined,
        title: context.l10n.cronEmptyTitle,
        description: context.l10n.cronEmptyDescription,
        primaryLabel: context.l10n.cronNew,
        onPrimary: () => _openEditor(),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(HermesSpacing.md),
              child: HermesNoticeBar(
                message: _error == connectionOfflineErrorCode
                    ? context.l10n.backendDisconnected
                    : _error!,
                color: HermesSemantic.red,
                icon: Icons.error_outline,
                onTap: _load,
              ),
            ),
          for (final j in jobs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: HermesGlassCard(
                radius: HermesRadius.card,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                onTap: () => _openEditor(j),
                onLongPress: () => _showMenu(j),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    j.enabled ? Icons.schedule : Icons.schedule_send_outlined,
                    color:
                        _cronStateColor[j.effectiveState] ??
                        HermesSemantic.gray,
                  ),
                  title: Text(
                    (j.name?.isNotEmpty == true ? j.name! : j.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CronStateBadge(state: j.effectiveState),
                      const SizedBox(height: 2),
                      if (j.schedule != null)
                        Text(
                          j.scheduleDisplay ?? j.schedule!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (j.prompt != null)
                        Text(
                          j.prompt!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (j.lastRunAt != null)
                        Text(
                          context.l10n.cronLastRun(j.lastRunAt!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (j.nextRunAt != null)
                        Text(
                          context.l10n.cronNextRun(j.nextRunAt!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (j.lastError?.isNotEmpty == true)
                        Text(
                          j.lastError!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: HermesSemantic.red),
                        ),
                    ],
                  ),
                  trailing: Switch(
                    value: j.enabled,
                    onChanged: (v) => _toggle(j, v),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMenu(CronJob job) {
    final ownerApi = _loadedApi;
    if (ownerApi == null) return;
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.commonEdit),
              onTap: () {
                Navigator.of(ctx).pop();
                _openEditor(job, ownerApi);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(context.l10n.cronRunHistory),
              onTap: () {
                Navigator.of(ctx).pop();
                _showRuns(job, ownerApi);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(context.l10n.cronTriggerNow),
              onTap: () async {
                Navigator.of(ctx).pop();
                final connection = context.read<ConnectionStore>();
                if (!identical(connection.api, ownerApi)) {
                  showHermesToast(
                    context,
                    message: context.l10n.backendDisconnected,
                    kind: HermesToastKind.error,
                  );
                  return;
                }
                try {
                  await ownerApi.cronTrigger(job.id);
                  if (mounted && identical(connection.api, ownerApi)) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(context.l10n.cronTriggered)),
                    );
                  }
                } catch (e) {
                  if (mounted && identical(connection.api, ownerApi)) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.cronTriggerFailed('$e')),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: HermesSemantic.red,
              ),
              title: Text(
                context.l10n.commonDelete,
                style: const TextStyle(color: HermesSemantic.red),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: Text(context.l10n.cronDeleteQuestion),
                    content: Text(
                      context.l10n.cronDeletePrompt(job.name ?? job.id),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dctx).pop(false),
                        child: Text(context.l10n.commonCancel),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: HermesSemantic.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(dctx).pop(true),
                        child: Text(context.l10n.commonDelete),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  if (!mounted) return;
                  final connection = context.read<ConnectionStore>();
                  if (!identical(connection.api, ownerApi)) {
                    showHermesToast(
                      context,
                      message: context.l10n.backendDisconnected,
                      kind: HermesToastKind.error,
                    );
                    return;
                  }
                  try {
                    await ownerApi.cronDelete(job.id);
                    if (mounted && identical(connection.api, ownerApi)) {
                      _load();
                    }
                  } catch (e) {
                    if (mounted && identical(connection.api, ownerApi)) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.cronDeleteFailed('$e')),
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRuns(CronJob job, ApiClient ownerApi) async {
    final connection = context.read<ConnectionStore>();
    if (!identical(connection.api, ownerApi)) {
      showHermesToast(
        context,
        message: context.l10n.backendDisconnected,
        kind: HermesToastKind.error,
      );
      return;
    }
    late final List<Map<String, dynamic>> runs;
    try {
      runs = await ownerApi.cronRuns(job.id);
    } catch (error) {
      if (mounted && identical(connection.api, ownerApi)) {
        showHermesToast(
          context,
          message: context.l10n.cronRunsLoadFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
      return;
    }
    if (!mounted || !identical(connection.api, ownerApi)) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                context.l10n.cronRunHistoryTitle(job.name ?? job.id),
                style: HermesType.onSurface(
                  HermesType.headline,
                  Theme.of(context),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: runs.isEmpty
                  ? HermesEmptyState(
                      icon: Icons.history,
                      title: context.l10n.cronNoRuns,
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: runs.length,
                      itemBuilder: (_, i) {
                        final r = runs[i];
                        final ok =
                            r['success'] != false && r['status'] != 'failed';
                        return ListTile(
                          dense: true,
                          onTap: () => _showRunDetail(r, ok: ok),
                          leading: Icon(
                            ok
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: ok
                                ? HermesSemantic.green
                                : HermesSemantic.red,
                          ),
                          title: Text(
                            r['scheduled_at']?.toString() ??
                                r['started_at']?.toString() ??
                                '—',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            r['status']?.toString() ??
                                r['output']?.toString() ??
                                '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRunDetail(Map<String, dynamic> run, {required bool ok}) {
    final l10n = context.l10n;
    final rows = <MapEntry<String, String>>[
      if (run['scheduled_at'] != null)
        MapEntry(l10n.cronRunScheduledAt, '${run['scheduled_at']}'),
      if (run['started_at'] != null)
        MapEntry(l10n.cronRunStartedAt, '${run['started_at']}'),
      if (run['finished_at'] != null)
        MapEntry(l10n.cronRunFinishedAt, '${run['finished_at']}'),
      if (run['status'] != null)
        MapEntry(l10n.cronRunStatus, '${run['status']}'),
    ];
    final output = (run['output'] ?? run['error'] ?? '').toString();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ok ? l10n.cronRunDetailTitle : l10n.cronRunDetailFailedTitle,
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in rows) ...[
                  Text(row.key, style: Theme.of(ctx).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  SelectableText(row.value),
                  const SizedBox(height: 8),
                ],
                if (output.isNotEmpty) ...[
                  Text(
                    l10n.cronRunOutput,
                    style: Theme.of(ctx).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
  }
}

/// One of the seven job states (completed/disabled/enabled/error/paused/
/// running/scheduled), colored to match desktop's STATE_DOT.
class _CronStateBadge extends StatelessWidget {
  final String state;

  const _CronStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = _cronStateColor[state] ?? HermesSemantic.gray;
    final label = _cronStateLabel(context, state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Cron editor with a frequency builder (spec §84) + raw cron input.
class _CronEditorSheet extends StatefulWidget {
  final CronJob? job;
  final ApiClient ownerApi;
  const _CronEditorSheet({this.job, required this.ownerApi});

  @override
  State<_CronEditorSheet> createState() => _CronEditorSheetState();
}

class _CronEditorSheetState extends State<_CronEditorSheet> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.job?.name ?? '',
  );
  late final TextEditingController _promptCtrl = TextEditingController(
    text: widget.job?.prompt ?? '',
  );
  late final TextEditingController _cronCtrl = TextEditingController(
    text: widget.job?.schedule ?? '0 9 * * *',
  );
  late final TextEditingController _scriptCtrl = TextEditingController(
    text: widget.job?.script ?? '',
  );
  bool _saving = false;
  bool _loadingTargets = true;
  bool _loadingBlueprints = true;
  bool _loadingModels = true;
  List<CronDeliveryTarget> _targets = const [];
  List<CronBlueprint> _blueprints = const [];
  List<ModelInfo> _modelProviders = const [];
  CronBlueprint? _blueprint;
  Map<String, String> _slotValues = {};
  String? _inlineError;
  late String _deliver = widget.job?.deliver ?? 'local';
  late String _modelChoice = widget.job?.model?.isNotEmpty == true
      ? '${widget.job?.provider ?? ''}:${widget.job!.model}'
      : '__default__';

  @override
  void initState() {
    super.initState();
    _loadEditorData();
  }

  void _loadEditorData() {
    _loadTargets();
    if (widget.job == null) _loadBlueprints();
    if (widget.job?.isScriptOnly != true) _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final providers = await widget.ownerApi.modelOptions();
      if (!mounted) return;
      if (!_ownsTarget) {
        setState(() {
          _loadingModels = false;
          _inlineError = connectionOfflineErrorCode;
        });
        return;
      }
      setState(() {
        _modelProviders = providers
            .where((item) => item.models.isNotEmpty)
            .toList();
        _loadingModels = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingModels = false;
          _inlineError = _ownsTarget
              ? context.l10n.cronModelsLoadFailed('$error')
              : connectionOfflineErrorCode;
        });
      }
    }
  }

  Future<void> _loadBlueprints() async {
    try {
      final blueprints = await widget.ownerApi.cronBlueprints();
      if (!mounted) return;
      if (!_ownsTarget) {
        setState(() {
          _loadingBlueprints = false;
          _inlineError = connectionOfflineErrorCode;
        });
        return;
      }
      setState(() {
        _blueprints = blueprints;
        _loadingBlueprints = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBlueprints = false;
          _inlineError = _ownsTarget
              ? context.l10n.cronBlueprintsLoadFailed('$e')
              : connectionOfflineErrorCode;
        });
      }
    }
  }

  void _selectBlueprint(CronBlueprint? value) {
    setState(() {
      _blueprint = value;
      _slotValues = value?.initialValues() ?? {};
      _inlineError = null;
    });
  }

  String _cleanBlueprintError(Object error) => error
      .toString()
      .replaceFirst(RegExp(r'^\w*Exception:\s*'), '')
      .replaceFirst(RegExp(r'^\d+:\s*'), '');

  Future<void> _saveBlueprint() async {
    final blueprint = _blueprint;
    if (blueprint == null) return;
    if (!_ownsTarget) {
      setState(() => _inlineError = connectionOfflineErrorCode);
      return;
    }
    setState(() {
      _saving = true;
      _inlineError = null;
    });
    try {
      await widget.ownerApi.instantiateCronBlueprint({
        'blueprint': blueprint.key,
        'values': _slotValues,
      });
      if (mounted && _ownsTarget) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _inlineError = connectionOfflineErrorCode);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _inlineError = _ownsTarget
              ? _cleanBlueprintError(e)
              : connectionOfflineErrorCode,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadTargets() async {
    try {
      final targets = await widget.ownerApi.cronDeliveryTargets();
      if (!mounted) return;
      if (!_ownsTarget) {
        setState(() {
          _loadingTargets = false;
          _inlineError = connectionOfflineErrorCode;
        });
        return;
      }
      setState(() {
        _targets = targets;
        if (!targets.any((item) => item.id == _deliver)) {
          _deliver = targets.any((item) => item.id == 'local')
              ? 'local'
              : (targets.isEmpty ? 'local' : targets.first.id);
        }
        _loadingTargets = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingTargets = false;
          _inlineError = _ownsTarget
              ? context.l10n.cronTargetsLoadFailed('$error')
              : connectionOfflineErrorCode;
        });
      }
    }
  }

  static const _presets = <(String, String)>[
    ('minute', '* * * * *'),
    ('hour', '0 * * * *'),
    ('day', '0 9 * * *'),
    ('week', '0 9 * * 1'),
    ('month', '0 9 1 * *'),
    ('custom', ''),
  ];

  String _presetLabel(String preset) => switch (preset) {
    'minute' => context.l10n.cronPresetMinute,
    'hour' => context.l10n.cronPresetHour,
    'day' => context.l10n.cronPresetDay,
    'week' => context.l10n.cronPresetWeek,
    'month' => context.l10n.cronPresetMonth,
    _ => context.l10n.cronPresetCustom,
  };

  String _presetHint(String preset) => switch (preset) {
    'minute' => context.l10n.cronPresetMinuteHint,
    'hour' => context.l10n.cronPresetHourHint,
    'day' => context.l10n.cronPresetDayHint,
    'week' => context.l10n.cronPresetWeekHint,
    'month' => context.l10n.cronPresetMonthHint,
    _ => '',
  };

  void _applyPreset(String cron, String hint) {
    setState(() {
      _cronCtrl.text = cron;
      _lastHint = hint;
    });
  }

  String _lastHint = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    _cronCtrl.dispose();
    _scriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_ownsTarget) {
      setState(() => _inlineError = connectionOfflineErrorCode);
      return;
    }
    final prompt = _promptCtrl.text.trim();
    final schedule = _cronCtrl.text.trim();
    final scriptOnly = widget.job?.isScriptOnly == true;
    if (schedule.isEmpty || (!scriptOnly && prompt.isEmpty)) {
      setState(() {
        _inlineError = schedule.isEmpty && (!scriptOnly && prompt.isEmpty)
            ? context.l10n.cronPromptAndExpressionRequired
            : schedule.isEmpty
            ? context.l10n.cronExpressionRequired
            : context.l10n.cronPromptRequired;
      });
      return;
    }
    final separator = _modelChoice.indexOf(':');
    final provider = separator >= 0 ? _modelChoice.substring(0, separator) : '';
    final model = separator >= 0 ? _modelChoice.substring(separator + 1) : '';
    setState(() {
      _saving = true;
      _inlineError = null;
    });
    try {
      if (widget.job == null) {
        await widget.ownerApi.cronCreate({
          'name': _nameCtrl.text.trim(),
          'prompt': prompt,
          'schedule': schedule,
          'deliver': _deliver,
          if (model.isNotEmpty) 'model': model,
          if (model.isNotEmpty && provider.isNotEmpty) 'provider': provider,
        });
      } else {
        await widget.ownerApi.cronUpdate(widget.job!.id, {
          if (_nameCtrl.text.trim().isNotEmpty) 'name': _nameCtrl.text.trim(),
          if (!scriptOnly || prompt.isNotEmpty) 'prompt': prompt,
          'schedule': schedule,
          'deliver': _deliver,
          if (!scriptOnly) 'model': model.isEmpty ? null : model,
          if (!scriptOnly) 'provider': provider.isEmpty ? null : provider,
          if (scriptOnly) 'script': _scriptCtrl.text,
        });
      }
      if (mounted && _ownsTarget) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _inlineError = connectionOfflineErrorCode);
      }
    } catch (e) {
      if (mounted) {
        if (_ownsTarget) {
          showHermesToast(
            context,
            message: context.l10n.cronSaveFailed('$e'),
            kind: HermesToastKind.error,
          );
        } else {
          setState(() => _inlineError = connectionOfflineErrorCode);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _ownsTarget =>
      identical(context.read<ConnectionStore>().api, widget.ownerApi);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: HermesSpacing.md,
        right: HermesSpacing.md,
        top: HermesSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + HermesSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.job == null
                  ? context.l10n.cronCreateTitle
                  : context.l10n.cronEditTitle,
              style: HermesType.onSurface(
                HermesType.headline,
                Theme.of(context),
              ),
            ),
            const SizedBox(height: HermesSpacing.md),
            if (_inlineError != null && _blueprint == null) ...[
              Text(
                _inlineError == connectionOfflineErrorCode
                    ? context.l10n.backendDisconnected
                    : _inlineError!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: HermesSemantic.red),
              ),
              const SizedBox(height: HermesSpacing.sm),
            ],
            if (widget.job == null &&
                (_loadingBlueprints || _blueprints.isNotEmpty)) ...[
              DropdownButtonFormField<String>(
                initialValue: _blueprint?.key ?? '__custom__',
                decoration: InputDecoration(
                  labelText: context.l10n.cronStartFromTemplate,
                  suffixIcon: _loadingBlueprints
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                items: [
                  DropdownMenuItem(
                    value: '__custom__',
                    child: Text(context.l10n.cronPresetCustom),
                  ),
                  for (final item in _blueprints)
                    DropdownMenuItem(value: item.key, child: Text(item.title)),
                ],
                onChanged: _loadingBlueprints
                    ? null
                    : (key) => _selectBlueprint(
                        key == '__custom__'
                            ? null
                            : _blueprints.firstWhere((item) => item.key == key),
                      ),
              ),
              if (_blueprint?.description.isNotEmpty == true) ...[
                const SizedBox(height: HermesSpacing.xs),
                Text(
                  _blueprint!.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: HermesSpacing.md),
            ],
            if (_blueprint != null) ...[
              for (final field in _blueprint!.fields) ...[
                _BlueprintFieldControl(
                  field: field,
                  value: _slotValues[field.name] ?? '',
                  deliveryTargets: _targets,
                  onChanged: (value) => setState(
                    () => _slotValues = {..._slotValues, field.name: value},
                  ),
                ),
                const SizedBox(height: HermesSpacing.sm),
              ],
              if (_inlineError != null) ...[
                Text(
                  _inlineError == connectionOfflineErrorCode
                      ? context.l10n.backendDisconnected
                      : _inlineError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: HermesSemantic.red),
                ),
                const SizedBox(height: HermesSpacing.sm),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveBlueprint,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.schedule_send_outlined),
                  label: Text(
                    _saving
                        ? context.l10n.cronScheduling
                        : context.l10n.cronScheduleAutomation,
                  ),
                ),
              ),
            ] else ...[
              if (widget.job?.isScriptOnly == true) ...[
                Text(
                  context.l10n.cronScriptOnlyDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: HermesSpacing.sm),
                Text(
                  context.l10n.cronScriptLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _scriptCtrl,
                  maxLines: 10,
                  minLines: 4,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: HermesSpacing.sm),
              ],
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.cronNameOptional,
                ),
              ),
              const SizedBox(height: HermesSpacing.sm),
              _DeliveryTargetCheckboxes(
                label: context.l10n.cronDeliverResultsTo,
                targets: _targets,
                value: _deliver,
                enabled: !_loadingTargets,
                onChanged: (value) => setState(() => _deliver = value),
              ),
              const SizedBox(height: HermesSpacing.sm),
              if (widget.job?.isScriptOnly != true) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'cron-model:$_modelChoice:${_modelProviders.length}',
                  ),
                  initialValue: _modelChoice,
                  decoration: InputDecoration(
                    labelText: context.l10n.cronTaskModel,
                    suffixIcon: _loadingModels
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '__default__',
                      child: Text(context.l10n.cronUseGlobalDefault),
                    ),
                    if (_modelChoice != '__default__' &&
                        !_allModelChoices.contains(_modelChoice))
                      DropdownMenuItem(
                        value: _modelChoice,
                        child: Text(
                          context.l10n.cronSavedModel('${widget.job?.model}'),
                        ),
                      ),
                    for (final provider in _modelProviders)
                      for (final model in provider.models)
                        DropdownMenuItem(
                          value: '${provider.slug}:$model',
                          child: Text('${provider.name} · $model'),
                        ),
                  ],
                  onChanged: _loadingModels
                      ? null
                      : (value) => setState(
                          () => _modelChoice = value ?? '__default__',
                        ),
                ),
                const SizedBox(height: HermesSpacing.sm),
              ],
              TextField(
                controller: _promptCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: context.l10n.cronPromptLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: HermesSpacing.md),
              Text(
                context.l10n.cronFrequency,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: HermesSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (preset, cron) in _presets)
                    ChoiceChip(
                      label: Text(_presetLabel(preset)),
                      selected: cron.isNotEmpty && _cronCtrl.text == cron,
                      onSelected: (_) =>
                          _applyPreset(cron, _presetHint(preset)),
                    ),
                ],
              ),
              if (_lastHint.isNotEmpty) ...[
                const SizedBox(height: HermesSpacing.xs),
                Text(_lastHint, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: HermesSpacing.sm),
              TextField(
                controller: _cronCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.cronExpression,
                  hintText: context.l10n.cronExpressionHint,
                  prefixIcon: const Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: HermesSpacing.lg),
              if (_inlineError != null) ...[
                Text(
                  _inlineError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: HermesSemantic.red),
                ),
                const SizedBox(height: HermesSpacing.sm),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? context.l10n.cronSaving : context.l10n.commonSave,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Set<String> get _allModelChoices => {
    for (final provider in _modelProviders)
      for (final model in provider.models) '${provider.slug}:$model',
  };
}

class _BlueprintFieldControl extends StatelessWidget {
  final CronBlueprintField field;
  final String value;
  final List<CronDeliveryTarget> deliveryTargets;
  final ValueChanged<String> onChanged;

  const _BlueprintFieldControl({
    required this.field,
    required this.value,
    required this.deliveryTargets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final help = field.help?.trim();
    if (field.name == 'deliver') {
      return _DeliveryTargetCheckboxes(
        label: field.label,
        targets: deliveryTargets,
        value: value,
        onChanged: onChanged,
      );
    }
    final options = field.name == 'deliver'
        ? deliveryTargets
              .where((target) => target.homeTargetSet || target.id == 'local')
              .map((target) => (target.id, target.name))
              .toList()
        : field.options.map((option) => (option, option)).toList();
    final safeValue = options.any((option) => option.$1 == value)
        ? value
        : (options.isEmpty ? null : options.first.$1);

    Widget control;
    if (field.type == 'enum' || field.type == 'weekdays') {
      control = DropdownButtonFormField<String>(
        key: ValueKey('${field.name}:$safeValue'),
        initialValue: safeValue,
        decoration: InputDecoration(labelText: field.label),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option.$1, child: Text(option.$2)),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      );
    } else {
      control = TextFormField(
        key: ValueKey('${field.name}:$value'),
        initialValue: value,
        keyboardType: field.type == 'time' ? TextInputType.datetime : null,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.type == 'text' ? (help ?? field.label) : null,
        ),
        onChanged: onChanged,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        control,
        if (help?.isNotEmpty == true &&
            field.type != 'text' &&
            field.name != 'deliver') ...[
          const SizedBox(height: 4),
          Text(help!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _DeliveryTargetCheckboxes extends StatelessWidget {
  final String label;
  final List<CronDeliveryTarget> targets;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _DeliveryTargetCheckboxes({
    required this.label,
    required this.targets,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final known = targets.map((target) => target.id).toSet();
    final options = <CronDeliveryTarget>[
      ...targets,
      for (final id in selected)
        if (!known.contains(id))
          CronDeliveryTarget(id: id, name: id, homeTargetSet: true),
    ];
    if (options.isEmpty) {
      options.add(
        const CronDeliveryTarget(id: 'local', name: '', homeTargetSet: true),
      );
    }

    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Column(
        children: [
          for (final target in options)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains(target.id),
              title: Text(
                target.id == 'local'
                    ? context.l10n.cronThisDevice
                    : target.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: target.id != 'local' && !target.homeTargetSet
                  ? Text(context.l10n.cronConfigureHomeChannelFirst)
                  : null,
              onChanged:
                  !enabled || (target.id != 'local' && !target.homeTargetSet)
                  ? null
                  : (checked) {
                      final next = [...selected];
                      if (checked == true) {
                        if (!next.contains(target.id)) next.add(target.id);
                      } else {
                        next.remove(target.id);
                      }
                      onChanged(next.join(','));
                    },
            ),
        ],
      ),
    );
  }
}
