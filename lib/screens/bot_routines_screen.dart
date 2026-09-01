library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/bot_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';

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
    try {
      final routines = await context.read<BotStore>().listBotRoutines(
        widget.bot,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _routines = routines;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration && _routines == null) {
        setState(() => _error = '$error');
      }
    }
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

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BotRoutineEditor(bot: widget.bot),
    );
    if (created == true) await _load();
  }

  Future<void> _delete(BotRoutine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.botRoutineDeleteQuestion),
        content: Text(context.l10n.botRoutineDeletePrompt(routine.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: HermesSemantic.red),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) await _mutate(routine, 'remove');
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
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.botRoutineTitle(widget.bot.displayName)),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
      return HermesErrorState(description: _error, onRetry: _load);
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

  const _BotRoutineEditor({required this.bot});

  @override
  State<_BotRoutineEditor> createState() => _BotRoutineEditorState();
}

class _BotRoutineEditorState extends State<_BotRoutineEditor> {
  final _title = TextEditingController();
  final _instruction = TextEditingController();
  final _time = TextEditingController(text: '09:00');
  final _number = TextEditingController(text: '1');
  final _repeat = TextEditingController();
  final _raw = TextEditingController(text: '0 9 * * *');
  String _frequency = 'daily';
  String _unit = 'h';
  String _weekday = '1';
  bool _continuity = false;
  bool _deliverToChat = false;
  bool _saving = false;
  String? _error;

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
    try {
      await context.read<BotStore>().createBotRoutine(
        widget.bot,
        BotRoutineDraft(
          title: _title.text,
          instruction: _instruction.text,
          schedule: _schedule,
          repeat: int.tryParse(_repeat.text),
          continuity: _continuity,
          deliverToBotChat: _deliverToChat,
        ),
      );
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
              context.l10n.botRoutineCreateTitle(widget.bot.displayName),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
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
              decoration: InputDecoration(
                labelText: context.l10n.botRoutineInstructionLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
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
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.schedule_send_outlined),
              label: Text(
                _saving
                    ? context.l10n.botRoutineCreating
                    : context.l10n.botRoutineCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
