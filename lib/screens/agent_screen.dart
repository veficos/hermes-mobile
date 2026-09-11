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
import 'bot_avatar_editor_screen.dart';
import 'bot_group_chat_screen.dart';
import 'bot_routines_screen.dart';
import 'mcp_screen.dart';
import 'bot_create_screen.dart';
import 'profiles_screen.dart';
import '../theme/hermes_tokens.dart';
import '../theme/hermes_glass_theme.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_search_field.dart';
import '../widgets/adaptive_form_dialog.dart';
import '../widgets/bot_avatar.dart';
import '../widgets/h/hermes_confirm_dialog.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_logo.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
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
  List<BotIdentity>? _visibleBots;

  @override
  void initState() {
    super.initState();
    _load();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_load().then((_) => _refreshAttention())),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BotStore>().refresh().then((_) => _refreshAttention());
    });
  }

  Future<void> _refreshAttention() {
    if (!mounted) return Future<void>.value();
    final bots = context.read<BotStore>();
    return bots.refreshBotAttention(_visibleBots ?? bots.bots);
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
      unawaited(
        context.read<BotStore>().refresh().then((_) => _refreshAttention()),
      );
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

  Widget? _botStatusBadge(BotStore bots, BotIdentity bot) {
    final pinned = bots.isBotPinned(bot);
    final needsAttention = bots.botNeedsAttention(bot);
    final working = bots.botIsWorking(bot);
    final unreachable = bots.isBotUnreachable(bot);
    if (!pinned && !needsAttention && !working && !unreachable) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unreachable)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.cloud_off, size: 14),
          )
        else if (needsAttention)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 4),
            decoration: const BoxDecoration(
              color: HermesSemantic.red,
              shape: BoxShape.circle,
            ),
          )
        else if (working)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
          ),
        if (pinned) const Icon(Icons.push_pin, size: 14),
      ],
    );
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
                    Flexible(
                      child: Container(
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
              OutlinedButton(
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
    final confirmed = await showHermesConfirmDialog(
      context: context,
      title: context.l10n.settingsRestartBackendQuestion,
      message: context.l10n.settingsRestartBackendWarning,
      confirmLabel: context.l10n.commonRestart,
    );
    if (!confirmed || !mounted) return;
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
    final action = await showMobileSheet<String>(
      context,
      isScrollControlled: false,
      (sheetContext) => SingleChildScrollView(
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
    final confirmed = await showHermesConfirmDialog(
      context: context,
      title: context.l10n.agentDeleteGroupQuestion(group.name),
      message: context.l10n.agentDeleteGroupWarning,
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
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

  Future<void> _showDirectoryActions(BotStore store) async {
    final action = await showMobileSheet<String>(
      context,
      (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.agentManageBots,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            HermesMobileGroup(
              children: [
                HermesMobileRow(
                  icon: Icons.manage_accounts_outlined,
                  title: context.l10n.agentManageBots,
                  onTap: () => Navigator.pop(sheetContext, 'profiles'),
                ),
                HermesMobileRow(
                  icon: Icons.group_add_outlined,
                  title: context.l10n.agentNewGroup,
                  onTap: store.bots.length >= 2
                      ? () => Navigator.pop(sheetContext, 'group')
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'group') {
      await _editGroup(store);
    } else if (action == 'profiles') {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ProfilesScreen()));
      if (mounted) await store.refresh();
    }
  }

  Future<void> _showBotActions(BotStore store, BotIdentity bot) async {
    final action = await showMobileSheet<String>(
      context,
      isScrollControlled: false,
      (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionSheetHeader(
              avatar: BotAvatar(
                name: bot.profile,
                metadata: bot.metadata,
                size: 48,
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
                  icon: Icons.push_pin_outlined,
                  title: store.isBotPinned(bot)
                      ? context.l10n.agentUnpinBot
                      : context.l10n.agentPinBot,
                  onTap: () => Navigator.pop(sheetContext, 'pin'),
                ),
                HermesMobileRow(
                  icon: Icons.visibility_off_outlined,
                  title: store.isBotHidden(bot)
                      ? context.l10n.agentUnhideBot
                      : context.l10n.agentHideBot,
                  onTap: () => Navigator.pop(sheetContext, 'hide'),
                ),
                HermesMobileRow(
                  icon: Icons.extension_outlined,
                  title: context.l10n.agentBotMcpMenuItem,
                  onTap: () => Navigator.pop(sheetContext, 'mcp'),
                ),
                HermesMobileRow(
                  icon: Icons.psychology_alt_outlined,
                  title: context.l10n.agentBotModelMenuItem,
                  onTap: () => Navigator.pop(sheetContext, 'model'),
                ),
                HermesMobileRow(
                  icon: Icons.face_retouching_natural_outlined,
                  title: context.l10n.agentEditAvatarMenuItem,
                  onTap: () => Navigator.pop(sheetContext, 'avatar'),
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
      } else if (action == 'mcp') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => McpScreen(
              targetConnectionId: bot.route.connectionId,
              fixedProfile: bot.profile,
            ),
          ),
        );
      } else if (action == 'model') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ProfilesScreen(
              targetConnectionId: bot.route.connectionId,
              fixedProfile: bot.profile,
            ),
          ),
        );
      } else if (action == 'avatar') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => BotAvatarEditorScreen(bot: bot)),
        );
      } else if (action == 'pin') {
        await store.setBotPinned(bot, !store.isBotPinned(bot));
      } else if (action == 'hide') {
        await store.setBotHidden(bot, !store.isBotHidden(bot));
      } else if (action == 'duplicate') {
        await store.duplicateBot(bot);
      } else if (action == 'delete') {
        final confirmed = await showHermesConfirmDialog(
          context: context,
          title: context.l10n.agentDeleteBotQuestion(bot.displayName),
          message: context.l10n.profilesDeleteWarning,
          confirmLabel: context.l10n.commonDelete,
          destructive: true,
        );
        if (confirmed && mounted) await store.deleteBot(bot);
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
    // A failed refresh invalidates the claim that the cached service state
    // is current. Keep the independent directory visible, but do not report
    // stale running/stopped state or diagnostic values as live data.
    final status = _error == null ? _status : null;
    return HermesPageScaffold(
      title: context.l10n.agentBotsTitle,
      separateHeader: HermesGlassTheme.of(context).enabled,
      titleMode: HermesPageTitleMode.large,
      scrollBodyBehindHeader: true,
      actions: [
        if (HermesGlassTheme.of(context).enabled)
          GlassButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _busy ? null : _refreshAll,
            child: const Icon(Icons.refresh),
          )
        else
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _busy ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
      ],
      body: _buildBody(context, status),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic>? status) {
    // The directory belongs to BotStore. A slow or unavailable diagnostics
    // endpoint must not hide its independently loaded records and actions.
    final backend = (status?['backend'] as Map?)?.cast<String, dynamic>() ?? {};
    final runtime = (status?['runtime'] as Map?)?.cast<String, dynamic>() ?? {};
    final gateway = (backend['gateway'] as Map?)?.cast<String, dynamic>() ?? {};
    final model = (backend['model'] as Map?)?.cast<String, dynamic>() ?? {};
    final server = (status?['server'] as Map?)?.cast<String, dynamic>() ?? {};
    final running = backend['running'] == true;
    final session = context.watch<SessionStore>();
    final info = session.info;
    final canRestart =
        context.watch<ConnectionStore>().api?.capabilities.backendRestart ==
        true;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(HermesSpacing.md),
        children: [
          if (status == null && _error == null) ...[
            LinearProgressIndicator(semanticsLabel: context.l10n.agentLoading),
            const SizedBox(height: HermesSpacing.sm),
          ],
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
              final matchingBots = query.isEmpty
                  ? bots.bots
                  : bots.bots
                        .where(
                          (bot) =>
                              bot.displayName.toLowerCase().contains(query) ||
                              bot.profile.toLowerCase().contains(query) ||
                              bot.description.toLowerCase().contains(query),
                        )
                        .toList(growable: false);
              final visibleBots =
                  matchingBots.where((bot) => !bots.isBotHidden(bot)).toList()
                    ..sort((a, b) {
                      final pinDiff =
                          (bots.isBotPinned(b) ? 1 : 0) -
                          (bots.isBotPinned(a) ? 1 : 0);
                      if (pinDiff != 0) return pinDiff;
                      return a.displayName.toLowerCase().compareTo(
                        b.displayName.toLowerCase(),
                      );
                    });
              final hiddenBots = matchingBots
                  .where((bot) => bots.isBotHidden(bot))
                  .toList(growable: false);
              _visibleBots = visibleBots;
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
                            if (status != null)
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
                        final statusChip = HermesStatusChip(
                          label: running
                              ? context.l10n.agentBackendRunning
                              : context.l10n.agentBackendStopped,
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
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              avatar,
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    details,
                                    if (status != null) ...[
                                      const SizedBox(height: 8),
                                      statusChip,
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            avatar,
                            const SizedBox(width: 14),
                            Expanded(child: details),
                            if (status != null) ...[
                              const SizedBox(width: 10),
                              statusChip,
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: HermesSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxWidth < 360 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.25;
                      final manage = FilledButton.tonalIcon(
                        key: const ValueKey('bot-directory-manage'),
                        onPressed: () async {
                          if (HermesGlassTheme.of(context).enabled) {
                            await _showDirectoryActions(bots);
                            return;
                          }
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfilesScreen(),
                            ),
                          );
                          if (context.mounted) await bots.refresh();
                        },
                        icon: const Icon(
                          Icons.manage_accounts_outlined,
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
                      final create = FilledButton.icon(
                        key: const ValueKey('bot-directory-create'),
                        style: HermesGlassTheme.of(context).enabled
                            ? FilledButton.styleFrom(
                                minimumSize: const Size(44, 48),
                                shape: const StadiumBorder(),
                              )
                            : null,
                        onPressed: () async {
                          final created = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BotCreateScreen(),
                            ),
                          );
                          if (created == true && context.mounted) {
                            await bots.refresh();
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: Text(context.l10n.botCreateTitle),
                      );
                      if (HermesGlassTheme.of(context).enabled) {
                        // Keep the roster close to the first fold. Secondary
                        // directory actions share a sheet instead of adding a
                        // third full-width button above search on phones.
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [create, manage],
                        );
                      }
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            create,
                            const SizedBox(height: 8),
                            manage,
                            const SizedBox(height: 8),
                            group,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: create),
                          const SizedBox(width: 8),
                          Expanded(child: manage),
                          const SizedBox(width: 8),
                          Expanded(child: group),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: HermesSpacing.sm),
                  if (HermesGlassTheme.of(context).enabled)
                    GlassSearchField(
                      key: const ValueKey('bot-directory-search'),
                      controller: _botSearch,
                      hintText: context.l10n.agentSearchBots,
                      onChanged: (_) => setState(() {}),
                    )
                  else
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
                    HermesSectionHeader(
                      title: context.l10n.agentGroupChatsSection,
                      trailing: Text('${visibleGroups.length}'),
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
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
                    HermesSectionHeader(
                      title: context.l10n.agentIndividualBotsSection,
                      trailing: Text('${visibleBots.length}'),
                      padding: EdgeInsets.fromLTRB(
                        4,
                        visibleGroups.isEmpty ? 8 : 18,
                        4,
                        8,
                      ),
                    ),
                    HermesMobileGroup(
                      children: [
                        for (final bot in visibleBots)
                          HermesMobileRow(
                            key: ValueKey('bot-${bot.key}'),
                            alignLeadingToTop: true,
                            leadingSize: 44,
                            icon: Icons.smart_toy_outlined,
                            iconWidget: BotAvatar(
                              name: bot.profile,
                              metadata: bot.metadata,
                              size: 44,
                              working: bots.botIsWorking(bot),
                            ),
                            title: bot.displayName,
                            titleTrailing: _botStatusBadge(bots, bot),
                            subtitle: [
                              if (bot.profile != bot.displayName) bot.profile,
                              bot.description,
                              if (bots.isBotUnreachable(bot))
                                context.l10n.agentBotUnreachable,
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
                  if (hiddenBots.isNotEmpty)
                    _HiddenBotsSection(
                      bots: bots,
                      hiddenBots: hiddenBots,
                      onOpen: _openBot,
                      onActions: (bot) => _showBotActions(bots, bot),
                    ),
                  const SizedBox(height: HermesSpacing.lg),
                ],
              );
            },
          ),
          if (status != null)
            HermesGlassCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                key: const PageStorageKey('agent-service-diagnostics'),
                title: Text(context.l10n.agentDiagnostics),
                leading: const Icon(Icons.monitor_heart_outlined),
                shape: const Border(),
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.all(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hermes',
                                    style: HermesType.onSurface(
                                      HermesType.title,
                                      Theme.of(context),
                                    ),
                                  ),
                                  Text(
                                    backend['hermes_version']?.toString() ??
                                        '—',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            _kv(
                              context,
                              context.l10n.agentGateway,
                              gateway['state']?.toString() ?? '—',
                            ),
                            _kv(
                              context,
                              context.l10n.agentActiveAgents,
                              '${gateway['active_agents'] ?? 0}',
                            ),
                            _kv(
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
                  const Divider(),
                  HermesSectionHeader(title: context.l10n.agentModelSection),
                  Padding(
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
                  const Divider(),
                  HermesSectionHeader(title: context.l10n.agentRuntimeSection),
                  Padding(
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
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              visualDensity: VisualDensity.standard,
                            ),
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
            ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          );
          final valueWidget = SelectableText(
            value,
            // Isolate editable scroll state from ExpansionTile's bool state.
            key: PageStorageKey('agent-diagnostic-value-$label'),
            style: Theme.of(context).textTheme.bodyMedium,
          );
          if (constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: labelWidget),
              const SizedBox(width: 16),
              Expanded(child: valueWidget),
            ],
          );
        },
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
                  BotAvatar(
                    name: bot.profile,
                    metadata: bot.metadata,
                    size: 40,
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
      crossAxisAlignment: CrossAxisAlignment.start,
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

class _HiddenBotsSection extends StatefulWidget {
  const _HiddenBotsSection({
    required this.bots,
    required this.hiddenBots,
    required this.onOpen,
    required this.onActions,
  });

  final BotStore bots;
  final List<BotIdentity> hiddenBots;
  final void Function(BotIdentity bot) onOpen;
  final void Function(BotIdentity bot) onActions;

  @override
  State<_HiddenBotsSection> createState() => _HiddenBotsSectionState();
}

class _HiddenBotsSectionState extends State<_HiddenBotsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesSectionHeader(
          title: context.l10n.agentHiddenBotsSection,
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          trailing: Semantics(
            expanded: _expanded,
            child: IconButton(
              key: const ValueKey('hidden-bots-toggle'),
              tooltip: context.l10n.agentHiddenBotsSection,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                visualDensity: VisualDensity.standard,
              ),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
        ),
        if (_expanded)
          HermesMobileGroup(
            children: [
              for (final bot in widget.hiddenBots)
                HermesMobileRow(
                  key: ValueKey('bot-hidden-${bot.key}'),
                  alignLeadingToTop: true,
                  leadingSize: 44,
                  icon: Icons.smart_toy_outlined,
                  iconWidget: BotAvatar(
                    name: bot.profile,
                    metadata: bot.metadata,
                    size: 44,
                  ),
                  title: bot.displayName,
                  subtitle: [
                    if (bot.profile != bot.displayName) bot.profile,
                    bot.description,
                  ].where((text) => text.isNotEmpty).join(' · '),
                  onTap: () => widget.onOpen(bot),
                  trailing: IconButton(
                    tooltip: context.l10n.commonMore,
                    onPressed: () => widget.onActions(bot),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
