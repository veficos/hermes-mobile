/// Hermes-mobile global navigation shell（IA 重设计 §3，page-layouts §7.1）。
///
/// S/M 档：Scaffold + 4 项底部 Tab（首页/会话/任务/更多）+ 搜索/审批 FAB。
/// L 档：NavigationRail（4 目的地）+ 主区；Chat 使用 RightSidebar。
/// XL 档（≥1200）：类 IDE 三栏工作台——可折叠侧边导航（64↔240）+
/// 48px 顶栏 + 24px 状态栏 + 主工作区（懒加载 IndexedStack）。
/// Chat is pushed full-screen on top of this shell.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_navigation.dart';
import '../core/connection_reload_mixin.dart';
import '../core/connections/connection_registry.dart';
import '../core/connectivity_service.dart';
import '../core/deep_link_service.dart';
import '../core/external_links.dart';
import '../core/models.dart';
import '../core/notifications_service.dart';
import '../core/stores/command_palette_store.dart';
import '../core/stores/billing_store.dart';
import '../core/stores/bot_store.dart';
import '../core/stores/coding_status_store.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/notification_store.dart';
import '../core/stores/pet_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../core/stores/request_store.dart';
import '../core/stores/session_store.dart';
import '../core/stores/terminal_store.dart';
import '../core/stores/voice_store.dart';
import '../core/stores/update_store.dart';
import '../kanban/store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/command_palette.dart';
import '../widgets/h/hermes_badge.dart';
import '../widgets/h/hermes_logo.dart';
import '../widgets/pet_overlay.dart';
import 'agent_screen.dart';
import 'about_screen.dart';
import 'chat_screen.dart';
import 'connect_screen.dart';
import 'files_screen.dart';
import 'git_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'mcp_screen.dart';
import 'onboarding_screen.dart';
import 'new_session_screen.dart';
import 'notification_screen.dart';
import 'plugins_screen.dart';
import 'request_sheet.dart';
import 'session_list_screen.dart';
import 'settings_hub_screen.dart';
import 'skills_screen.dart';
import 'kanban_canonical_screen.dart';
import 'terminal_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  static const _tabKey = 'hm_app_shell_tab';
  static const _legacyTabKey = 'hm_state_tab';

  /// XL 档侧边导航折叠状态持久化键（design-system §7.2：状态持久化）。
  static const _xlNavKey = 'hm_xl_nav_expanded';
  bool _xlNavExpanded = true;
  bool _wakeNavigationScheduled = false;
  bool _onboardingChecked = false;
  Set<String> _backgroundStreamingIds = {};
  String? _backgroundConnectionId;
  DateTime? _backgroundedAt;
  NotificationsService? _notificationsService;
  DeepLinkService? _deepLinkService;
  UpdateStore? _updateStore;
  bool _updateDialogScheduled = false;
  StreamSubscription<bool>? _connectivitySub;

  // Spec §194: tabs are built lazily — only the visited ones stay alive in
  // the IndexedStack, so cold start only pays for the visible tab.
  // IA：首页 / 会话 / 任务 / 更多。
  static const _tabBuilders = <Widget Function()>[
    HomeScreen.new,
    SessionListScreen.new,
    KanbanCanonicalScreen.new,
    MoreScreen.new,
  ];

  static const _tabIcons = <IconData>[
    Icons.home_outlined,
    Icons.chat_bubble_outline,
    Icons.task_alt_outlined,
    Icons.more_horiz,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationsService = Provider.of<NotificationsService?>(
      context,
      listen: false,
    );
    _notificationsService?.onTapTarget = (target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openNotificationTarget(target));
      });
    };
    _deepLinkService = Provider.of<DeepLinkService?>(context, listen: false);
    _deepLinkService?.handler = (link) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_handleDeepLink(link));
      });
    };
    _updateStore = Provider.of<UpdateStore?>(context, listen: false);
    _updateStore?.addListener(_onUpdateStateChanged);
    _onUpdateStateChanged();
    // Weak-network: nudge the reconnect loop the instant the OS reports
    // connectivity back, instead of waiting out whatever's left of the
    // current backoff delay (see `ConnectionRuntime.notifyConnectivityRegained`).
    final connectivity = Provider.of<ConnectivityService?>(
      context,
      listen: false,
    );
    _connectivitySub = connectivity?.onChange.listen((hasNetwork) {
      if (!hasNetwork || !mounted) return;
      context.read<ConnectionStore>().registry.notifyConnectivityRegained();
      _readOptional<TerminalStore>()?.notifyConnectivityRegained();
    });
    if (connectivity != null) {
      _readOptional<KanbanStore>()?.hasNetwork = () => connectivity.hasNetwork;
    }
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      // P5-3: restore the last active tab after a process kill.
      // IA §6.5 迁移：键值域 5→4，越界旧值（如"更多"伪 Tab 序号）回落首页。
      final current = prefs.getInt(_tabKey);
      final legacy = prefs.getInt(_legacyTabKey);
      final migrated =
          legacy != null && legacy >= 0 && legacy < _tabBuilders.length
          ? legacy
          : 0;
      final saved = current ?? (legacy == null ? null : migrated);
      if (current == null && legacy != null) {
        prefs.setInt(_tabKey, migrated);
        prefs.remove(_legacyTabKey);
      }
      if (saved != null && saved >= 0 && saved < _tabBuilders.length) {
        _selectTab(saved);
      }
      final expanded = prefs.getBool(_xlNavKey);
      if (expanded != null && expanded != _xlNavExpanded) {
        setState(() => _xlNavExpanded = expanded);
      }
    });
    // Pet system: load pet info after first frame so the overlay can appear.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PetStore>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationsService?.onTapTarget = null;
    _deepLinkService?.handler = null;
    _updateStore?.removeListener(_onUpdateStateChanged);
    unawaited(_connectivitySub?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      final enteredBackground =
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden;
      if (enteredBackground) {
        _backgroundedAt ??= DateTime.now();
        context.read<ConnectionStore>().setForeground(false);
      }
      _setNetworkPollingForeground(false);
      _backgroundStreamingIds = {
        for (final row
            in context.read<SessionStore>().sessions ?? const <SessionRow>[])
          if (row.effectivelyStreaming) row.id,
      };
      _backgroundConnectionId = context
          .read<ConnectionStore>()
          .activeConnectionId
          .value;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      context.read<ConnectionStore>().setForeground(true);
      _setNetworkPollingForeground(true);
      unawaited(_reconcileAfterResume(backgroundedAt));
    }
  }

  void _setNetworkPollingForeground(bool foreground) {
    _readOptional<BillingStore>()?.setForeground(foreground);
    _readOptional<CodingStatusStore>()?.setForeground(foreground);
    _readOptional<ProfileScopeStore>()?.setForeground(foreground);
    _readOptional<BotStore>()?.setForeground(foreground);
    _readOptional<KanbanStore>()?.setForeground(foreground);
  }

  T? _readOptional<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _reconcileAfterResume(DateTime? backgroundedAt) async {
    if (!mounted) return;
    // Snapshot the ids this call is responsible for reconciling: a rapid
    // pause→resume while this is still in flight would otherwise overwrite
    // `_backgroundStreamingIds` mid-await, causing either a stale read here
    // or a lost snapshot when we clear the field unconditionally below.
    final pending = _backgroundStreamingIds;
    final pendingConnectionId = _backgroundConnectionId;
    final connection = context.read<ConnectionStore>();
    final sessions = context.read<SessionStore>();
    final notifications = context.read<NotificationStore>();
    final l10n = context.l10n;
    if (pendingConnectionId != null &&
        pendingConnectionId != connection.activeConnectionId.value) {
      _backgroundStreamingIds = _backgroundStreamingIds.difference(pending);
      return;
    }
    try {
      await connection.reconnectAfterResume(
        // iOS may retain the Dart WebSocket object after its underlying
        // network path has gone away. Any observed background transition is
        // enough reason to replace it; checking isConnected is not a useful
        // liveness probe in that state.
        refreshSocket: backgroundedAt != null,
      );
    } catch (_) {
      return;
    }
    if (pendingConnectionId != null &&
        pendingConnectionId != connection.activeConnectionId.value) {
      _backgroundStreamingIds = _backgroundStreamingIds.difference(pending);
      return;
    }
    final loaded = sessions.sessions?.length ?? 0;
    try {
      await sessions.refreshList(
        limit: loaded > SessionStore.sessionPageSize
            ? loaded
            : SessionStore.sessionPageSize,
      );
    } catch (_) {
      return;
    }
    final rows = sessions.sessions ?? const <SessionRow>[];
    for (final row in rows) {
      if (pending.contains(row.id) && !row.effectivelyStreaming) {
        notifications.addExternal(
          key: 'resume-complete:${row.id}:${row.lastMessageAt ?? 0}',
          kind: NotificationKind.success,
          title: l10n.appSessionCompletedTitle,
          message: row.title?.trim().isNotEmpty == true
              ? row.title!.trim()
              : l10n.appSessionCompletedBody,
          sessionId: row.id,
          connectionId: pendingConnectionId,
          profile: row.profile,
        );
      }
    }
    _backgroundStreamingIds = _backgroundStreamingIds.difference(pending);
    if (_backgroundStreamingIds.isEmpty) _backgroundConnectionId = null;
  }

  Future<void> _openNotificationTarget(NotificationTarget target) async {
    final store = context.read<NotificationStore>();
    if (target.notificationId.isNotEmpty) {
      store.markRead(target.notificationId);
    }
    if (target.approval) {
      final navContext = hermesNavigatorKey.currentContext ?? context;
      final owner = target.connectionId == null
          ? null
          : OwnerRoute(
              connectionId: ConnectionId(target.connectionId!),
              profile: target.profile,
            );
      await showRequestSheet(
        navContext,
        requestId: target.requestId,
        ownerRoute: owner,
        sessionId: target.sessionId,
      );
      return;
    }
    final sessionId = target.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      hermesNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const NotificationScreen()),
      );
      return;
    }

    final connection = context.read<ConnectionStore>();
    final sessions = context.read<SessionStore>();
    try {
      final requestedConnection = target.connectionId;
      if (requestedConnection != null && requestedConnection.isNotEmpty) {
        final id = ConnectionId(requestedConnection);
        if (connection.registry.runtime(id) != null &&
            connection.activeConnectionId != id) {
          connection.activateConnection(id);
        }
        await sessions.resumeOwnedSession(
          sessionId,
          OwnerRoute(connectionId: id, profile: target.profile),
        );
      } else {
        await sessions.resumeSession(sessionId, profile: target.profile);
      }
      if (!mounted) return;
      hermesNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
      );
    } catch (error) {
      final navContext = hermesNavigatorKey.currentContext ?? context;
      if (!navContext.mounted) return;
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(
          content: Text(navContext.l10n.appOpenNotificationFailed('$error')),
        ),
      );
    }
  }

  Future<void> _handleDeepLink(HermesDeepLink link) async {
    final action = resolveDeepLink(link);
    switch (action) {
      case SessionDeepLinkAction():
        await _openNotificationTarget(
          NotificationTarget(
            notificationId: '',
            sessionId: action.sessionId,
            connectionId: action.connectionId,
            profile: action.profile,
          ),
        );
      case BlueprintDeepLinkAction():
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('hm_chat_draft', action.command);
        if (!mounted) return;
        final sessions = context.read<SessionStore>();
        hermesNavigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => sessions.hasSession
                ? const ChatScreen()
                : NewSessionScreen(initialDraftText: action.command),
          ),
        );
      case PluginInstallDeepLinkAction():
        await _confirmPluginInstall(action);
      case McpInstallDeepLinkAction():
        await _confirmMcpInstall(action.request);
      case RejectedDeepLinkAction():
        _showDeepLinkMessage(action.reason, error: true);
    }
  }

  Future<void> _confirmPluginInstall(
    PluginInstallDeepLinkAction request,
  ) async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final profile = context.read<SessionStore>().activeProfile;
    if (api == null) {
      _showDeepLinkMessage(context.l10n.backendDisconnected, error: true);
      return;
    }
    var enable = request.enable;
    var force = request.force;
    final navContext = hermesNavigatorKey.currentContext ?? context;
    final accepted = await showDialog<bool>(
      context: navContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(dialogContext.l10n.deepLinkPluginInstallTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dialogContext.l10n.deepLinkPluginInstallPrompt),
              const SizedBox(height: 8),
              SelectableText(
                request.identifier,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'HermesJetBrainsMono',
                ),
              ),
              if (request.legacyKind == 'plugin-desktop')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(dialogContext.l10n.deepLinkLegacyPluginWarning),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(dialogContext.l10n.deepLinkEnableAfterInstall),
                value: enable,
                onChanged: (value) => setDialogState(() => enable = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(dialogContext.l10n.deepLinkForceReinstall),
                value: force,
                onChanged: (value) => setDialogState(() => force = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.l10n.commonCancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download, size: 18),
              label: Text(dialogContext.l10n.deepLinkInstall),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      requireActiveApi(context, connection, api);
      _showDeepLinkMessage(
        context.l10n.deepLinkPluginInstalling(request.identifier),
      );
      await connection.installPlugin(
        request.identifier,
        enable: enable,
        force: force,
        profile: profile,
      );
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      _showDeepLinkMessage(context.l10n.deepLinkPluginInstalled);
      hermesNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const PluginsScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      _showDeepLinkMessage(
        context.l10n.deepLinkPluginInstallFailed('$error'),
        error: true,
      );
    }
  }

  Future<void> _confirmMcpInstall(McpInstallRequest request) async {
    final connection = context.read<ConnectionStore>();
    final profile = context.read<SessionStore>().activeProfile;
    final api = connection.api;
    if (api == null) {
      _showDeepLinkMessage(context.l10n.backendDisconnected, error: true);
      return;
    }
    Set<String> existing = {};
    try {
      existing = (await api.mcpServers(profile: profile))
          .map((server) => server['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();
    } catch (_) {
      // Confirmation remains usable; the backend enforces the final write.
    }
    if (!mounted) return;
    try {
      requireActiveApi(context, connection, api);
    } catch (error) {
      _showDeepLinkMessage('$error', error: true);
      return;
    }

    final name = TextEditingController(text: request.name);
    var valid = true;
    final navContext = hermesNavigatorKey.currentContext ?? context;
    if (!navContext.mounted) {
      name.dispose();
      return;
    }
    final accepted = await showDialog<bool>(
      context: navContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final trimmed = name.text.trim();
          final formatOk = RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(trimmed);
          final conflict = existing.contains(trimmed);
          valid = formatOk && !conflict;
          return AlertDialog(
            title: Text(dialogContext.l10n.deepLinkMcpAddTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: dialogContext.l10n.deepLinkMcpServerName,
                      errorText: !formatOk
                          ? dialogContext.l10n.deepLinkMcpNameFormatError
                          : conflict
                          ? dialogContext.l10n.deepLinkMcpNameConflict
                          : null,
                    ),
                  ),
                  if (request.transport == 'stdio')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        dialogContext.l10n.deepLinkMcpCommandWarning,
                        style: const TextStyle(color: HermesSemantic.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    dialogContext.l10n.deepLinkConfigPreview,
                    style: Theme.of(dialogContext).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(request.config),
                    style: Theme.of(dialogContext).textTheme.bodySmall
                        ?.copyWith(fontFamily: 'HermesJetBrainsMono'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.l10n.commonCancel),
              ),
              FilledButton.icon(
                onPressed: valid
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                icon: const Icon(Icons.add, size: 18),
                label: Text(dialogContext.l10n.commonAdd),
              ),
            ],
          );
        },
      ),
    );
    final serverName = name.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => name.dispose());
    if (accepted != true || !valid || !mounted) return;
    try {
      requireActiveApi(context, connection, api);
      await api.mcpCreate({
        'name': serverName,
        ...request.config,
      }, profile: profile);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      _showDeepLinkMessage(context.l10n.deepLinkMcpAdded(serverName));
      hermesNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const McpScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      _showDeepLinkMessage(
        context.l10n.deepLinkMcpAddFailed('$error'),
        error: true,
      );
    }
  }

  void _showDeepLinkMessage(String message, {bool error = false}) {
    final navContext = hermesNavigatorKey.currentContext ?? context;
    if (!navContext.mounted) return;
    ScaffoldMessenger.of(navContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? HermesSemantic.red : null,
      ),
    );
  }

  void _onUpdateStateChanged() {
    final updates = _updateStore;
    if (updates?.requiresUpdate != true || _updateDialogScheduled) return;
    _updateDialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showRequiredUpdateDialog(updates!));
    });
  }

  Future<void> _showRequiredUpdateDialog(UpdateStore updates) async {
    final navContext = hermesNavigatorKey.currentContext ?? context;
    if (!navContext.mounted) return;
    await showDialog<void>(
      context: navContext,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(navContext.l10n.updateRequiredTitle),
          content: Text(
            updates.manifest?.message?.isNotEmpty == true
                ? updates.manifest!.message!
                : navContext.l10n.updateRequiredDefault(
                    updates.currentVersion,
                    updates.manifest!.minimumSupportedVersion,
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  launchExternalOrNotify(navContext, updates.releaseNotesUri),
              child: Text(navContext.l10n.updateReleaseNotes),
            ),
            FilledButton.icon(
              onPressed: () =>
                  launchExternalOrNotify(navContext, updates.updateUri),
              icon: const Icon(Icons.system_update_outlined, size: 18),
              label: Text(navContext.l10n.updateGoToUpdate),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int i) {
    setState(() => _index = i);
    // Persist lazily; failures are non-fatal.
    SharedPreferences.getInstance().then((prefs) => prefs.setInt(_tabKey, i));
  }

  void _toggleXlNav() {
    final next = !_xlNavExpanded;
    setState(() => _xlNavExpanded = next);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_xlNavKey, next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionStore>();
    final requests = context.watch<RequestStore>();
    final voice = context.watch<VoiceStore>();

    if (voice.wakeDetection != null &&
        !_wakeNavigationScheduled &&
        ModalRoute.of(context)?.isCurrent != false) {
      _wakeNavigationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _wakeNavigationScheduled = false;
        if (context.read<VoiceStore>().wakeDetection == null) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
      });
    }

    if (!connection.isConfigured) {
      return const ConnectScreen();
    }

    if (!_onboardingChecked) {
      _onboardingChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        if (await hasSeenOnboarding()) return;
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const OnboardingScreen(),
            fullscreenDialog: true,
          ),
        );
      });
    }

    final width = MediaQuery.of(context).size.width;
    final isXl = width >= HermesBreakpoints.desktop;
    final isTablet = width >= HermesBreakpoints.navigation && !isXl;

    // Reconnect banner (spec §149): Offline → Connecting → Connected.
    final reconnecting = connection.phase == ConnectionPhase.reconnecting;
    final connecting = connection.phase == ConnectionPhase.connecting;

    final body = Column(
      children: [
        if (reconnecting || connecting)
          Material(
            color: reconnecting
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reconnecting
                          ? context.l10n.shellReconnecting
                          : context.l10n.connectConnecting,
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(
                      connection
                          .reconnectAfterResume(refreshSocket: true)
                          .catchError((_) {}),
                    ),
                    child: Text(context.l10n.shellReconnectNow),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _LazyIndexedStack(index: _index, builders: _tabBuilders),
        ),
      ],
    );

    if (isXl) {
      // XL 档：类 IDE 三栏工作台（design-system §7.2）。
      return PetOverlay(
        child: Stack(
          children: [
            Scaffold(
              body: Column(
                children: [
                  _XlTopBar(title: _tabLabels(context)[_index]),
                  Expanded(
                    child: Row(
                      children: [
                        _buildXlSideNav(context, connection, requests),
                        const VerticalDivider(width: 1),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                  const _XlStatusBar(),
                ],
              ),
            ),
            const CommandPalette(),
          ],
        ),
      );
    }

    if (isTablet) {
      // Tablet: NavigationRail + Main + ContextRail (spec §164).
      // Rail 目的地与手机 Tab 对齐（首页/会话/任务/更多）。
      return PetOverlay(
        child: Stack(
          children: [
            Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    key: const ValueKey('app-shell-tablet-navigation'),
                    selectedIndex: _index,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    leading: FloatingActionButton.small(
                      heroTag: 'palette_rail',
                      tooltip: context.l10n.commonSearch,
                      onPressed: () =>
                          context.read<CommandPaletteStore>().open(),
                      child: const Icon(Icons.search),
                    ),
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home),
                        label: Text(context.l10n.navHome),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.chat_bubble_outline),
                        selectedIcon: const Icon(Icons.chat_bubble),
                        label: Text(context.l10n.navSessions),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.task_alt_outlined),
                        selectedIcon: const Icon(Icons.task_alt),
                        label: Text(context.l10n.navTasks),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.more_horiz),
                        selectedIcon: const Icon(Icons.more_horiz),
                        label: Text(context.l10n.navMore),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
            const CommandPalette(),
          ],
        ),
      );
    }

    // Phone: compact four-tab navigation matching the mobile prototype.
    // Search is exposed by page headers so it no longer obscures content.
    return PetOverlay(
      child: Stack(
        children: [
          Scaffold(
            body: body,
            bottomNavigationBar: _PrototypeBottomNavigation(
              selectedIndex: _index,
              pendingRequests: requests.pendingCount,
              onSelected: _selectTab,
            ),
            floatingActionButton: requests.pendingCount > 0
                ? FloatingActionButton.small(
                    heroTag: 'requests',
                    onPressed: () => showRequestSheet(context),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.rule),
                        Positioned(
                          right: -6,
                          top: -4,
                          child: HermesBadge(count: requests.pendingCount),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          const CommandPalette(),
        ],
      ),
    );
  }

  /// XL 档侧边导航：可折叠 64↔240，激活条目 accentBg 底 + 左 3px accent
  /// 竖条；底部固定设置与连接状态（design-system §6.11 / IA §3.3）。
  Widget _buildXlSideNav(
    BuildContext context,
    ConnectionStore connection,
    RequestStore requests,
  ) {
    final labels = _tabLabels(context);
    final l10n = context.l10n;
    final palette = HermesPalette.of(context);
    final expanded = _xlNavExpanded;
    return AnimatedContainer(
      key: const ValueKey('app-shell-xl-navigation'),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: const Cubic(0.3, 0, 0.2, 1),
      width: expanded ? 240 : 64,
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 品牌头部 + 折叠开关
          SizedBox(
            height: 56,
            child: expanded
                ? Row(
                    children: [
                      const SizedBox(width: 16),
                      const HermesLogo(size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hermes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.shellCollapseNavigation,
                        iconSize: 20,
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _toggleXlNav,
                      ),
                    ],
                  )
                : Center(
                    child: IconButton(
                      tooltip: l10n.shellExpandNavigation,
                      iconSize: 20,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _toggleXlNav,
                    ),
                  ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                      child: Text(
                        l10n.shellNavigation,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: palette.text4,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                  if (expanded) _xlSectionLabel(context, l10n.shellSessionArea),
                  _xlNavItem(
                    context,
                    icon: _tabIcons[0],
                    label: labels[0],
                    selected: _index == 0,
                    badgeCount: requests.pendingCount,
                    onTap: () => _selectTab(0),
                  ),
                  _xlNavItem(
                    context,
                    icon: _tabIcons[1],
                    label: labels[1],
                    selected: _index == 1,
                    onTap: () => _selectTab(1),
                  ),
                  if (expanded)
                    _xlSectionLabel(context, l10n.shellWorkspaceArea),
                  _xlNavItem(
                    context,
                    icon: _tabIcons[2],
                    label: labels[2],
                    selected: _index == 2,
                    onTap: () => _selectTab(2),
                  ),
                  _xlNavItem(
                    context,
                    icon: Icons.folder_open_outlined,
                    label: l10n.featureFiles,
                    selected: false,
                    onTap: () => _pushPage(context, const FilesScreen()),
                  ),
                  _xlNavItem(
                    context,
                    icon: Icons.terminal_outlined,
                    label: l10n.featureTerminal,
                    selected: false,
                    onTap: () => _pushPage(context, const TerminalScreen()),
                  ),
                  _xlNavItem(
                    context,
                    icon: Icons.account_tree_outlined,
                    label: l10n.featureGit,
                    selected: false,
                    onTap: () => _pushPage(context, const GitScreen()),
                  ),
                  if (expanded)
                    _xlSectionLabel(context, l10n.shellIntelligenceArea),
                  _xlNavItem(
                    context,
                    icon: Icons.bolt_outlined,
                    label: l10n.featureAgent,
                    selected: false,
                    onTap: () => _pushPage(context, const AgentScreen()),
                  ),
                  _xlNavItem(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    label: l10n.featureSkills,
                    selected: false,
                    onTap: () => _pushPage(context, const SkillsScreen()),
                  ),
                  _xlNavItem(
                    context,
                    icon: _tabIcons[3],
                    label: labels[3],
                    selected: _index == 3,
                    onTap: () => _selectTab(3),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: palette.border),
          _xlNavItem(
            context,
            icon: Icons.settings_outlined,
            label: l10n.featureSettings,
            selected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsHubScreen()),
            ),
          ),
          _xlNavItem(
            context,
            icon: Icons.info_outline,
            label: l10n.featureAbout,
            selected: false,
            onTap: () => _pushPage(context, const AboutScreen()),
          ),
          _xlNavItem(
            context,
            icon: connection.isConnected
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            label: connection.isConnected
                ? l10n.commonConnected
                : l10n.commonDisconnected,
            selected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsHubScreen()),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _pushPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _xlSectionLabel(BuildContext context, String label) {
    final palette = HermesPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.text4,
        ),
      ),
    );
  }

  Widget _xlNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    int badgeCount = 0,
    VoidCallback? onTap,
  }) {
    final palette = HermesPalette.of(context);
    final expanded = _xlNavExpanded;
    final iconColor = selected ? palette.accent : palette.text3;
    final iconWidget = badgeCount > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20, color: iconColor),
              Positioned(
                right: -6,
                top: -4,
                child: HermesBadge(count: badgeCount),
              ),
            ],
          )
        : Icon(icon, size: 20, color: iconColor);
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected ? palette.accentBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 0),
        child: expanded
            ? Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: selected ? palette.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 9),
                  iconWidget,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? palette.text : palette.text2,
                      ),
                    ),
                  ),
                ],
              )
            : Center(child: iconWidget),
      ),
    );
    final wrapped = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: child,
      ),
    );
    return expanded ? wrapped : Tooltip(message: label, child: wrapped);
  }
}

class _PrototypeBottomNavigation extends StatelessWidget {
  const _PrototypeBottomNavigation({
    required this.selectedIndex,
    required this.pendingRequests,
    required this.onSelected,
  });

  final int selectedIndex;
  final int pendingRequests;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final labels = _tabLabels(context);
    const icons = [
      Icons.home_outlined,
      Icons.chat_bubble_outline,
      Icons.task_alt_outlined,
      Icons.more_horiz,
    ];
    return DecoratedBox(
      key: const ValueKey('app-shell-phone-navigation'),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var index = 0; index < labels.length; index++)
                Expanded(
                  child: Semantics(
                    selected: selectedIndex == index,
                    button: true,
                    label: labels[index],
                    child: InkWell(
                      onTap: () => onSelected(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selectedIndex == index
                                  ? palette.accentBg
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: index == 1 && pendingRequests > 0
                                ? Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        icons[index],
                                        size: 19,
                                        color: selectedIndex == index
                                            ? palette.accent
                                            : palette.text3,
                                      ),
                                      Positioned(
                                        right: -6,
                                        top: -4,
                                        child: HermesBadge(
                                          count: pendingRequests,
                                        ),
                                      ),
                                    ],
                                  )
                                : Icon(
                                    icons[index],
                                    size: 19,
                                    color: selectedIndex == index
                                        ? palette.accent
                                        : palette.text3,
                                  ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selectedIndex == index
                                  ? palette.accent
                                  : palette.text3,
                              fontSize: 11,
                              height: 1.1,
                              fontWeight: selectedIndex == index
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
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
}

List<String> _tabLabels(BuildContext context) {
  final l10n = context.l10n;
  return [l10n.navHome, l10n.navSessions, l10n.navTasks, l10n.navMore];
}

/// XL 档顶栏（48px）：页面标题 + 全局搜索入口（⌘K）+ 连接状态点 + 审批角标。
class _XlTopBar extends StatelessWidget {
  final String title;
  const _XlTopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = HermesPalette.of(context);
    final connection = context.watch<ConnectionStore>();
    final requests = context.watch<RequestStore>();
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
          Tooltip(
            message: l10n.globalSearch,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => context.read<CommandPaletteStore>().open(),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 15, color: palette.text3),
                      const SizedBox(width: 6),
                      Text(
                        l10n.commonSearch,
                        style: TextStyle(fontSize: 12, color: palette.text3),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '⌘K',
                        style: TextStyle(fontSize: 11, color: palette.text4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: connection.isConnected
                ? l10n.backendConnected
                : l10n.backendDisconnected,
            child: Icon(
              Icons.circle,
              size: 10,
              color: connection.isConnected
                  ? HermesSemantic.green
                  : HermesSemantic.red,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.commonNotifications,
            icon: const Icon(Icons.notifications_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
          ),
          const CircleAvatar(
            radius: 14,
            child: Icon(Icons.person_outline, size: 17),
          ),
          if (requests.pendingCount > 0) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: l10n.approvalRequests,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.rule_outlined, size: 20),
                  Positioned(
                    right: -6,
                    top: -4,
                    child: HermesBadge(count: requests.pendingCount),
                  ),
                ],
              ),
              onPressed: () => showRequestSheet(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// XL 档状态栏（24px）：后端连接 · 当前模型 · 工作区路径 · Agent 状态。
/// 数据全部来自现有 store；读不到时显示占位"—"，不编造数据。
class _XlStatusBar extends StatelessWidget {
  const _XlStatusBar();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = HermesPalette.of(context);
    final connection = context.watch<ConnectionStore>();
    final session = context.watch<SessionStore>();
    final info = session.info;
    final style = TextStyle(fontSize: 11, color: palette.text3);
    Widget sep() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('·', style: style),
    );

    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Container(
      height: 24 * textScale,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 7,
            color: connection.isConnected
                ? HermesSemantic.green
                : HermesSemantic.red,
          ),
          const SizedBox(width: 5),
          Text(
            connection.isConnected
                ? l10n.commonConnected
                : l10n.commonDisconnected,
            style: style,
          ),
          sep(),
          Text(l10n.shellModelStatus(info?.model ?? '—'), style: style),
          sep(),
          Flexible(
            child: Text(
              l10n.shellWorkspaceStatus(info?.cwd ?? '—'),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          sep(),
          Text(
            l10n.shellAgentStatus(
              info?.running == true ? l10n.commonRunning : l10n.commonIdle,
            ),
            style: style,
          ),
        ],
      ),
    );
  }
}

/// `IndexedStack` that defers building each tab until first visited. Once a
/// tab has been built, its widget instance is reused on subsequent rebuilds
/// so its `State` is preserved (spec §194: faster cold start).
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget Function()> builders;

  const _LazyIndexedStack({required this.index, required this.builders});

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<Widget?> _built;

  @override
  void initState() {
    super.initState();
    _built = List<Widget?>.filled(
      widget.builders.length,
      null,
      growable: false,
    );
    _ensureBuilt(widget.index);
  }

  void _ensureBuilt(int i) {
    if (i < 0 || i >= _built.length) return;
    _built[i] ??= widget.builders[i]();
  }

  @override
  Widget build(BuildContext context) {
    _ensureBuilt(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < _built.length; i++)
          _built[i] ?? const SizedBox.shrink(),
      ],
    );
  }
}
