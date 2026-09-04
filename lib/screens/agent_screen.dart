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
import '../widgets/adaptive_form_dialog.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_logo.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
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
  final TextEditingController _botSearch = TextEditingController();

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
    _botSearch.dispose();
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
    final search = TextEditingController();
    final phoneLayout =
        MediaQuery.sizeOf(context).width < HermesBreakpoints.phone;
    // Phones get a full-height, thumb-reachable bottom sheet (drag handle,
    // large checkbox rows with leading avatars, a live selection counter);
    // larger windows keep the compact dialog. Validation stays server-side
    // (BotStore throws ArgumentError with a localized message) rather than
    // gating the button, matching every other showAdaptiveFormDialog caller.
    final ok = await showAdaptiveFormDialog<bool>(
      context: context,
      title: existing == null
          ? context.l10n.agentNewGroup
          : context.l10n.agentEditGroup,
      content: StatefulBuilder(
        builder: (ctx, setFormState) {
          final query = search.text.trim().toLowerCase();
          final bots = query.isEmpty
              ? store.bots
              : store.bots
                    .where(
                      (bot) =>
                          bot.displayName.toLowerCase().contains(query) ||
                          bot.profile.toLowerCase().contains(query),
                    )
                    .toList(growable: false);
          final atLimit = selected.length >= BotStore.maxGroupMembers;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: existing == null,
                decoration: InputDecoration(
                  labelText: context.l10n.agentGroupName,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.primaryContainer.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_2_outlined,
                      size: 20,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.agentSelectMembers,
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: atLimit
                            ? Theme.of(ctx).colorScheme.errorContainer
                            : Theme.of(ctx).colorScheme.surface,
                        borderRadius: BorderRadius.circular(
                          HermesRadius.capsule,
                        ),
                      ),
                      child: Text(
                        context.l10n.agentGroupMemberCount(
                          selected.length,
                          BotStore.maxGroupMembers,
                        ),
                        style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          color: atLimit
                              ? Theme.of(ctx).colorScheme.onErrorContainer
                              : Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: context.l10n.agentSearchBots,
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.commonClose,
                          onPressed: () {
                            search.clear();
                            setFormState(() {});
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                  filled: true,
                  isDense: true,
                ),
                onChanged: (_) => setFormState(() {}),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: bots.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(context.l10n.agentSearchNoMatches),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final bot in bots)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _BotMemberChoice(
                                bot: bot,
                                selected: selected.contains(bot.key),
                                enabled: !atLimit || selected.contains(bot.key),
                                onTap: () => setFormState(
                                  () => selected.contains(bot.key)
                                      ? selected.remove(bot.key)
                                      : selected.add(bot.key),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      actions: phoneLayout
          ? [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    existing == null
                        ? context.l10n.commonCreate
                        : context.l10n.commonSave,
                  ),
                ),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  existing == null
                      ? context.l10n.commonCreate
                      : context.l10n.commonSave,
                ),
              ),
            ],
    );
    final value = name.text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      search.dispose();
    });
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

  Future<void> _refreshAll() async {
    if (_busy) return;
    await Future.wait([_load(), context.read<BotStore>().refresh()]);
  }

  Future<void> _showGroupActions(BotStore store, BotGroup group) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionSheetHeader(
              icon: Icons.groups_outlined,
              tone: HermesSemantic.purple,
              title: group.name,
              subtitle: context.l10n.agentGroupSummary(
                group.memberKeys.length,
                store.isGroupBusy(group.id)
                    ? context.l10n.agentRunningSuffix
                    : '',
              ),
            ),
            const SizedBox(height: 14),
            HermesMobileGroup(
              children: [
                HermesMobileRow(
                  icon: Icons.edit_outlined,
                  title: context.l10n.agentEditGroup,
                  onTap: () => Navigator.pop(sheetContext, 'edit'),
                ),
                HermesMobileRow(
                  icon: Icons.delete_outline,
                  tone: HermesSemantic.red,
                  title: context.l10n.agentDeleteGroup,
                  onTap: () => Navigator.pop(sheetContext, 'delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editGroup(store, group);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.agentDeleteGroupQuestion(group.name)),
        content: Text(context.l10n.agentDeleteGroupWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await store.removeGroup(group.id);
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.agentDeleteGroupFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _showBotActions(BotStore store, BotIdentity bot) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionSheetHeader(
              avatar: HermesAvatar(
                label: bot.displayName,
                size: 48,
                color: botAvatarColor(bot.metadata),
              ),
              icon: Icons.smart_toy_outlined,
              title: bot.displayName,
              subtitle: [
                bot.profile,
                bot.description,
              ].where((text) => text.isNotEmpty).join(' · '),
            ),
            const SizedBox(height: 14),
            HermesMobileGroup(
              children: [
                HermesMobileRow(
                  icon: Icons.schedule_outlined,
                  title: context.l10n.agentBotRoutinesMenuItem,
                  onTap: () => Navigator.pop(sheetContext, 'routines'),
                ),
                HermesMobileRow(
                  icon: Icons.copy_outlined,
                  title: context.l10n.agentDuplicateBot,
                  onTap: () => Navigator.pop(sheetContext, 'duplicate'),
                ),
                if (bot.profile.toLowerCase() != 'default')
                  HermesMobileRow(
                    icon: Icons.delete_outline,
                    tone: HermesSemantic.red,
                    title: context.l10n.agentDeleteBot,
                    onTap: () => Navigator.pop(sheetContext, 'delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'routines') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => BotRoutinesScreen(bot: bot)),
        );
      } else if (action == 'duplicate') {
        await store.duplicateBot(bot);
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.agentDeleteBotQuestion(bot.displayName)),
            content: Text(context.l10n.profilesDeleteWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.commonDelete),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) await store.deleteBot(bot);
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.agentBotOperationFailed('$error'),
          kind: HermesToastKind.error,
        );
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
            onPressed: _busy ? null : _refreshAll,
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
      onRefresh: _refreshAll,
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
            builder: (context, bots, _) {
              final query = _botSearch.text.trim().toLowerCase();
              final visibleGroups = query.isEmpty
                  ? bots.groups
                  : bots.groups
                        .where(
                          (group) => group.name.toLowerCase().contains(query),
                        )
                        .toList(growable: false);
              final visibleBots = query.isEmpty
                  ? bots.bots
                  : bots.bots
                        .where(
                          (bot) =>
                              bot.displayName.toLowerCase().contains(query) ||
                              bot.profile.toLowerCase().contains(query) ||
                              bot.description.toLowerCase().contains(query),
                        )
                        .toList(growable: false);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HermesMobileCard(
                    key: const ValueKey('bot-directory-overview'),
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth < 320 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.25;
                        final avatar = Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const HermesAgentAvatar(size: 52),
                            PositionedDirectional(
                              end: -2,
                              bottom: -2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: running
                                      ? HermesSemantic.green
                                      : HermesSemantic.gray,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: HermesPalette.of(context).surface,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                        final statusChip = HermesMobileStatusChip(
                          label: running
                              ? context.l10n.commonRunning
                              : context.l10n.agentStopped,
                          color: running
                              ? HermesSemantic.green
                              : HermesSemantic.gray,
                        );
                        final details = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.agentBotDirectoryTitle,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.agentBotDirectorySummary(
                                bots.bots.length,
                                bots.groups.length,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: HermesPalette.of(context).text3,
                                  ),
                            ),
                          ],
                        );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  avatar,
                                  const SizedBox(width: 12),
                                  const Spacer(),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: statusChip,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              details,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            avatar,
                            const SizedBox(width: 14),
                            Expanded(child: details),
                            const SizedBox(width: 10),
                            statusChip,
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: HermesSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: HermesSectionHeader(
                          title: context.l10n.agentBotsTitle,
                        ),
                      ),
                      Text(
                        '${bots.groups.length + bots.bots.length}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HermesSpacing.xs),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxWidth < 360 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.25;
                      final manage = FilledButton.tonalIcon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfilesScreen(),
                            ),
                          );
                          if (context.mounted) await bots.refresh();
                        },
                        icon: const Icon(
                          Icons.person_add_alt_outlined,
                          size: 18,
                        ),
                        label: Text(context.l10n.agentManageBots),
                      );
                      final group = OutlinedButton.icon(
                        onPressed: bots.bots.length >= 2
                            ? () => _editGroup(bots)
                            : null,
                        icon: const Icon(Icons.group_add_outlined, size: 18),
                        label: Text(context.l10n.agentNewGroup),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [manage, const SizedBox(height: 8), group],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: manage),
                          const SizedBox(width: 8),
                          Expanded(child: group),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: HermesSpacing.sm),
                  TextField(
                    key: const ValueKey('bot-directory-search'),
                    controller: _botSearch,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: context.l10n.agentSearchBots,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isEmpty
                          ? IconButton(
                              tooltip: context.l10n.agentRefreshRoster,
                              onPressed: bots.loading ? null : bots.refresh,
                              icon: bots.loading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 20),
                            )
                          : IconButton(
                              tooltip: context.l10n.commonClose,
                              onPressed: () {
                                _botSearch.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                      filled: true,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: HermesSpacing.sm),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: HermesSpacing.md,
                      ),
                      child: HermesEmptyState(
                        icon: Icons.smart_toy_outlined,
                        title: context.l10n.agentBotsEmptyTitle,
                        description: context.l10n.agentBotsEmptyDescription,
                      ),
                    ),
                  if (query.isNotEmpty &&
                      visibleGroups.isEmpty &&
                      visibleBots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(context.l10n.agentSearchNoMatches),
                      ),
                    ),
                  if (visibleGroups.isNotEmpty) ...[
                    HermesMobileSectionLabel(
                      title: context.l10n.agentGroupChatsSection,
                      trailing: Text('${visibleGroups.length}'),
                      top: 8,
                    ),
                    HermesMobileGroup(
                      children: [
                        for (final group in visibleGroups)
                          HermesMobileRow(
                            key: ValueKey('bot-group-${group.id}'),
                            icon: Icons.groups_outlined,
                            tone: HermesSemantic.purple,
                            title: group.name,
                            subtitle: context.l10n.agentGroupSummary(
                              group.memberKeys.length,
                              bots.isGroupBusy(group.id)
                                  ? context.l10n.agentRunningSuffix
                                  : '',
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BotGroupChatScreen(
                                  group: group,
                                  onEdit: () => _editGroup(bots, group),
                                ),
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: context.l10n.commonMore,
                              onPressed: () => _showGroupActions(bots, group),
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (visibleBots.isNotEmpty) ...[
                    HermesMobileSectionLabel(
                      title: context.l10n.agentIndividualBotsSection,
                      trailing: Text('${visibleBots.length}'),
                      top: visibleGroups.isEmpty ? 8 : 18,
                    ),
                    HermesMobileGroup(
                      children: [
                        for (final bot in visibleBots)
                          HermesMobileRow(
                            key: ValueKey('bot-${bot.key}'),
                            icon: Icons.smart_toy_outlined,
                            iconWidget: HermesAvatar(
                              label: bot.displayName,
                              size: 31,
                              color: botAvatarColor(bot.metadata),
                            ),
                            title: bot.displayName,
                            subtitle: [
                              bot.profile,
                              bot.description,
                            ].where((text) => text.isNotEmpty).join(' · '),
                            onTap: () => _openBot(bot),
                            trailing: IconButton(
                              tooltip: context.l10n.commonMore,
                              onPressed: () => _showBotActions(bots, bot),
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: HermesSpacing.lg),
                ],
              );
            },
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

class _BotMemberChoice extends StatelessWidget {
  const _BotMemberChoice({
    required this.bot,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final BotIdentity bot;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = HermesPalette.of(context);
    return AnimatedContainer(
      duration: HermesMotion.fast,
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer.withValues(alpha: .42)
            : palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? colors.primary : palette.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
              child: Row(
                children: [
                  HermesAvatar(
                    label: bot.displayName,
                    size: 40,
                    color: botAvatarColor(bot.metadata),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bot.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: enabled ? palette.text : palette.text4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bot.route.connectionId} · ${bot.profile}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: enabled ? palette.text3 : palette.text4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IgnorePointer(
                    child: Checkbox(
                      value: selected,
                      onChanged: enabled ? (_) {} : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionSheetHeader extends StatelessWidget {
  const _ActionSheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.avatar,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? avatar;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final resolvedTone = tone ?? palette.accent;
    return Row(
      children: [
        avatar ??
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: resolvedTone.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: resolvedTone, size: 23),
            ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.text3),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
