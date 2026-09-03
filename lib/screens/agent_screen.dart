/// Agent (spec §47–50, ADR 0002): renders the backend process — gateway
/// state, model, runtime and session context — with Stop/Restart controls.
/// Backed by `GET /api/v1/status` (which merges backend /api/status +
/// /api/model/info) — no persona entity exists to CRUD.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/bot_store.dart';
import '../core/stores/session_store.dart';
import 'bot_group_chat_screen.dart';
import 'bot_routines_screen.dart';
import 'profiles_screen.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_logo.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';
import '../l10n/l10n.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen>
    with ConnectionReloadMixin<AgentScreen> {
  Map<String, dynamic>? _status;
  String? _error;
  bool _busy = false;
  int _loadGeneration = 0;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_load()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BotStore>().refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  Future<void> _reloadForConnection() {
    if (mounted) {
      setState(() {
        _status = null;
        _error = null;
      });
    }
    if (mounted) {
      unawaited(context.read<BotStore>().refresh());
    }
    return _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _openBot(BotIdentity bot) async {
    try {
      final id = await context.read<BotStore>().ensureCanonicalChat(bot);
      if (id == null || !mounted) return;
      await context.read<SessionStore>().resumeOwnedSession(id, bot.route);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.agentOpenBotFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _editGroup(BotStore store, [BotGroup? existing]) async {
    final selected = <String>{...?existing?.memberKeys};
    final name = TextEditingController(text: existing?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? context.l10n.agentNewGroup
                : context.l10n.agentEditGroup,
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: context.l10n.agentGroupName,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final bot in store.bots)
                        CheckboxListTile(
                          value: selected.contains(bot.key),
                          title: Text(bot.displayName),
                          subtitle: Text(
                            '${bot.route.connectionId} · ${bot.profile}',
                          ),
                          onChanged:
                              selected.length >= BotStore.maxGroupMembers &&
                                  !selected.contains(bot.key)
                              ? null
                              : (on) => setDialogState(
                                  () => on == true
                                      ? selected.add(bot.key)
                                      : selected.remove(bot.key),
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.commonCancel),
            ),
            FilledButton(
              onPressed:
                  selected.length >= 2 &&
                      selected.length <= BotStore.maxGroupMembers &&
                      name.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text(
                existing == null
                    ? context.l10n.commonCreate
                    : context.l10n.commonSave,
              ),
            ),
          ],
        ),
      ),
    );
    final value = name.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => name.dispose());
    if (ok == true) {
      final members = store.bots.where((b) => selected.contains(b.key));
      try {
        if (existing == null) {
          await store.createGroup(value, members);
        } else {
          await store.updateGroup(existing, name: value, members: members);
        }
      } catch (e) {
        if (mounted) {
          showHermesToast(
            context,
            message: context.l10n.agentGroupSaveFailed('$e'),
            kind: HermesToastKind.error,
          );
        }
      }
    }
  }

  Future<void> _load() async {
    final api = context.read<ConnectionStore>().api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = connectionOfflineErrorCode;
        });
      }
      return;
    }
    try {
      final status = await api.status();
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<ConnectionStore>().api)) {
        setState(() {
          _status = status;
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

  Future<void> _restart() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsRestartBackendQuestion),
        content: Text(context.l10n.settingsRestartBackendWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.commonRestart),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      requireActiveApi(context, connection, api);
      await api.restartBackend();
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      await _load();
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        showHermesToast(
          context,
          message: context.l10n.settingsBackendRestartFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && identical(api, connection.api)) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.featureAgent),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context, status),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic>? status) {
    if (status == null && _error == null) {
      return HermesLoadingState(label: context.l10n.agentLoading);
    }
    if (_error != null && status == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    if (status == null) {
      return HermesEmptyState(
        icon: Icons.memory_outlined,
        title: context.l10n.agentNoData,
      );
    }
    final backend = (status['backend'] as Map?)?.cast<String, dynamic>() ?? {};
    final runtime = (status['runtime'] as Map?)?.cast<String, dynamic>() ?? {};
    final gateway = (backend['gateway'] as Map?)?.cast<String, dynamic>() ?? {};
    final model = (backend['model'] as Map?)?.cast<String, dynamic>() ?? {};
    final server = (status['server'] as Map?)?.cast<String, dynamic>() ?? {};
    final running = backend['running'] == true;
    final session = context.watch<SessionStore>();
    final info = session.info;
    final canRestart =
        context.watch<ConnectionStore>().api?.capabilities.backendRestart ==
        true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(HermesSpacing.md),
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
          Consumer<BotStore>(
            builder: (context, bots, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: HermesSectionHeader(
                        title: context.l10n.agentBotsTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.agentManageBots,
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfilesScreen(),
                          ),
                        );
                        if (context.mounted) await bots.refresh();
                      },
                      icon: const Icon(Icons.person_add_alt_outlined),
                    ),
                    IconButton(
                      tooltip: context.l10n.agentNewGroup,
                      onPressed: bots.bots.length >= 2
                          ? () => _editGroup(bots)
                          : null,
                      icon: const Icon(Icons.group_add_outlined),
                    ),
                    IconButton(
                      tooltip: context.l10n.agentRefreshRoster,
                      onPressed: bots.loading ? null : bots.refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (bots.loading && bots.bots.isEmpty)
                  const LinearProgressIndicator(),
                if (bots.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: HermesSpacing.sm),
                    child: HermesNoticeBar(
                      message: bots.error!,
                      color: HermesSemantic.red,
                      icon: Icons.error_outline,
                      onTap: bots.refresh,
                    ),
                  ),
                if (!bots.loading &&
                    bots.error == null &&
                    bots.bots.isEmpty &&
                    bots.groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: HermesSpacing.md),
                    child: HermesEmptyState(
                      icon: Icons.smart_toy_outlined,
                      title: context.l10n.agentBotsEmptyTitle,
                      description: context.l10n.agentBotsEmptyDescription,
                    ),
                  ),
                for (final group in bots.groups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.groups_outlined),
                    ),
                    title: Text(group.name),
                    subtitle: Text(
                      context.l10n.agentGroupSummary(
                        group.memberKeys.length,
                        bots.isGroupBusy(group.id)
                            ? context.l10n.agentRunningSuffix
                            : '',
                      ),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BotGroupChatScreen(
                          group: group,
                          onEdit: () => _editGroup(bots, group),
                        ),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') _editGroup(bots, group);
                        if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                context.l10n.agentDeleteGroupQuestion(
                                  group.name,
                                ),
                              ),
                              content: Text(
                                context.l10n.agentDeleteGroupWarning,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(ctx.l10n.commonCancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(ctx.l10n.commonDelete),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          try {
                            await bots.removeGroup(group.id);
                          } catch (e) {
                            if (context.mounted) {
                              showHermesToast(
                                context,
                                message: context.l10n.agentDeleteGroupFailed(
                                  '$e',
                                ),
                                kind: HermesToastKind.error,
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(context.l10n.agentEditGroup),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(context.l10n.agentDeleteGroup),
                        ),
                      ],
                    ),
                  ),
                for (final bot in bots.bots)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: HermesAvatar(
                      label: bot.displayName,
                      size: 36,
                      color: botAvatarColor(bot.metadata),
                    ),
                    title: Text(bot.displayName),
                    subtitle: Text(
                      '${bot.route.connectionId} · ${bot.profile}${bot.description.isEmpty ? '' : ' · ${bot.description}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        try {
                          if (value == 'routines') {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => BotRoutinesScreen(bot: bot),
                              ),
                            );
                          }
                          if (value == 'duplicate') {
                            await bots.duplicateBot(bot);
                          }
                          if (value == 'delete') {
                            if (!mounted) return;
                            final confirmed = await showDialog<bool>(
                              context: this.context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                  context.l10n.agentDeleteBotQuestion(
                                    bot.displayName,
                                  ),
                                ),
                                content: Text(
                                  context.l10n.profilesDeleteWarning,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(ctx.l10n.commonCancel),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(ctx.l10n.commonDelete),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            await bots.deleteBot(bot);
                          }
                        } catch (error) {
                          if (context.mounted) {
                            showHermesToast(
                              context,
                              message: context.l10n.agentBotOperationFailed(
                                '$error',
                              ),
                              kind: HermesToastKind.error,
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'routines',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.smart_toy_outlined),
                            title: Text(context.l10n.agentBotRoutinesMenuItem),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Text(context.l10n.agentDuplicateBot),
                        ),
                        if (bot.profile.toLowerCase() != 'default')
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(context.l10n.agentDeleteBot),
                          ),
                      ],
                    ),
                    onTap: () => _openBot(bot),
                  ),
                const SizedBox(height: HermesSpacing.lg),
              ],
            ),
          ),
          // ── Status hero ──────────────────────────────────────────
          HermesGlassCard(
            radius: HermesRadius.largeCard,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const HermesAgentAvatar(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hermes Agent',
                            style: HermesType.onSurface(
                              HermesType.title,
                              Theme.of(context),
                            ),
                          ),
                          Text(
                            backend['hermes_version']?.toString() ?? '—',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    HermesAgentStatusView(
                      status: running
                          ? HermesAgentStatus.running
                          : HermesAgentStatus.stopped,
                      showLabel:
                          MediaQuery.sizeOf(context).width >= 400 &&
                          MediaQuery.textScalerOf(context).scale(1) <= 1.4,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat(
                      context,
                      context.l10n.agentGateway,
                      gateway['state']?.toString() ?? '—',
                    ),
                    _stat(
                      context,
                      context.l10n.agentActiveAgents,
                      '${gateway['active_agents'] ?? 0}',
                    ),
                    _stat(
                      context,
                      context.l10n.agentBusy,
                      gateway['gateway_busy'] == true
                          ? context.l10n.agentYes
                          : context.l10n.agentNo,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: HermesSpacing.lg),
          // ── Model ────────────────────────────────────────────────
          HermesSectionHeader(title: context.l10n.agentModelSection),
          HermesGlassCard(
            radius: HermesRadius.card,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(
                  context,
                  context.l10n.agentCurrentModel,
                  model['model']?.toString() ?? '—',
                ),
                _kv(
                  context,
                  context.l10n.agentProvider,
                  model['provider']?.toString() ?? '—',
                ),
                _kv(
                  context,
                  context.l10n.agentContextLength,
                  '${model['context_length'] ?? '—'}',
                ),
                _kv(
                  context,
                  context.l10n.agentSessionModel,
                  info?.model ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: HermesSpacing.lg),
          // ── Runtime ──────────────────────────────────────────────
          HermesSectionHeader(title: context.l10n.agentRuntimeSection),
          HermesGlassCard(
            radius: HermesRadius.card,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(
                  context,
                  context.l10n.agentType,
                  runtime['kind']?.toString() ?? '—',
                ),
                _kv(
                  context,
                  context.l10n.agentSourceRoot,
                  runtime['source_root']?.toString() ?? '—',
                ),
                _kv(
                  context,
                  context.l10n.agentHermesHome,
                  runtime['hermes_home']?.toString() ?? '—',
                ),
                _kv(
                  context,
                  context.l10n.agentServerVersion,
                  server['version']?.toString() ?? '—',
                ),
                _kv(
                  context,
                  context.l10n.agentCapability,
                  status['capability']?.toString() ?? '—',
                ),
              ],
            ),
          ),
          if (canRestart) ...[
            const SizedBox(height: HermesSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _restart,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(
                      _busy
                          ? context.l10n.agentRestarting
                          : context.l10n.settingsRestartBackend,
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

  Widget _stat(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: HermesType.onSurface(HermesType.headline, Theme.of(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

