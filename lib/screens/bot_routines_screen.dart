library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/models.dart';
import '../core/stores/bot_store.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_confirm_dialog.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

class BotRoutinesScreen extends StatefulWidget {
  final BotIdentity bot;

  const BotRoutinesScreen({super.key, required this.bot});

  @override
  State<BotRoutinesScreen> createState() => _BotRoutinesScreenState();
}

class _BotRoutinesScreenState extends State<BotRoutinesScreen> {
  List<BotRoutine>? _routines;
  String? _error;
  String? _busyId;
  Timer? _poller;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final botStore = context.read<BotStore>();
    final connection = botStore.connection;
    final registryManaged = connection.registry.runtimes.isNotEmpty;
    final ownerRuntime = connection.registry.runtime(
      widget.bot.route.connectionId,
    );
    if (registryManaged && ownerRuntime == null) {
      if (mounted) {
        setState(() {
          _routines = null;
          _error = connectionOfflineErrorCode;
        });
      }
      return;
    }
    try {
      final routines = await botStore.listBotRoutines(widget.bot);
      if (!mounted ||
          generation != _loadGeneration ||
          !_ownerIsCurrent(connection, ownerRuntime, registryManaged)) {
        return;
      }
      setState(() {
        _routines = routines;
        _error = null;
      });
    } catch (error) {
      if (mounted &&
          generation == _loadGeneration &&
          _ownerIsCurrent(connection, ownerRuntime, registryManaged)) {
        setState(() => _error = '$error');
      }
    }
  }

  bool _ownerIsCurrent(
    ConnectionStore connection,
    Object? ownerRuntime,
    bool registryManaged,
  ) {
    final current = connection.registry.runtime(widget.bot.route.connectionId);
    if (registryManaged) return identical(current, ownerRuntime);
    return connection.registry.runtimes.isEmpty || current != null;
  }

  Future<void> _mutate(BotRoutine routine, String action) async {
    if (_busyId != null) return;
    setState(() => _busyId = routine.id);
    try {
      await context.read<BotStore>().mutateBotRoutine(
        widget.bot,
        routine.id,
        action,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.botRoutineUpdateFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _openEditor([BotRoutine? routine]) async {
    final ownerApi = _ownerApi();
    if (ownerApi == null) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.backendDisconnected,
          kind: HermesToastKind.error,
        );
      }
      return;
    }
    final saved = await showMobileSheet<bool>(
      context,
      (_) => _BotRoutineEditor(
        bot: widget.bot,
        ownerApi: ownerApi,
        routine: routine,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _create() => _openEditor();

  Future<void> _edit(BotRoutine routine) => _openEditor(routine);

  Future<void> _delete(BotRoutine routine) async {
    final confirmed = await showHermesConfirmDialog(
      context: context,
      title: context.l10n.botRoutineDeleteQuestion,
      message: context.l10n.botRoutineDeletePrompt(routine.title),
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (confirmed) await _mutate(routine, 'remove');
  }

  ApiClient? _ownerApi() {
    return context
        .read<BotStore>()
        .connection
        .registry
        .runtime(widget.bot.route.connectionId)
        ?.api;
  }

  Future<void> _trigger(BotRoutine routine) async {
    final ownerApi = _ownerApi();
    if (ownerApi == null) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.backendDisconnected,
          kind: HermesToastKind.error,
        );
      }
      return;
    }
    try {
      await ownerApi.cronTrigger(routine.id);
      if (mounted) {
        showHermesToast(context, message: context.l10n.cronTriggered);
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.cronTriggerFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _showRuns(BotRoutine routine) async {
    final ownerApi = _ownerApi();
    if (ownerApi == null) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.backendDisconnected,
          kind: HermesToastKind.error,
        );
      }
      return;
    }
    late final List<Map<String, dynamic>> runs;
    try {
      runs = await ownerApi.cronRuns(routine.id);
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.cronRunsLoadFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
      return;
    }
    if (!mounted) return;
    showMobileSheet<void>(
      context,
      (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                context.l10n.cronRunHistoryTitle(routine.title),
                style: Theme.of(context).textTheme.titleMedium,
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

  void _showDetails(BotRoutine routine) {
    final rows = <(String, String?)>[
      (
        context.l10n.botRoutineStatus,
        routine.active
            ? context.l10n.commonRunning
            : context.l10n.botRoutinePaused,
      ),
      (
        context.l10n.botRoutineSchedule,
        _scheduleLabel(context, routine.schedule),
      ),
      if (_scheduleLabel(context, routine.schedule) != routine.schedule)
        (context.l10n.botRoutineRawSchedule, routine.schedule),
      (context.l10n.botRoutineRepeatCount, routine.repeat),
      (
        context.l10n.botRoutineNextRun,
        routine.active ? routine.nextRunAt : null,
      ),
      (context.l10n.botRoutineLastRun, routine.lastRunAt),
      (context.l10n.botRoutineLastResult, routine.lastStatus),
      (context.l10n.botRoutineDeliverTo, routine.deliver),
      (context.l10n.botRoutineModel, routine.model),
      (context.l10n.botRoutineWorkdir, routine.workdir),
    ].where((row) => row.$2?.trim().isNotEmpty == true).toList();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(routine.title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (routine.issue?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(HermesRadius.card),
                    ),
                    child: Text(routine.issue!),
                  ),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(
                            row.$1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(child: Text(row.$2!)),
                      ],
                    ),
                  ),
                if (routine.promptPreview.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.botRoutineInstruction,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(routine.promptPreview),
                ],
                if (routine.legacyUnsafe) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.botRoutineLegacyWarning,
                    style: const TextStyle(color: HermesSemantic.orange),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRuns(routine);
            },
            child: Text(context.l10n.cronRunHistory),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _trigger(routine);
            },
            child: Text(context.l10n.cronTriggerNow),
          ),
          if (!routine.legacyUnsafe)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _edit(routine);
              },
              child: Text(context.l10n.botRoutineEdit),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobilePageScaffold(
      title: context.l10n.botRoutineTitle(widget.bot.displayName),
      actions: [
        IconButton(
          tooltip: context.l10n.commonRefresh,
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        heroTag: 'new-bot-routine-${widget.bot.key}',
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final routines = _routines;
    if (routines == null && _error == null) {
      return HermesLoadingState(label: context.l10n.botRoutineLoading);
    }
    if (routines == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    if (routines.isEmpty) {
      return HermesEmptyState(
        icon: Icons.schedule_outlined,
        title: context.l10n.botRoutineEmptyTitle,
        description: context.l10n.botRoutineEmptyDescription(
          widget.bot.displayName,
        ),
        primaryLabel: context.l10n.botRoutineNew,
        onPrimary: _create,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: routines.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final routine = routines[index];
          final busy = _busyId == routine.id;
          final anyBusy = _busyId != null;
          return ListTile(
            onTap: () => _showDetails(routine),
            leading: Icon(
              routine.active ? Icons.schedule : Icons.pause_circle_outline,
              color: routine.active
                  ? HermesSemantic.green
                  : HermesSemantic.gray,
            ),
            title: Text(
              routine.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_scheduleLabel(context, routine.schedule)),
                Text(
                  routine.active && routine.nextRunAt != null
                      ? context.l10n.botRoutineNext(routine.nextRunAt!)
                      : routine.legacyUnsafe
                      ? context.l10n.botRoutineLegacyPaused
                      : context.l10n.botRoutinePaused,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: routine.active,
                    onChanged: routine.legacyUnsafe || anyBusy
                        ? null
                        : (enabled) =>
                              _mutate(routine, enabled ? 'resume' : 'pause'),
                  ),
                IconButton(
                  tooltip: context.l10n.botRoutineDelete,
                  onPressed: anyBusy ? null : () => _delete(routine),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _scheduleLabel(BuildContext context, String schedule) {
  final value = schedule.trim();
  final once = RegExp(r'^(?:once in )?(\d+)([mhd])$').firstMatch(value);
  if (once != null) {
    return context.l10n.botRoutineScheduleOnce(
      '${once.group(1)}${once.group(2)}',
    );
  }
  final interval = RegExp(r'^every\s+(\d+)([mhd])$').firstMatch(value);
  if (interval != null) {
    return context.l10n.botRoutineScheduleEvery(
      '${interval.group(1)}${interval.group(2)}',
    );
  }
  return switch (value) {
    '0 * * * *' => context.l10n.botRoutineScheduleHourly,
    '0 9 * * *' => context.l10n.botRoutineScheduleDaily,
    '0 9 * * 1-5' => context.l10n.botRoutineScheduleWeekdays,
    '0 9 * * 1' => context.l10n.botRoutineScheduleWeekly,
    '0 9 1 * *' => context.l10n.botRoutineScheduleMonthly,
    _ => value,
  };
}

class _BotRoutineEditor extends StatefulWidget {
  final BotIdentity bot;
  final ApiClient ownerApi;
  final BotRoutine? routine;

  const _BotRoutineEditor({
    required this.bot,
    required this.ownerApi,
    this.routine,
  });

  @override
  State<_BotRoutineEditor> createState() => _BotRoutineEditorState();
}

class _BotRoutineEditorState extends State<_BotRoutineEditor> {
  late final _title = TextEditingController(text: widget.routine?.title ?? '');
  late final _instruction = TextEditingController(
    text: widget.routine?.promptPreview ?? '',
  );
  final _time = TextEditingController(text: '09:00');
  final _number = TextEditingController(text: '1');
  late final _repeat = TextEditingController(
    text: widget.routine?.repeat ?? '',
  );
  late final _raw = TextEditingController(
    text: widget.routine?.schedule ?? '0 9 * * *',
  );
  late String _frequency = widget.routine != null ? 'advanced' : 'daily';
  String _unit = 'h';
  String _weekday = '1';
  bool _continuity = false;
  late bool _deliverToChat = widget.routine?.deliver == 'bot-chat';
  bool _saving = false;
  String? _error;

  bool get _editing => widget.routine != null;

  bool _loadingModels = true;
  List<ModelInfo> _modelProviders = const [];
  String _modelChoice = '__default__';
  bool _loadingJob = false;
  String? _savedModel;

  @override
  void initState() {
    super.initState();
    _loadModels();
    if (widget.routine != null) {
      _loadingJob = true;
      _loadFullJob();
    }
  }

  Future<void> _loadModels() async {
    try {
      final providers = await widget.ownerApi.modelOptions();
      if (!mounted) return;
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
          _error = context.l10n.cronModelsLoadFailed('$error');
        });
      }
    }
  }

  Future<void> _loadFullJob() async {
    final routineId = widget.routine!.id;
    try {
      final jobs = await widget.ownerApi.cronJobs();
      final job = jobs.where((j) => j.id == routineId).firstOrNull;
      if (!mounted) return;
      setState(() {
        _loadingJob = false;
        if (job != null) {
          if (job.prompt != null && job.prompt!.isNotEmpty) {
            _instruction.text = job.prompt!;
          }
          if (job.model?.isNotEmpty == true) {
            _modelChoice = '${job.provider ?? ''}:${job.model}';
            _savedModel = job.model;
          }
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingJob = false;
          _error = context.l10n.botRoutineLoadFailed('$error');
        });
      }
    }
  }

  Set<String> get _allModelChoices => {
    for (final provider in _modelProviders)
      for (final model in provider.models) '${provider.slug}:$model',
  };

  @override
  void dispose() {
    _title.dispose();
    _instruction.dispose();
    _time.dispose();
    _number.dispose();
    _repeat.dispose();
    _raw.dispose();
    super.dispose();
  }

  String get _schedule {
    final number = int.tryParse(_number.text) ?? 1;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_time.text.trim());
    final hour = (int.tryParse(match?.group(1) ?? '') ?? 9).clamp(0, 23);
    final minute = (int.tryParse(match?.group(2) ?? '') ?? 0).clamp(0, 59);
    return switch (_frequency) {
      'once' => '${number.clamp(1, 9999)}$_unit',
      'hourly' => 'every 1h',
      'daily' => '$minute $hour * * *',
      'weekdays' => '$minute $hour * * 1-5',
      'weekly' => '$minute $hour * * $_weekday',
      'monthly' => '$minute $hour ${number.clamp(1, 31)} * *',
      'interval' => 'every ${number.clamp(1, 9999)}$_unit',
      _ => _raw.text.trim(),
    };
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty ||
        _instruction.text.trim().isEmpty ||
        _schedule.isEmpty) {
      setState(() => _error = context.l10n.botRoutineRequiredFields);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final separator = _modelChoice.indexOf(':');
    final provider = separator >= 0 ? _modelChoice.substring(0, separator) : '';
    final model = separator >= 0 ? _modelChoice.substring(separator + 1) : '';
    final draft = BotRoutineDraft(
      title: _title.text,
      instruction: _instruction.text,
      schedule: _schedule,
      repeat: int.tryParse(_repeat.text),
      continuity: _continuity,
      deliverToBotChat: _deliverToChat,
      model: model.isEmpty ? null : model,
      provider: provider.isEmpty ? null : provider,
    );
    try {
      final store = context.read<BotStore>();
      if (widget.routine == null) {
        await store.createBotRoutine(widget.bot, draft);
      } else {
        await store.updateBotRoutine(widget.bot, widget.routine!.id, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsTime = {
      'daily',
      'weekdays',
      'weekly',
      'monthly',
    }.contains(_frequency);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editing
                  ? context.l10n.botRoutineEditTitle(widget.bot.displayName)
                  : context.l10n.botRoutineCreateTitle(widget.bot.displayName),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_editing,
              decoration: InputDecoration(
                labelText: context.l10n.commonName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instruction,
              minLines: 3,
              maxLines: 6,
              enabled: !_loadingJob,
              decoration: InputDecoration(
                labelText: context.l10n.botRoutineInstructionLabel,
                border: const OutlineInputBorder(),
                suffixIcon: _loadingJob
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'bot-routine-model:$_modelChoice:${_modelProviders.length}',
              ),
              dropdownColor: hermesDropdownColor(context),
              borderRadius: hermesDropdownBorderRadius,
              initialValue: _modelChoice,
              decoration: InputDecoration(
                labelText: context.l10n.cronTaskModel,
                border: const OutlineInputBorder(),
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
                    child: Text(context.l10n.cronSavedModel('$_savedModel')),
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
                  : (value) => setState(() => _modelChoice = value ?? '__default__'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: hermesDropdownColor(context),
              borderRadius: hermesDropdownBorderRadius,
              initialValue: _frequency,
              decoration: InputDecoration(
                labelText: context.l10n.cronFrequency,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'once',
                  child: Text(context.l10n.botRoutineFrequencyOnce),
                ),
                DropdownMenuItem(
                  value: 'hourly',
                  child: Text(context.l10n.botRoutineFrequencyHourly),
                ),
                DropdownMenuItem(
                  value: 'daily',
                  child: Text(context.l10n.botRoutineFrequencyDaily),
                ),
                DropdownMenuItem(
                  value: 'weekdays',
                  child: Text(context.l10n.botRoutineFrequencyWeekdays),
                ),
                DropdownMenuItem(
                  value: 'weekly',
                  child: Text(context.l10n.botRoutineFrequencyWeekly),
                ),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text(context.l10n.botRoutineFrequencyMonthly),
                ),
                DropdownMenuItem(
                  value: 'interval',
                  child: Text(context.l10n.botRoutineFrequencyInterval),
                ),
                DropdownMenuItem(
                  value: 'advanced',
                  child: Text(context.l10n.botRoutineFrequencyAdvanced),
                ),
              ],
              onChanged: (value) => setState(() => _frequency = value!),
            ),
            const SizedBox(height: 10),
            if (needsTime)
              TextField(
                controller: _time,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: context.l10n.botRoutineTime,
                  border: const OutlineInputBorder(),
                ),
              ),
            if (_frequency == 'weekly') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                dropdownColor: hermesDropdownColor(context),
                borderRadius: hermesDropdownBorderRadius,
                initialValue: _weekday,
                decoration: InputDecoration(
                  labelText: context.l10n.botRoutineWeekday,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: '1',
                    child: Text(context.l10n.botRoutineMonday),
                  ),
                  DropdownMenuItem(
                    value: '2',
                    child: Text(context.l10n.botRoutineTuesday),
                  ),
                  DropdownMenuItem(
                    value: '3',
                    child: Text(context.l10n.botRoutineWednesday),
                  ),
                  DropdownMenuItem(
                    value: '4',
                    child: Text(context.l10n.botRoutineThursday),
                  ),
                  DropdownMenuItem(
                    value: '5',
                    child: Text(context.l10n.botRoutineFriday),
                  ),
                  DropdownMenuItem(
                    value: '6',
                    child: Text(context.l10n.botRoutineSaturday),
                  ),
                  DropdownMenuItem(
                    value: '0',
                    child: Text(context.l10n.botRoutineSunday),
                  ),
                ],
                onChanged: (value) => setState(() => _weekday = value!),
              ),
            ],
            if ({'once', 'monthly', 'interval'}.contains(_frequency)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _number,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _frequency == 'monthly'
                            ? context.l10n.botRoutineDayOfMonth
                            : context.l10n.botRoutineValue,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (_frequency != 'monthly') ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        dropdownColor: hermesDropdownColor(context),
                        borderRadius: hermesDropdownBorderRadius,
                        initialValue: _unit,
                        decoration: InputDecoration(
                          labelText: context.l10n.botRoutineUnit,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'm',
                            child: Text(context.l10n.botRoutineMinutes),
                          ),
                          DropdownMenuItem(
                            value: 'h',
                            child: Text(context.l10n.botRoutineHours),
                          ),
                          DropdownMenuItem(
                            value: 'd',
                            child: Text(context.l10n.botRoutineDays),
                          ),
                        ],
                        onChanged: (value) => setState(() => _unit = value!),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (_frequency == 'advanced') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _raw,
                decoration: InputDecoration(
                  labelText: context.l10n.botRoutineAdvancedExpression,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              context.l10n.botRoutineWillSaveAs(_schedule),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _repeat,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.botRoutineRepeatLimit,
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.botRoutineContinuity),
              subtitle: Text(context.l10n.botRoutineContinuityDescription),
              value: _continuity,
              onChanged: (value) => setState(() => _continuity = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.l10n.botRoutineSendToBot(widget.bot.displayName),
              ),
              subtitle: Text(context.l10n.botRoutineSendToBotDescription),
              value: _deliverToChat,
              onChanged: (value) => setState(() => _deliverToChat = value),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: HermesSemantic.red)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_saving || _loadingJob) ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.schedule_send_outlined),
              label: Text(
                _saving
                    ? (_editing
                          ? context.l10n.botRoutineSaving
                          : context.l10n.botRoutineCreating)
                    : (_editing
                          ? context.l10n.botRoutineSave
                          : context.l10n.botRoutineCreate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
