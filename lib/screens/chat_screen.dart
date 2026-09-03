/// ChatScreen — full-screen chat experience (spec §22–36).
///
/// Header (back + title/subtitle + interrupt + more menu), message timeline
/// with scroll-to-top pagination and streaming auto-scroll, and the floating
/// glass composer with image / voice / model picker / draft restore.
library;

export '../core/chat_scroll_coordinator.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/chat_message.dart';
import '../core/clipboard.dart';
import '../core/composer_input_history.dart';
import '../core/composer_suggestions.dart';
import '../chat/transcript/scroll_coordinator.dart';
import '../core/diagnostics.dart';
import '../core/external_links.dart';
import '../core/local_file_io.dart';
import '../core/local_slash_commands.dart';
import '../core/model_catalog.dart';
import '../core/models.dart';
import '../core/performance_metrics.dart';
import '../core/session_tree.dart';
import '../core/session_refs.dart';
import '../chat/composer/background_process_sheet.dart';
import '../chat/composer/session_completion.dart';
import '../core/structured_composer_controller.dart';
import '../chat/timeline/chat_timeline.dart';
import '../chat/timeline/changed_files_card.dart';
import '../chat/timeline/turn_activity_card.dart';
import '../chat/tools/tool_group_card.dart';
import '../chat/tools/tool_dismiss_store.dart';
import '../core/stores/appearance_store.dart';
import '../core/stores/chat_store.dart';
import '../core/stores/billing_store.dart';
import '../core/stores/command_store.dart';
import '../core/stores/composer_status_store.dart';
import '../core/stores/coding_status_store.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../core/stores/preview_store.dart';
import '../core/stores/pull_request_store.dart';
import '../core/stores/request_store.dart';
import '../core/stores/session_store.dart';
import '../core/stores/voice_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/adaptive_form_dialog.dart';
import '../widgets/h/hermes_badge.dart';
import '../widgets/h/hermes_composer.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/h/hermes_voice_menu.dart';
import '../widgets/chat_enter_to_send.dart';
import '../widgets/message_bubble.dart';
import '../widgets/model_picker_sheet.dart';
import '../widgets/pet_overlay.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import '../widgets/web_preview.dart';
import '../widgets/right_sidebar/right_sidebar.dart';
import '../widgets/session/session_detail_panel.dart';
import '../widgets/session/session_list_meta.dart';
import 'request_sheet.dart';
import 'provider_config_screen.dart';
import 'billing_screen.dart';
import 'files_screen.dart';
import 'git_screen.dart';
import 'skills_screen.dart';
import 'pet_generate_screen.dart';
import 'starmap_screen.dart';

String _chatStatusKindLabel(BuildContext context, String kind) =>
    switch (kind.trim().toLowerCase()) {
      'compacting' => context.l10n.chatCompactingThread,
      'tool-drafting' || 'tool_drafting' => context.l10n.chatStatusToolDrafting,
      'notification' => context.l10n.chatHermesNotification,
      'provider' => context.l10n.chatStatusProvider,
      _ => kind,
    };

extension _MaybeRead on BuildContext {
  /// Reads a provider if it exists in the tree, otherwise returns null.
  /// Keeps the screen usable in test harnesses that don't wire every store.
  T? maybeRead<T>() {
    try {
      return read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class ChatPageBackButton extends StatelessWidget {
  const ChatPageBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.chatBackToWorkspace,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  /// When opened from the sidebar's full-text search, jump to the exact
  /// message returned by the server instead of merely opening the session.
  final String? initialMessageId;
  final String? initialSearchQuery;
  final bool recallNewChatDraft;
  final bool embedded;
  final String? surfaceId;
  final String? initialDraftText;
  final String? initialDraftSaveError;

  const ChatScreen({
    super.key,
    this.initialMessageId,
    this.initialSearchQuery,
    this.recallNewChatDraft = false,
    this.embedded = false,
    this.surfaceId,
    this.initialDraftText,
    this.initialDraftSaveError,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composerCtrl = StructuredComposerController();
  final _composerHistory = ComposerInputHistory();
  String _composerHistoryKey(String scope) =>
      'hm_composer_input_history_v1:$scope';
  final _composerFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sending = false;
  String? _continuousHandledReplyId;
  bool _continuousAdvanceScheduled = false;
  bool _wakeHandling = false;
  String? _autoSpokenReplyId;
  bool _desktopSidebarReady = false;

  // ── Inline message editing (WebUI .msg-edit-area parity): the bubble
  // under edit is swapped for an in-place textarea; confirm re-sends
  // through the real rewind/edit chain, Esc/cancel restores. ──
  String? _editingMessageId;
  final _editCtrl = TextEditingController();
  final _editFocus = FocusNode();

  /// Autocomplete (slash / @path / @session) normally targets the main
  /// composer; while an inline message edit is open it retargets the edit
  /// field so F1 parity (completions in the edit position) comes for free.
  TextEditingController? _acTargetOverride;
  TextEditingController get _acTarget => _acTargetOverride ?? _composerCtrl;
  FocusNode get _acFocus =>
      _acTargetOverride != null ? _editFocus : _composerFocus;

  /// Attachments staged while an inline edit is open (composed into the edited
  /// text on submit, like the main composer).
  List<ComposerAttachment> _editAttachments = const [];
  final _scrollCoordinator = ChatScrollCoordinator();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final Set<String> _mountedUserMessageIds = <String>{};
  final ValueNotifier<String?> _activeTopic = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _stuckToBottom = ValueNotifier<bool>(true);
  bool _activeTopicUpdateScheduled = false;

  /// Id of the user turn nearest the top of the viewport — highlights its dot
  /// in the topic rail (desktop timeline "active tick" parity).
  final Set<String> _markedMessageIds = <String>{};
  String? _markerSessionId;
  String? _locatorHighlightId;
  Timer? _locatorHighlightTimer;
  final _findCtrl = TextEditingController();
  final _findFocus = FocusNode();
  bool _findOpen = false;
  int _findIndex = -1;
  bool _initialSearchLocated = false;
  bool _initialSearchPaging = false;
  bool _loadingOlderViewport = false;
  Timer? _backgroundPollTimer;
  StreamSubscription<ComposerStatusItem>? _backgroundCompletionSub;
  StreamSubscription<ChatStatusItem>? _agentNoticeSub;
  StreamSubscription<void>? _autoRetrySub;
  final Stopwatch _autoScrollLogWatch = Stopwatch()..start();
  int _lastAutoScrollLogMs = -500;
  int _lastAutoScrollSkipLogMs = -500;

  bool get _diagnosticLogging => kDebugMode || kProfileMode;

  List<ChatMessage> _findMatches(ChatStore chat) {
    final query = _findCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return chat.messages
        .where((message) => message.fullText.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _toggleFind() {
    setState(() {
      _findOpen = !_findOpen;
      if (!_findOpen) {
        _findCtrl.clear();
        _findIndex = -1;
        _locatorHighlightId = null;
      }
    });
    if (_findOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _findFocus.requestFocus();
      });
    }
  }

  void _stepFind(ChatStore chat, {required bool forward}) {
    final matches = _findMatches(chat);
    if (matches.isEmpty) {
      setState(() {
        _findIndex = -1;
        _locatorHighlightId = null;
      });
      return;
    }
    final candidate = _findIndex < 0
        ? (forward ? 0 : matches.length - 1)
        : (_findIndex + (forward ? 1 : -1)) % matches.length;
    final next = candidate < 0 ? candidate + matches.length : candidate;
    setState(() => _findIndex = next);
    _locateMessage(matches[next]);
  }

  void _logScroll(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_diagnosticLogging) return;
    developer.log(
      message,
      name: 'hermes.chat.scroll',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Desktop parity: attachments list for the composer
  List<ComposerAttachment> _attachments = const [];

  /// WebUI `MAX_UPLOAD_BYTES` (ui.js:16): files larger than 20 MB are
  /// rejected before upload.
  static const int _maxUploadBytes = 20 * 1024 * 1024;

  // Queue strip (above the composer) expand/collapse state.
  bool _queueStripExpanded = false;
  bool _statusDetailsExpanded = false;
  final Set<ComposerStatusType> _collapsedStatusGroups = {
    ComposerStatusType.subagent,
    ComposerStatusType.background,
    ComposerStatusType.preview,
  };
  String? _editingQueuedMessageId;

  // ── WebUI agent-session draft persistence state ──
  String? _lastDraftSid;
  ComposerDraft _rememberedServerDraft = const ComposerDraft();
  bool _draftRestoreInProgress = false;
  int _draftRestoreGeneration = 0;
  bool _sessionChangeScheduled = false;

  Future<void> _showSkills() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (c) => const SkillsScreen()));
  }

  /// Shared cross-screen chat draft key (terminal "send to chat").
  static const _sharedDraftKey = 'hm_chat_draft';

  // Batch 3.3: slash / @mention autocomplete state.
  List<SlashSuggestion> _slashSuggestions = const [];
  List<PathSuggestion> _pathSuggestions = const [];
  List<SessionRefSuggestion> _sessionRefSuggestions = const [];
  bool _slashSuggestionsLoading = false;
  bool _slashSuggestionQueryActive = false;
  int _slashSuggestionIndex = 0;
  int _slashReplaceFrom = 1;
  Timer? _acDebounce;
  // Passive draft suggestion (desktop's cron suggestion-provider parity):
  // the matched recurrence phrase, or null. Dismissal is keyed to the exact
  // phrase so it stays gone while the user keeps typing around it, but
  // reappears if they delete it and type a different recurring phrase.
  String? _cronSuggestionPhrase;
  String? _cronSuggestionDismissedFor;
  // Yolo state is initialized from the real backend config (`yolo` key).
  // null = the backend exposes no such field → the menu entry stays hidden
  // instead of showing a made-up initial state.
  bool? _yoloEnabled;
  double? _contextUsagePercent;

  // ── Real composer context, loaded from the domain API ──
  Map<String, dynamic> _serverConfig = const {};
  int _composerContextGeneration = 0;

  SessionStore get _session => context.read<SessionStore>();
  List<ProfileInfo> get _profiles => _session.profiles;
  String? get _activeProfileName => _session.activeProfile;
  bool _configLoaded = false;
  List<ToolsetInfo> _sessionToolsets = const [];
  List<ToolsetInfo> _globalCliToolsets = const [];
  bool _sessionToolsetsLoaded = false;
  bool _globalCliToolsetsLoaded = false;
  bool _showGlobalToolsets = false;

  bool get _toolsetsSessionScoped =>
      _sessionToolsetsLoaded && !_showGlobalToolsets;
  bool get _toolsetsLoaded =>
      _sessionToolsetsLoaded || _globalCliToolsetsLoaded;
  List<ToolsetInfo> get _toolsets =>
      _toolsetsSessionScoped ? _sessionToolsets : _globalCliToolsets;

  // 临时按 Hermes 当前静态定义中的组合工具集名称分组；后端提供类型字段后应改为读取接口。
  static const _compositeToolsetNames = {'debugging', 'safe', 'hermes-gateway'};

  String _toolsetCountLabel(List<ToolsetInfo> toolsets) =>
      '${toolsets.where((toolset) => toolset.enabled).length}/${toolsets.length}';

  List<(String?, int?)> get _toolsetDisplayEntries {
    if (!_toolsetsSessionScoped) {
      return [for (var i = 0; i < _toolsets.length; i++) (null, i)];
    }
    final basic = <int>[];
    final composite = <int>[];
    for (var i = 0; i < _toolsets.length; i++) {
      (_compositeToolsetNames.contains(_toolsets[i].name) ? composite : basic)
          .add(i);
    }
    return [
      if (basic.isNotEmpty) ...[
        (context.l10n.chatBasicToolsets, null),
        for (final i in basic) (null, i),
      ],
      if (composite.isNotEmpty) ...[
        (context.l10n.chatCompositeToolsets, null),
        for (final i in composite) (null, i),
      ],
    ];
  }

  String get _toolsetsLabel {
    final sessionCount = _sessionToolsetsLoaded
        ? _toolsetCountLabel(_sessionToolsets)
        : context.l10n.chatNotConnected;
    final globalCount = _globalCliToolsetsLoaded
        ? _toolsetCountLabel(_globalCliToolsets)
        : context.l10n.chatLoadFailed;
    if (!_sessionToolsetsLoaded && _globalCliToolsetsLoaded) {
      return context.l10n.chatToolsetsEnabled(globalCount);
    }
    return context.l10n.chatToolsetCounts(sessionCount, globalCount);
  }

  String? _defaultCwd;
  List<Map<String, dynamic>> _workspaceProjects = const [];
  String? _workspaceCwd; // explicit pick for the current session

  // A18: saved prompts (WebUI btnSavedPrompts). Hidden unless the server
  // actually serves the prompts resource.
  bool _savedPromptsSupported = false;

  // A16: ambient provider quota chip (WebUI providerQuotaChip). Null unless
  // the backend reported real quota data.
  String? _quotaLabel;
  String? _quotaMessage;

  @override
  void initState() {
    super.initState();
    final initialDraft = widget.initialDraftText?.trim() ?? '';
    if (initialDraft.isNotEmpty) {
      _composerCtrl.text = initialDraft;
      _composerCtrl.selection = TextSelection.collapsed(
        offset: initialDraft.length,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draftError = widget.initialDraftSaveError;
      if (mounted && draftError != null && draftError.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatDraftHandoffSaveFailed(draftError)),
          ),
        );
      }
      if (mounted && MediaQuery.sizeOf(context).width >= 840) {
        setState(() => _desktopSidebarReady = true);
      }
    });
    _scrollCtrl.addListener(_onScroll);
    _composerCtrl.addListener(_onComposerChanged);
    // E1: track whether the user is near the bottom.
    _onScroll();
    // Pull a cross-screen draft (e.g. from the terminal "发送到聊天" action)
    // before the composer's own draft restore runs — the composer only
    // restores when its controller is empty, so this wins.
    if (initialDraft.isEmpty) _restoreSharedDraft();
    _restoreMessageMarkers();
    // Lazy-load the slash command catalog (best-effort, errors swallowed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CommandStore>().loadCatalog();
      _loadComposerContext();
      unawaited(_loadToolsets());
    });
    _startBackgroundPolling();
    // Desktop parity: `store/keep-awake.ts` (opt-in, off by default) — the
    // mobile analog of "don't let the machine sleep during a long run" is
    // keeping the *screen* on while this chat is the foreground surface.
    // Nullable read: several widget-test harnesses render ChatScreen with
    // no AppearanceStore above it (that dependency didn't exist before this
    // feature), so a plain `read<AppearanceStore>()` would throw there.
    if (context.maybeRead<AppearanceStore>()?.keepAwake == true) {
      unawaited(WakelockPlus.enable());
    }
    // Weak-network: a message that failed to submit because the socket was
    // already down (see `ChatStore.submit`'s catch — this only fires when
    // the gateway never accepted the turn, so resending can't duplicate an
    // already-accepted one) gets one automatic resend when the connection
    // comes back, instead of waiting on the user to notice the error bubble
    // and tap retry themselves.
    _autoRetrySub = context.maybeRead<ConnectionStore>()?.reconnected.listen((
      _,
    ) {
      unawaited(_autoRetryAfterReconnect());
    });
  }

  /// See the `_autoRetrySub` wiring in [initState]. Bounded to a recent
  /// failure only — a much older one sitting unresolved on screen is more
  /// likely something the user has already moved past than a message they
  /// still want fired off the moment the network happens to come back.
  static const _autoRetryMaxAge = Duration(minutes: 2);

  /// Every store with a `connection.reconnected` listener (session list,
  /// this one, others) fires on the same event — resending immediately
  /// would pile this request onto that same first-instant burst, right
  /// where `GatewayClient`'s in-flight cap (`gatewayTooManyPendingCode`,
  /// gateway.dart) is most likely to actually bind. Let that initial burst
  /// clear first.
  static const _autoRetrySettleDelay = Duration(milliseconds: 600);

  Future<void> _autoRetryAfterReconnect() async {
    if (!mounted) return;
    await Future<void>.delayed(_autoRetrySettleDelay);
    if (!mounted || _sending) return;
    final chat = context.read<ChatStore>();
    if (chat.busy || chat.recoveryJournal.isEmpty) return;
    final entry = chat.recoveryJournal.first;
    if (!entry.retryable) return;
    if (DateTime.now().difference(entry.at) > _autoRetryMaxAge) return;
    final text = entry.retryText?.trim();
    if (text == null || text.isEmpty) return;
    chat.clearRecoveryJournal();
    await _send(text);
  }

  /// Poll the gateway process registry every few seconds while the chat screen
  /// is visible. This is the mobile equivalent of desktop's background process
  /// sync in `composer-status.ts`.
  void _startBackgroundPolling() {
    final composer = context.maybeRead<ComposerStatusStore>();
    if (composer == null) return;

    final initialRuntime = context.maybeRead<SessionStore>()?.runtimeId;
    if (initialRuntime != null && initialRuntime.isNotEmpty) {
      unawaited(composer.refreshBackgroundProcesses(initialRuntime));
    }

    _backgroundPollTimer?.cancel();
    _backgroundPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final session = context.read<SessionStore>();
      final runtimeId = session.runtimeId;
      if (runtimeId != null && runtimeId.isNotEmpty) {
        unawaited(composer.refreshBackgroundProcesses(runtimeId));
      }
    });
    _backgroundCompletionSub ??= composer.completionEvents.listen(
      _onBackgroundCompletion,
    );
    final chat = context.maybeRead<ChatStore>();
    _agentNoticeSub ??= chat?.notificationEvents.listen((notice) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: notice.label,
        kind: notice.state == 'error' || notice.state == 'failed'
            ? HermesToastKind.error
            : HermesToastKind.info,
      );
    });
  }

  void _stopBackgroundPolling() {
    _backgroundPollTimer?.cancel();
    _backgroundPollTimer = null;
    _backgroundCompletionSub?.cancel();
    _backgroundCompletionSub = null;
    _agentNoticeSub?.cancel();
    _agentNoticeSub = null;
  }

  void _onBackgroundCompletion(ComposerStatusItem item) {
    if (!mounted) return;
    final label = item.title;
    final message = item.state == ComposerStatusState.failed
        ? context.l10n.chatBackgroundTaskFailed(label)
        : context.l10n.chatBackgroundTaskCompleted(label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// Load the current session runtime toolsets and the global CLI
  /// configurable toolsets independently so their different scopes stay
  /// visible instead of silently replacing one another.
  Future<void> _loadToolsets() async {
    final session = context.read<SessionStore>();
    final runtimeId = session.runtimeId;
    final api = session.api;
    final profile = session.profile ?? session.activeProfile;

    final sessionRequest = runtimeId == null
        ? Future<List<ToolsetInfo>?>.value(null)
        : session.sessionToolsets().then<List<ToolsetInfo>?>((value) => value);
    final globalRequest = api == null
        ? Future<List<ToolsetInfo>?>.value(null)
        : api
              .toolsets(profile: profile)
              .then<List<ToolsetInfo>?>((value) => value);

    List<ToolsetInfo>? sessionToolsets;
    List<ToolsetInfo>? globalToolsets;
    try {
      sessionToolsets = await sessionRequest;
    } catch (_) {}
    try {
      globalToolsets = await globalRequest;
    } catch (_) {}
    if (!mounted ||
        runtimeId != session.runtimeId ||
        !identical(api, session.api)) {
      return;
    }

    setState(() {
      _sessionToolsets = sessionToolsets ?? const [];
      _sessionToolsetsLoaded = sessionToolsets != null;
      if (globalToolsets != null) {
        _globalCliToolsets = globalToolsets;
        _globalCliToolsetsLoaded = true;
      }
    });
  }

  /// Load the composer chips' real data: profiles, config (reasoning/yolo),
  /// toolsets and workspace candidates. Every piece is best-effort; a failed
  /// piece keeps its pill hidden/fallback rather than showing mock data.
  Future<void> _loadComposerContext() async {
    final session = context.read<SessionStore>();
    final api = session.api;
    if (api == null) return;
    final generation = ++_composerContextGeneration;
    try {
      await session.refreshProfiles();
    } catch (_) {}

    final configProfile = session.profile ?? session.activeProfile;
    Map<String, dynamic>? config;
    try {
      config = await api.getConfig(profile: configProfile);
    } catch (_) {}

    // A18: probe the saved-prompts resource once; the bookmark entry stays
    // hidden when the server has no such backend.
    var promptsSupported = false;
    try {
      await api.savedPrompts();
      promptsSupported = true;
    } catch (_) {}

    // A16: ambient provider quota — rendered only with real backend data.
    Map<String, dynamic>? quota;
    try {
      quota = await api.providerQuota();
    } catch (_) {}

    String? defaultCwd;
    try {
      final cwd = await api.fsDefaultCwd();
      if (cwd.isNotEmpty) defaultCwd = cwd;
    } catch (_) {}

    List<Map<String, dynamic>>? projects;
    try {
      projects = await api.listProjects();
    } catch (_) {}

    if (!mounted ||
        generation != _composerContextGeneration ||
        !identical(api, session.api)) {
      return;
    }
    final currentProfile = session.profile ?? session.activeProfile;
    setState(() {
      if (config != null && configProfile == currentProfile) {
        _applyServerConfig(config);
      }
      _savedPromptsSupported = promptsSupported;
      _applyQuotaStatus(quota);
      if (defaultCwd != null) _defaultCwd = defaultCwd;
      if (projects != null) _workspaceProjects = projects;
    });
  }

  /// WebUI `_providerQuotaIndicatorText` parity: derive the compact chip
  /// label from a real quota payload; null hides the chip entirely.
  void _applyQuotaStatus(Map<String, dynamic>? status) {
    _quotaLabel = _quotaLabelFrom(status);
    _quotaMessage = status?['message']?.toString();
  }

  String? _quotaLabelFrom(Map<String, dynamic>? status) {
    if (status == null || status['status'] != 'available') return null;
    final limits = status['account_limits'];
    if (limits is Map) {
      final windows = limits['windows'];
      if (windows is List && windows.isNotEmpty) {
        final window = windows.firstWhere(
          (w) => w is Map && w['remaining_percent'] is num,
          orElse: () => windows.first,
        );
        final pct = window is Map
            ? (window['remaining_percent'] as num?)?.toDouble()
            : null;
        if (pct != null) {
          return '${pct.clamp(0, 100).toStringAsFixed(0)}%';
        }
      }
    }
    final quota = status['quota'];
    if (quota is Map) return _quotaMoneyShort(quota['limit_remaining']);
    return null;
  }

  static String? _quotaMoneyShort(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    if (n == null || !n.isFinite) return null;
    if (n.abs() >= 100) return '\$${n.toStringAsFixed(0)}';
    if (n.abs() >= 10) return '\$${n.toStringAsFixed(1)}';
    return '\$${n.toStringAsFixed(2)}';
  }

  /// Quota chip tap: force-refresh the real status and surface the backend
  /// message (WebUI chip title parity).
  Future<void> _refreshQuotaChip() async {
    final session = context.read<SessionStore>();
    final api = session.api;
    if (api == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final status = await api.providerQuota(refresh: true);
      if (!mounted || !identical(api, session.api)) return;
      setState(() => _applyQuotaStatus(status));
      final message = _quotaMessage;
      if (message != null && message.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted && identical(api, session.api)) {
        setState(() => _applyQuotaStatus(null));
      }
    }
  }

  void _applyServerConfig(Map<String, dynamic> config) {
    _serverConfig = config;
    _configLoaded = true;
    _yoloEnabled = config.containsKey('yolo') ? config['yolo'] == true : null;
  }

  /// Real reasoning effort from the backend config (`agent.reasoning_effort`),
  /// or null when the backend has no such field (the difficulty pill is
  /// removed in that case).
  String? get _reasoningEffort {
    if (!_configLoaded) return null;
    final agent = _serverConfig['agent'];
    if (agent is Map && agent['reasoning_effort'] != null) {
      return agent['reasoning_effort'].toString();
    }
    // Fallbacks for older backends.
    final reasoning = _serverConfig['reasoning'];
    if (reasoning is Map && reasoning['effort'] != null) {
      return reasoning['effort'].toString();
    }
    final flat = _serverConfig['reasoning_effort'] ?? _serverConfig['effort'];
    return flat?.toString();
  }

  String _workspaceBaseName(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  String _markerStorageKey([String? sessionId]) {
    final sid =
        sessionId ?? context.read<SessionStore>().durableId ?? 'pending';
    return 'hm_chat_markers_$sid';
  }

  String _messageMarkerId(ChatMessage message) =>
      message.rowId?.toString() ?? message.id;

  Future<void> _restoreMessageMarkers([String? sessionId]) async {
    final sid =
        sessionId ?? context.read<SessionStore>().durableId ?? 'pending';
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _markerSessionId = sid;
      _markedMessageIds
        ..clear()
        ..addAll(prefs.getStringList(_markerStorageKey(sid)) ?? const []);
    });
  }

  Future<void> _toggleMessageMarker(ChatMessage message) async {
    final id = _messageMarkerId(message);
    setState(() {
      if (!_markedMessageIds.add(id)) _markedMessageIds.remove(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _markerStorageKey(),
      _markedMessageIds.toList(growable: false),
    );
  }

  GlobalKey _keyForMessage(ChatMessage message) {
    return _messageKeys.putIfAbsent(message.id, GlobalKey.new);
  }

  void _onUserMessageMountChanged(String id, bool mounted) {
    if (mounted) {
      _mountedUserMessageIds.add(id);
    } else {
      _mountedUserMessageIds.remove(id);
    }
  }

  void _pruneMessageKeys(List<ChatMessage> messages) {
    final live = messages.map((m) => m.id).toSet();
    _messageKeys.removeWhere((id, _) => !live.contains(id));
    _mountedUserMessageIds.removeWhere((id) => !live.contains(id));
  }

  void _setStuckToBottom(bool value) {
    _scrollCoordinator.updateStuck(value);
    if (_stuckToBottom.value != value) _stuckToBottom.value = value;
  }

  void _onTranscriptChanged(
    int messageCount,
    int streamTick,
    bool isStreaming,
  ) {
    _pruneMessageKeys(context.read<ChatStore>().messages);
    if (_scrollCoordinator.messagesChanged(messageCount)) {
      _scrollToBottom();
    }
    if (isStreaming) _scrollToBottom();
  }

  void _retryFromRecovery(ChatRecoveryEntry entry) {
    final text = entry.retryText?.trim();
    if (text != null && text.isNotEmpty) {
      _composerCtrl.text = text;
      _composerFocus.requestFocus();
    }
    context.read<ChatStore>().clearRecoveryJournal();
  }

  Widget _buildInflightRecoveryBanner(SessionStore session) {
    if (!session.inflightRecoveryNotice) return const SizedBox.shrink();
    return MaterialBanner(
      content: Text(
        context.l10n.chatInflightRecovered,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      leading: const Icon(Icons.cloud_sync_outlined),
      actions: [
        TextButton(
          onPressed: session.clearInflightRecoveryNotice,
          child: Text(context.l10n.commonGotIt),
        ),
      ],
    );
  }

  ({String label, IconData icon, bool config}) _errorLayerInfo(
    ChatErrorLayer layer,
  ) {
    switch (layer) {
      case ChatErrorLayer.auth:
        return (
          label: context.l10n.chatErrorAuth,
          icon: Icons.key_off_outlined,
          config: true,
        );
      case ChatErrorLayer.billing:
        return (
          label: context.l10n.chatErrorBilling,
          icon: Icons.account_balance_wallet_outlined,
          config: true,
        );
      case ChatErrorLayer.provider:
        return (
          label: context.l10n.chatErrorProvider,
          icon: Icons.cloud_off_outlined,
          config: true,
        );
      case ChatErrorLayer.rateLimit:
        return (
          label: context.l10n.chatErrorRateLimit,
          icon: Icons.speed_outlined,
          config: false,
        );
      case ChatErrorLayer.network:
        return (
          label: context.l10n.chatErrorNetwork,
          icon: Icons.wifi_off_outlined,
          config: false,
        );
      case ChatErrorLayer.generic:
        return (
          label: context.l10n.chatErrorReply,
          icon: Icons.history_edu_outlined,
          config: false,
        );
    }
  }

  String _errorDiagnosticsBlob(ChatRecoveryEntry entry) {
    final session = context.maybeRead<SessionStore>();
    final info = session?.info;
    final now = DateTime.now().toIso8601String();
    return [
      context.l10n.chatDiagnosticsTitle,
      context.l10n.chatDiagnosticsTime(now),
      if (info?.model != null)
        context.l10n.chatDiagnosticsModel(info!.provider ?? '?', info.model!),
      context.l10n.chatDiagnosticsError(entry.diagnostics),
    ].join('\n');
  }

  Future<void> _sendDiagnostics(ChatRecoveryEntry entry) =>
      showSendDiagnosticsDialog(
        context,
        errorContext: _errorDiagnosticsBlob(entry),
      );

  Widget _buildRecoveryBanner(ChatStore chat) {
    if (chat.recoveryJournal.isEmpty) return const SizedBox.shrink();
    final entry = chat.recoveryJournal.first;
    final layer = classifyChatError(
      entry.diagnostics,
      surface: entry.errorSurface,
    );
    final info = _errorLayerInfo(layer);
    return MaterialBanner(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(entry.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
      leading: Icon(info.icon),
      actions: [
        if (entry.retryable &&
            entry.retryText != null &&
            entry.retryText!.trim().isNotEmpty)
          TextButton(
            onPressed: () => _retryFromRecovery(entry),
            child: Text(context.l10n.chatFillRetry),
          ),
        if (info.config)
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProviderConfigScreen(),
                ),
              );
            },
            child: Text(context.l10n.chatConfigureProvider),
          ),
        TextButton(
          onPressed: () => copyTextOrNotify(
            context,
            _errorDiagnosticsBlob(entry),
            successMessage: context.l10n.chatDiagnosticsCopied,
          ),
          child: Text(context.l10n.chatCopyDiagnostics),
        ),
        if (context.read<ConnectionStore>().gateway != null)
          TextButton(
            onPressed: () => _sendDiagnostics(entry),
            child: Text(context.l10n.chatSendDiagnostics),
          ),
        TextButton(
          onPressed: chat.clearRecoveryJournal,
          child: Text(context.l10n.commonIgnore),
        ),
      ],
    );
  }

  int _messageIndex(List<ChatMessage> messages, ChatMessage message) {
    final byId = messages.indexWhere((m) => m.id == message.id);
    if (byId >= 0) return byId;
    final rowId = message.rowId;
    if (rowId != null) {
      return messages.indexWhere((m) => m.rowId == rowId);
    }
    return -1;
  }

  Future<void> _scrollTowardMessageIndex(
    int messageIndex,
    int messageCount,
  ) async {
    if (!_scrollCtrl.hasClients || messageIndex < 0 || messageCount <= 0) {
      return;
    }
    final position = _scrollCtrl.position;
    // Message rows have highly variable heights (markdown, code and tool
    // cards), so a fixed row extent quickly drifts away from the real row.
    // A proportional jump gets us close; the loop below then uses the
    // actually mounted rows to approach the target from either direction.
    final fraction = messageCount <= 1
        ? 0.0
        : messageIndex / (messageCount - 1);
    final target = (position.maxScrollExtent * fraction).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    if (duration == Duration.zero) {
      _scrollCtrl.jumpTo(target);
    } else {
      await _scrollCtrl.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _locateMessage(ChatMessage message) async {
    final chat = context.read<ChatStore>();
    final messages = chat.messages;
    final messageIndex = _messageIndex(messages, message);
    if (messageIndex < 0) return;

    _setStuckToBottom(false);

    await _scrollTowardMessageIndex(messageIndex, messages.length);
    if (!mounted) return;

    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);

    for (var attempt = 0; attempt < 48; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final key = _keyForMessage(message);
      final target = key.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: 0.36,
        );
        _locatorHighlightTimer?.cancel();
        if (!mounted) return;
        setState(() => _locatorHighlightId = message.id);
        _locatorHighlightTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _locatorHighlightId = null);
        });
        return;
      }

      final mountedIndexes = <int>[];
      for (var index = 0; index < messages.length; index++) {
        final context = _messageKeys[messages[index].id]?.currentContext;
        if (context != null && context.mounted) mountedIndexes.add(index);
      }
      if (mountedIndexes.isEmpty || !_scrollCtrl.hasClients) continue;

      final position = _scrollCtrl.position;
      final first = mountedIndexes.first;
      final last = mountedIndexes.last;
      final direction = messageIndex < first
          ? -1.0
          : messageIndex > last
          ? 1.0
          : 0.0;
      if (direction == 0) continue;
      final next =
          (position.pixels + direction * position.viewportDimension * .8).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
      if ((next - position.pixels).abs() < 1) return;
      if (duration == Duration.zero) {
        _scrollCtrl.jumpTo(next);
      } else {
        await _scrollCtrl.animateTo(
          next,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _buildTopicRail(List<ChatMessage> messages) {
    final topics = messages.where((message) => message.role == 'user').toList();
    final visible = topics.length <= 7
        ? topics
        : <ChatMessage>[topics.first, ...topics.sublist(topics.length - 6)];
    final theme = Theme.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: _activeTopic,
      builder: (context, activeTopicId, _) => Semantics(
        label: context.l10n.chatTopicRailSemantics(topics.length),
        child: Material(
          elevation: 1,
          color: theme.colorScheme.surface.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final topic in visible)
                  Tooltip(
                    message: topic.plainText.isEmpty
                        ? context.l10n.chatLocateTopic
                        : topic.plainText.split('\n').first,
                    child: InkWell(
                      key: ValueKey('topic-rail-${topic.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _locateMessage(topic),
                      // I1: long-press shows the full prompt preview before
                      // deciding to jump (desktop tick-hover popover parity).
                      onLongPress: () => _showTopicPreview(topic),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 5,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: topic.id == activeTopicId ? 14 : 7,
                          height: topic.id == activeTopicId ? 4 : 7,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: topic.id == activeTopicId ? 1 : .45,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTopicPreview(ChatMessage topic) {
    HapticFeedback.selectionClick();
    final preview = topic.plainText.trim();
    final index =
        context
            .read<ChatStore>()
            .messages
            .where((m) => m.role == 'user')
            .toList()
            .indexOf(topic) +
        1;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.chatTopicNumber(index),
                style: Theme.of(sheetCtx).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: SelectableText(
                    preview.isEmpty ? context.l10n.chatNoText : preview,
                    style: Theme.of(sheetCtx).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _locateMessage(topic);
                  },
                  icon: const Icon(Icons.my_location, size: 16),
                  label: Text(context.l10n.chatJumpToTopic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _locateInitialSearchHit(ChatStore chat) {
    if (_initialSearchLocated) return;
    final targetId = widget.initialMessageId;
    if (targetId == null || targetId.isEmpty) return;
    final match = _messageForSearchTarget(chat, targetId);
    final target = match;
    if (target == null) {
      if (chat.hasMoreHistory && !_initialSearchPaging) {
        _initialSearchPaging = true;
        unawaited(_loadSearchHitHistory(targetId));
      }
      return;
    }
    _initialSearchLocated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locateMessage(target);
    });
  }

  ChatMessage? _messageForSearchTarget(ChatStore chat, String targetId) {
    for (final message in chat.messages) {
      if (message.id == targetId || message.rowId?.toString() == targetId) {
        return message;
      }
    }
    return null;
  }

  Future<void> _loadSearchHitHistory(String targetId) async {
    try {
      final session = context.read<SessionStore>();
      // Each page contains 50 messages. Bound the eager lookup to 1,000
      // messages so an unexpectedly malformed search response cannot make a
      // chat opening unbounded; normal scroll-to-top pagination remains
      // available for older transcripts.
      for (
        var page = 0;
        page < 20 && mounted && session.chat.hasMoreHistory;
        page++
      ) {
        await session.loadOlderMessages();
        if (_messageForSearchTarget(session.chat, targetId) != null) break;
      }
    } finally {
      _initialSearchPaging = false;
      if (mounted) _locateInitialSearchHit(context.read<SessionStore>().chat);
    }
  }

  void _showHistoryLocator(ChatStore chat) {
    final searchCtrl = TextEditingController();
    var role = 'all';
    var rangeDays = 0;
    var markedOnly = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final now = DateTime.now();
          final keyword = searchCtrl.text.trim().toLowerCase();
          final messages = chat.messages
              .where((message) {
                if (role != 'all' && message.role != role) {
                  return false;
                }
                if (markedOnly &&
                    !_markedMessageIds.contains(_messageMarkerId(message))) {
                  return false;
                }
                if (rangeDays > 0 &&
                    message.timestamp != null &&
                    now.difference(message.timestamp!).inDays >= rangeDays) {
                  return false;
                }
                if (rangeDays > 0 && message.timestamp == null) {
                  return false;
                }
                if (keyword.isNotEmpty &&
                    !message.fullText.toLowerCase().contains(keyword)) {
                  return false;
                }
                return message.fullText.isNotEmpty || message.parts.isNotEmpty;
              })
              .toList(growable: false);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * .78,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: context.l10n.chatSearchLoadedHistory,
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (final item in [
                          ('all', context.l10n.commonAll),
                          ('user', context.l10n.chatMyMessages),
                          ('assistant', context.l10n.chatAssistant),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(item.$2),
                              selected: role == item.$1,
                              onSelected: (_) => setSheet(() => role = item.$1),
                            ),
                          ),
                        for (final item in [
                          (0, context.l10n.chatAllDates),
                          (1, context.l10n.chatLast24Hours),
                          (7, context.l10n.chatLast7Days),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(item.$2),
                              selected: rangeDays == item.$1,
                              onSelected: (_) =>
                                  setSheet(() => rangeDays = item.$1),
                            ),
                          ),
                        FilterChip(
                          label: Text(context.l10n.chatMarkedOnly),
                          selected: markedOnly,
                          onSelected: (v) => setSheet(() => markedOnly = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Text(context.l10n.chatNoMatchingMessages),
                          )
                        : ListView.builder(
                            itemCount: messages.length,
                            itemBuilder: (_, index) {
                              final message = messages[index];
                              final marked = _markedMessageIds.contains(
                                _messageMarkerId(message),
                              );
                              final preview = message.fullText
                                  .replaceAll(RegExp(r'\s+'), ' ')
                                  .trim();
                              return ListTile(
                                leading: Icon(
                                  message.role == 'user'
                                      ? Icons.person_outline
                                      : Icons.smart_toy_outlined,
                                ),
                                title: Text(
                                  preview.isEmpty
                                      ? context.l10n.chatToolStatusMessage
                                      : preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  message.timestamp?.toLocal().toString() ??
                                      context.l10n.chatUnknownTime,
                                ),
                                trailing: IconButton(
                                  tooltip: marked
                                      ? context.l10n.chatUnmarkMessage
                                      : context.l10n.chatMarkMessage,
                                  onPressed: () async {
                                    await _toggleMessageMarker(message);
                                    setSheet(() {});
                                  },
                                  icon: Icon(
                                    marked
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.of(sheetCtx).pop();
                                  _locateMessage(message);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(searchCtrl.dispose);
  }

  Future<void> _restoreSharedDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(_sharedDraftKey);
    if (draft == null || draft.isEmpty) return;
    await prefs.remove(_sharedDraftKey);
    if (!mounted) return;
    setState(() {
      _composerCtrl.text = draft;
      _composerCtrl.selection = TextSelection.collapsed(offset: draft.length);
    });
  }

  // ──── Draft persistence (WebUI agent-session parity) ────

  List<dynamic> get _attachmentsForPersist {
    final list = _attachments;
    if (list.isEmpty) return const [];
    return list
        .map(
          (a) => {
            'name': a.label,
            'occurrence_id': a.occurrenceId,
            'path': a.path ?? a.url ?? '',
            'kind': a.kind.name,
            'url': a.url,
            'snippet': a.snippetText,
            'local_path': a.localPath,
          },
        )
        .toList(growable: false);
  }

  List<QueuedAttachment> _queueAttachments(
    List<ComposerAttachment> attachments,
  ) => attachments
      .map(
        (item) => QueuedAttachment(
          kind: item.kind.name,
          label: item.label,
          occurrenceId: item.occurrenceId,
          path: item.path,
          localPath: item.localPath,
          url: item.url,
          snippetText: item.snippetText,
        ),
      )
      .toList(growable: false);

  List<ComposerAttachment> _composerAttachments(
    List<QueuedAttachment> attachments,
  ) => attachments
      .map(
        (item) => ComposerAttachment(
          kind: ComposerAttachmentKind.values.firstWhere(
            (kind) => kind.name == item.kind,
            orElse: () => ComposerAttachmentKind.file,
          ),
          label: item.label,
          occurrenceId: item.occurrenceId,
          path: item.path,
          localPath: item.localPath,
          url: item.url,
          snippetText: item.snippetText,
        ),
      )
      .toList(growable: false);

  /// Called when session.durableId transitions (or on first mount).
  /// Flushes any open prior-session draft, fetches the current session draft,
  /// and restores it into the composer (unless suppressed).
  Future<void> _onSessionChanged(SessionStore session, String sid) async {
    if (sid.isEmpty) return;
    final route = session.owner?.route;
    await context.read<VoiceStore>().bindConversationScope(
      '${route?.connectionId.value ?? 'active'}|${route?.profile ?? ''}|$sid',
    );
    if (!mounted) return;
    // A session hop invalidates any in-place message edit.
    if (_editingMessageId != null && mounted) {
      _endInlineEdit();
    }
    // Flush previous session's draft NOW (before the cross-session hop can
    // lose the pending 400 ms debounced save).
    final prev = _lastDraftSid;
    final changedSession = prev != null && prev != sid;
    if (prev != null && prev.isNotEmpty) {
      await _composerHistory.persist(_composerHistoryKey(prev));
    }
    await _composerHistory.load(_composerHistoryKey(sid));
    _editingQueuedMessageId = null;
    if (changedSession && prev.isNotEmpty) {
      await session.flushDraftNow(
        prev,
        currentText: _composerCtrl.text,
        currentFiles: _attachmentsForPersist,
        serverDraft: _rememberedServerDraft,
      );
      if (!mounted) return;
    }
    if (changedSession) {
      _draftRestoreInProgress = true;
      _composerCtrl.clear();
      if (mounted) setState(() => _attachments = const []);
      _rememberedServerDraft = const ComposerDraft();
      _draftRestoreInProgress = false;
      _pruneMessageKeys(session.chat.messages);
    }
    _lastDraftSid = sid;
    if (_markerSessionId != sid) {
      await _restoreMessageMarkers(sid);
    }
    // Session hop: the toolsets chip follows the live session's selection.
    unawaited(_loadToolsets());

    if (session.connection.api == null) return;

    // Attempt to recall "new chat draft session" — on mount / first resume
    // we prefer the remembered draft over a brand new empty session.
    if (prev == null && widget.recallNewChatDraft) {
      final recalled = await session.recalledNewChatDraftSessionId();
      if (recalled != null && recalled.isNotEmpty && recalled != sid) {
        try {
          await session.resumeSession(recalled);
          return; // resumeSession triggers another rebuild → re-entered
        } catch (_) {}
      }
    }

    // If the composer already has content, do not overwrite it. WebUI: only
    // restores when the textarea is empty AND unchanged since mount.
    final hasComposerContent =
        _composerCtrl.text.isNotEmpty || _attachments.isNotEmpty;
    if (hasComposerContent) {
      return;
    }

    _draftRestoreInProgress = true;
    final restoreGeneration = ++_draftRestoreGeneration;
    try {
      final draft = await session.loadStoredDraft(sid);
      if (!mounted ||
          restoreGeneration != _draftRestoreGeneration ||
          _lastDraftSid != sid ||
          session.durableId != sid) {
        return;
      }
      _rememberedServerDraft = draft;
      // Remember new-chat draft pointer before restore so we can auto-resume.
      await session.rememberNewChatDraftSession(sid);
      if (!mounted ||
          restoreGeneration != _draftRestoreGeneration ||
          _lastDraftSid != sid ||
          session.durableId != sid) {
        return;
      }
      // 30-second suppression + signature check (WebUI
      // `_isComposerDraftRestoreSuppressed`).
      final files = draft.files;
      if (session.isDraftRestoreSuppressed(sid, draft.text, files)) {
        return;
      }
      if (!mounted) return;
      setState(() {
        if (draft.text.isNotEmpty) {
          _composerCtrl.text = draft.text;
          _composerCtrl.selection = TextSelection.collapsed(
            offset: draft.text.length,
          );
        }
        // Attachments: rebuild the ComposerAttachment list from persisted spec.
        if (files.isNotEmpty) {
          final att = <ComposerAttachment>[];
          for (final f in files) {
            if (f is Map) {
              try {
                final kindName = (f['kind'] ?? 'file').toString();
                final kind = ComposerAttachmentKind.values.firstWhere(
                  (k) => k.name == kindName,
                  orElse: () {
                    final p = (f['path'] ?? f['url'] ?? '')
                        .toString()
                        .toLowerCase();
                    if (p.startsWith('http://') || p.startsWith('https://')) {
                      return ComposerAttachmentKind.url;
                    }
                    if (p.endsWith('.png') ||
                        p.endsWith('.jpg') ||
                        p.endsWith('.jpeg') ||
                        p.endsWith('.gif') ||
                        p.endsWith('.webp')) {
                      return ComposerAttachmentKind.image;
                    }
                    if (f['snippet'] != null &&
                        f['snippet'].toString().isNotEmpty) {
                      return ComposerAttachmentKind.snippet;
                    }
                    return ComposerAttachmentKind.file;
                  },
                );
                att.add(
                  ComposerAttachment(
                    kind: kind,
                    label: (f['name'] ?? f['label'] ?? context.l10n.commonFile)
                        .toString(),
                    occurrenceId: f['occurrence_id']?.toString(),
                    path: (f['path'] ?? '').toString().isEmpty
                        ? null
                        : (f['path'] ?? '').toString(),
                    localPath: (f['local_path'] ?? '').toString().isEmpty
                        ? null
                        : f['local_path'].toString(),
                    url: (f['url'] ?? '').toString().isEmpty
                        ? null
                        : (f['url'] ?? '').toString(),
                    snippetText:
                        (f['snippet'] ?? f['snippetText'] ?? '')
                            .toString()
                            .isEmpty
                        ? null
                        : (f['snippet'] ?? f['snippetText']).toString(),
                  ),
                );
              } catch (_) {}
            }
          }
          if (att.isNotEmpty) _attachments = List.unmodifiable(att);
        }
      });
    } finally {
      if (restoreGeneration == _draftRestoreGeneration) {
        _draftRestoreInProgress = false;
      }
    }
  }

  /// Cached in build() so dispose() can flush without an ancestor lookup
  /// (context.read during unmount is unsafe).
  SessionStore? _sessionStoreRef;

  /// Flush any pending debounced save immediately.
  Future<void> _flushCurrentDraftNow() async {
    final sid = _lastDraftSid;
    if (sid == null || sid.isEmpty) return;
    final session = _sessionStoreRef;
    if (session == null) return;
    await session.flushDraftNow(
      sid,
      currentText: _composerCtrl.text,
      currentFiles: _attachmentsForPersist,
      serverDraft: _rememberedServerDraft,
    );
  }

  @override
  void dispose() {
    _acDebounce?.cancel();
    _locatorHighlightTimer?.cancel();
    unawaited(_autoRetrySub?.cancel());
    _stopBackgroundPolling();
    // Always disable on the way out — harmless no-op if this screen never
    // enabled it (e.g. the setting was off), and correct if another chat
    // screen instance is about to enable it for itself.
    unawaited(WakelockPlus.disable());
    // Flush draft synchronously-best-effort before destroying state so typing
    // on the way out doesn't get lost.
    unawaited(_flushCurrentDraftNow());
    _composerCtrl.dispose();
    _composerFocus.dispose();
    _findCtrl.dispose();
    _findFocus.dispose();
    _scrollCtrl.dispose();
    _activeTopic.dispose();
    _stuckToBottom.dispose();
    _editCtrl.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  /// Pick the user turn whose bubble sits just above the viewport top; cheap
  /// (user turns are few) and only setState()s when the winner changes.
  void _scheduleActiveTopicUpdate() {
    if (_activeTopicUpdateScheduled) return;
    _activeTopicUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activeTopicUpdateScheduled = false;
      if (mounted) _recomputeActiveTopic();
    });
  }

  void _recomputeActiveTopic() {
    final scrollBox = context.findRenderObject();
    if (scrollBox is! RenderBox) return;
    final viewportTop = scrollBox.localToGlobal(Offset.zero).dy + 80;
    String? winner;
    double winnerTop = double.negativeInfinity;
    String? firstMounted;
    double firstTop = double.infinity;
    // Only mounted user rows can affect the viewport result. This set is
    // bounded by the sliver viewport/cache instead of transcript length.
    for (final id in _mountedUserMessageIds) {
      final ctx = _messageKeys[id]?.currentContext;
      final box = ctx?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top < firstTop) {
        firstTop = top;
        firstMounted = id;
      }
      if (top <= viewportTop && top > winnerTop) {
        winnerTop = top;
        winner = id;
      }
    }
    if (_activeTopic.value == null) winner ??= firstMounted;
    if (winner != null && winner != _activeTopic.value) {
      _activeTopic.value = winner;
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    final nextStuck = position.pixels >= position.maxScrollExtent - 120;
    if (nextStuck != _scrollCoordinator.stuckToBottom) {
      if (_diagnosticLogging) {
        _logScroll(
          'event=stuck.changed stuck=$nextStuck '
          'pixels=${position.pixels.toStringAsFixed(1)} '
          'max_extent=${position.maxScrollExtent.toStringAsFixed(1)} '
          'distance_to_bottom=${(position.maxScrollExtent - position.pixels).toStringAsFixed(1)}',
        );
      }
      _setStuckToBottom(nextStuck);
    }
    _scheduleActiveTopicUpdate();
    if (_scrollCoordinator.allowPagination &&
        position.pixels < 160 &&
        !_loadingOlderViewport &&
        mounted) {
      _loadingOlderViewport = true;
      if (_diagnosticLogging) {
        _logScroll(
          'event=history.triggered pixels=${position.pixels.toStringAsFixed(1)} '
          'max_extent=${position.maxScrollExtent.toStringAsFixed(1)}',
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadOlderKeepingViewport());
      });
    }
  }

  Future<void> _loadOlderKeepingViewport() async {
    if (!mounted || !_scrollCtrl.hasClients) {
      _loadingOlderViewport = false;
      return;
    }
    final session = context.read<SessionStore>();
    final beforeCount = session.chat.loadedCount;
    final sessionEpoch = _scrollCoordinator.sessionEpoch;
    final beforeExtent = _scrollCtrl.position.maxScrollExtent;
    final beforePixels = _scrollCtrl.position.pixels;
    final elapsed = Stopwatch()..start();
    if (_diagnosticLogging) {
      _logScroll(
        'event=history.started before_count=$beforeCount '
        'before_pixels=${beforePixels.toStringAsFixed(1)} '
        'before_extent=${beforeExtent.toStringAsFixed(1)}',
      );
    }
    try {
      // `deferTrim: true` — see `ChatStore.appendOlderHistory`'s doc. The
      // window trim runs after the restore below instead of alongside the
      // prepend, so the extent delta this restore measures reflects only
      // the prepend and the pixel math stays correct.
      await session.loadOlderMessages(deferTrim: true);
      if (!mounted) return;
      final restored = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted && _scrollCtrl.hasClients) {
            if (!_scrollCoordinator.ownsEpoch(sessionEpoch)) {
              restored.complete();
              return;
            }
            final position = _scrollCtrl.position;
            final extentDelta = position.maxScrollExtent - beforeExtent;
            final restoredPixels = _scrollCoordinator.restorePrependOffset(
              beforePixels: beforePixels,
              beforeExtent: beforeExtent,
              afterExtent: position.maxScrollExtent,
              minExtent: position.minScrollExtent,
              maxExtent: position.maxScrollExtent,
            );
            _scrollCtrl.jumpTo(restoredPixels);
            if (_diagnosticLogging) {
              _logScroll(
                'event=history.completed before_count=$beforeCount '
                'after_count=${session.chat.loadedCount} '
                'duration_ms=${elapsed.elapsedMilliseconds} '
                'before_pixels=${beforePixels.toStringAsFixed(1)} '
                'extent_delta=${extentDelta.toStringAsFixed(1)} '
                'restored_pixels=${restoredPixels.toStringAsFixed(1)}',
              );
            }
          }
          restored.complete();
        } catch (error, stackTrace) {
          restored.completeError(error, stackTrace);
        }
      });
      await restored.future;
      // Now that the viewport is anchored, trimming the newer end (if the
      // transcript crossed budget) is just an off-screen removal — no
      // further position compensation needed.
      if (mounted) session.chat.trimTranscriptWindowIfNeeded();
    } catch (error, stackTrace) {
      if (_diagnosticLogging) {
        _logScroll(
          'event=history.failed before_count=$beforeCount '
          'after_count=${session.chat.loadedCount} '
          'duration_ms=${elapsed.elapsedMilliseconds} '
          'before_pixels=${beforePixels.toStringAsFixed(1)} '
          'error_type=${error.runtimeType}',
          null,
          stackTrace,
        );
      }
      rethrow;
    } finally {
      _loadingOlderViewport = false;
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_scrollCoordinator.stuckToBottom) {
      if (_diagnosticLogging) {
        final now = _autoScrollLogWatch.elapsedMilliseconds;
        if (now - _lastAutoScrollSkipLogMs >= 500) {
          _lastAutoScrollSkipLogMs = now;
          _logScroll('event=auto_scroll.skipped_unpinned');
        }
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        final position = _scrollCtrl.position;
        final target = position.maxScrollExtent;
        final jump = force || MediaQuery.disableAnimationsOf(context);
        if (jump) {
          _scrollCtrl.jumpTo(target);
        } else {
          _scrollCtrl.animateTo(
            target,
            duration: HermesMotion.fast,
            curve: Curves.easeOut,
          );
        }
        if (_diagnosticLogging) {
          final now = _autoScrollLogWatch.elapsedMilliseconds;
          if (force || now - _lastAutoScrollLogMs >= 500) {
            _lastAutoScrollLogMs = now;
            _logScroll(
              'event=auto_scroll.executed force=$force mode=${jump ? 'jump' : 'animate'} '
              'from_pixels=${position.pixels.toStringAsFixed(1)} '
              'target_pixels=${target.toStringAsFixed(1)}',
            );
          }
        }
        if (force) {
          _scrollCoordinator.markInitialPositioned();
          if (_diagnosticLogging) {
            _logScroll(
              'event=initial_bottom.positioned target_pixels=${target.toStringAsFixed(1)}',
            );
          }
          // A freshly-entered transcript has never been laid out: Flutter's
          // sliver list only discovers an item's real extent once it's
          // actually built, so a single jumpTo(maxScrollExtent) here jumps
          // to an ESTIMATE that can land well short of the true bottom on a
          // long/variable-height (tool cards, images, …) history — leaving
          // a blank gap the list has no content measured for yet, until a
          // manual drag forced Flutter to relayout and correct it. Re-check
          // across a few more frames and jump again while the estimate is
          // still growing, so entry alone settles it.
          _settleInitialScrollToBottom(attemptsLeft: 5);
        }
      }
    });
  }

  void _settleInitialScrollToBottom({required int attemptsLeft}) {
    if (attemptsLeft <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final position = _scrollCtrl.position;
      final target = position.maxScrollExtent;
      // Within half a pixel of the current position: the estimate has
      // stabilized, nothing left to correct.
      if ((target - position.pixels).abs() < 0.5) return;
      _scrollCtrl.jumpTo(target);
      if (_diagnosticLogging) {
        _logScroll(
          'event=initial_bottom.settled target_pixels=${target.toStringAsFixed(1)} '
          'attempts_left=${attemptsLeft - 1}',
        );
      }
      _settleInitialScrollToBottom(attemptsLeft: attemptsLeft - 1);
    });
  }

  Future<bool> _tryLocalSlashInvocation(String trimmed) async {
    final local = matchLocalSlashInvocation(trimmed);
    if (local == null) return false;
    _composerCtrl.clear();
    await _runLocalSlashCommand(trimmed, local);
    return true;
  }

  Future<void> _send(String text) async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final chat = session.chat;
    final voice = context.read<VoiceStore>();
    final messenger = ScaffoldMessenger.of(context);
    final trimmed = text.trim();
    // The composer already cleared its controller before invoking this
    // callback (so double-taps can't resend), so `_composerCtrl.value` is
    // empty by the time we get here — rebuild the pre-clear value from the
    // text this callback was actually given, or a failure-path restore is a
    // no-op and the user's typed message is lost.
    final originalValue = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    final submittedAttachments = _attachments;
    if ((trimmed.isEmpty && submittedAttachments.isEmpty) || _sending) return;
    // Lock before any async slash-command or attachment work so rapid taps
    // cannot dispatch the same prompt twice.
    if (mounted) setState(() => _sending = true);
    if (trimmed.isNotEmpty) {
      _composerHistory.add(trimmed);
      final historyScope = _lastDraftSid ?? session.durableId ?? 'new';
      unawaited(_composerHistory.persist(_composerHistoryKey(historyScope)));
    }
    if (_editingMessageId != null) {
      _endInlineEdit();
    }
    // WebUI built-in commands (commands.js): intercepted before send, never
    // forwarded to the model as prompt text.
    var handledLocally = false;
    try {
      if (await _tryLocalSlashInvocation(trimmed)) {
        handledLocally = true;
      } else if (trimmed.startsWith('/') &&
          await _dispatchSlashCommand(trimmed, busy: chat.busy)) {
        handledLocally = true;
      }
    } catch (e) {
      if (mounted) {
        _composerCtrl.value = originalValue;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatCommandFailed('$e'))),
        );
      }
      if (mounted) setState(() => _sending = false);
      return;
    }
    if (handledLocally || !mounted) {
      if (mounted) setState(() => _sending = false);
      return;
    }
    final sid = _lastDraftSid ?? session.durableId ?? '';
    final submittedFiles = List<dynamic>.from(_attachmentsForPersist);
    final remembered = _rememberedServerDraft;

    // WebUI uploadPendingFiles parity: upload staged attachments and embed
    // real references into the outgoing text before dispatch.
    final String composed;
    try {
      composed = await _composeWithAttachments(trimmed, submittedAttachments);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _composerCtrl.value = originalValue;
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatAttachmentUploadFailed('$e')),
          ),
        );
      }
      return;
    }

    final editingQueueId = _editingQueuedMessageId;
    if (editingQueueId != null) {
      await session.updateQueued(
        editingQueueId,
        composed,
        displayText: trimmed,
        attachments: _queueAttachments(submittedAttachments),
      );
      _editingQueuedMessageId = null;
      _composerCtrl.clear();
      if (mounted) setState(() => _attachments = const []);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatQueuedMessageUpdated)),
      );
      if (mounted) setState(() => _sending = false);
      return;
    }

    try {
      // Batch 2.4: Queue up sends while a turn is in flight so rapid submit
      // (multiple messages in a row) don't get dropped. The queue dispatches
      // each turn sequentially when the transcript is idle.
      if (chat.busy) {
        session.enqueueMessage(
          composed,
          displayText: trimmed,
          attachments: _queueAttachments(submittedAttachments),
        );
        _composerCtrl.clear();
        if (mounted) setState(() => _attachments = const []);
        _setStuckToBottom(true);
        if (sid.isNotEmpty) {
          session.suppressDraftRestoreAfterSubmit(
            sid,
            submittedText: composed,
            submittedFiles: submittedFiles,
            rememberedServerDraft: remembered,
          );
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.chatAddedToQueue(session.queueCount)),
            duration: const Duration(seconds: 1, milliseconds: 500),
          ),
        );
      } else {
        final runtimeBeforeSubmit = session.runtimeId;
        final interrupted = voice.takePlaybackInterrupted();
        await session.sendMessage(
          composed,
          onAutoRetry: _showAutoRetryNotice,
          interrupted: interrupted,
        );
        // A first submit creates the runtime session. Refresh immediately
        // instead of waiting for the next build/post-frame draft transition,
        // which can race a fast response and leave the tools chip global-only.
        if (runtimeBeforeSubmit != session.runtimeId) {
          await _loadToolsets();
        }
        _composerCtrl.clear();
        if (mounted) setState(() => _attachments = const []);
        _scrollToBottom();
        // WebUI parity: suppress stale draft restore for 30 s after submit
        // so a slow server poll doesn't repopulate the just-cleared composer.
        if (sid.isNotEmpty) {
          session.suppressDraftRestoreAfterSubmit(
            sid,
            submittedText: composed,
            submittedFiles: submittedFiles,
            rememberedServerDraft: remembered,
          );
          // Flush the cleared state immediately — the composer has been
          // submitted and must not be rehydrated from the stale server state.
          await session.flushDraftNow(
            sid,
            currentText: '',
            currentFiles: const [],
            serverDraft: remembered,
          );
        }
      }
    } catch (e) {
      // E2: restore the text and attachments on failure so the user doesn't
      // lose their input.
      if (mounted) {
        _composerCtrl.value = originalValue;
        setState(() => _attachments = submittedAttachments);
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatSendFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// WebUI busy-mode steer (ui.js `getComposerPrimaryAction` → 'steer',
  /// commands.js `_trySteer`): inject the draft into the running turn; on
  /// failure fall back to the send queue instead of dropping the message.
  Future<void> _steerFromComposer(String text) async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final trimmed = text.trim();
    // See the matching comment in `_send`: the composer already cleared its
    // controller before calling this, so rebuild the restorable value from
    // `text` rather than reading the (already-empty) controller.
    final originalValue = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    final submittedAttachments = _attachments;
    if (trimmed.isEmpty && submittedAttachments.isEmpty) return;
    // Local built-in commands win over steering — `/retry` while busy must
    // not be injected into the running turn as prompt text.
    if (await _tryLocalSlashInvocation(trimmed)) {
      return;
    }
    if (trimmed.startsWith('/') &&
        await _dispatchSlashCommand(trimmed, busy: true)) {
      return;
    }
    final sid = _lastDraftSid ?? session.durableId ?? '';
    final submittedFiles = List<dynamic>.from(_attachmentsForPersist);
    final remembered = _rememberedServerDraft;

    final String composed;
    try {
      composed = await _composeWithAttachments(trimmed, submittedAttachments);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _composerCtrl.value = originalValue;
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatAttachmentUploadFailed('$e')),
          ),
        );
      }
      return;
    }

    try {
      await session.steer(composed);
      if (!mounted) return;
      setState(() => _attachments = const []);
      if (sid.isNotEmpty) {
        session.suppressDraftRestoreAfterSubmit(
          sid,
          submittedText: composed,
          submittedFiles: submittedFiles,
          rememberedServerDraft: remembered,
        );
      }
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatSteerInjected)),
      );
    } catch (_) {
      // WebUI `_trySteer` fallback: queue the message (with the uploaded
      // attachment refs already embedded) instead of losing it.
      await session.enqueueMessage(
        composed,
        displayText: trimmed,
        attachments: _queueAttachments(submittedAttachments),
      );
      if (!mounted) return;
      setState(() => _attachments = const []);
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatSteerQueued)),
      );
    }
  }

  Future<bool> _dispatchSlashCommand(
    String invocation, {
    required bool busy,
  }) async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final commands = context.read<CommandStore>();
    final messenger = ScaffoldMessenger.of(context);
    if (session.runtimeId == null) await session.openNewSession();
    final runtimeId = session.runtimeId;
    if (runtimeId == null) return false;

    final commandName = invocation.split(RegExp(r'\s+')).first;
    final statusId = session.chat.appendSlashStatus(
      commandName,
      l10n.chatExecuting,
      pending: true,
    );
    _scrollToBottom();

    Map<String, dynamic> result;
    try {
      result = await commands.executeSlash(invocation, sessionId: runtimeId);
    } catch (e) {
      session.chat.completeSlashStatus(
        statusId,
        l10n.chatExecutionFailed('$e'),
        isError: true,
      );
      return true;
    }
    final type = result['type']?.toString();
    final message = result['message']?.toString().trim() ?? '';
    switch (type) {
      case 'skill':
      case 'send':
        if (message.isEmpty) {
          session.chat.completeSlashStatus(
            statusId,
            l10n.chatCommandNoSendableContent,
            isError: true,
          );
          return true;
        }
        final notice = result['notice']?.toString().trim() ?? '';
        session.chat.completeSlashStatus(
          statusId,
          notice.isNotEmpty
              ? notice
              : (busy ? l10n.chatCommandQueued : l10n.chatCommandStarting),
        );
        if (busy) {
          await session.enqueueMessage(message);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.chatCommandMessageQueued)),
          );
        } else {
          await session.sendMessage(message, onAutoRetry: _showAutoRetryNotice);
        }
        _composerCtrl.clear();
        return true;
      case 'prefill':
        session.chat.completeSlashStatus(
          statusId,
          message.isEmpty
              ? l10n.chatCommandNoFillContent
              : l10n.chatContentFilled,
          isError: message.isEmpty,
        );
        if (message.isNotEmpty) {
          _composerCtrl.setCanonicalText(
            message,
            selection: TextSelection.collapsed(offset: message.length),
          );
          _composerFocus.requestFocus();
        }
        return true;
      case 'exec':
      case 'plugin':
      case 'rpc':
      case 'action':
        final output = result['output']?.toString().trim() ?? '';
        final actionMessage = result['message']?.toString().trim() ?? '';
        final warning = result['warning']?.toString().trim() ?? '';
        final structured = result['result'];
        final rendered = output.isNotEmpty
            ? output
            : actionMessage.isNotEmpty
            ? actionMessage
            : structured == null
            ? l10n.chatCommandCompletedNoOutput
            : const JsonEncoder.withIndent('  ').convert(structured);
        session.chat.completeSlashStatus(
          statusId,
          [
            if (warning.isNotEmpty) l10n.chatWarning(warning),
            rendered,
          ].join('\n'),
        );
        return true;
      case 'alias':
        final target = (result['target'] ?? result['command'])
            ?.toString()
            .trim();
        if (target == null || target.isEmpty || target == commandName) {
          session.chat.completeSlashStatus(
            statusId,
            l10n.chatInvalidCommandAlias,
            isError: true,
          );
          return true;
        }
        final arg = invocation.substring(commandName.length).trim();
        session.chat.completeSlashStatus(
          statusId,
          l10n.chatForwardedToCommand(target),
        );
        return _dispatchSlashCommand(
          '/$target${arg.isEmpty ? '' : ' $arg'}',
          busy: busy,
        );
      case 'error':
        session.chat.completeSlashStatus(
          statusId,
          message.isEmpty ? l10n.chatCommandExecutionFailed : message,
          isError: true,
        );
        return true;
      default:
        final output = result['output']?.toString().trim() ?? '';
        if (output.isNotEmpty || message.isNotEmpty) {
          session.chat.completeSlashStatus(
            statusId,
            output.isNotEmpty ? output : message,
          );
        } else {
          session.chat.completeSlashStatus(
            statusId,
            context.l10n.chatUnknownCommandResult,
            isError: true,
          );
        }
        return true;
    }
  }

  /// Run a WebUI built-in local slash command (composer already cleared).
  Future<void> _runLocalSlashCommand(
    String trimmed,
    LocalSlashCommand command,
  ) async {
    final l10n = context.l10n;
    setState(() {
      _attachments = const [];
      _slashSuggestions = const [];
    });
    final arg = localSlashArg(trimmed, command);
    final chat = context.read<SessionStore>().chat;
    final statusId = chat.appendSlashStatus(
      '/${command.name}',
      l10n.chatExecuting,
      pending: true,
    );
    var outcome = l10n.commonCompleted;
    var failed = false;
    try {
      switch (command.handler) {
        case LocalSlashHandler.retry:
          await _retryLastTurn();
          break;
        case LocalSlashHandler.clear:
          await _clearConversationView();
          break;
        case LocalSlashHandler.undo:
          await _undoLastTurn();
          break;
        case LocalSlashHandler.steer:
          await _steerSlash(arg);
          break;
        case LocalSlashHandler.status:
          _showSessionInfo();
          break;
        case LocalSlashHandler.title:
          await _titleSlash(arg);
          break;
        case LocalSlashHandler.newChat:
          await context.read<SessionStore>().newChat();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.chatNewSessionOpened)));
          }
          break;
        case LocalSlashHandler.yolo:
          await _toggleYolo();
          break;
        case LocalSlashHandler.handoff:
          await _showHandoffDialog();
          break;
        case LocalSlashHandler.profile:
          await _showProfilePicker();
          break;
        case LocalSlashHandler.help:
          await _showSlashHelp();
          break;
        case LocalSlashHandler.background:
          if (arg.trim().isEmpty) {
            await _showBackgroundDialog();
          } else {
            await _submitBackgroundSlash(arg.trim());
          }
          break;
        case LocalSlashHandler.compress:
          await _compressSlash();
          break;
        case LocalSlashHandler.queue:
          await _queueSlash(arg);
          break;
        case LocalSlashHandler.usage:
          await _showContextPopover(context);
          break;
        case LocalSlashHandler.version:
          await _showVersionSlash();
          break;
        case LocalSlashHandler.stop:
          await context.read<SessionStore>().interrupt();
          break;
        case LocalSlashHandler.tools:
          await _showToolsConfig();
          break;
        case LocalSlashHandler.approvals:
          await _approvalsSlash(arg);
          break;
        case LocalSlashHandler.model:
          await _showModelPicker();
          break;
        case LocalSlashHandler.wake:
          final wake = context.read<VoiceStore>().wakeWord;
          if (wake == null) {
            outcome = l10n.chatWakeServiceUnavailable;
            failed = true;
          } else {
            outcome = await wake.command(arg);
          }
          break;
        case LocalSlashHandler.journey:
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const StarmapScreen()),
          );
          break;
        case LocalSlashHandler.pet:
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const PetCenterScreen()),
          );
          break;
        case LocalSlashHandler.hatch:
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const PetGenerateScreen()),
          );
          break;
        case LocalSlashHandler.save:
          final session = context.read<SessionStore>();
          final connection = context.read<ConnectionStore>();
          if (session.runtimeId == null) await session.openNewSession();
          final runtimeId = session.runtimeId;
          final gateway = connection.gateway;
          if (runtimeId == null || gateway == null) {
            throw StateError(l10n.backendDisconnected);
          }
          final result = await gateway.request('session.save', {
            'session_id': runtimeId,
          });
          final path = (result['file'] ?? result['path'])?.toString().trim();
          outcome = path == null || path.isEmpty
              ? l10n.chatCommandCompletedNoOutput
              : l10n.chatSessionSaved(path);
          break;
        case LocalSlashHandler.unavailable:
          outcome = localSlashDescription(command, l10n);
          failed = true;
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(outcome)));
          }
          break;
      }
    } catch (error) {
      outcome = l10n.chatExecutionFailed('$error');
      failed = true;
      rethrow;
    } finally {
      if (!chat.completeSlashStatus(statusId, outcome, isError: failed)) {
        chat.appendSlashStatus('/${command.name}', outcome);
      }
    }
  }

  Future<void> _undoLastTurn() async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    if (session.readOnly) return;
    try {
      await session.undoLastTurn();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatLastTurnUndone)),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatUndoFailed('$e'))),
        );
      }
    }
  }

  Future<void> _steerSlash(String text) async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final payload = text.trim();
    if (payload.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatSteerUsage)),
      );
      return;
    }
    if (!session.chat.busy) {
      await session.enqueueMessage(payload);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatNoActiveTurnQueued)),
        );
      }
      return;
    }
    try {
      await session.steer(payload);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatSteerInjected)),
        );
      }
    } catch (_) {
      await session.enqueueMessage(payload);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatSteerQueued)),
        );
      }
    }
  }

  Future<void> _titleSlash(String arg) async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final title = arg.trim();
    if (title.isEmpty) {
      await _regenerateTitle();
      return;
    }
    try {
      await session.rename(title);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatTitleSet(title))),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatSetTitleFailed('$e'))),
        );
      }
    }
  }

  Future<void> _showSlashHelp() async {
    final local = localSlashCommandPairs(context.l10n);
    final catalog = context.read<CommandStore>().catalog;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.l10n.chatSlashCommands),
          content: SizedBox(
            width: 420,
            height: 420,
            child: ListView(
              children: [
                Text(
                  context.l10n.chatLocalCommands,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final pair in local)
                  ListTile(
                    dense: true,
                    title: Text('/${pair.$1}'),
                    subtitle: Text(pair.$2),
                  ),
                const Divider(),
                Text(
                  context.l10n.chatServerCatalog,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (catalog.isEmpty)
                  ListTile(
                    dense: true,
                    title: Text(context.l10n.chatCatalogEmpty),
                  )
                else
                  for (final cmd in catalog)
                    if (!isMobileSlashSuggestionHidden(cmd.name))
                      ListTile(
                        dense: true,
                        title: Text(
                          cmd.name.startsWith('/') ? cmd.name : '/${cmd.name}',
                        ),
                        subtitle: cmd.description == null
                            ? null
                            : Text(cmd.description!),
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonClose),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitBackgroundSlash(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await context.read<SessionStore>().submitBackground(text);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            id.isEmpty
                ? context.l10n.chatBackgroundSubmitted
                : context.l10n.chatBackgroundSubmittedWithId(id),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatBackgroundSubmitFailed('$e')),
          ),
        );
      }
    }
  }

  Future<void> _compressSlash() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SessionStore>().compress();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatCompressionRequested)),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatCompressionFailed('$e'))),
        );
      }
    }
  }

  Future<void> _queueSlash(String arg) async {
    final text = arg.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (text.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatQueueUsage)),
      );
      return;
    }
    try {
      await context.read<SessionStore>().enqueueMessage(text);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatQueued)),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatQueueFailed('$e'))),
        );
      }
    }
  }

  Future<void> _showVersionSlash() async {
    final session = context.read<SessionStore>();
    final api = session.api;
    final messenger = ScaffoldMessenger.of(context);
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatServerNotConnected)),
      );
      return;
    }
    try {
      final status = await api.status();
      if (!mounted || !identical(api, session.api)) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(context.l10n.chatVersion),
            content: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(status),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(context.l10n.commonClose),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted && identical(api, session.api)) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatVersionLoadFailed('$e'))),
        );
      }
    }
  }

  Future<void> _approvalsSlash(String arg) async {
    final mode = arg.trim().toLowerCase();
    if (!const {'manual', 'smart', 'off'}.contains(mode)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.chatApprovalsUsage)));
      return;
    }
    await _setApprovalMode(mode);
  }

  /// Current `approvals.mode`, or null when the backend config doesn't
  /// expose the field at all (menu entry stays hidden in that case, same
  /// convention as `_yoloEnabled`).
  String? get _approvalMode {
    final approvals = _serverConfig['approvals'];
    return approvals is Map ? approvals['mode']?.toString() : null;
  }

  /// Desktop parity: statusbar `approval-mode-menu.tsx` lets you flip
  /// manual/smart/off mid-conversation without leaving chat. Mobile only had
  /// this buried in Settings → 对话配置; this is the quick "更多" menu path,
  /// backed by the same `/approvals` slash-command plumbing.
  Future<void> _setApprovalMode(String mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionStore>();
    final api = session.api;
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatServerNotConnected)),
      );
      return;
    }
    final current = _serverConfig['approvals'] is Map
        ? Map<String, dynamic>.from(_serverConfig['approvals'] as Map)
        : <String, dynamic>{};
    current['mode'] = mode;
    final patch = {'approvals': current};
    final profile = session.profile ?? session.activeProfile;
    try {
      if (!identical(api, session.api)) return;
      await api.putConfig(patch, profile: profile);
      if (!mounted ||
          !identical(api, session.api) ||
          profile != (session.profile ?? session.activeProfile)) {
        return;
      }
      session.applyProfileConfigPatch(profile, patch);
      setState(() => _serverConfig = {..._serverConfig, ...patch});
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatApprovalModeSet(mode))),
      );
    } catch (e) {
      if (mounted &&
          identical(api, session.api) &&
          profile == (session.profile ?? session.activeProfile)) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatApprovalModeFailed('$e'))),
        );
      }
    }
  }

  Future<void> _showApprovalModeSheet() async {
    const options = ['manual', 'smart', 'off'];
    final labels = {
      'manual': context.l10n.chatApprovalManual,
      'smart': context.l10n.chatApprovalSmart,
      'off': context.l10n.chatApprovalOff,
    };
    final descriptions = {
      'manual': context.l10n.chatApprovalManualDescription,
      'smart': context.l10n.chatApprovalSmartDescription,
      'off': context.l10n.chatApprovalOffDescription,
    };
    final current = _approvalMode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.chatApprovalMode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: current,
              onChanged: (value) => Navigator.pop(sheetContext, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    RadioListTile<String>(
                      value: option,
                      title: Text(labels[option] ?? option),
                      subtitle: Text(descriptions[option] ?? ''),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != current) {
      await _setApprovalMode(selected);
    }
  }

  /// B15 `/retry` (WebUI commands.js `cmdRetry`): gateways advertising a
  /// native `retry` command run the truncate + resend server-side; otherwise
  /// fall back to the real rewind + resubmit chain (`retry_last` + `send()`
  /// parity).
  Future<void> _retryLastTurn() async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    if (session.readOnly) return;
    if (session.chat.lastUserText() == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatNoRetryMessage)),
      );
      return;
    }
    final cmd = context.read<CommandStore>();
    final rt = session.runtimeId;
    final hasGatewayRetry = cmd.catalog.any(
      (c) => c.name.replaceFirst('/', '') == 'retry',
    );
    if (hasGatewayRetry && rt != null) {
      try {
        final result = await cmd.dispatch('retry', sessionId: rt);
        if (!mounted) return;
        // A `send`-typed dispatch hands the recovered text back for the
        // caller to resubmit; anything else already ran server-side.
        final resend =
            (result['message'] ?? result['text'] ?? result['output'])
                ?.toString() ??
            '';
        if (result['type'] == 'send' && resend.trim().isNotEmpty) {
          await session.sendMessage(resend, onAutoRetry: _showAutoRetryNotice);
        } else {
          await session.refreshTranscript();
        }
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.chatLastTurnRetried)),
          );
        }
        return;
      } catch (_) {
        // Fall through to the rewind chain.
      }
    }
    try {
      await session.regenerate();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatLastTurnRetried)),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatRetryFailed('$e'))),
        );
      }
    }
  }

  /// C2 `/clear` (WebUI `cmdClear`): gateways advertising a native `clear`
  /// command reset the session server-side; otherwise clear the current view
  /// only — exactly what the WebUI built-in does.
  Future<void> _clearConversationView() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final cmd = context.read<CommandStore>();
    final rt = session.runtimeId;
    final hasGatewayClear = cmd.catalog.any(
      (c) => c.name.replaceFirst('/', '') == 'clear',
    );
    if (hasGatewayClear && rt != null && !session.readOnly) {
      try {
        await cmd.dispatch('clear', sessionId: rt);
        if (!mounted) return;
        await session.refreshTranscript();
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.chatSessionCleared)),
          );
        }
        return;
      } catch (_) {
        // Fall through to the view-only clear.
      }
    }
    session.chat.clearView();
    messenger.showSnackBar(SnackBar(content: Text(l10n.chatViewCleared)));
  }

  /// B15 auto-retry notice: surfaced when a send hits a retryable transport
  /// error and the store resubmits once on its own.
  void _showAutoRetryNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.chatAutoRetried)));
  }

  // -------------------------------------------------------- saved prompts
  /// A18 (WebUI `btnSavedPrompts` popup): list saved prompt snippets, tap to
  /// insert into the composer, delete per row, save the current input.
  Future<void> _showSavedPrompts() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final api = session.api;
    final messenger = ScaffoldMessenger.of(context);
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatServerNotConnected)),
      );
      return;
    }
    List<SavedPrompt> prompts;
    try {
      prompts = await api.savedPrompts();
    } catch (e) {
      if (mounted && identical(api, session.api)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatSavedPromptsLoadFailed('$e')),
          ),
        );
      }
      return;
    }
    if (!mounted || !identical(api, session.api)) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Text(
                  context.l10n.chatSavedPrompts,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (prompts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Text(context.l10n.chatNoSavedPrompts),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: prompts.length,
                    itemBuilder: (_, i) {
                      final p = prompts[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.notes, size: 18),
                        title: Text(
                          p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          p.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: context.l10n.commonDelete,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () async {
                            if (!identical(api, session.api)) return;
                            try {
                              await api.deletePrompt(p.id);
                              if (!ctx.mounted ||
                                  !identical(api, session.api)) {
                                return;
                              }
                              setSheet(
                                () => prompts = prompts
                                    .where((x) => x.id != p.id)
                                    .toList(growable: false),
                              );
                            } catch (e) {
                              if (mounted && identical(api, session.api)) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.chatDeletePromptFailed('$e'),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _insertSavedPrompt(p.text);
                        },
                      );
                    },
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: Text(context.l10n.chatSaveCurrentInput),
                    onPressed: _composerCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            if (!identical(api, session.api)) return;
                            try {
                              final saved = await api.savePrompt(
                                _composerCtrl.text.trim(),
                              );
                              if (!ctx.mounted ||
                                  !identical(api, session.api)) {
                                return;
                              }
                              setSheet(() => prompts = [...prompts, saved]);
                              messenger.showSnackBar(
                                SnackBar(content: Text(l10n.chatPromptSaved)),
                              );
                            } catch (e) {
                              if (mounted && identical(api, session.api)) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.chatSavePromptFailed('$e'),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// WebUI `insertSavedPromptIntoComposer` parity: append the snippet after a
  /// blank line and keep editing.
  void _insertSavedPrompt(String text) {
    final current = _composerCtrl.text.replaceAll(RegExp(r'\s+$'), '');
    final next = current.isEmpty ? '$text\n\n' : '$current\n\n$text\n\n';
    setState(() {
      _composerCtrl.text = next;
      _composerCtrl.selection = TextSelection.collapsed(offset: next.length);
    });
  }

  /// Upload staged attachments (WebUI `uploadPendingFiles` semantics) and
  /// build the outgoing text: images inline as `@image:path`, files/folders
  /// appended as an `[Attached files: …]` path reference, URLs inline as
  /// `@url:`, snippets appended as text blocks.
  Future<String> _composeWithAttachments(
    String text,
    List<ComposerAttachment> attachments,
  ) async {
    if (attachments.isEmpty) return text;
    final imageRefs = <String>[];
    final filePaths = <String>[];
    final urlRefs = <String>[];
    final snippets = <String>[];

    for (final att in attachments) {
      switch (att.kind) {
        case ComposerAttachmentKind.snippet:
          final snippet = att.snippetText?.trim() ?? '';
          if (snippet.isNotEmpty) snippets.add(snippet);
        case ComposerAttachmentKind.url:
          final url = att.url?.trim() ?? att.path?.trim() ?? '';
          if (url.isNotEmpty) urlRefs.add('@url:$url');
        case ComposerAttachmentKind.folder:
          // Local folder path refs are not uploaded to the server.
          continue;
        case ComposerAttachmentKind.image:
        case ComposerAttachmentKind.file:
          var path = att.path?.trim() ?? '';
          if (path.isEmpty) {
            path = await _uploadLocalAttachment(att);
          }
          if (path.isEmpty) continue;
          if (att.kind == ComposerAttachmentKind.image) {
            imageRefs.add('@image:$path');
          } else {
            filePaths.add(path);
          }
      }
    }

    final referencedPaths = <String>[
      ...filePaths,
      ...imageRefs.map((ref) => ref.substring('@image:'.length)),
      ...urlRefs.map((ref) => ref.substring('@url:'.length)),
    ];

    var result = text;
    if (snippets.isNotEmpty) {
      result = [result, ...snippets].where((p) => p.isNotEmpty).join('\n\n');
    }
    final inlineRefs = [...imageRefs, ...urlRefs];
    if (inlineRefs.isNotEmpty) {
      result = result.isEmpty
          ? inlineRefs.join(' ')
          : '$result ${inlineRefs.join(' ')}';
    }
    if (filePaths.isNotEmpty) {
      result = result.isEmpty
          ? "I've uploaded ${filePaths.length} file(s): ${filePaths.join(', ')}"
          : '$result\n\n[Attached files: ${filePaths.join(', ')}]';
    }
    if (result.isEmpty && referencedPaths.isNotEmpty) {
      result =
          "I've uploaded ${referencedPaths.length} file(s): ${referencedPaths.join(', ')}";
    }
    return result;
  }

  /// Upload one staged local file to the server working directory via the
  /// domain API (`POST /api/v1/files/upload`, D6) and return the server path.
  Future<String> _uploadLocalAttachment(ComposerAttachment att) async {
    final l10n = context.l10n;
    final local = att.localPath;
    if (local == null || local.isEmpty) return '';
    final session = context.read<SessionStore>();
    final api = session.api;
    if (api == null) throw StateError(l10n.chatServerNotConnected);
    final file = fs.XFile(local);
    final length = await file.length();
    if (length > _maxUploadBytes) {
      throw StateError(
        l10n.chatFileTooLarge(_maxUploadBytes ~/ 1024 ~/ 1024, att.label),
      );
    }
    final bytes = await file.readAsBytes();
    final ext = _extOf(att.label);
    final mime = att.kind == ComposerAttachmentKind.image
        ? 'image/$ext'
        : 'application/octet-stream';
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    final safeName = att.label.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final name = 'hm_attach_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    if (!identical(api, session.api)) {
      throw StateError(l10n.chatServerNotConnected);
    }
    final result = await api.uploadFile('/hm-attachments/$name', dataUrl);
    if (!identical(api, session.api)) {
      throw StateError(l10n.chatServerNotConnected);
    }
    return result['path']?.toString() ?? name;
  }

  // Batch 2.4: Queue panel — shows all pending queued messages with per-item
  // cancel and a "clear all" action.
  Future<void> _showQueuePanel() async {
    final session = context.read<SessionStore>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ChangeNotifierProvider.value(
          value: session,
          child: Consumer<SessionStore>(
            builder: (_, s, child) {
              final queue = s.sendQueue;
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                      child: Row(
                        children: [
                          Text(
                            context.l10n.chatSendQueue,
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx).colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${queue.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(ctx).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (queue.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                s.clearQueue();
                                Navigator.of(ctx).pop();
                              },
                              child: Text(context.l10n.commonCancelAll),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (queue.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.inbox_outlined,
                                size: 44,
                                color: Colors.black26,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.l10n.chatNoQueuedMessages,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: queue.length,
                          itemBuilder: (listCtx, i) {
                            final item = queue[i];
                            final preview = item.text.length > 140
                                ? '${item.text.substring(0, 140)}…'
                                : item.text;
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: Theme.of(
                                  listCtx,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      listCtx,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                              title: Text(
                                preview,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _fmtQueueTime(item.createdAt),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: context.l10n.commonCancel,
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => s.cancelQueued(item.id),
                              ),
                              dense: true,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _fmtQueueTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) {
      return context.l10n.chatQueuedSecondsAgo(diff.inSeconds);
    }
    if (diff.inMinutes < 60) {
      return context.l10n.chatQueuedMinutesAgo(diff.inMinutes);
    }
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// Extracted composer construction so the desktop-only [DropTarget] wrapper
  /// and the plain touch-platform path can share one definition.
  List<MobilePluginContribution> _composerContributions(BuildContext context) {
    try {
      return context.watch<PluginContributionStore>().forArea(
        MobileContributionArea.composer,
      );
    } on ProviderNotFoundException {
      return const [];
    }
  }

  Widget _buildComposer(
    SessionStore session,
    ChatStore chat,
    VoiceStore voice,
  ) {
    return HermesComposer(
      controller: _composerCtrl,
      focusNode: _composerFocus,
      readOnly: session.readOnly,
      busy: chat.busy || _sending,
      modelLabel: session.info?.model,
      onModelTap: session.readOnly ? null : _showModelPicker,
      onStop: session.readOnly ? null : () => session.interrupt(),
      onSteer: session.readOnly ? null : _steerFromComposer,
      onSpeak: _speakLastReply,
      onSend: _send,
      onUndo: () {
        if (_composerCtrl.undoStructuredEdit()) setState(() {});
      },
      onRedo: () {
        if (_composerCtrl.redoStructuredEdit()) setState(() {});
      },
      // A17: ambient context-usage indicator fed by the real per-turn
      // usage payloads accumulated in the chat store; null (and not
      // rendered) when no turn has reported usage.
      ctxUsageLabel: switch (chat.cumulativeUsageTokens) {
        final total? => formatCtxUsageLabel(total),
        null => null,
      },
      suggestions: _buildSuggestions(),
      onSuggestionKeyEvent: _handleSuggestionKey,
      attachments: _attachments,
      onAttachmentsChanged: (list) {
        setState(() => _attachments = list);
        // Also schedule a draft save on attachment add/remove.
        final sid = _lastDraftSid;
        if (sid != null && !_draftRestoreInProgress) {
          final s = context.read<SessionStore>();
          s.scheduleDraftSave(sid, _composerCtrl.text, _attachmentsForPersist);
        }
      },
      // Profile chip: the real active profile from the profiles API.
      personalityLabel: _activeProfileName,
      onPersonalityTap: session.readOnly ? null : _showProfilePicker,
      // Workspace chip: session cwd → explicit pick → server default cwd.
      workspaceLabel: switch (_workspaceCwd ??
          session.info?.cwd ??
          _defaultCwd) {
        final cwd? => _workspaceBaseName(cwd),
        null => null,
      },
      onWorkspaceTap: session.readOnly ? null : _showWorkspacePicker,
      // Reasoning-effort chip: removed entirely when the backend config
      // has no reasoning/effort field (no invented difficulties).
      difficultyLabel: _reasoningEffort,
      onDifficultyTap: session.readOnly || _reasoningEffort == null
          ? null
          : _showDifficultyPicker,
      toolsLabel: _toolsetsLoaded ? _toolsetsLabel : null,
      toolsSelected: false,
      onToolsTap: session.readOnly ? null : _showToolsConfig,
      yoloEnabled: _yoloEnabled,
      onYoloTap: session.readOnly || _yoloEnabled == null ? null : _toggleYolo,
      // A16: ambient provider quota chip — only with real backend data.
      quotaLabel: _quotaLabel,
      onQuotaTap: _quotaLabel == null ? null : _refreshQuotaChip,
      leadingActions: session.readOnly
          ? const []
          : [
              for (final contribution in _composerContributions(context))
                IconButton(
                  tooltip: contribution.title,
                  icon: const Icon(Icons.extension_outlined),
                  onPressed: () => context
                      .read<PluginContributionStore>()
                      .invoke(contribution),
                ),
              // Merged attach entry: file / folder picker (the tray's
              // old "附加" menu is gone — these buttons are the only
              // add path).
              PopupMenuButton<String>(
                tooltip: context.l10n.chatAttachFiles,
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'file') _pickFilesToTray();
                  if (v == 'folder') _pickFolderToTray();
                  if (v == 'snippet') _addSnippetAttachment();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'file',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.insert_drive_file_outlined),
                      title: Text(context.l10n.commonFile),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'folder',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.folder_outlined),
                      title: Text(context.l10n.commonFolder),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'snippet',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.notes),
                      title: Text(context.l10n.chatTextSnippet),
                    ),
                  ),
                ],
                child: _footerIcon(
                  tooltip: context.l10n.chatAttachFiles,
                  icon: Icons.attach_file,
                ),
              ),
              _footerIconButton(
                tooltip: context.l10n.chatAddImage,
                icon: Icons.image_outlined,
                onTap: _pickImage,
              ),
              _footerIconButton(
                tooltip: context.l10n.chatAttachLink,
                icon: Icons.link_outlined,
                onTap: _addUrlAttachment,
              ),
              // A18: saved prompt snippets (WebUI btnSavedPrompts) —
              // only when the server actually serves the resource.
              if (_savedPromptsSupported)
                _footerIconButton(
                  tooltip: context.l10n.chatSavedPrompts,
                  icon: Icons.bookmark_outline,
                  onTap: _showSavedPrompts,
                ),
            ],
      // Queue / voice / TTS / more moved from the old bottom bar into
      // the composer card footer (settings & new-chat removed).
      footerActions: [
        _footerQueueButton(count: session.queueCount, onTap: _showQueuePanel),
        HermesVoiceMenu(
          voice: voice,
          onDictate: _toggleRecording,
          onToggleContinuous: _toggleContinuousVoice,
          onToggleAutoSpeak: () => voice.toggleAutoSpeak(),
        ),
        Builder(
          builder: (anchorContext) => _footerIconButton(
            tooltip: _contextUsagePercent == null
                ? context.l10n.chatContextUsage
                : context.l10n.chatContextUsagePercent(
                    _contextUsagePercent!.round(),
                  ),
            icon: Icons.data_usage,
            onTap: () => _showContextPopover(anchorContext),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: context.l10n.commonMore,
          padding: EdgeInsets.zero,
          onSelected: (v) {
            switch (v) {
              case 'info':
                _showSessionInfo();
              case 'rename':
                _renameSession();
              case 'yolo':
                _toggleYolo();
              case 'approval_mode':
                _showApprovalModeSheet();
              case 'steer':
                _showSteerDialog();
              case 'background':
                _showBackgroundDialog();
              case 'branch':
                _branchFromHere();
              case 'handoff':
                _showHandoffDialog();
              case 'skills':
                _showSkills();
            }
          },
          itemBuilder: (_) => session.readOnly
              ? [
                  PopupMenuItem(
                    value: 'info',
                    child: Text(context.l10n.chatSessionInfo),
                  ),
                ]
              : [
                  PopupMenuItem(
                    value: 'info',
                    child: Text(context.l10n.chatSessionInfo),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(context.l10n.chatRename),
                  ),
                  const PopupMenuDivider(),
                  // Hidden entirely when the backend config exposes no
                  // approvals field — same "no misleading default" rule as
                  // the yolo switch below.
                  if (_approvalMode != null)
                    PopupMenuItem(
                      value: 'approval_mode',
                      child: Row(
                        children: [
                          const Icon(Icons.rule_folder_outlined, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(context.l10n.chatApprovalMode)),
                          Text(
                            _approvalMode ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Hidden entirely when the backend config exposes no
                  // yolo field — never a misleading default-off switch.
                  if (_yoloEnabled != null)
                    PopupMenuItem(
                      value: 'yolo',
                      child: Row(
                        children: [
                          const Icon(Icons.flash_on, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(context.l10n.chatYoloMode)),
                          if (_yoloEnabled == true)
                            const Icon(
                              Icons.check,
                              size: 18,
                              color: HermesSemantic.green,
                            ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'steer',
                    child: Text(context.l10n.chatSteerMessage),
                  ),
                  PopupMenuItem(
                    value: 'background',
                    child: Text(context.l10n.chatRunInBackground),
                  ),
                  PopupMenuItem(
                    value: 'branch',
                    child: Text(context.l10n.chatBranch),
                  ),
                  PopupMenuItem(
                    value: 'handoff',
                    child: Text(context.l10n.chatHandoff),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'skills',
                    child: Text(context.l10n.chatSkillsCenter),
                  ),
                ],
          child: _footerIcon(
            tooltip: context.l10n.commonMore,
            icon: Icons.more_vert,
          ),
        ),
      ],
    );
  }

  /// Pending interactive requests (approval / clarify / secret / sudo /
  /// terminal.read) shown as a slim strip above the composer; tapping opens
  /// the existing global request sheet via [showRequestSheet].
  Widget _buildRequestBanner() {
    // Nullable watch: returns null (instead of ProviderNotFoundException)
    // where no RequestStore is scoped above the chat screen (unit tests).
    final requests = context.watch<RequestStore?>();
    final req = requests?.current;
    if (requests == null || req == null) return const SizedBox.shrink();
    final runtimeId = context.read<SessionStore>().runtimeId;
    if (req.sessionId == null || req.sessionId == runtimeId) {
      // Foreground requests are rendered at their exact timeline position by
      // the interaction ChatPart. Keep this strip for background requests.
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final warning = theme.brightness == Brightness.dark
        ? HermesSemanticDark.orange
        : HermesSemantic.orange;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warning.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showRequestSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.rule, size: 16, color: warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  requests.pendingCount > 1
                      ? context.l10n.chatPendingRequests(
                          _requestKindLabel(req.kind),
                          requests.pendingCount,
                        )
                      : _requestKindLabel(req.kind),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: warning),
            ],
          ),
        ),
      ),
    );
  }

  String _requestKindLabel(RequestKind kind) {
    switch (kind) {
      case RequestKind.approval:
        return context.l10n.chatRequestApproval;
      case RequestKind.clarify:
        return context.l10n.chatRequestQuestion;
      case RequestKind.mcpSetup:
        return context.l10n.chatRequestMcpConfig;
      case RequestKind.secret:
        return context.l10n.chatRequestSecret;
      case RequestKind.sudo:
        return context.l10n.chatRequestPassword;
      case RequestKind.terminalRead:
        return context.l10n.chatRequestTerminalInput;
    }
  }

  /// WebUI queue-card parity: a persistent strip above the composer shows the
  /// pending queue count; tapping expands it to a per-item list with delete
  /// (and a clear-all action).
  Widget _buildQueueStrip(SessionStore session) {
    final queue = session.sendQueue;
    if (queue.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  setState(() => _queueStripExpanded = !_queueStripExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      session.queueParked
                          ? Icons.pause_circle_outline
                          : Icons.queue_play_next_outlined,
                      size: 16,
                      color: muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.chatQueueSummary(
                          session.queueParked
                              ? context.l10n.chatQueuePaused
                              : context.l10n.chatQueue,
                          queue.length,
                          _queueStripExpanded
                              ? context.l10n.commonCollapse
                              : context.l10n.commonExpand,
                        ),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (session.queueParked)
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: session.resumeQueue,
                        child: Text(context.l10n.commonContinue),
                      ),
                    if (_queueStripExpanded && !session.queueParked)
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          session.clearQueue();
                          setState(() => _queueStripExpanded = false);
                        },
                        child: Text(context.l10n.commonCancelAll),
                      ),
                    Icon(
                      _queueStripExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: muted,
                    ),
                  ],
                ),
              ),
            ),
            if (_queueStripExpanded) ...[
              const Divider(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: queue.length,
                  itemBuilder: (listCtx, i) {
                    final item = queue[i];
                    final preview = item.text.length > 80
                        ? '${item.text.substring(0, 80)}…'
                        : item.text;
                    return ListTile(
                      dense: true,
                      leading: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                      title: Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        item.deliveryUncertain
                            ? context.l10n.chatDeliveryUncertain
                            : _fmtQueueTime(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: item.deliveryUncertain
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                      onTap: () {
                        _composerCtrl.text = item.displayText ?? item.text;
                        _attachments = _composerAttachments(item.attachments);
                        _editingQueuedMessageId = item.id;
                        setState(() => _queueStripExpanded = false);
                        _composerFocus.requestFocus();
                      },
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          if (session.chat.busy)
                            IconButton(
                              tooltip: context.l10n.chatSteerCurrentTurn,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.explore_outlined,
                                size: 17,
                              ),
                              onPressed: () async {
                                try {
                                  await session.steerQueuedNow(item.id);
                                } catch (e) {
                                  if (mounted) {
                                    showHermesToast(
                                      context,
                                      message: context.l10n.chatSteerNowFailed(
                                        '$e',
                                      ),
                                      kind: HermesToastKind.error,
                                    );
                                  }
                                }
                              },
                            ),
                          IconButton(
                            tooltip: session.chat.busy
                                ? context.l10n.chatSetAsNext
                                : context.l10n.chatSendNow,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.subdirectory_arrow_left,
                              size: 18,
                            ),
                            onPressed: () => session.sendQueuedNow(item.id),
                          ),
                          IconButton(
                            tooltip: context.l10n.commonCancel,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => session.cancelQueued(item.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposerStatusStack(SessionStore session) {
    final chat = context.read<ChatStore>();
    final composer =
        context.maybeRead<ComposerStatusStore>() ?? session.composerStatus;
    final preview = context.maybeRead<PreviewStore>();
    final coding = context.maybeRead<CodingStatusStore>();
    final billing = context.maybeRead<BillingStore>();
    final pullRequests = Provider.of<PullRequestStore?>(context);
    final listenables = <Listenable>[
      chat.composerSurfaceRevision,
      session,
      ?composer,
      ?preview,
      ?coding,
      ?billing,
      ?pullRequests,
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final statusSnapshot = composer?.snapshotFor(session.runtimeId);
        final typed = statusSnapshot?.items ?? const [];
        // Generic ChatStore rows are transient turn activity. Only running
        // work or explicit failures belong in the attention stack; settled
        // success is emitted through the notification/toast channel.
        final generic = chat.statusItems
            .where(
              (item) => !const {
                'completed',
                'complete',
                'done',
                'dismissed',
                'removed',
              }.contains(item.state),
            )
            .toList(growable: false);
        if (billing != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => billing.refresh(),
          );
        }
        final billingBlocked =
            chat.billingBlock != null ||
            billing?.gate.blocked == true ||
            chat.recoveryJournal.any(
              (entry) =>
                  classifyChatError(
                    entry.diagnostics,
                    surface: entry.errorSurface,
                  ) ==
                  ChatErrorLayer.billing,
            );
        final info = session.info;
        final currentRow = session.sessions
            ?.where((row) => row.id == session.durableId)
            .firstOrNull;
        final pullRequest = currentRow == null
            ? null
            : pullRequests?.forSession(currentRow);
        final codingStatus = coding?.forCwd(info?.cwd);
        if (info?.cwd?.isNotEmpty == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            coding?.refresh(info?.cwd);
          });
        }
        final hasCoding =
            info?.branch?.isNotEmpty == true || info?.cwd?.isNotEmpty == true;
        final hasDetails =
            generic.isNotEmpty ||
            typed.isNotEmpty ||
            session.sendQueue.isNotEmpty ||
            preview?.hasContent == true ||
            billingBlocked ||
            hasCoding;
        final palette = HermesPalette.of(context);
        final groups = statusSnapshot?.groups ?? const {};
        final agentStatus = chat.busy
            ? HermesAgentStatus.thinking
            : info?.running == true
            ? HermesAgentStatus.running
            : HermesAgentStatus.idle;
        final subagentCount = typed
            .where(
              (item) =>
                  item.type == ComposerStatusType.subagent &&
                  item.state == ComposerStatusState.running,
            )
            .length;
        final backgroundCount = typed
            .where(
              (item) =>
                  item.type == ComposerStatusType.background &&
                  item.state == ComposerStatusState.running,
            )
            .length;
        return AnimatedOpacity(
          duration: HermesMotion.standard,
          opacity: _scrollCoordinator.stuckToBottom ? 1 : .38,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .4,
            ),
            child: Container(
              key: const ValueKey('composer-status-stack'),
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: palette.codeBg,
                border: Border(
                  top: BorderSide(color: palette.border),
                  bottom: BorderSide(color: palette.border),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCompactComposerStatusBar(
                    agentStatus: agentStatus,
                    branch: codingStatus?.branch.isNotEmpty == true
                        ? codingStatus!.branch
                        : info?.branch,
                    changedFiles: codingStatus?.changed ?? 0,
                    subagentCount: subagentCount,
                    backgroundCount: backgroundCount,
                    pullRequest: pullRequest,
                    hasDetails: hasDetails,
                    onCodingTap: info?.cwd?.isNotEmpty == true
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GitScreen(initialPath: info?.cwd),
                            ),
                          )
                        : null,
                  ),
                  if (chat.billingBlock != null)
                    _buildStructuredBillingRow(chat),
                  if (_statusDetailsExpanded && hasDetails) ...[
                    Divider(height: 1, color: palette.border),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .32,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (billingBlocked && chat.billingBlock == null)
                              Material(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                  title: Text(
                                    context.l10n.chatInsufficientQuota,
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const BillingScreen(),
                                      ),
                                    ),
                                    child: Text(context.l10n.chatViewBilling),
                                  ),
                                ),
                              ),
                            if (hasCoding)
                              ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.account_tree_outlined,
                                  size: 18,
                                ),
                                title: Text(
                                  codingStatus?.branch.isNotEmpty == true
                                      ? codingStatus!.branch
                                      : info?.branch?.isNotEmpty == true
                                      ? info!.branch!
                                      : context.l10n.chatWorkspace,
                                ),
                                subtitle: info?.cwd?.isNotEmpty == true
                                    ? Text(
                                        info!.cwd!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (codingStatus != null &&
                                        codingStatus.changed > 0)
                                      Text(
                                        '+${codingStatus.added} −${codingStatus.removed}'
                                        '${codingStatus.untracked > 0 ? ' ?${codingStatus.untracked}' : ''}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    if (codingStatus?.ahead case final ahead?
                                        when ahead > 0)
                                      Text(
                                        ' ↑$ahead',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    if (codingStatus?.behind case final behind?
                                        when behind > 0)
                                      Text(
                                        ' ↓$behind',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    const Icon(Icons.chevron_right, size: 18),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        FilesScreen(initialPath: info?.cwd),
                                  ),
                                ),
                                onLongPress: coding == null || info?.cwd == null
                                    ? null
                                    : () => _showCodingActions(
                                        coding,
                                        info!.cwd!,
                                        codingStatus?.branch ??
                                            info.branch ??
                                            '',
                                      ),
                              ),
                            for (final type in ComposerStatusType.values)
                              if (groups[type]?.isNotEmpty == true)
                                _buildTypedStatusGroup(
                                  session: session,
                                  composer: composer!,
                                  type: type,
                                  items: groups[type]!,
                                ),
                            if (preview != null)
                              for (final tab in preview.tabs.where(
                                (tab) =>
                                    tab.sessionId == null ||
                                    tab.sessionId == session.runtimeId,
                              ))
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.preview_outlined,
                                    size: 18,
                                  ),
                                  title: Text(
                                    tab.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: tab.url == null
                                      ? Text(context.l10n.chatHtmlPreview)
                                      : Text(
                                          tab.url!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  trailing: IconButton(
                                    tooltip: context.l10n.chatClosePreview,
                                    onPressed: () => preview.closeTab(tab.id),
                                    icon: const Icon(Icons.close, size: 16),
                                  ),
                                  onTap: () {
                                    preview.activate(tab.id);
                                    if (tab.url != null) {
                                      openChatLink(context, tab.url!);
                                    } else if (tab.html != null) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => WebPreviewPage(
                                            html: tab.html,
                                            title: tab.title,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                            if (chat.artifactRegistry.isNotEmpty)
                              ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                ),
                                title: Text(
                                  context.l10n.chatArtifactVersions(
                                    chat.artifactRegistry.values.fold<int>(
                                      0,
                                      (sum, versions) => sum + versions.length,
                                    ),
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                ),
                                onTap: () => _showArtifactVersions(chat),
                              ),
                            for (final item in generic)
                              ListTile(
                                dense: true,
                                leading: item.state == 'running'
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        item.state == 'error' ||
                                                item.state == 'failed'
                                            ? Icons.error_outline
                                            : Icons.check_circle_outline,
                                        size: 18,
                                      ),
                                title: Text(
                                  item.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  _chatStatusKindLabel(context, item.kind),
                                ),
                                trailing: IconButton(
                                  tooltip: context.l10n.chatHideStatus,
                                  onPressed: () => chat.dismissStatus(item.id),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            if (session.sendQueue.isNotEmpty)
                              _buildQueueStrip(session),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStructuredBillingRow(ChatStore chat) {
    final block = chat.billingBlock!;
    final firstLine = block.message.split('\n').first.trim();
    return Material(
      key: const ValueKey('chat-billing-block'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.account_balance_wallet_outlined, size: 19),
        title: Text(
          '${context.l10n.chatInsufficientQuota} · ${block.providerLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: firstLine.isEmpty
            ? null
            : Text(firstLine, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                if (!block.isNous && block.billingUrl != null) {
                  launchExternalOrNotify(context, block.billingUrl!);
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BillingScreen(),
                  ),
                );
              },
              child: Text(
                block.isNous
                    ? context.l10n.chatViewBilling
                    : context.l10n.billingPurchaseCredits,
              ),
            ),
            IconButton(
              tooltip: context.l10n.commonClose,
              visualDensity: VisualDensity.compact,
              onPressed: chat.dismissBillingBlock,
              icon: const Icon(Icons.close, size: 17),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactComposerStatusBar({
    required HermesAgentStatus agentStatus,
    required String? branch,
    required int changedFiles,
    required int subagentCount,
    required int backgroundCount,
    required bool hasDetails,
    required SessionPullRequest? pullRequest,
    VoidCallback? onCodingTap,
  }) {
    final palette = HermesPalette.of(context);

    Widget divider() => Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: palette.border,
    );

    Widget segment({
      required IconData icon,
      required String label,
      VoidCallback? onTap,
      Color? color,
    }) => InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? palette.text3),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: palette.text2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      key: const ValueKey('composer-status-bar'),
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  HermesAgentStatusView(status: agentStatus, animate: false),
                  if (branch?.isNotEmpty == true) ...[
                    divider(),
                    segment(
                      icon: Icons.account_tree_outlined,
                      label: changedFiles > 0
                          ? context.l10n.chatBranchChanges(
                              branch!,
                              changedFiles,
                            )
                          : branch!,
                      onTap: onCodingTap,
                    ),
                  ],
                  if (pullRequest != null) ...[
                    divider(),
                    segment(
                      icon: Icons.call_made,
                      label: 'PR #${pullRequest.number}',
                      color: switch (pullRequest.bucket) {
                        PullRequestBucket.open => hermesSemantic(
                          context,
                          HermesSemantic.green,
                          HermesSemanticDark.green,
                        ),
                        PullRequestBucket.draft => hermesSemantic(
                          context,
                          HermesSemantic.gray,
                          HermesSemanticDark.gray,
                        ),
                        PullRequestBucket.merged => hermesSemantic(
                          context,
                          HermesSemantic.purple,
                          HermesSemanticDark.purple,
                        ),
                        PullRequestBucket.closed => hermesSemantic(
                          context,
                          HermesSemantic.red,
                          HermesSemanticDark.red,
                        ),
                        PullRequestBucket.none => palette.text3,
                      },
                      onTap: pullRequest.url.isEmpty
                          ? null
                          : () => unawaited(
                              launchExternalOrNotify(
                                context,
                                Uri.parse(pullRequest.url),
                                failureMessage:
                                    context.l10n.sessionPrOpenFailed,
                              ),
                            ),
                    ),
                  ],
                  if (subagentCount > 0) ...[
                    divider(),
                    segment(
                      icon: Icons.hub_outlined,
                      label: context.l10n.chatSubagentCount(subagentCount),
                      onTap: () =>
                          setState(() => _statusDetailsExpanded = true),
                    ),
                  ],
                  if (backgroundCount > 0) ...[
                    divider(),
                    segment(
                      icon: Icons.dns_outlined,
                      label: context.l10n.chatBackgroundCount(backgroundCount),
                      onTap: () =>
                          setState(() => _statusDetailsExpanded = true),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasDetails)
            IconButton(
              tooltip: _statusDetailsExpanded
                  ? context.l10n.chatCollapseStatusDetails
                  : context.l10n.chatExpandStatusDetails,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(
                () => _statusDetailsExpanded = !_statusDetailsExpanded,
              ),
              // ▲ while collapsed (tap to open upward into view), ▼ once
              // expanded (tap to fold the detail panel back down/away).
              icon: Icon(
                _statusDetailsExpanded ? Icons.expand_more : Icons.expand_less,
                size: 18,
                color: palette.text3,
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Future<void> _showArtifactVersions(ChatStore chat) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .72,
          child: ListView(
            children: [
              ListTile(
                title: Text(context.l10n.chatCurrentSessionArtifacts),
                subtitle: Text(context.l10n.chatBrowseArtifactsDescription),
              ),
              for (final entry in chat.artifactRegistry.entries)
                ExpansionTile(
                  leading: const Icon(Icons.code_outlined),
                  title: Text(entry.key.toUpperCase()),
                  subtitle: Text(
                    context.l10n.chatVersionCount(entry.value.length),
                  ),
                  children: [
                    for (var index = 0; index < entry.value.length; index++)
                      ListTile(
                        dense: true,
                        title: Text(context.l10n.chatVersionNumber(index + 1)),
                        subtitle: Text(
                          entry.value[index],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WebPreviewPage(
                                html: entry.key == 'html'
                                    ? entry.value[index]
                                    : '<pre>${const HtmlEscape().convert(entry.value[index])}</pre>',
                                title:
                                    '${entry.key.toUpperCase()} · v${index + 1}',
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCodingActions(
    CodingStatusStore coding,
    String cwd,
    String currentBranch,
  ) async {
    List<String> branches;
    try {
      branches = await coding.branches(cwd);
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.chatBranchesLoadFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(context.l10n.gitSwitchBranch),
              subtitle: Text(context.l10n.chatLongPressCodingStatus),
            ),
            ListTile(
              leading: const Icon(Icons.call_split),
              title: Text(context.l10n.gitNewWorktree),
              subtitle: Text(context.l10n.chatNewWorktreeDescription),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _createWorktree(coding, cwd, currentBranch);
              },
            ),
            const Divider(height: 1),
            for (final branch in branches)
              ListTile(
                leading: Icon(
                  branch == currentBranch
                      ? Icons.check_circle
                      : Icons.account_tree_outlined,
                ),
                title: Text(branch),
                enabled: branch != currentBranch,
                onTap: branch == currentBranch
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        try {
                          await coding.switchBranch(cwd, branch);
                        } catch (error) {
                          if (mounted) {
                            showHermesToast(
                              context,
                              message: context.l10n.gitSwitchBranchFailed(
                                '$error',
                              ),
                              kind: HermesToastKind.error,
                            );
                          }
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createWorktree(
    CodingStatusStore coding,
    String cwd,
    String currentBranch,
  ) async {
    final ctrl = TextEditingController();
    final name = await showAdaptiveFormDialog<String>(
      context: context,
      title: context.l10n.gitNewWorktree,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.l10n.commonName,
          hintText: context.l10n.gitWorktreeNameHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
          child: Text(context.l10n.commonCreate),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final result = await coding.addWorktree(
        cwd,
        name: name,
        base: currentBranch,
      );
      final path = (result?['path'] ?? result?['worktreePath'])?.toString();
      if (path != null && path.isNotEmpty && mounted) {
        await context.read<SessionStore>().openNewSession(cwd: path);
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.gitCreateWorktreeFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Widget _buildTypedStatusGroup({
    required SessionStore session,
    required ComposerStatusStore composer,
    required ComposerStatusType type,
    required List<ComposerStatusItem> items,
  }) {
    final collapsed = _collapsedStatusGroups.contains(type);
    final groupRunning = items.any(
      (item) => item.state == ComposerStatusState.running,
    );
    final label = switch (type) {
      ComposerStatusType.goal => context.l10n.chatGoals,
      ComposerStatusType.todo => context.l10n.chatPlanProgress(
        items.where((i) => i.todoStatus == 'completed').length,
        items.length,
      ),
      ComposerStatusType.subagent => context.l10n.chatSubagentCount(
        items.length,
      ),
      ComposerStatusType.background => context.l10n.chatBackgroundCount(
        items.length,
      ),
      ComposerStatusType.preview => context.l10n.chatPreviewCount(items.length),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          dense: true,
          leading: Icon(switch (type) {
            ComposerStatusType.goal => Icons.flag_outlined,
            ComposerStatusType.todo => Icons.checklist,
            ComposerStatusType.subagent => Icons.hub_outlined,
            ComposerStatusType.background => Icons.dns_outlined,
            ComposerStatusType.preview => Icons.preview_outlined,
          }, size: 18),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (collapsed && groupRunning)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
              Icon(collapsed ? Icons.expand_more : Icons.expand_less),
            ],
          ),
          onTap: () => setState(() {
            collapsed
                ? _collapsedStatusGroups.remove(type)
                : _collapsedStatusGroups.add(type);
          }),
        ),
        if (!collapsed)
          for (final item in items)
            _buildTypedStatusRow(
              session: session,
              composer: composer,
              item: item,
            ),
      ],
    );
  }

  Widget _buildTypedStatusRow({
    required SessionStore session,
    required ComposerStatusStore composer,
    required ComposerStatusItem item,
  }) {
    if (item.type == ComposerStatusType.background) {
      return _buildBackgroundStatusRow(
        session: session,
        composer: composer,
        item: item,
        theme: Theme.of(context),
      );
    }
    final running = item.state == ComposerStatusState.running;
    final todoPending = item.todoStatus == 'pending';
    final goalPaused =
        item.type == ComposerStatusType.goal && item.goalStatus == 'paused';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 32, right: 8),
      leading: todoPending
          ? Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : goalPaused
          ? const Icon(Icons.pause_circle_outline, size: 17)
          : running
          ? const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              item.state == ComposerStatusState.failed
                  ? Icons.error_outline
                  : item.todoStatus == 'cancelled'
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline,
              size: 17,
            ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: item.currentTool == null ? null : Text(item.currentTool!),
      trailing: IconButton(
        tooltip: context.l10n.commonHide,
        onPressed: () => composer.dismissStatus(session.runtimeId!, item.id),
        icon: const Icon(Icons.close, size: 15),
      ),
      onTap:
          item.type == ComposerStatusType.subagent &&
              item.sessionId?.isNotEmpty == true
          ? () => session.openReadOnlySession(item.sessionId!)
          : null,
    );
  }

  Widget _buildBackgroundStatusRow({
    required SessionStore session,
    required ComposerStatusStore? composer,
    required ComposerStatusItem item,
    required ThemeData theme,
  }) {
    final isRunning = item.state == ComposerStatusState.running;
    final failed = item.state == ComposerStatusState.failed;
    final subtitleParts = <String>[
      if (item.output != null && item.output!.isNotEmpty) item.output!,
      if (!isRunning && item.exitCode != null) 'exit ${item.exitCode}',
    ];
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: isRunning
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              failed ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: failed ? theme.colorScheme.error : null,
            ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(
              subtitleParts.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: failed ? theme.colorScheme.error : null,
              ),
            ),
      trailing: IconButton(
        tooltip: isRunning
            ? context.l10n.chatStopProcess
            : context.l10n.commonHide,
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          final runtimeId = session.runtimeId;
          if (runtimeId == null || runtimeId.isEmpty || composer == null) {
            return;
          }
          if (isRunning) {
            try {
              await composer.stopBackgroundProcess(runtimeId, item.id);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.chatStopProcessFailed('$e')),
                  ),
                );
              }
            }
          } else {
            composer.dismissBackgroundProcess(runtimeId, item.id);
          }
        },
        icon: Icon(isRunning ? Icons.stop : Icons.close, size: 16),
      ),
      onTap: () {
        final runtimeId = session.runtimeId;
        if (runtimeId == null || runtimeId.isEmpty) return;
        showBackgroundProcessSheet(
          context,
          sessionId: runtimeId,
          processId: item.id,
        );
      },
    );
  }

  // ----------------------------------------------------- autocomplete (3.3)
  void _onComposerChanged() {
    _acDebounce?.cancel();
    final text = _composerCtrl.text;
    // ── WebUI draft persistence: schedule 400 ms debounced save. ──
    final sid = _lastDraftSid;
    if (sid != null && !_draftRestoreInProgress) {
      final s = context.read<SessionStore>();
      s.scheduleDraftSave(sid, text, _attachmentsForPersist);
    }
    if (text.isEmpty) {
      if (_slashSuggestions.isNotEmpty ||
          _pathSuggestions.isNotEmpty ||
          _slashSuggestionQueryActive ||
          _slashSuggestionsLoading ||
          _cronSuggestionPhrase != null) {
        setState(() {
          _slashSuggestions = const [];
          _pathSuggestions = const [];
          _slashSuggestionsLoading = false;
          _slashSuggestionQueryActive = false;
          _cronSuggestionPhrase = null;
        });
      }
      return;
    }
    _updateCronSuggestion(text);
    _acDebounce = Timer(const Duration(milliseconds: 250), () {
      _refreshSuggestions(text);
    });
  }

  void _updateCronSuggestion(String text) {
    final phrase =
        shouldSuggestCron(
          text,
          acceptedPrefix: context.l10n.cronSuggestionPrefix,
        )
        ? matchRecurrence(text)
        : null;
    final shown = (phrase != null && phrase != _cronSuggestionDismissedFor)
        ? phrase
        : null;
    if (shown != _cronSuggestionPhrase) {
      setState(() => _cronSuggestionPhrase = shown);
    }
  }

  Future<void> _refreshSuggestions(String text) async {
    final cmd = context.read<CommandStore>();
    // Keep completion active through argument stages. `replace_from` tells us
    // whether a pick replaces the command token or only the argument suffix.
    if (text.startsWith('/') && !text.contains('\n')) {
      setState(() {
        _slashSuggestionsLoading = true;
        _slashSuggestionQueryActive = true;
      });
      final List<SlashSuggestion> rawResults;
      var replaceFrom = 1;
      if (text == '/') {
        if (cmd.catalogSuggestions.isEmpty) await cmd.loadCatalog();
        rawResults = cmd.catalogSuggestions;
      } else {
        final completion = await cmd.completeSlashResult(text);
        rawResults = completion.items;
        replaceFrom = completion.replaceFrom;
      }
      final results = rawResults
          .where((item) => !isMobileSlashSuggestionHidden(item.name))
          .toList(growable: false);
      if (!mounted) return;
      // Stale guard: the user may have typed more while we were waiting.
      if (_acTarget.text != text) return;
      // Merge WebUI built-in local commands (commands.js `COMMANDS`) that
      // the gateway catalog does not cover.
      final token = text.substring(1).toLowerCase();
      final seen = results
          .map((r) => r.name.replaceFirst('/', '').toLowerCase())
          .toSet();
      final merged = [...results];
      for (final (name, desc) in localSlashCommandPairs(context.l10n)) {
        if (name.startsWith(token) && !seen.contains(name)) {
          merged.add(
            SlashSuggestion(
              name: '/$name',
              description: desc,
              group: slashGroupCommands,
            ),
          );
        }
      }
      setState(() {
        _slashSuggestions = merged;
        _pathSuggestions = const [];
        _slashSuggestionsLoading = false;
        _slashSuggestionIndex = 0;
        _slashReplaceFrom = replaceFrom;
      });
      return;
    }
    // Session completion precedes generic path completion. References are
    // atomic composer tokens and carry profile/id separately on navigation.
    if (SessionComposerCompletion.queryFor(text) != null) {
      final results = SessionComposerCompletion.suggestions(
        text: text,
        sessions: _session.sessions ?? const <SessionRow>[],
        activeProfile: _activeProfileName,
      );
      setState(() {
        _sessionRefSuggestions = results;
        _pathSuggestions = const [];
        _slashSuggestions = const [];
      });
      return;
    }
    // Path completion: a trailing `@word` (no space after the @).
    final m = RegExp(r'@([^\s@]*)$').firstMatch(text);
    if (m != null) {
      final word = m.group(1)!;
      if (word.isNotEmpty) {
        final results = await cmd.completePath(word);
        if (!mounted) return;
        if (_acTarget.text != text) return;
        setState(() {
          _pathSuggestions = results;
          _sessionRefSuggestions = const [];
          _slashSuggestions = const [];
        });
        return;
      }
    }
    if (_slashSuggestions.isNotEmpty ||
        _pathSuggestions.isNotEmpty ||
        _sessionRefSuggestions.isNotEmpty) {
      setState(() {
        _slashSuggestions = const [];
        _pathSuggestions = const [];
        _sessionRefSuggestions = const [];
        _slashSuggestionsLoading = false;
        _slashSuggestionQueryActive = false;
      });
    }
  }

  /// Set the autocomplete target's text + caret, honouring the structured
  /// composer's canonical-text path when that's the target.
  void _acSetText(String next) {
    final sel = TextSelection.collapsed(offset: next.length);
    final target = _acTarget;
    if (target is StructuredComposerController) {
      target.setCanonicalText(next, selection: sel);
    } else {
      target.value = TextEditingValue(text: next, selection: sel);
    }
  }

  void _applySlashSuggestion(SlashSuggestion s) {
    var text = s.text;
    final current = _acTarget.text;
    var replaceFrom = _slashReplaceFrom.clamp(0, current.length);
    if (replaceFrom <= 1 && !text.startsWith('/')) text = '/$text';
    if (replaceFrom == 1 && current.startsWith('/') && text.startsWith('/')) {
      replaceFrom = 0;
    }
    final next = '${current.replaceRange(replaceFrom, current.length, text)} ';
    _acSetText(next);
    setState(() {
      _slashSuggestions = const [];
      _slashSuggestionQueryActive = false;
    });
    _acFocus.requestFocus();
  }

  void _applyPathSuggestion(PathSuggestion p) {
    final text = _acTarget.text;
    final suffix = p.isDirectory ? '/' : ' ';
    final normalized = p.path.endsWith('/') ? p.path : '${p.path}$suffix';
    final replaced = text.replaceFirst(RegExp(r'@([^\s@]*)$'), '@$normalized');
    _acTarget.text = replaced;
    _acTarget.selection = TextSelection.collapsed(offset: replaced.length);
    setState(() => _pathSuggestions = const []);
    if (p.isDirectory) _refreshSuggestions(replaced);
  }

  void _applySessionRefSuggestion(SessionRefSuggestion suggestion) {
    final current = _acTarget.text;
    final next = current.replaceFirst(
      RegExp(r'@session:[^\s]*$'),
      '@session:${suggestion.value} ',
    );
    _acSetText(next);
    setState(() => _sessionRefSuggestions = const []);
    _acFocus.requestFocus();
  }

  void _acceptCronSuggestion() {
    final phrase = _cronSuggestionPhrase;
    if (phrase == null) return;
    _acSetText('${context.l10n.cronSuggestionPrefix}${_composerCtrl.text}');
    setState(() => _cronSuggestionPhrase = null);
    _acFocus.requestFocus();
  }

  void _dismissCronSuggestion() {
    final phrase = _cronSuggestionPhrase;
    if (phrase == null) return;
    setState(() {
      _cronSuggestionDismissedFor = phrase;
      _cronSuggestionPhrase = null;
    });
  }

  Widget _buildCronSuggestionCard(String phrase) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: HermesGlassCard(
        radius: HermesRadius.card,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.event_repeat,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.chatCronSuggestion(phrase),
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: _acceptCronSuggestion,
              child: Text(context.l10n.chatCreateScheduledTask),
            ),
            IconButton(
              tooltip: context.l10n.commonIgnore,
              iconSize: 18,
              onPressed: _dismissCronSuggestion,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the suggestions card passed to [HermesComposer.suggestions].
  Widget? _buildSuggestions() {
    if (_slashSuggestions.isEmpty &&
        _pathSuggestions.isEmpty &&
        _sessionRefSuggestions.isEmpty &&
        !_slashSuggestionQueryActive) {
      return _cronSuggestionPhrase != null
          ? _buildCronSuggestionCard(_cronSuggestionPhrase!)
          : null;
    }
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(bottom: 6),
      child: HermesGlassCard(
        radius: HermesRadius.card,
        padding: EdgeInsets.zero,
        // ListTile paints its background/splash on the nearest Material
        // ancestor; the glass card is a DecoratedBox, so insert a transparent
        // Material to keep taps visible (and debug assertions quiet).
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              if (_slashSuggestionsLoading)
                ListTile(
                  key: ValueKey('slash-suggestions-loading'),
                  dense: true,
                  leading: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text(context.l10n.chatLoadingCommands),
                )
              else if (_slashSuggestions.isNotEmpty)
                for (var i = 0; i < _slashSuggestions.length; i++) ...[
                  if (_slashSuggestions[i].group?.isNotEmpty == true &&
                      (i == 0 ||
                          _slashSuggestions[i - 1].group !=
                              _slashSuggestions[i].group))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        _slashSuggestions[i].group == slashGroupSkills
                            ? context.l10n.slashGroupSkills
                            : _slashSuggestions[i].group == slashGroupCommands
                            ? context.l10n.slashGroupCommands
                            : _slashSuggestions[i].group!,
                        style: HermesType.onSurfaceVariant(
                          HermesType.caption,
                          theme,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ListTile(
                    key: ValueKey('slash-suggestion-$i'),
                    dense: true,
                    selected: i == _slashSuggestionIndex,
                    leading: Icon(
                      _slashSuggestions[i].group == slashGroupSkills
                          ? Icons.auto_awesome_outlined
                          : Icons.bolt,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      _slashSuggestions[i].display,
                      style: HermesType.onSurface(HermesType.body, theme),
                    ),
                    subtitle: _slashSuggestions[i].meta == null
                        ? null
                        : Text(
                            _slashSuggestions[i].meta!,
                            style: HermesType.onSurfaceVariant(
                              HermesType.caption,
                              theme,
                            ),
                          ),
                    onTap: () => _applySlashSuggestion(_slashSuggestions[i]),
                  ),
                ]
              else if (_slashSuggestionQueryActive)
                if (context.watch<CommandStore>().lastCompletionFailed)
                  ListTile(
                    key: ValueKey('slash-suggestions-failed'),
                    dense: true,
                    leading: Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(context.l10n.chatCommandSearchFailed),
                  )
                else
                  ListTile(
                    key: ValueKey('slash-suggestions-empty'),
                    dense: true,
                    leading: Icon(Icons.search_off_outlined, size: 18),
                    title: Text(context.l10n.chatNoMatchingCommands),
                    subtitle: Text(context.l10n.chatCommandSearchHint),
                  )
              else if (_sessionRefSuggestions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Text(context.l10n.chatSessions),
                ),
                for (final suggestion in _sessionRefSuggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.chat_bubble_outline, size: 18),
                    title: Text(suggestion.title),
                    subtitle: Text(suggestion.value),
                    onTap: () => _applySessionRefSuggestion(suggestion),
                  ),
              ] else
                for (final p in _pathSuggestions)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      p.isDirectory
                          ? Icons.folder_outlined
                          : Icons.insert_drive_file_outlined,
                      size: 18,
                      color: p.isDirectory
                          ? HermesSemantic.orange
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      p.name,
                      style: HermesType.onSurface(HermesType.body, theme),
                    ),
                    subtitle: Text(
                      p.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HermesType.onSurfaceVariant(
                        HermesType.caption,
                        theme,
                      ),
                    ),
                    onTap: () => _applyPathSuggestion(p),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleSuggestionKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final historyKey =
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!_slashSuggestionQueryActive &&
        _pathSuggestions.isEmpty &&
        historyKey) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          _composerCtrl.selection.baseOffset <= 0) {
        final previous = _composerHistory.previous();
        if (previous != null) {
          _composerCtrl.setCanonicalText(previous);
          _composerCtrl.selection = TextSelection.collapsed(
            offset: previous.length,
          );
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final next = _composerHistory.next();
        if (next != null) {
          _composerCtrl.setCanonicalText(next);
          _composerCtrl.selection = TextSelection.collapsed(
            offset: next.length,
          );
          return KeyEventResult.handled;
        }
      }
    }
    if (!_slashSuggestionQueryActive && _pathSuggestions.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _slashSuggestions = const [];
        _pathSuggestions = const [];
        _slashSuggestionQueryActive = false;
      });
      return KeyEventResult.handled;
    }
    if (_slashSuggestions.isEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          _composerCtrl.selection.baseOffset <= 0) {
        final previous = _composerHistory.previous();
        if (previous != null) {
          _composerCtrl.setCanonicalText(previous);
          _composerCtrl.selection = TextSelection.collapsed(
            offset: previous.length,
          );
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final delta = event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
      setState(() {
        _slashSuggestionIndex =
            (_slashSuggestionIndex + delta) % _slashSuggestions.length;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _applySlashSuggestion(_slashSuggestions[_slashSuggestionIndex]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------ session menu actions (3.3)
  Future<void> _toggleYolo() async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final next = !(_yoloEnabled ?? false);
    try {
      await session.setYoloMode(next);
      if (!mounted) return;
      setState(() => _yoloEnabled = next);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            next ? context.l10n.chatYoloEnabled : context.l10n.chatYoloDisabled,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatYoloToggleFailed('$e'))),
        );
      }
    }
  }

  Future<void> _showSteerDialog() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final text = await showAdaptiveFormDialog<String>(
      context: context,
      title: context.l10n.chatSteerMessage,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 4,
        decoration: InputDecoration(labelText: context.l10n.chatSteerHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
          child: Text(context.l10n.commonSend),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (text == null || text.isEmpty) return;
    try {
      await session.steer(text);
      messenger.showSnackBar(SnackBar(content: Text(l10n.chatSteerInjected)));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatSteerNowFailed('$e'))),
        );
      }
    }
  }

  Future<void> _showBackgroundDialog() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final text = await showAdaptiveFormDialog<String>(
      context: context,
      title: context.l10n.chatRunInBackground,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: context.l10n.chatBackgroundPrompt,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
          child: Text(context.l10n.commonSubmit),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (text == null || text.isEmpty) return;
    try {
      final taskId = await session.submitBackground(text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            taskId.isEmpty
                ? l10n.chatBackgroundSubmitted
                : l10n.chatBackgroundSubmittedWithId(taskId),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatBackgroundSubmitFailed('$e')),
          ),
        );
      }
    }
  }

  Future<void> _branchFromHere([ChatMessage? atMessage]) async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final newId = await session.branchSession(atMessageId: atMessage?.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            newId.isEmpty
                ? context.l10n.chatBranchCreated
                : context.l10n.chatBranchCreatedWithId(newId),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatBranchFailed('$e'))),
        );
      }
    }
  }

  Future<void> _showHandoffDialog() async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final api = session.api;
    final runtimeId = session.runtimeId;
    final sessionId = session.durableId;
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatServerNotConnected)),
      );
      return;
    }

    List<MessagingPlatform> platforms;
    try {
      platforms = (await api.messagingPlatforms(
        profile: session.profile ?? session.activeProfile,
      )).where((platform) => platform.canHandoff).toList(growable: false);
    } catch (error) {
      if (mounted && identical(api, session.api)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatHandoffPlatformsFailed('$error')),
          ),
        );
      }
      return;
    }
    if (!mounted ||
        !identical(api, session.api) ||
        runtimeId != session.runtimeId ||
        sessionId != session.durableId) {
      return;
    }

    if (platforms.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.chatNoHandoffPlatforms),
          content: Text(context.l10n.chatNoHandoffPlatformsDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonGotIt),
            ),
          ],
        ),
      );
      return;
    }

    final picked = await showDialog<MessagingPlatform>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.l10n.chatHandoffToPlatform),
        children: [
          for (final platform in platforms)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(platform),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.forum_outlined),
                title: Text(platform.displayName),
                subtitle: Text(
                  platform.homeChannelName?.isNotEmpty == true
                      ? context.l10n.chatHomeChannel(platform.homeChannelName!)
                      : context.l10n.chatHomeChannelNotSet,
                ),
                trailing: platform.gatewayRunning
                    ? const Icon(
                        Icons.circle,
                        size: 10,
                        color: HermesSemantic.green,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (!identical(api, session.api) ||
        runtimeId != session.runtimeId ||
        sessionId != session.durableId) {
      return;
    }

    final progress = ValueNotifier<String>('pending');
    var cancelled = false;
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(context.l10n.chatHandingOffTo(picked.displayName)),
          content: ValueListenableBuilder<String>(
            valueListenable: progress,
            builder: (_, state, _) => Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: HermesSpacing.md),
                Expanded(child: Text(_handoffStateLabel(state))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.of(ctx).pop();
              },
              child: Text(context.l10n.commonCancel),
            ),
          ],
        ),
      ),
    );

    HandoffResult? result;
    try {
      result = await session
          .handoff(picked.name, onProgress: (state) => progress.value = state)
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      result = null;
    } catch (_) {
      result = null;
    }
    if (mounted && !cancelled) Navigator.of(context, rootNavigator: true).pop();
    await dialog;
    progress.dispose();
    if (!mounted ||
        cancelled ||
        !identical(api, session.api) ||
        runtimeId != session.runtimeId ||
        sessionId != session.durableId) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result != null && result.ok
              ? context.l10n.chatHandoffCompletedTo(picked.displayName)
              : context.l10n.chatHandoffFailed(
                  result?.error ?? context.l10n.chatHandoffTimeout,
                ),
        ),
      ),
    );
  }

  String _handoffStateLabel(String state) => switch (state) {
    'running' => context.l10n.chatHandoffGatewayRunning,
    'completed' => context.l10n.chatHandoffCompleted,
    'failed' => context.l10n.chatHandoffFailedStatus,
    _ => context.l10n.chatHandoffWaiting,
  };

  Future<void> _showContextPopover(BuildContext anchorContext) async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final usage = await _loadContextUsage(session);
    if (!mounted || !anchorContext.mounted) return;
    if (usage != null) {
      setState(() => _contextUsagePercent = usage.percent);
    }

    final anchor = anchorContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject()! as RenderBox;
    final anchorRect = Rect.fromPoints(
      anchor.localToGlobal(Offset.zero, ancestor: overlay),
      anchor.localToGlobal(
        anchor.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final selected = await showMenu<String>(
      context: anchorContext,
      position: RelativeRect.fromRect(anchorRect, Offset.zero & overlay.size),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.chatContextUsage,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    usage == null
                        ? context.l10n.chatNoContextData
                        : '${usage.percent.round()}% of ${_formatContextLimit(usage.max)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (usage != null && usage.categories.isEmpty) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (usage.percent / 100).clamp(0, 1),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                  if (usage != null && usage.categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ContextUsageBreakdown(categories: usage.categories),
                  ],
                ],
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'compress',
          enabled: !session.readOnly,
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.compress, size: 18),
                const SizedBox(width: 10),
                Text(
                  context.l10n.chatCompressContext,
                  style: TextStyle(
                    color: session.readOnly
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    if (selected != 'compress' || !mounted) return;

    try {
      await session.compress();
      await session.refreshTranscript();
      final refreshed = await _loadContextUsage(session);
      if (!mounted) return;
      setState(() => _contextUsagePercent = refreshed?.percent);
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatCompressionRequested)),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatCompressionFailed('$error'))),
      );
    }
  }

  Future<ContextUsageSnapshot?> _loadContextUsage(SessionStore session) async {
    final breakdown = _contextUsageValues(await session.contextBreakdown());
    if (breakdown != null) return breakdown;
    return _contextUsageValues(await session.usage());
  }

  static ContextUsageSnapshot? _contextUsageValues(
    Map<String, dynamic> payload,
  ) {
    Map<String, dynamic> values = payload;
    for (final key in const ['usage', 'context', 'data', 'result']) {
      final nested = values[key];
      if (nested is Map) values = nested.cast<String, dynamic>();
      if (values.containsKey('context_max')) break;
    }
    double? number(String key) {
      final value = values[key];
      return value is num ? value.toDouble() : double.tryParse('$value');
    }

    final used = number('context_used');
    final max = number('context_max');
    var percent = number('context_percent');
    if (used == null || max == null || max <= 0) return null;
    percent ??= used / max * 100;
    final rawCategories = values['categories'];
    final categories = rawCategories is List
        ? rawCategories
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .where((e) => ((e['tokens'] as num?) ?? 0) > 0)
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return ContextUsageSnapshot(
      used: used,
      max: max,
      percent: percent,
      categories: categories,
    );
  }

  static String _formatContextLimit(double tokens) {
    if (tokens >= 1000000) return '${tokens / 1000000}M';
    if (tokens >= 1000) {
      final value = tokens / 1000;
      return '${value == value.roundToDouble() ? value.round() : value.toStringAsFixed(1)}K';
    }
    return tokens.round().toString();
  }

  // ----------------------------------------------------- inline editing
  /// WebUI `editMessage` parity (ui.js:18598): the bubble under edit becomes
  /// an in-place textarea inside the message list.
  /// Debounced slash / @path / @session completion for the inline edit field
  /// (F1 — the edit position gets the same completions as the main composer).
  void _onEditChanged() {
    _acDebounce?.cancel();
    final text = _editCtrl.text;
    if (text.isEmpty) {
      if (_slashSuggestions.isNotEmpty ||
          _pathSuggestions.isNotEmpty ||
          _sessionRefSuggestions.isNotEmpty ||
          _slashSuggestionQueryActive) {
        setState(() {
          _slashSuggestions = const [];
          _pathSuggestions = const [];
          _sessionRefSuggestions = const [];
          _slashSuggestionQueryActive = false;
          _slashSuggestionsLoading = false;
        });
      }
      return;
    }
    _acDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _refreshSuggestions(text),
    );
  }

  void _startInlineEdit(ChatMessage message) {
    _acTargetOverride = _editCtrl;
    _editCtrl.addListener(_onEditChanged);
    setState(() {
      _editingMessageId = message.id;
      _editCtrl.text = message.fullText;
      _editCtrl.selection = TextSelection.collapsed(
        offset: message.fullText.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _editingMessageId != message.id) return;
      // Scroll the row into view (no locator highlight — this is an edit,
      // not a search hit) and focus the editor.
      final target = _keyForMessage(message).currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: HermesMotion.deliberate,
          curve: Curves.easeOutCubic,
          alignment: 0.3,
        );
      }
      _editFocus.requestFocus();
    });
  }

  void _endInlineEdit() {
    _acDebounce?.cancel();
    _editCtrl.removeListener(_onEditChanged);
    _acTargetOverride = null;
    _editCtrl.clear();
    _editAttachments = const [];
    _editFocus.unfocus();
    final hadSuggestions =
        _slashSuggestions.isNotEmpty ||
        _pathSuggestions.isNotEmpty ||
        _sessionRefSuggestions.isNotEmpty;
    if (_editingMessageId == null && !hadSuggestions) return;
    setState(() {
      _editingMessageId = null;
      _slashSuggestions = const [];
      _pathSuggestions = const [];
      _sessionRefSuggestions = const [];
      _slashSuggestionQueryActive = false;
    });
  }

  void _cancelInlineEdit() {
    if (_editingMessageId == null) return;
    _endInlineEdit();
  }

  /// True when [messageId] is followed by at least one later transcript row
  /// (assistant reply, tool call, or another user turn). Editing then truncates.
  bool _hasSubsequentTurns(List<ChatMessage> messages, String messageId) {
    final index = messages.indexWhere((m) => m.id == messageId);
    return index >= 0 && index < messages.length - 1;
  }

  /// Shared truncate warning used by edit-submit and restore-to-message.
  Future<bool> _confirmTruncateResubmit({
    required String title,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(context.l10n.chatTruncateWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Confirm: re-send through the existing real rewind/edit chain
  /// (`SessionStore.editMessage` → truncate + resubmit).
  /// Keeps the in-place editor + draft open until the gateway call succeeds.
  Future<void> _submitInlineEdit(ChatMessage message) async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    var text = _editCtrl.text.trim();
    if (text.isEmpty && _editAttachments.isEmpty) {
      _cancelInlineEdit();
      return;
    }
    // F1: fold any staged attachments into the edited text, like the main
    // composer's send path.
    if (_editAttachments.isNotEmpty) {
      text = (await _composeWithAttachments(text, _editAttachments)).trim();
    }
    if (text == message.fullText.trim()) {
      _cancelInlineEdit();
      return;
    }
    if (_hasSubsequentTurns(session.chat.messages, message.id)) {
      final ok = await _confirmTruncateResubmit(
        title: l10n.chatSendEditTitle,
        confirmLabel: l10n.chatSendEditAndRerun,
      );
      if (!ok || !mounted) return;
    }
    try {
      await session.editMessage(message, text);
      if (!mounted) return;
      _endInlineEdit();
    } catch (e) {
      if (!mounted) return;
      // Failure path: transcript is restored by SessionStore; keep the
      // editor open with the user's draft so they can retry or cancel.
      if (_editingMessageId != message.id) {
        setState(() {
          _editingMessageId = message.id;
          _editCtrl.text = text;
          _editCtrl.selection = TextSelection.collapsed(offset: text.length);
        });
      } else if (_editCtrl.text.trim() != text) {
        _editCtrl.text = text;
        _editCtrl.selection = TextSelection.collapsed(offset: text.length);
      }
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatEditFailed('$e'))),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _editingMessageId != message.id) return;
        _editFocus.requestFocus();
      });
    }
  }

  Future<void> _confirmRestoreMessage(ChatMessage message) async {
    final confirmed = await _confirmTruncateResubmit(
      title: context.l10n.chatRestoreToMessageTitle,
      confirmLabel: context.l10n.chatRestoreAndRerun,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<SessionStore>().restoreToMessage(message);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatRestoreFailed('$error'))),
        );
      }
    }
  }

  /// "恢复此版本" from the per-turn version picker: re-send the previewed
  /// version's prompt through the rewind chain (which snapshots the current
  /// live tail as its own version, so the navigation stays reversible).
  Future<void> _restorePreviewedVersion() async {
    final chat = context.read<ChatStore>();
    final text = chat.previewedVersionText();
    final anchor = chat.previewedAnchorLiveMessage();
    if (text == null || anchor == null) return;
    final confirmed = await _confirmTruncateResubmit(
      title: context.l10n.chatRestoreVersionTitle,
      confirmLabel: context.l10n.chatRestoreAndRerun,
    );
    if (!confirmed || !mounted) return;
    chat.clearVersionPreview();
    try {
      await context.read<SessionStore>().resendTurn(anchor, text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatRestoreFailed('$error'))),
        );
      }
    }
  }

  // ------------------------------------------------------------ attachments
  static const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

  bool _isImageName(String name) =>
      _imageExts.contains(_extOf(name).toLowerCase());

  /// Stage picked/dropped files into the attachment tray (WebUI
  /// `S.pendingFiles` semantics — upload happens at send time).
  void _stageAttachments(List<ComposerAttachment> staged) {
    if (staged.isEmpty || !mounted) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    final normalized = <ComposerAttachment>[
      for (var index = 0; index < staged.length; index++)
        staged[index].occurrenceId != null
            ? staged[index]
            : staged[index].copyWith(occurrenceId: 'attachment-$now-$index'),
    ];
    setState(() => _attachments = [..._attachments, ...normalized]);
    final sid = _lastDraftSid;
    if (sid != null && !_draftRestoreInProgress) {
      context.read<SessionStore>().scheduleDraftSave(
        sid,
        _composerCtrl.text,
        _attachmentsForPersist,
      );
    }
  }

  Future<ComposerAttachment?> _attachmentForFile(XFile file) async {
    final name = file.name.isNotEmpty
        ? file.name
        : _workspaceBaseName(file.path);
    try {
      if (await file.length() > _maxUploadBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.chatFileTooLarge(
                  _maxUploadBytes ~/ 1024 ~/ 1024,
                  name,
                ),
              ),
            ),
          );
        }
        return null;
      }
    } catch (_) {
      // Length probe failed (e.g. web stream) — let the upload path decide.
    }
    return ComposerAttachment(
      kind: _isImageName(name)
          ? ComposerAttachmentKind.image
          : ComposerAttachmentKind.file,
      label: name,
      localPath: file.path,
    );
  }

  /// Gallery image → staged tray chip (uploaded at send time, then sent as an
  /// inline `@image:path` reference — same ref format the gateway consumes).
  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final att = await _attachmentForFile(file);
      if (att != null) _stageAttachments([att]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatAddImageFailed('$e'))),
        );
      }
    }
  }

  /// F1: attach an image while inline-editing a message.
  Future<void> _pickImageForEdit() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final att = await _attachmentForFile(file);
      if (att != null && mounted) {
        setState(() => _editAttachments = [..._editAttachments, att]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatAddImageFailed('$e'))),
        );
      }
    }
  }

  /// Arbitrary files (WebUI A2 parity) via the platform file selector.
  Future<void> _pickFilesToTray() async {
    try {
      final files = await fs.openFiles();
      if (files.isEmpty) return;
      final staged = <ComposerAttachment>[];
      for (final file in files) {
        final att = await _attachmentForFile(file);
        if (att != null) staged.add(att);
      }
      _stageAttachments(staged);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatSelectFilesFailed('$e'))),
        );
      }
    }
  }

  /// Folder attach: desktop directory picker, mobile falls back to multi-file.
  Future<void> _pickFolderToTray() async {
    try {
      String? dirPath;
      try {
        dirPath = await fs.getDirectoryPath(
          confirmButtonText: context.l10n.chatSelectFolder,
        );
      } catch (_) {
        dirPath = null;
      }
      if (dirPath == null || dirPath.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.chatFolderPickerUnavailable)),
          );
        }
        await _pickFilesToTray();
        return;
      }
      final listed = await listFolderFiles(
        dirPath,
        maxFileBytes: _maxUploadBytes,
      );
      if (listed.files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                listed.warning ?? context.l10n.chatNoUploadableFolderFiles,
              ),
            ),
          );
        }
        return;
      }
      final staged = <ComposerAttachment>[];
      for (final entry in listed.files) {
        final att = await _attachmentForFile(XFile(entry.path));
        if (att != null) staged.add(att);
      }
      _stageAttachments(staged);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.chatFolderFilesAttached(staged.length, listed.skipped),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatSelectFolderFailed('$e'))),
        );
      }
    }
  }

  /// Desktop drag-and-drop into the composer area (desktop_drop).
  Future<void> _onDropFiles(DropDoneDetails details) async {
    if (details.files.isEmpty) return;
    final staged = <ComposerAttachment>[];
    for (final file in details.files) {
      final att = await _attachmentForFile(file);
      if (att != null) staged.add(att);
    }
    _stageAttachments(staged);
  }

  /// URL chip in the tray (text `@url:` refs are composed at send time).
  Future<void> _addUrlAttachment() async {
    final url = await _promptForUrl();
    if (url == null || url.isEmpty) return;
    _stageAttachments([
      ComposerAttachment(
        kind: ComposerAttachmentKind.url,
        label: Uri.tryParse(url)?.host.isNotEmpty == true
            ? Uri.parse(url).host
            : url,
        url: url,
      ),
    ]);
  }

  /// Snippet chip: real multiline text appended to the message at send time.
  Future<void> _addSnippetAttachment() async {
    final ctrl = TextEditingController();
    final snippet = await showAdaptiveFormDialog<String>(
      context: context,
      title: context.l10n.chatTextSnippet,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(
          hintText: context.l10n.chatTextSnippetHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final v = ctrl.text.trim();
            Navigator.of(context).pop(v.isEmpty ? null : v);
          },
          child: Text(context.l10n.chatAttach),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (snippet == null || snippet.isEmpty) return;
    final firstLine = snippet.split('\n').first;
    _stageAttachments([
      ComposerAttachment(
        kind: ComposerAttachmentKind.snippet,
        label: firstLine.length > 24
            ? '${firstLine.substring(0, 24)}…'
            : firstLine,
        snippetText: snippet,
      ),
    ]);
  }

  String _extOf(String name) {
    final i = name.lastIndexOf('.');
    return i >= 0 ? name.substring(i + 1) : 'jpg';
  }

  // -------------------------------------------------------- URL attachment
  Future<String?> _promptForUrl() async {
    final ctrl = TextEditingController();
    final result = await showAdaptiveFormDialog<String>(
      context: context,
      title: context.l10n.chatAttachLink,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.l10n.commonUrl,
          hintText: 'https://example.com/article.pdf',
          prefixIcon: const Icon(Icons.link_outlined),
        ),
        keyboardType: TextInputType.url,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final v = ctrl.text.trim();
            Navigator.of(context).pop(v.isEmpty ? null : v);
          },
          child: Text(context.l10n.chatAttach),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    return result;
  }

  // ------------------------------------------------------------- voice
  /// WebUI parity (boot.js mic button): the transcript lands in the composer
  /// as editable text; nothing is sent until the user hits send.
  Future<void> _toggleRecording() async {
    final voice = context.read<VoiceStore>();
    final session = context.read<SessionStore>();
    final chat = context.read<ChatStore>();
    if (voice.speaking || voice.streamingSpeechId != null) {
      await voice.stopSpeaking();
      if (chat.busy) await session.interrupt();
    }
    final text = await voice.recordAndTranscribe();
    if (text == null || text.trim().isEmpty || !mounted) return;
    final current = _composerCtrl.text;
    final needsSpace = current.isNotEmpty && !RegExp(r'\s$').hasMatch(current);
    setState(() {
      _composerCtrl.text = '$current${needsSpace ? ' ' : ''}$text';
      _composerCtrl.selection = TextSelection.collapsed(
        offset: _composerCtrl.text.length,
      );
    });
    if (voice.continuousConversation && !context.read<ChatStore>().busy) {
      voice.markWaiting();
      await _send(_composerCtrl.text);
    }
  }

  Future<void> _handleWakeDetection() async {
    final voice = context.read<VoiceStore>();
    final detection = voice.takeWakeDetection();
    if (detection == null) return;
    final session = context.read<SessionStore>();
    try {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
      final targetProfile = detection.profile?.trim();
      if (targetProfile != null &&
          targetProfile.isNotEmpty &&
          targetProfile != session.activeProfile) {
        await session.switchActiveProfile(targetProfile);
      }
      if (detection.startNewSession || session.runtimeId == null) {
        await session.newChat();
      }
      final route = session.owner?.route;
      await voice.bindConversationScope(
        '${route?.connectionId.value ?? 'active'}|'
        '${route?.profile ?? session.activeProfile ?? ''}|'
        '${session.durableId ?? ''}',
      );
      if (!voice.continuousConversation) {
        voice.toggleContinuousConversation();
      }
      await _toggleRecording();
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.chatWakeVoiceFailed('$error'),
        );
      }
      if (voice.continuousConversation) {
        // Disabling continuous conversation already resumes wake listening
        // (VoiceStore.toggleContinuousConversation).
        voice.toggleContinuousConversation();
      } else {
        // The wake.detected handler paused listening before this method ran;
        // if we never got far enough to hand off into a voice session (e.g.
        // switchActiveProfile/newChat failed), nothing else resumes it.
        unawaited(voice.wakeWord?.resumeAfterVoice());
      }
    }
  }

  void _toggleContinuousVoice() {
    final voice = context.read<VoiceStore>();
    if (!voice.continuousConversation) {
      _continuousHandledReplyId = context
          .read<ChatStore>()
          .lastCompletedAssistant()
          ?.id;
    }
    voice.toggleContinuousConversation();
  }

  void _scheduleContinuousVoice(ChatStore chat, VoiceStore voice) {
    final streaming = chat.streamingMessage;
    if (voice.continuousConversation && streaming != null) {
      voice.appendStreamingSpeech(streaming.id, streaming.fullText);
    }
    if (chat.busy || chat.isStreaming) return;
    final reply = chat.lastCompletedAssistant();
    if (reply == null) return;
    // Auto-speak is independent from continuous conversation. Mark before
    // scheduling so rebuilds cannot enqueue the same reply more than once.
    if (voice.autoSpeak &&
        !voice.continuousConversation &&
        _autoSpokenReplyId != reply.id) {
      _autoSpokenReplyId = reply.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !chat.busy && !chat.isStreaming) {
          unawaited(voice.speak(reply.fullText));
        }
      });
    }
    if (!voice.continuousConversation ||
        reply.id == _continuousHandledReplyId ||
        _continuousAdvanceScheduled) {
      return;
    }
    _continuousAdvanceScheduled = true;
    _continuousHandledReplyId = reply.id;
    final generation = voice.generation;
    final sessionId = context.read<SessionStore>().durableId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted ||
            !voice.continuousConversation ||
            voice.generation != generation ||
            context.read<SessionStore>().durableId != sessionId) {
          return;
        }
        if (voice.streamingSpeechId == reply.id) {
          await voice.finishStreamingSpeech(reply.id, reply.fullText);
        } else {
          await voice.speak(reply.fullText);
        }
        if (!mounted ||
            !voice.continuousConversation ||
            voice.generation != generation ||
            context.read<SessionStore>().durableId != sessionId) {
          return;
        }
        // Rearm through the same path as a user mic action so the recognized
        // utterance is inserted and submitted instead of being discarded.
        await _toggleRecording();
      } finally {
        _continuousAdvanceScheduled = false;
      }
    });
  }

  Future<void> _speakLastReply() async {
    final chat = context.read<ChatStore>();
    final voice = context.read<VoiceStore>();
    // E3: only completed assistant messages.
    final last = chat.lastCompletedAssistant();
    if (last == null) return;
    final text = last.fullText;
    if (text.trim().isEmpty) return;
    await voice.speak(text);
  }

  // ------------------------------------------------------------- model picker
  Future<void> _showModelPicker() async {
    final session = context.read<SessionStore>();
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final runtimeId = session.runtimeId;
    ModelCatalog catalog;
    try {
      catalog = await api.modelCatalog();
    } catch (e) {
      if (mounted && identical(api, session.api)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatModelsLoadFailed('$e'))),
        );
      }
      return;
    }
    if (!mounted ||
        !identical(api, session.api) ||
        runtimeId != session.runtimeId) {
      return;
    }
    final info = session.info;
    final currentProvider = info?.provider?.trim() ?? '';
    final currentModel = info?.model?.trim() ?? '';
    if (currentProvider.isNotEmpty && currentModel.isNotEmpty) {
      catalog = catalog.copyWithCurrent(
        currentProvider: currentProvider,
        currentModel: currentModel,
      );
    }
    final preferences = await SharedPreferences.getInstance();
    if (!mounted ||
        !identical(api, session.api) ||
        runtimeId != session.runtimeId) {
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (_) => ModelPickerSheet(
        api: api,
        initialCatalog: catalog,
        visibilityStore: ModelVisibilityStore(preferences),
      ),
    );
    if (selected == null) return;
    if (!mounted ||
        !identical(api, session.api) ||
        runtimeId != session.runtimeId) {
      return;
    }
    final idx = selected.indexOf('|');
    final provider = idx < 0 ? selected : selected.substring(0, idx);
    final model = idx < 0 ? selected : selected.substring(idx + 1);
    try {
      final result = await session.switchCurrentModel(provider, model);
      if (!mounted ||
          !identical(api, session.api) ||
          runtimeId != session.runtimeId) {
        return;
      }
      final applied = result['applied']?.toString() ?? 'now';
      if (applied == 'deferred') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatModelSwitchDeferred)),
        );
      }
    } catch (e) {
      if (mounted &&
          identical(api, session.api) &&
          runtimeId == session.runtimeId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatModelSwitchFailed('$e'))),
        );
      }
    }
  }

  // ---------------------------------------------------------- session menu
  void _showSessionInfo() {
    final session = context.read<SessionStore>();
    final info = session.info;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.chatSessionInfo,
                style: HermesType.onSurface(
                  HermesType.headline,
                  Theme.of(context),
                ),
              ),
              const SizedBox(height: 12),
              _infoRow(
                context.l10n.commonTitle,
                info?.title ?? context.l10n.chatUntitled,
              ),
              _infoRow(context.l10n.chatModel, info?.model ?? '—'),
              _infoRow(context.l10n.chatProvider, info?.provider ?? '—'),
              _infoRow(context.l10n.chatWorkingDirectory, info?.cwd ?? '—'),
              const SizedBox(height: 8),
              Row(
                children: [
                  HermesAgentStatusView(
                    status: info?.running == true
                        ? HermesAgentStatus.running
                        : HermesAgentStatus.idle,
                    showLabel: true,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(context.l10n.commonClose),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
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

  Future<void> _renameSession() async {
    final session = context.read<SessionStore>();
    final ctrl = TextEditingController(text: session.info?.title ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.chatRenameSession),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.commonTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              await session.rename(ctrl.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  }

  // ------------------------------------------------ AppBar session more menu
  /// C11/C12 parity: title regeneration + copy session ID / link. Entries
  /// that need a durable session are disabled for a fresh, never-sent chat.
  Widget _buildSessionMoreMenu(SessionStore session) {
    final hasDurable = session.durableId != null;
    final supportsSharing = session.api?.supportsSessionSharing ?? false;
    return PopupMenuButton<String>(
      tooltip: context.l10n.chatSessionMenu,
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'workspace':
            _showWorkspacePicker();
          case 'regen_title':
            _regenerateTitle();
          case 'copy_id':
            _copySessionId();
          case 'copy_link':
            _copySessionLink();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'workspace',
          enabled: hasDurable && !session.readOnly,
          child: ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: Text(context.l10n.chatChangeWorkspace),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'regen_title',
          enabled: hasDurable && !session.readOnly,
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(context.l10n.chatRegenerateTitle),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'copy_id',
          enabled: hasDurable,
          child: ListTile(
            leading: const Icon(Icons.content_copy_outlined),
            title: Text(context.l10n.chatCopySessionId),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        if (supportsSharing)
          PopupMenuItem(
            value: 'copy_link',
            enabled: hasDurable,
            child: ListTile(
              leading: const Icon(Icons.link_outlined),
              title: Text(context.l10n.chatCopySessionLink),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
      ],
    );
  }

  Future<void> _regenerateTitle() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final title = await session.regenerateCurrentTitle();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            title.isEmpty
                ? l10n.chatTitleUnchanged
                : l10n.chatTitleUpdated(title),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatRegenerateTitleFailed('$e'))),
        );
      }
    }
  }

  Future<void> _copySessionId() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final sid = session.durableId;
    if (sid == null) return;
    await copyTextOrNotify(
      context,
      sid,
      successMessage: l10n.chatSessionIdCopied,
    );
  }

  /// Copy a browser-openable immutable share URL served by Mobile Server.
  /// Unlike the desktop-only `/session/{id}` route, `/share/{token}` is
  /// actually reachable from the phone/LAN browser.
  Future<void> _copySessionLink() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    final sid = session.durableId;
    final runtimeId = session.runtimeId;
    if (sid == null) return;
    final api = session.api;
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatServerNotConnected)),
      );
      return;
    }
    try {
      final url = await session.createStoredSessionShare(sid);
      if (url.isEmpty) throw StateError(l10n.chatShareUrlMissing);
      if (!mounted ||
          !identical(api, session.api) ||
          runtimeId != session.runtimeId ||
          sid != session.durableId) {
        return;
      }
      await copyTextOrNotify(
        context,
        url,
        successMessage: l10n.chatSessionShareLinkCopied,
      );
    } catch (error) {
      if (mounted &&
          identical(api, session.api) &&
          runtimeId == session.runtimeId &&
          sid == session.durableId) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatShareLinkFailed('$error'))),
        );
      }
    }
  }

  // ---------------------------------------------------------- message menu
  /// Desktop parity: inline assistant-footer regenerate action.
  Future<void> _regenerateFromFooter(ChatMessage message) async {
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await session.reloadFromMessage(message);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatRegenerateFailed('$e'))),
        );
      }
    }
  }

  /// Insert a quoted reference to [message] into the composer (mobile
  /// swipe-to-reply gesture).
  void _quoteMessage(ChatMessage message) {
    final text = message.plainText.trim();
    if (text.isEmpty) return;
    final quoted = text.split('\n').map((line) => '> $line').join('\n');
    final current = _composerCtrl.text;
    final next = current.isEmpty ? '$quoted\n\n' : '$current\n\n$quoted\n\n';
    _composerCtrl.setCanonicalText(
      next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _composerFocus.requestFocus();
  }

  void _insertStarterPrompt(String prompt) {
    _composerCtrl.setCanonicalText(
      prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
    _composerFocus.requestFocus();
  }

  void _showMessageMenu(ChatMessage message) {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(context.l10n.chatCopyText),
              onTap: () {
                Navigator.of(ctx).pop();
                // Desktop parity: "Copy text" strips markdown syntax.
                final text = message.plainText;
                if (text.isEmpty) return;
                copyTextOrNotify(
                  context,
                  text,
                  successMessage: context.l10n.commonCopied,
                );
              },
            ),
            ListTile(
              leading: Icon(
                _markedMessageIds.contains(_messageMarkerId(message))
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined,
              ),
              title: Text(
                _markedMessageIds.contains(_messageMarkerId(message))
                    ? context.l10n.chatUnmarkMessage
                    : context.l10n.chatMarkMessage,
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _toggleMessageMarker(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.data_object_outlined),
              title: Text(context.l10n.chatCopyAsMarkdown),
              onTap: () {
                Navigator.of(ctx).pop();
                final text = message.fullText;
                if (text.isEmpty) return;
                copyTextOrNotify(
                  context,
                  text,
                  successMessage: context.l10n.chatMarkdownCopied,
                );
              },
            ),
            if (!session.readOnly && message.role == 'assistant')
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(context.l10n.chatRegenerate),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await session.reloadFromMessage(message);
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.chatRegenerateFailed('$e'),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            if (!session.readOnly &&
                message.role == 'assistant' &&
                message.isError &&
                message.errorSurface?.retryable != false)
              ListTile(
                leading: const Icon(Icons.replay),
                title: Text(context.l10n.commonRetry),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await session.reloadFromMessage(message);
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.chatRetryFailed('$e')),
                        ),
                      );
                    }
                  }
                },
              ),
            if (!session.readOnly &&
                (message.role == 'user' || message.role == 'assistant') &&
                message.fullText.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.call_split),
                title: Text(context.l10n.chatBranchInNewSession),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final newId = await session.branchSession(
                      atMessageId: message.id,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          newId.isEmpty
                              ? l10n.chatBranchedHere
                              : l10n.chatBranchedWithId(newId),
                        ),
                      ),
                    );
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.chatBranchFailed('$e')),
                        ),
                      );
                    }
                  }
                },
              ),
            if (!session.readOnly && message.role == 'user') ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.commonEdit),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // WebUI .msg-edit-area: swap the bubble for an in-place
                  // editor instead of opening a dialog.
                  _startInlineEdit(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text(context.l10n.chatRestoreToMessage),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmRestoreMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connection = context.watch<ConnectionStore>();
    final session = context.watch<SessionStore>();
    final chat = context.read<ChatStore>();
    final voice = context.watch<VoiceStore>();
    _sessionStoreRef = session;
    final toolDismiss = context.maybeRead<ToolDismissStore>();
    if (toolDismiss != null) {
      unawaited(toolDismiss.bindSession(session.durableId));
    }

    _locateInitialSearchHit(chat);
    _scheduleContinuousVoice(chat, voice);
    if (voice.wakeDetection != null && !_wakeHandling) {
      _wakeHandling = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (mounted) await _handleWakeDetection();
        } finally {
          _wakeHandling = false;
        }
      });
    }

    // ── Draft session lifecycle: durable id transitions. ──
    final sid = session.durableId ?? '';
    if (_scrollCoordinator.enterSession(sid)) {
      _mountedUserMessageIds.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setStuckToBottom(true);
        _activeTopic.value = null;
      });
      if (_diagnosticLogging) {
        _logScroll(
          'event=session.enter session_id=$sid message_count=${chat.messages.length} '
          'streaming=${chat.isStreaming} busy=${chat.busy}',
        );
      }
      _scrollToBottom(force: true);
    }
    if (sid.isNotEmpty && sid != _lastDraftSid && !_sessionChangeScheduled) {
      _sessionChangeScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await _onSessionChanged(session, sid);
        } finally {
          _sessionChangeScheduled = false;
        }
      });
    }

    // Auto-scroll is driven by [_ChatTranscriptPanel] transcript callbacks.

    final viewportWidth = MediaQuery.of(context).size.width;
    final screenWidth = widget.embedded
        ? viewportWidth.clamp(0, HermesBreakpoints.navigation - 1).toDouble()
        : viewportWidth;
    final isPhone = screenWidth < HermesBreakpoints.navigation;
    final hasSessionRail =
        !widget.embedded && screenWidth >= HermesBreakpoints.navigation;
    const railWidth = 220.0;
    const sidebarWidth = 280.0;
    final useThreePane =
        !widget.embedded &&
        hermesCanUseThreePaneChat(
          screenWidth,
          sessionRailWidth: railWidth,
          contextRailWidth: sidebarWidth,
        );
    final info = session.info;
    final hasModel = info?.model != null && info!.model!.isNotEmpty;
    final hasProvider = info?.provider != null && info!.provider!.isNotEmpty;
    final hasBranch = info?.branch != null && info!.branch!.isNotEmpty;
    final statusText = switch (connection.phase) {
      ConnectionPhase.connected => context.l10n.commonConnected,
      ConnectionPhase.connecting => context.l10n.chatConnecting,
      ConnectionPhase.reconnecting => context.l10n.chatReconnecting,
      ConnectionPhase.exhausted => context.l10n.chatConnectionFailed,
      ConnectionPhase.disconnected =>
        connection.isConfigured
            ? context.l10n.commonDisconnected
            : context.l10n.chatNotConfigured,
    };
    final providerVal = info?.provider;
    final modelVal = info?.model;
    final subtitleParts = <String>[
      if (hasProvider) providerVal!,
      if (hasModel) modelVal!,
      statusText,
    ];
    final branch = info?.branch;
    final branchChip = (hasBranch && branch != null)
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.call_split,
                  size: 11,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  branch,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        : null;

    final appBar = AppBar(
      automaticallyImplyLeading: !widget.embedded && !hasSessionRail,
      leading: hasSessionRail ? const ChatPageBackButton() : null,
      title: hasSessionRail
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        info?.title?.isNotEmpty == true
                            ? info!.title!
                            : context.l10n.chatTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (branchChip != null) ...[
                      const SizedBox(width: 8),
                      branchChip,
                    ],
                  ],
                ),
                if (!isPhone) const SizedBox(height: 2),
                if (!isPhone)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitleParts.join(' · '),
                          style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            )
          : GestureDetector(
              onTap: () => _showSessionInfo(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          info?.title?.isNotEmpty == true
                              ? info!.title!
                              : context.l10n.chatTitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (branchChip != null) ...[
                        const SizedBox(width: 8),
                        branchChip,
                      ],
                    ],
                  ),
                  if (!isPhone) const SizedBox(height: 2),
                  if (!isPhone)
                    Row(
                      children: [
                        Icon(
                          connection.isConnected
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 8,
                          color: connection.isConnected
                              ? HermesSemantic.green
                              : HermesSemantic.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
      actions: [
        IconButton(
          tooltip: context.l10n.chatFindInConversation,
          icon: Icon(_findOpen ? Icons.search_off : Icons.search),
          onPressed: _toggleFind,
        ),
        if (hasSessionRail)
          IconButton(
            tooltip: context.l10n.chatHistoryLocator,
            icon: const Icon(Icons.travel_explore_outlined),
            onPressed: () => _showHistoryLocator(chat),
          ),
        // A12: phone layouts have no persistent right rail — this opens the
        // workspace file panel as an end drawer. Tablets keep the 3-column
        // layout, so no entry is shown there.
        if (!useThreePane)
          IconButton(
            tooltip: context.l10n.chatWorkspaceFiles,
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        _buildSessionMoreMenu(session),
      ],
    );

    final chatBody = Column(
      children: [
        if (_findOpen)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _findCtrl,
                      focusNode: _findFocus,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: context.l10n.chatFindHint,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (_) {
                        _findIndex = -1;
                        _stepFind(chat, forward: true);
                      },
                      onSubmitted: (_) => _stepFind(chat, forward: true),
                    ),
                  ),
                  Builder(
                    builder: (_) {
                      final count = _findMatches(chat).length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          count == 0 ? '0/0' : '${_findIndex + 1}/$count',
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: context.l10n.commonPrevious,
                    onPressed: () => _stepFind(chat, forward: false),
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonNext,
                    onPressed: () => _stepFind(chat, forward: true),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    onPressed: _toggleFind,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        if (voice.voiceError != null)
          MaterialBanner(
            content: Text(voice.voiceError!),
            actions: [
              TextButton(
                onPressed: () => voice.clearError(),
                child: Text(context.l10n.commonGotIt),
              ),
            ],
          ),
        Selector<SessionStore, bool>(
          selector: (_, s) => s.inflightRecoveryNotice,
          builder: (context, _, child) =>
              _buildInflightRecoveryBanner(context.read<SessionStore>()),
        ),
        Selector<ChatStore, int>(
          selector: (_, c) => c.recoveryJournal.length,
          builder: (context, _, child) =>
              _buildRecoveryBanner(context.read<ChatStore>()),
        ),
        Expanded(
          child: Stack(
            children: [
              _ChatTranscriptPanel(
                scrollCtrl: _scrollCtrl,
                scrollCoordinator: _scrollCoordinator,
                onTranscriptChanged: _onTranscriptChanged,
                onMessageLongPress: _showMessageMenu,
                onRegenerate: session.readOnly ? null : _regenerateFromFooter,
                onBranch: session.readOnly ? null : _branchFromHere,
                onJumpToQuestion: _locateMessage,
                onQuoteMessage: session.readOnly ? null : _quoteMessage,
                keyForMessage: _keyForMessage,
                onUserMessageMountChanged: _onUserMessageMountChanged,
                highlightMessageId: _locatorHighlightId,
                editingMessageId: _editingMessageId,
                editController: _editCtrl,
                editFocusNode: _editFocus,
                onEditSubmit: _submitInlineEdit,
                onEditCancel: _cancelInlineEdit,
                onRestoreVersion: session.readOnly
                    ? null
                    : _restorePreviewedVersion,
                editSuggestions: _editingMessageId != null
                    ? _buildSuggestions()
                    : null,
                onEditAttach: _editingMessageId != null
                    ? _pickImageForEdit
                    : null,
                editAttachmentCount: _editAttachments.length,
                loadError: chat.loadingTranscript ? null : connection.error,
                onRetryLoad: sid.isEmpty
                    ? null
                    : () => session.resumeSession(
                        sid,
                        profile: session.activeProfile,
                      ),
                onPromptSelected: _insertStarterPrompt,
              ),
              Positioned.fill(
                child: Selector<ChatStore, int>(
                  selector: (_, store) => store.vibeBurstRevision,
                  builder: (context, revision, _) => _VibeHeartBurst(
                    revision: revision,
                    animationsDisabled: MediaQuery.disableAnimationsOf(context),
                  ),
                ),
              ),
              if (chat.messages.where((m) => m.role == 'user').length > 1)
                Positioned(
                  right: 8,
                  top: 16,
                  child: _buildTopicRail(chat.messages),
                ),
              // Scroll-to-bottom FAB (desktop parity: scroll-to-bottom-button)
              Positioned(
                right: 12,
                bottom: 8,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _stuckToBottom,
                  builder: (context, stuckToBottom, _) => AnimatedOpacity(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : HermesMotion.standard,
                    opacity: stuckToBottom ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: stuckToBottom,
                      child: FloatingActionButton.small(
                        heroTag:
                            'scroll_to_bottom:${widget.surfaceId ?? 'main'}',
                        tooltip: context.l10n.chatScrollToBottom,
                        onPressed: () {
                          if (_diagnosticLogging) {
                            if (_scrollCtrl.hasClients) {
                              final position = _scrollCtrl.position;
                              _logScroll(
                                'event=scroll_to_bottom.clicked '
                                'pixels=${position.pixels.toStringAsFixed(1)} '
                                'max_extent=${position.maxScrollExtent.toStringAsFixed(1)} '
                                'distance_to_bottom=${(position.maxScrollExtent - position.pixels).toStringAsFixed(1)} '
                                'message_count=${chat.messages.length}',
                              );
                            } else {
                              _logScroll(
                                'event=scroll_to_bottom.clicked has_clients=false '
                                'message_count=${chat.messages.length}',
                              );
                            }
                          }
                          _setStuckToBottom(true);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollCtrl.hasClients) {
                              final target =
                                  _scrollCtrl.position.maxScrollExtent;
                              if (MediaQuery.disableAnimationsOf(context)) {
                                _scrollCtrl.jumpTo(target);
                              } else {
                                _scrollCtrl.animateTo(
                                  target,
                                  duration: HermesMotion.deliberate,
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            }
                          });
                        },
                        child: const Icon(Icons.arrow_downward_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Pending interactive requests (approval/clarify/…) surface as a slim
        // strip so an approval-gated turn never looks like endless "思考中…";
        // tapping opens the global request sheet (same as the shell FAB).
        _buildRequestBanner(),
        // WebUI queue parity: a strip above the composer shows the pending
        // queue count and expands to per-item management (ui.js queue card).
        _buildComposerStatusStack(session),
        // Desktop file-drop is only meaningful on desktop platforms; mobile
        // browsers / touch devices have no drag-and-drop file gesture.
        if (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)
          DropTarget(
            onDragDone: session.readOnly ? null : _onDropFiles,
            child: _buildComposer(session, chat, voice),
          )
        else
          _buildComposer(session, chat, voice),
      ],
    );

    // L/XL use Sessions + Chat + Context and retain page-level navigation
    // because ChatScreen is pushed above AppShell.
    if (hasSessionRail) {
      return _WithUndoShortcuts(
        onFind: _toggleFind,
        onUndo: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await session.undoLastTurn();
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.chatLastTurnUndone)),
              );
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.chatUndoFailed('$e'))),
              );
            }
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          appBar: appBar,
          body: Row(
            children: [
              TabletSessionRail(
                width: railWidth,
                onOpen: (row) => row.isDelegatedChild
                    ? session.openReadOnlySession(row.id, profile: row.profile)
                    : session.resumeSession(row.id, profile: row.profile),
                onNew: () => session.newChat(),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(children: [Expanded(child: chatBody)]),
              ),
              if (useThreePane) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: sidebarWidth,
                  child: _desktopSidebarReady
                      ? const RightSidebar(
                          width: sidebarWidth,
                          initialTab: RightSidebarTab.files,
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
            ],
          ),
          endDrawer: useThreePane
              ? null
              : const Drawer(
                  width: 360,
                  child: RightSidebar(
                    width: 360,
                    initialTab: RightSidebarTab.files,
                  ),
                ),
        ),
      );
    }

    return _WithUndoShortcuts(
      onFind: _toggleFind,
      onUndo: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await session.undoLastTurn();
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.chatLastTurnUndone)),
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.chatUndoFailed('$e'))),
            );
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: appBar,
        body: widget.embedded ? chatBody : MobileSafeBody(child: chatBody),
        // A12 phone entry: workspace file panel as an end drawer (the tablet
        // layout keeps RightSidebar docked in the third column instead).
        endDrawer: Builder(
          builder: (drawerCtx) {
            final screenWidth = MediaQuery.sizeOf(drawerCtx).width;
            final width = screenWidth < 600
                ? (screenWidth * .85).clamp(0.0, 320.0).toDouble()
                : 360.0;
            return Drawer(
              width: width,
              child: RightSidebar(
                width: width,
                initialTab: RightSidebarTab.files,
              ),
            );
          },
        ),
      ),
    );
  }

  /// WebUI icon-btn spec (§2): 34×34 tap target, 16px muted icon at 0.75
  /// resting opacity, light-gray rounded hover. Non-interactive variant for
  /// use as a PopupMenuButton child.
  Widget _footerIcon({
    required String tooltip,
    required IconData icon,
    Color? color,
  }) {
    final resolved = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 44,
      height: 44,
      child: Icon(icon, size: 18, color: resolved.withValues(alpha: 0.75)),
    );
  }

  Widget _footerIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolved = color ?? theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDark ? null : const Color(0x0F000000),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 18,
              color: resolved.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }

  /// Queue button with a red count badge (moved from the old bottom bar).
  Widget _footerQueueButton({required int count, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: count > 0
          ? context.l10n.chatSendQueueCount(count)
          : context.l10n.chatSendQueue,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDark ? null : const Color(0x0F000000),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.queue_play_next_outlined,
                  size: 18,
                  color: color.withValues(alpha: 0.75),
                ),
                if (count > 0)
                  Positioned(
                    right: 2,
                    top: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: HermesSemantic.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Desktop parity pickers — personality / workspace /
  // difficulty / tools configuration sheets.
  // ────────────────────────────────────────────────────────

  /// Profile chip → real profiles API. Selecting a profile updates the sticky
  /// profile used by profile-scoped reads and subsequent backend starts.
  Future<void> _showProfilePicker() async {
    final session = context.read<SessionStore>();
    final api = session.api;
    final messenger = ScaffoldMessenger.of(context);
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatServerNotConnected)),
      );
      return;
    }
    try {
      await session.refreshProfiles();
      if (!mounted) return;
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatProfilesLoadFailed('$e'))),
        );
      }
      return;
    }
    if (!mounted) return;
    if (_profiles.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatNoProfiles)),
      );
      return;
    }
    final picked = await _showOptionSheet<String>(
      title: context.l10n.chatSelectProfile,
      subtitle: context.l10n.chatSelectProfileDescription,
      current: _activeProfileName ?? '',
      options: [for (final p in _profiles) (p.name, Icons.person_outline)],
      selectedLabel: context.l10n.chatCurrentlyActive,
    );
    if (picked == null || !mounted || picked == _activeProfileName) return;
    try {
      ++_composerContextGeneration;
      final payload = await session.switchActiveProfile(picked);
      final finalActive = payload.active ?? picked;
      if (!mounted) return;
      setState(() => _applyServerConfig(session.profileConfig));
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatProfileSwitched(finalActive))),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatProfileSwitchFailed('$e'))),
        );
      }
    }
  }

  /// Workspace chip → real server data: the default cwd plus every project
  /// path from `projects.list`. Picking one calls the real
  /// `session.workspace.move` gateway RPC through the domain API.
  Future<void> _showWorkspacePicker() async {
    final session = context.read<SessionStore>();
    final api = session.api;
    final sessionId = session.durableId;
    final runtimeId = session.runtimeId;
    final messenger = ScaffoldMessenger.of(context);
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatServerNotConnected)),
      );
      return;
    }
    // Refresh candidates best-effort so the sheet never goes stale.
    try {
      final cwd = await api.fsDefaultCwd();
      if (cwd.isNotEmpty &&
          mounted &&
          identical(api, session.api) &&
          runtimeId == session.runtimeId) {
        setState(() => _defaultCwd = cwd);
      }
    } catch (_) {}
    try {
      final projects = await api.listProjects();
      if (mounted &&
          identical(api, session.api) &&
          runtimeId == session.runtimeId) {
        setState(() => _workspaceProjects = projects);
      }
    } catch (_) {}
    if (!mounted) return;

    final current = _workspaceCwd ?? session.info?.cwd ?? _defaultCwd ?? '';
    final seen = <String>{};
    final options = <(String, IconData)>[];
    void add(String? path, IconData icon) {
      final value = (path ?? '').trim();
      if (value.isEmpty || !seen.add(value)) return;
      options.add((value, icon));
    }

    add(_defaultCwd, Icons.folder_special);
    add(session.info?.cwd, Icons.folder);
    for (final project in _workspaceProjects) {
      var path = project['path']?.toString();
      if (path == null || path.trim().isEmpty) {
        final repos = project['repos'] as List? ?? const [];
        for (final repo in repos) {
          if (repo is Map && (repo['path']?.toString().isNotEmpty ?? false)) {
            path = repo['path'].toString();
            break;
          }
        }
      }
      add(path, Icons.source);
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(context.l10n.chatChangeWorkspace),
                subtitle: Text(context.l10n.chatChangeWorkspaceDescription),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(context.l10n.chatBrowseFiles),
                subtitle: Text(context.l10n.chatBrowseFilesDescription),
                onTap: () async {
                  final picked = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) =>
                          FilesScreen(initialPath: current, pickMode: true),
                    ),
                  );
                  if (picked != null &&
                      picked.isNotEmpty &&
                      sheetContext.mounted) {
                    Navigator.of(sheetContext).pop(picked);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_location_alt_outlined),
                title: Text(context.l10n.chatEnterOtherDirectory),
                subtitle: Text(context.l10n.chatAbsoluteServerPath),
                onTap: () async {
                  final custom = await _promptWorkspacePath(current);
                  if (custom != null && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop(custom);
                  }
                },
              ),
              if (options.isNotEmpty) const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, index) {
                    final (path, icon) = options[index];
                    final selected = path == current;
                    return ListTile(
                      leading: Icon(icon),
                      title: Text(
                        path,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(path),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted || picked == current) return;
    if (!identical(api, session.api) ||
        runtimeId != session.runtimeId ||
        sessionId != session.durableId) {
      return;
    }
    if (sessionId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatStartSessionBeforeWorkspace)),
      );
      return;
    }
    try {
      await session.setStoredSessionWorkspace(sessionId, picked);
      if (!mounted ||
          !identical(api, session.api) ||
          runtimeId != session.runtimeId ||
          sessionId != session.durableId) {
        return;
      }
      setState(() => _workspaceCwd = picked);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.chatWorkspaceSwitched(_workspaceBaseName(picked)),
          ),
        ),
      );
    } catch (e) {
      if (mounted &&
          identical(api, session.api) &&
          runtimeId == session.runtimeId &&
          sessionId == session.durableId) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatWorkspaceSwitchFailed('$e'))),
        );
      }
    }
  }

  Future<String?> _promptWorkspacePath(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showAdaptiveFormDialog<String>(
      context: context,
      title: context.l10n.chatEnterWorkspacePath,
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: context.l10n.chatServerDirectory,
          hintText: '/home/user/project',
          helperText: context.l10n.chatServerDirectoryHelp,
        ),
        onSubmitted: (value) {
          final path = value.trim();
          if (path.isNotEmpty) Navigator.of(context).pop(path);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final path = controller.text.trim();
            if (path.isNotEmpty) Navigator.of(context).pop(path);
          },
          child: Text(context.l10n.commonSwitch),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result?.trim();
  }

  /// Difficulty chip → the real reasoning effort in the backend config.
  /// Reads `agent.reasoning_effort` (with older-key fallbacks) and writes the
  /// picked value back through PUT /config.
  Future<void> _showDifficultyPicker() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final api = session.api;
    final runtimeId = session.runtimeId;
    final configProfile = session.profile ?? session.activeProfile;
    final messenger = ScaffoldMessenger.of(context);
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatServerNotConnected)),
      );
      return;
    }
    final current = _reasoningEffort;
    if (current == null) return; // pill is hidden in this state anyway
    // WebUI `/reasoning` ladder (commands.js:33): the full effort set the
    // backend accepts.
    const levels = [
      ('none', Icons.block),
      ('minimal', Icons.eco_outlined),
      ('low', Icons.sentiment_satisfied_alt),
      ('medium', Icons.trending_up),
      ('high', Icons.local_fire_department),
      ('xhigh', Icons.whatshot_outlined),
      ('max', Icons.rocket_launch_outlined),
    ];
    final options = [
      ...levels,
      if (!levels.any((l) => l.$1 == current)) (current, Icons.psychology),
    ];
    final picked = await _showOptionSheet<String>(
      title: context.l10n.chatReasoningEffort,
      subtitle: context.l10n.chatReasoningEffortDescription,
      current: current,
      options: options,
    );
    if (picked == null || !mounted || picked == current) return;
    if (!identical(api, session.api) ||
        runtimeId != session.runtimeId ||
        configProfile != (session.profile ?? session.activeProfile)) {
      return;
    }
    // Always write the canonical shape: merge into the existing `agent` map.
    final patch = {
      'agent': {
        ...(_serverConfig['agent'] is Map
            ? (_serverConfig['agent'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{}),
        'reasoning_effort': picked,
      },
    };
    try {
      await api.putConfig(patch, profile: configProfile);
      if (!mounted ||
          !identical(api, session.api) ||
          runtimeId != session.runtimeId ||
          configProfile != (session.profile ?? session.activeProfile)) {
        return;
      }
      session.applyProfileConfigPatch(configProfile, patch);
      setState(() => _serverConfig = {..._serverConfig, ...patch});
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatReasoningEffortSet(picked))),
      );
    } catch (e) {
      if (mounted &&
          identical(api, session.api) &&
          runtimeId == session.runtimeId &&
          configProfile == (session.profile ?? session.activeProfile)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.chatReasoningEffortSetFailed('$e'))),
        );
      }
    }
  }

  /// Tools chip → session-scoped toolset selection when a live session is
  /// bound (WebUI session toolsets chip, A15); otherwise the global list
  /// (GET /tools + PUT /tools/{name}/enabled).
  Future<void> _showToolsConfig() async {
    final l10n = context.l10n;
    final session = context.read<SessionStore>();
    final api = session.api;
    final runtimeId = session.runtimeId;
    final messenger = ScaffoldMessenger.of(context);
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatServerNotConnected)),
      );
      return;
    }
    // Refresh best-effort so the sheet reflects the current session.
    await _loadToolsets();
    if (!mounted ||
        !identical(api, session.api) ||
        runtimeId != session.runtimeId) {
      return;
    }
    if (!_toolsetsLoaded) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatToolsetsLoadFailed)),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.chatToolConfiguration,
                  style: HermesType.onSurface(
                    HermesType.headline,
                    Theme.of(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _toolsetsSessionScoped
                      ? context.l10n.chatSessionToolsetsDescription
                      : context.l10n.chatGlobalToolsetsDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToolsetCountChip(
                      label: context.l10n.chatCurrentSessionToolsets,
                      count: _sessionToolsetsLoaded
                          ? _toolsetCountLabel(_sessionToolsets)
                          : context.l10n.chatNotConnected,
                      selected: _toolsetsSessionScoped,
                      onTap: !_sessionToolsetsLoaded
                          ? null
                          : () {
                              setModal(() => _showGlobalToolsets = false);
                              setState(() {});
                            },
                    ),
                    _ToolsetCountChip(
                      label: context.l10n.chatGlobalCliToolsets,
                      count: _globalCliToolsetsLoaded
                          ? _toolsetCountLabel(_globalCliToolsets)
                          : context.l10n.chatLoadFailed,
                      selected: !_toolsetsSessionScoped,
                      onTap: !_globalCliToolsetsLoaded
                          ? null
                          : () {
                              setModal(() => _showGlobalToolsets = true);
                              setState(() {});
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(HermesRadius.card),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.chatToolsetsExplanation,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                height: 1.45,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _toolsets.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              context.l10n.chatNoConfigurableToolsets,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _toolsetDisplayEntries.length,
                          itemBuilder: (_, displayIndex) {
                            final entry = _toolsetDisplayEntries[displayIndex];
                            final section = entry.$1;
                            if (section != null) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      section ==
                                              context.l10n.chatCompositeToolsets
                                          ? Icons.account_tree_outlined
                                          : Icons.build_outlined,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      section,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final i = entry.$2!;
                            final t = _toolsets[i];
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: Icon(
                                _compositeToolsetNames.contains(t.name)
                                    ? Icons.account_tree_outlined
                                    : Icons.handyman_outlined,
                              ),
                              title: Text(t.name),
                              subtitle: Text(
                                t.description?.isNotEmpty == true
                                    ? t.description!
                                    : context.l10n.chatToolCount(t.toolCount),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              value: t.enabled,
                              onChanged: (enabled) async {
                                if (!identical(api, session.api) ||
                                    runtimeId != session.runtimeId) {
                                  return;
                                }
                                // Optimistic toggle; revert on failure.
                                setModal(() {
                                  _toolsets[i] = ToolsetInfo(
                                    name: t.name,
                                    description: t.description,
                                    enabled: enabled,
                                    toolCount: t.toolCount,
                                  );
                                });
                                setState(() {});
                                try {
                                  if (_toolsetsSessionScoped) {
                                    await session.setSessionToolsetEnabled(
                                      t.name,
                                      enabled,
                                    );
                                  } else {
                                    await api.toggleToolset(
                                      t.name,
                                      enabled,
                                      profile:
                                          session.profile ??
                                          session.activeProfile,
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted ||
                                      !identical(api, session.api) ||
                                      runtimeId != session.runtimeId) {
                                    return;
                                  }
                                  setModal(() {
                                    _toolsets[i] = t;
                                  });
                                  setState(() {});
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.l10n.chatToolsetToggleFailed(
                                          t.name,
                                          '$e',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(context.l10n.commonDone),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<T?> _showOptionSheet<T extends String>({
    required String title,
    required String subtitle,
    required T current,
    required List<(T, IconData)> options,
    String? selectedLabel,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: HermesType.onSurface(
                  HermesType.headline,
                  Theme.of(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final (value, icon) = options[i];
                    final selected = value == current;
                    final colors = Theme.of(context).colorScheme;
                    return Semantics(
                      selected: selected,
                      child: ListTile(
                        leading: Icon(
                          icon,
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        title: Text(
                          value,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: colors.onSurface,
                          ),
                        ),
                        trailing: selected
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: colors.primary,
                                  ),
                                  if (selectedLabel != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      selectedLabel,
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            HermesRadius.smallCard,
                          ),
                          side: BorderSide(
                            color: selected
                                ? colors.primary
                                : colors.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        tileColor: selected
                            ? colors.primary.withValues(alpha: 0.16)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(value),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ephemeral desktop-parity feedback for the standalone gateway `reaction`
/// event ("ily", "<3", "good bot"). Persistent per-message reactions
/// continue to render inside [MessageBubble]; this overlay intentionally owns
/// no transcript state and never intercepts gestures.
class _VibeHeartBurst extends StatefulWidget {
  const _VibeHeartBurst({
    required this.revision,
    required this.animationsDisabled,
  });

  final int revision;
  final bool animationsDisabled;

  @override
  State<_VibeHeartBurst> createState() => _VibeHeartBurstState();
}

class _VibeHeartBurstState extends State<_VibeHeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
  }

  @override
  void didUpdateWidget(covariant _VibeHeartBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision && widget.revision > 0) {
      if (widget.animationsDisabled) {
        _controller.value = 0;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animationsDisabled) return const SizedBox.expand();
    const hearts = <(double, double, double)>[
      (0.28, 0.00, 24),
      (0.40, 0.14, 31),
      (0.52, 0.04, 27),
      (0.63, 0.18, 34),
      (0.73, 0.08, 25),
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          if (_controller.value == 0 || _controller.isDismissed) {
            return const SizedBox.expand();
          }
          final opacity =
              (1 -
                      Curves.easeIn.transform(
                        ((_controller.value - 0.55) / 0.45).clamp(0.0, 1.0),
                      ))
                  .clamp(0.0, 1.0);
          return LayoutBuilder(
            builder: (context, constraints) => Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (x, delay, size) in hearts)
                  if (_controller.value > delay)
                    Positioned(
                      left: constraints.maxWidth * x - size / 2,
                      bottom:
                          24 +
                          (constraints.maxHeight *
                              0.42 *
                              ((t - delay).clamp(0.0, 1.0))),
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.rotate(
                          angle: (x - 0.5) * 0.55,
                          child: Transform.scale(
                            scale: 0.55 + 0.45 * t,
                            child: Text('❤️', style: TextStyle(fontSize: size)),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Snapshot for transcript list rebuilds (counts + streaming lifecycle).
///
/// `streamTick` is deliberately EXCLUDED from equality: it bumps ~30 Hz while
/// streaming, and rebuilding the whole list per tick re-ran Markdown parsing
/// for every visible historical bubble. The actively-streaming row subscribes
/// to the tick itself ([_StreamingBubble]); the list only rebuilds when its
/// structure changes.
class _ChatTranscriptSnapshot {
  const _ChatTranscriptSnapshot({
    required this.messages,
    required this.isStreaming,
    required this.busy,
    required this.streamingMessageId,
    required this.streamTick,
    required this.loadingHistory,
    required this.hasMoreHistory,
    required this.loadingTranscript,
    required this.historyError,
    required this.hasNewerWindow,
    required this.versionPreviewSignature,
    required this.tailStatusLabel,
    required this.transcriptRevision,
    required this.transcriptStructureRevision,
  });

  final List<ChatMessage> messages;
  final bool isStreaming;
  final bool busy;
  final String? streamingMessageId;
  final int streamTick;
  final bool loadingHistory;
  final bool hasMoreHistory;
  final bool loadingTranscript;
  final String? historyError;
  final bool hasNewerWindow;
  final String? versionPreviewSignature;
  final String? tailStatusLabel;
  final int transcriptRevision;
  final int transcriptStructureRevision;

  factory _ChatTranscriptSnapshot.from(ChatStore chat) {
    return _ChatTranscriptSnapshot(
      messages: chat.transcriptStructure,
      isStreaming: chat.isStreaming,
      busy: chat.busy,
      streamingMessageId: chat.streamingMessageId,
      streamTick: chat.streamTick,
      loadingHistory: chat.loadingHistory,
      hasMoreHistory: chat.hasMoreHistory,
      loadingTranscript: chat.loadingTranscript,
      historyError: chat.historyError,
      hasNewerWindow: chat.hasNewerTranscriptWindow,
      versionPreviewSignature: chat.versionPreviewSignature,
      tailStatusLabel: chat.tailStatusLabel,
      transcriptRevision: chat.transcriptRevision,
      transcriptStructureRevision: chat.transcriptStructureRevision,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ChatTranscriptSnapshot &&
        other.isStreaming == isStreaming &&
        other.busy == busy &&
        other.streamingMessageId == streamingMessageId &&
        other.loadingHistory == loadingHistory &&
        other.hasMoreHistory == hasMoreHistory &&
        other.loadingTranscript == loadingTranscript &&
        other.historyError == historyError &&
        other.hasNewerWindow == hasNewerWindow &&
        other.versionPreviewSignature == versionPreviewSignature &&
        other.tailStatusLabel == tailStatusLabel &&
        other.transcriptRevision == transcriptRevision &&
        other.transcriptStructureRevision == transcriptStructureRevision &&
        other.messages.length == messages.length &&
        (messages.isEmpty || other.messages.last.id == messages.last.id);
  }

  @override
  int get hashCode => Object.hash(
    isStreaming,
    busy,
    streamingMessageId,
    loadingHistory,
    hasMoreHistory,
    loadingTranscript,
    historyError,
    hasNewerWindow,
    versionPreviewSignature,
    tailStatusLabel,
    transcriptRevision,
    transcriptStructureRevision,
    messages.length,
    messages.isEmpty ? null : messages.last.id,
  );
}

class _ChatTranscriptPanel extends StatefulWidget {
  final ScrollController scrollCtrl;
  final ChatScrollCoordinator scrollCoordinator;
  final void Function(int messageCount, int streamTick, bool isStreaming)
  onTranscriptChanged;
  final void Function(ChatMessage) onMessageLongPress;
  final void Function(ChatMessage)? onRegenerate;
  final void Function(ChatMessage)? onBranch;
  final void Function(ChatMessage) onJumpToQuestion;
  final void Function(ChatMessage)? onQuoteMessage;
  final GlobalKey Function(ChatMessage) keyForMessage;
  final void Function(String id, bool mounted) onUserMessageMountChanged;
  final String? highlightMessageId;
  final String? editingMessageId;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final void Function(ChatMessage)? onEditSubmit;
  final VoidCallback? onEditCancel;

  /// Re-send the turn version currently previewed (desktop BranchPicker /
  /// checkpoint "restore" parity).
  final Future<void> Function()? onRestoreVersion;

  /// F1: inline-edit completions overlay + attach button + staged count.
  final Widget? editSuggestions;
  final VoidCallback? onEditAttach;
  final int editAttachmentCount;

  /// Last transcript/session load failure (ConnectionStore.error). Rendered
  /// in place of the empty state so a failed load doesn't masquerade as an
  /// empty session.
  final String? loadError;
  final VoidCallback? onRetryLoad;
  final ValueChanged<String>? onPromptSelected;

  const _ChatTranscriptPanel({
    required this.scrollCtrl,
    required this.scrollCoordinator,
    required this.onTranscriptChanged,
    required this.onMessageLongPress,
    this.onRegenerate,
    this.onBranch,
    required this.onJumpToQuestion,
    this.onQuoteMessage,
    required this.keyForMessage,
    required this.onUserMessageMountChanged,
    required this.highlightMessageId,
    this.editingMessageId,
    this.editController,
    this.editFocusNode,
    this.onEditSubmit,
    this.onEditCancel,
    this.onRestoreVersion,
    this.editSuggestions,
    this.onEditAttach,
    this.editAttachmentCount = 0,
    this.loadError,
    this.onRetryLoad,
    this.onPromptSelected,
  });

  @override
  State<_ChatTranscriptPanel> createState() => _ChatTranscriptPanelState();
}

class _ChatTranscriptPanelState extends State<_ChatTranscriptPanel> {
  int _lastMessageCount = -1;
  List<ChatTimelineItem> _timeline = const [];
  int _timelineMessageCount = -1;
  ChatMessage? _timelineFirst;
  ChatMessage? _timelineLast;
  String? _timelineStreamingId;
  String? _timelineVersionSignature;
  int _timelineRevision = -1;

  List<ChatTimelineItem> _timelineFor(_ChatTranscriptSnapshot snapshot) {
    final messages = snapshot.messages;
    final first = messages.firstOrNull;
    final last = messages.lastOrNull;
    if (_timelineMessageCount == messages.length &&
        identical(_timelineFirst, first) &&
        identical(_timelineLast, last) &&
        _timelineStreamingId == snapshot.streamingMessageId &&
        _timelineVersionSignature == snapshot.versionPreviewSignature &&
        _timelineRevision == snapshot.transcriptRevision) {
      return _timeline;
    }
    _timelineMessageCount = messages.length;
    _timelineFirst = first;
    _timelineLast = last;
    _timelineStreamingId = snapshot.streamingMessageId;
    _timelineVersionSignature = snapshot.versionPreviewSignature;
    _timelineRevision = snapshot.transcriptRevision;
    final started = Stopwatch()..start();
    _timeline = buildChatTimeline(
      messages,
      preserveMessageId: snapshot.streamingMessageId,
    );
    started.stop();
    final metrics = ClientPerformanceMetrics.instance;
    if (started.elapsedMicroseconds > metrics.maxTimelineBuildMicros) {
      metrics.maxTimelineBuildMicros = started.elapsedMicroseconds;
    }
    return _timeline;
  }

  void _notifyTranscriptChanged(_ChatTranscriptSnapshot snapshot) {
    if (_lastMessageCount != snapshot.messages.length) {
      _lastMessageCount = snapshot.messages.length;
      widget.onTranscriptChanged(
        snapshot.messages.length,
        snapshot.streamTick,
        snapshot.isStreaming,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ChatStore, _ChatTranscriptSnapshot>(
      selector: (_, chat) => _ChatTranscriptSnapshot.from(chat),
      builder: (context, snapshot, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _notifyTranscriptChanged(snapshot);
        });
        if (snapshot.messages.isEmpty && !snapshot.busy) {
          if (snapshot.loadingTranscript) {
            return const Center(
              key: ValueKey('transcript-loading'),
              child: CircularProgressIndicator(),
            );
          }
          final loadError = widget.loadError;
          if (loadError != null) {
            return _TranscriptLoadError(
              message: loadError,
              onRetry: widget.onRetryLoad,
            );
          }
          return _EmptyChat(onPromptSelected: widget.onPromptSelected);
        }
        return Column(
          children: [
            Expanded(
              child: _MessageList(
                snapshot: snapshot,
                timeline: _timelineFor(snapshot),
                scrollCtrl: widget.scrollCtrl,
                onTranscriptChanged: widget.onTranscriptChanged,
                onMessageLongPress: widget.onMessageLongPress,
                onRegenerate: widget.onRegenerate,
                onBranch: widget.onBranch,
                onJumpToQuestion: widget.onJumpToQuestion,
                onQuoteMessage: widget.onQuoteMessage,
                keyForMessage: widget.keyForMessage,
                onUserMessageMountChanged: widget.onUserMessageMountChanged,
                highlightMessageId: widget.highlightMessageId,
                editingMessageId: widget.editingMessageId,
                editController: widget.editController,
                editFocusNode: widget.editFocusNode,
                onEditSubmit: widget.onEditSubmit,
                onEditCancel: widget.onEditCancel,
                onRestoreVersion: widget.onRestoreVersion,
                editSuggestions: widget.editSuggestions,
                onEditAttach: widget.onEditAttach,
                editAttachmentCount: widget.editAttachmentCount,
              ),
            ),
            const _BackgroundResumeNotice(),
          ],
        );
      },
    );
  }
}

/// Desktop `BackgroundResumeNotice` parity: while the session is idle but a
/// top-level delegated agent is still running in the background, a slim
/// shimmer line reminds the user the turn will resume when it finishes.
class _BackgroundResumeNotice extends StatelessWidget {
  const _BackgroundResumeNotice();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatStore>();
    final status = context.maybeRead<ComposerStatusStore>();
    final session = context.maybeRead<SessionStore>();
    if (chat.busy || status == null) return const SizedBox.shrink();
    final sid = session?.runtimeId ?? session?.durableId;
    final running = status
        .itemsFor(sid)
        .where(
          (item) =>
              item.type == ComposerStatusType.subagent &&
              item.state == ComposerStatusState.running,
        )
        .toList();
    if (running.isEmpty) return const SizedBox.shrink();
    final palette = HermesPalette.of(context);
    return Container(
      key: const ValueKey('background-resume-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: palette.text3,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              running.length == 1
                  ? context.l10n.chatBackgroundAgentRunning
                  : context.l10n.chatBackgroundAgentsRunning(running.length),
              style: TextStyle(fontSize: 11, color: palette.text3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Message list with date separators (Phase 6 Wave 2): a "today / yesterday /
/// date" chip is inserted whenever the message day changes.
class _MessageList extends StatelessWidget {
  final _ChatTranscriptSnapshot snapshot;
  final List<ChatTimelineItem> timeline;
  final ScrollController scrollCtrl;
  final void Function(int messageCount, int streamTick, bool isStreaming)
  onTranscriptChanged;
  final void Function(ChatMessage) onMessageLongPress;
  final void Function(ChatMessage)? onRegenerate;
  final void Function(ChatMessage)? onBranch;
  final void Function(ChatMessage userMessage) onJumpToQuestion;
  final void Function(ChatMessage)? onQuoteMessage;
  final GlobalKey Function(ChatMessage) keyForMessage;
  final void Function(String id, bool mounted) onUserMessageMountChanged;
  final String? highlightMessageId;
  final String? editingMessageId;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final void Function(ChatMessage)? onEditSubmit;
  final VoidCallback? onEditCancel;
  final Future<void> Function()? onRestoreVersion;
  final Widget? editSuggestions;
  final VoidCallback? onEditAttach;
  final int editAttachmentCount;

  const _MessageList({
    required this.snapshot,
    required this.timeline,
    required this.scrollCtrl,
    required this.onTranscriptChanged,
    required this.onMessageLongPress,
    this.onRegenerate,
    this.onBranch,
    required this.onJumpToQuestion,
    this.onQuoteMessage,
    required this.keyForMessage,
    required this.onUserMessageMountChanged,
    required this.highlightMessageId,
    this.editingMessageId,
    this.editController,
    this.editFocusNode,
    this.onEditSubmit,
    this.onEditCancel,
    this.onRestoreVersion,
    this.editSuggestions,
    this.onEditAttach,
    this.editAttachmentCount = 0,
  });

  bool _showDateDivider(List<ChatMessage> msgs, int index) {
    final ts = msgs[index].timestamp?.toLocal();
    if (ts == null) return false;
    final day = DateTime(ts.year, ts.month, ts.day);
    if (index == 0) return true;
    final prev = msgs[index - 1].timestamp?.toLocal();
    if (prev == null) return true;
    return day != DateTime(prev.year, prev.month, prev.day);
  }

  Widget _wrapRow(BuildContext context, Widget row) {
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: ConstrainedBox(
        key: const ValueKey('transcript-content-column'),
        constraints: BoxConstraints(maxWidth: width < 600 ? width : 820),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width < 600 ? 8 : 12),
          child: row,
        ),
      ),
    );
  }

  Widget _messageRow(
    BuildContext context,
    ChatTimelineMessage item,
    List<ChatMessage> messages, {
    required bool firstForSource,
    required bool lastForSource,
  }) {
    final m = item.message;
    final logical = item.sourceMessage;
    final sourceIndex = item.sourceIndex;
    final assistantLike = logical.role == 'assistant' || logical.interim;
    final previous = sourceIndex > 0 ? messages[sourceIndex - 1] : null;
    final continues =
        previous != null &&
        (previous.role == 'assistant' || previous.interim) &&
        assistantLike;
    final question =
        logical.role == 'assistant' && !logical.interim && !logical.pending
        ? item.ownerUserMessage
        : null;
    final isEditing =
        editingMessageId == item.sourceMessage.id &&
        editController != null &&
        item.sourceMessage.role == 'user';
    final isStreaming =
        snapshot.isStreaming &&
        snapshot.streamingMessageId == item.sourceMessage.id;
    // Desktop BranchPicker / checkpoint parity: per-user-turn version nav.
    final chatStore = context.read<ChatStore>();
    final versionAnchor = logical.role == 'user'
        ? ChatStore.turnAnchorKey(logical)
        : null;
    final versionTotal = versionAnchor == null
        ? 1
        : chatStore.turnVersionCount(versionAnchor);
    final versionIndex = versionAnchor == null
        ? 0
        : chatStore.turnVersionCurrent(versionAnchor);
    final rowMessage = isStreaming
        ? (context.read<ChatStore>().streamingMessage ?? m)
        : m;
    final children = <Widget>[];
    if (firstForSource && _showDateDivider(messages, sourceIndex)) {
      children.add(
        _DateDivider(
          date: item.sourceMessage.timestamp?.toLocal() ?? DateTime.now(),
        ),
      );
    }
    Widget messageRow = AnimatedContainer(
      key: firstForSource
          ? keyForMessage(logical)
          : ValueKey('timeline-row-${item.key}'),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : HermesMotion.standard,
      decoration: BoxDecoration(
        color: highlightMessageId == logical.id
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: isEditing
          ? _InlineMessageEditor(
              controller: editController!,
              focusNode: editFocusNode,
              onSubmit: () => onEditSubmit?.call(logical),
              onCancel: onEditCancel,
              suggestions: editSuggestions,
              onAttach: onEditAttach,
              attachmentCount: editAttachmentCount,
            )
          : Dismissible(
              key: ValueKey('msg_dismiss_${item.key}'),
              direction: onQuoteMessage != null
                  ? DismissDirection.endToStart
                  : DismissDirection.none,
              dismissThresholds: const {DismissDirection.endToStart: .45},
              confirmDismiss: (_) async {
                HapticFeedback.lightImpact();
                onQuoteMessage?.call(logical);
                return false;
              },
              background: const SizedBox.shrink(),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: Icon(
                  Icons.reply,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              child: GestureDetector(
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  onMessageLongPress(logical);
                },
                child: isStreaming
                    ? _StreamingBubble(
                        fallback: rowMessage,
                        showRoleHeader:
                            firstForSource && assistantLike && !continues,
                        onRegenerate: onRegenerate,
                        onJumpToQuestion: question == null
                            ? null
                            : () => onJumpToQuestion(question),
                        onTick: (tick) =>
                            onTranscriptChanged(messages.length, tick, true),
                      )
                    : MessageBubble(
                        message: rowMessage,
                        showFooter: lastForSource,
                        showRoleHeader:
                            firstForSource && assistantLike && !continues,
                        onRegenerate: onRegenerate,
                        onBranch: assistantLike ? onBranch : null,
                        onMore: () => onMessageLongPress(logical),
                        onJumpToQuestion: question == null
                            ? null
                            : () => onJumpToQuestion(question),
                        isActivelyStreaming: false,
                        agentReplySender:
                            (assistantLike &&
                                firstForSource &&
                                lastForSource &&
                                question != null)
                            ? agentDeliverySender(question.fullText)
                            : null,
                        turnVersionTotal: versionTotal,
                        turnVersionIndex: versionIndex,
                        onSelectTurnVersion: versionAnchor == null
                            ? null
                            : (i) =>
                                  chatStore.selectTurnVersion(versionAnchor, i),
                        onRestoreTurnVersion:
                            (versionAnchor == null ||
                                versionIndex >= versionTotal - 1)
                            ? null
                            : onRestoreVersion,
                      ),
              ),
            ),
    );
    if (logical.role == 'user' && firstForSource) {
      messageRow = _UserMessageMountMarker(
        messageId: logical.id,
        onMountChanged: onUserMessageMountChanged,
        child: messageRow,
      );
    }
    children.add(messageRow);
    return _wrapRow(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = snapshot.messages;
    final itemCount = 1 + timeline.length + (snapshot.hasNewerWindow ? 1 : 0);
    return RefreshIndicator(
      onRefresh: () async {
        final session = context.read<SessionStore>();
        if (session.chat.hasMoreHistory && !session.chat.loadingHistory) {
          await session.loadOlderMessages();
        }
      },
      child: ListView.builder(
        controller: scrollCtrl,
        scrollCacheExtent: const ScrollCacheExtent.pixels(640),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _wrapRow(
              context,
              _HistoryHeader(
                loadingHistory: snapshot.loadingHistory,
                hasMoreHistory: snapshot.hasMoreHistory,
                historyError: snapshot.historyError,
              ),
            );
          }
          final index = i - 1;
          if (snapshot.hasNewerWindow && index == timeline.length) {
            return _wrapRow(
              context,
              Center(
                child: OutlinedButton.icon(
                  key: const ValueKey('restore-newer-transcript-window'),
                  onPressed: () {
                    context.read<ChatStore>().restoreNewerTranscriptWindow();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (scrollCtrl.hasClients) {
                        scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
                      }
                    });
                  },
                  icon: const Icon(Icons.south),
                  label: Text(context.l10n.chatBackToNewerMessages),
                ),
              ),
            );
          }
          final item = timeline[index];
          final firstForSource =
              index == 0 || timeline[index - 1].sourceIndex != item.sourceIndex;
          final lastForSource =
              index + 1 >= timeline.length ||
              timeline[index + 1].sourceIndex != item.sourceIndex;
          if (item is ChatTimelineToolGroup) {
            return _wrapRow(
              context,
              Container(
                key: firstForSource
                    ? keyForMessage(item.sourceMessage)
                    : ValueKey('timeline-row-${item.key}'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ToolGroupCard(
                  groupId: item.id,
                  parts: item.tools,
                  interactions: item.interactions,
                  detailBuilder: buildToolCallCard,
                ),
              ),
            );
          }
          if (item is ChatTimelineTurnActivity) {
            // Unkeyed rows here used to let ListView's default index-based
            // element reuse silently attach a *different* turn's stats to a
            // recycled Element once older messages were prepended by
            // pagination — visibly wrong content at a given scroll position
            // ("错屏") once the transcript had enough messages to page.
            return _wrapRow(
              context,
              TurnActivityCard(
                key: firstForSource
                    ? keyForMessage(item.sourceMessage)
                    : ValueKey('timeline-row-${item.key}'),
                activity: item.activity,
              ),
            );
          }
          if (item is ChatTimelineChangedFiles) {
            return _wrapRow(
              context,
              Container(
                key: firstForSource
                    ? keyForMessage(item.sourceMessage)
                    : ValueKey('timeline-row-${item.key}'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ChangedFilesCard(files: item.files),
              ),
            );
          }
          return _messageRow(
            context,
            item as ChatTimelineMessage,
            messages,
            firstForSource: firstForSource,
            lastForSource: lastForSource,
          );
        },
      ),
    );
  }
}

class _UserMessageMountMarker extends StatefulWidget {
  const _UserMessageMountMarker({
    required this.messageId,
    required this.onMountChanged,
    required this.child,
  });

  final String messageId;
  final void Function(String id, bool mounted) onMountChanged;
  final Widget child;

  @override
  State<_UserMessageMountMarker> createState() =>
      _UserMessageMountMarkerState();
}

class _UserMessageMountMarkerState extends State<_UserMessageMountMarker> {
  @override
  void initState() {
    super.initState();
    widget.onMountChanged(widget.messageId, true);
  }

  @override
  void didUpdateWidget(covariant _UserMessageMountMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId == widget.messageId &&
        oldWidget.onMountChanged == widget.onMountChanged) {
      return;
    }
    oldWidget.onMountChanged(oldWidget.messageId, false);
    widget.onMountChanged(widget.messageId, true);
  }

  @override
  void dispose() {
    widget.onMountChanged(widget.messageId, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The actively-streaming bubble: subscribes to the throttled stream tick so
/// only this row rebuilds during streaming — historical rows keep their
/// parsed Markdown/tool cards untouched. Reads the live buffer through
/// [ChatStore.streamingMessage] once per tick.
class _StreamingBubble extends StatelessWidget {
  final ChatMessage fallback;
  final bool showRoleHeader;
  final void Function(ChatMessage)? onRegenerate;
  final VoidCallback? onJumpToQuestion;
  final void Function(int streamTick) onTick;

  const _StreamingBubble({
    required this.fallback,
    required this.showRoleHeader,
    this.onRegenerate,
    this.onJumpToQuestion,
    required this.onTick,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ChatStore, int>(
      selector: (_, chat) => chat.streamTick,
      builder: (context, tick, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onTick(tick));
        final live = context.read<ChatStore>().streamingMessage;
        return MessageBubble(
          message: live != null && live.id == fallback.id ? live : fallback,
          showRoleHeader: showRoleHeader,
          onRegenerate: onRegenerate,
          onJumpToQuestion: onJumpToQuestion,
          isActivelyStreaming: true,
        );
      },
    );
  }
}

/// WebUI `.msg-edit-area` parity: an in-place multiline editor that replaces
/// the user bubble while editing. Layout mirrors the user bubble (§6.5);
/// desktop keeps Enter/Esc shortcuts, touch platforms rely on buttons.
class _InlineMessageEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;

  /// F1: slash / @path / @session completions overlay (built by the screen),
  /// an attach-image button, and the count of staged attachments.
  final Widget? suggestions;
  final VoidCallback? onAttach;
  final int attachmentCount;

  const _InlineMessageEditor({
    required this.controller,
    this.focusNode,
    required this.onSubmit,
    this.onCancel,
    this.suggestions,
    this.onAttach,
    this.attachmentCount = 0,
  });

  static bool _isTouchPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final platform = Theme.of(context).platform;
    final touch = _isTouchPlatform(platform);
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= HermesBreakpoints.tablet
        ? HermesLayout.contentNarrow
        : width * 0.9;
    final onBubble = palette.bubbleUserText;
    final hint = touch
        ? context.l10n.chatEditMessageHint
        : context.l10n.chatEditMessageKeyboardHint;
    final cancelLabel = touch
        ? context.l10n.commonCancel
        : context.l10n.chatCancelKeyboardHint;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // F1: completions overlay sits above the edit bubble, like the
            // main composer's suggestions card.
            if (suggestions != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: suggestions,
              ),
            Container(
              margin: const EdgeInsets.only(top: 6, bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              decoration: BoxDecoration(
                color: palette.bubbleUser,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(HermesRadius.bubble),
                  topRight: Radius.circular(HermesRadius.bubble),
                  bottomLeft: Radius.circular(HermesRadius.bubble),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                  color: onBubble.withValues(alpha: 0.55),
                  width: 1.4,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape):
                          onCancel ?? () {},
                    },
                    child: Focus(
                      onKeyEvent: (node, event) =>
                          handleChatEnterToSend(node, event, onSubmit),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 8,
                        cursorColor: onBubble,
                        textInputAction: TextInputAction.newline,
                        style: HermesType.messageBody.copyWith(
                          color: onBubble,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: hint,
                          hintStyle: HermesType.messageBody.copyWith(
                            color: onBubble.withValues(alpha: 0.55),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (onAttach != null)
                        IconButton(
                          tooltip: context.l10n.chatAddImage,
                          visualDensity: VisualDensity.compact,
                          color: onBubble,
                          onPressed: onAttach,
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              Positioned(
                                right: -6,
                                top: -4,
                                child: HermesBadge(count: attachmentCount),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: onBubble,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(cancelLabel),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.tonalIcon(
                        onPressed: onSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: onBubble.withValues(alpha: 0.18),
                          foregroundColor: onBubble,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(context.l10n.chatSendEdit),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    final label = switch (diff) {
      0 => context.l10n.chatToday,
      1 => context.l10n.chatYesterday,
      _ => context.l10n.chatMonthDay(date.month, date.day),
    };
    final palette = HermesPalette.of(context);
    return Padding(
      key: const ValueKey('transcript-date-divider'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: palette.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: palette.text3),
            ),
          ),
          Expanded(child: Divider(height: 1, color: palette.border)),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final bool loadingHistory;
  final bool hasMoreHistory;
  final String? historyError;

  const _HistoryHeader({
    required this.loadingHistory,
    required this.hasMoreHistory,
    this.historyError,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    if (loadingHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.text3,
            ),
          ),
        ),
      );
    }
    if (historyError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: TextButton.icon(
            key: const ValueKey('history-retry'),
            onPressed: () => context.read<SessionStore>().loadOlderMessages(),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(context.l10n.chatOlderMessagesLoadFailed),
          ),
        ),
      );
    }
    if (hasMoreHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            context.l10n.chatLoadOlderMessagesHint,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: palette.text3),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          context.l10n.chatAllHistoryShown,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: palette.text3),
        ),
      ),
    );
  }
}

class _TranscriptLoadError extends StatelessWidget {
  const _TranscriptLoadError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 42, color: palette.text3),
            const SizedBox(height: 12),
            Text(context.l10n.chatTranscriptLoadFailed),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const ValueKey('transcript-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonReload),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({this.onPromptSelected});

  final ValueChanged<String>? onPromptSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_alt_outlined,
              size: 56,
              color: HermesSemantic.purple.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.chatEmptyTitle),
            const SizedBox(height: 4),
            Text(
              context.l10n.chatEmptyDescription,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onPromptSelected != null) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in [
                    (
                      context.l10n.chatStarterExplainProject,
                      context.l10n.chatStarterExplainProjectPrompt,
                    ),
                    (
                      context.l10n.chatStarterReviewChanges,
                      context.l10n.chatStarterReviewChangesPrompt,
                    ),
                    (
                      context.l10n.chatStarterDebugIssue,
                      context.l10n.chatStarterDebugIssuePrompt,
                    ),
                  ])
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: Text(prompt.$1),
                      onPressed: () => onPromptSelected!(prompt.$2),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact session list for the tablet chat layout (spec §176 left rail).
class TabletSessionRail extends StatefulWidget {
  final double width;
  final Future<void> Function(SessionRow row) onOpen;
  final Future<void> Function() onNew;
  final List<SessionRow>? rows;
  final String? currentId;

  const TabletSessionRail({
    super.key,
    required this.width,
    required this.onOpen,
    required this.onNew,
    this.rows,
    this.currentId,
  });

  @override
  State<TabletSessionRail> createState() => _TabletSessionRailState();
}

class _TabletSessionRailState extends State<TabletSessionRail> {
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.rows == null) {
      context.read<SessionStore>().refreshList(limit: HermesPolicy.pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final rows = widget.rows ?? session.sessions ?? [];
    final items = buildVisibleSessionTree(rows, _expandedIds);
    final parentIds = {
      for (final row in rows)
        if (row.parentSessionId?.isNotEmpty == true) row.parentSessionId!,
    };
    final currentId = widget.currentId ?? session.durableId;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: widget.width,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.chatSessions,
                      style: HermesType.onSurface(
                        HermesType.headline,
                        Theme.of(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.chatNoSessions,
                        style: const TextStyle(fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final s = item.row;
                        final selected = s.id == currentId;
                        final hasChildren = parentIds.contains(s.id);
                        final expanded = _expandedIds.contains(s.id);
                        return ListTile(
                          key: ValueKey('tablet-session-tile-${s.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.only(
                            left: 16 + item.depth * 18.0,
                            right: 16,
                          ),
                          selected: selected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          leading: s.needsAttention || s.isActivelyWorking
                              ? SessionStatusIndicator(
                                  attention: s.needsAttention,
                                  working: s.isActivelyWorking,
                                  size: 18,
                                )
                              : Icon(
                                  key: ValueKey(
                                    'tablet-session-leading-${s.id}',
                                  ),
                                  item.depth > 0
                                      ? Icons.account_tree_outlined
                                      : sessionSourceIcon(s),
                                  size: 18,
                                ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.title?.isNotEmpty == true
                                      ? s.title!
                                      : context.l10n.chatUntitledSession,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              SessionMetaBadges(row: s, iconSize: 12),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.preview?.trim().isNotEmpty == true)
                                Text(
                                  s.preview!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                [
                                  context.l10n.chatMessageCount(
                                    s.messageCount ?? 0,
                                  ),
                                  context.l10n.chatToolCount(s.toolCallCount),
                                  '${s.apiCallCount} API',
                                  '${_compactSessionTokens(s.totalTokens)} Token',
                                  if ((s.actualCostUsd ?? s.estimatedCostUsd) >
                                      0)
                                    '\$${(s.actualCostUsd ?? s.estimatedCostUsd).toStringAsFixed(4)}',
                                  if (s.model?.isNotEmpty == true) s.model!,
                                  if (s.profile?.isNotEmpty == true) s.profile!,
                                  sessionSourceLabel(s),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: hasChildren
                              ? IconButton(
                                  key: ValueKey(
                                    'tablet-session-toggle-${s.id}',
                                  ),
                                  tooltip: expanded
                                      ? context.l10n.chatCollapseSubsessions
                                      : context.l10n.chatExpandSubsessions,
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  onPressed: () => setState(() {
                                    if (!_expandedIds.add(s.id)) {
                                      _expandedIds.remove(s.id);
                                    }
                                  }),
                                  icon: Icon(
                                    expanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                  ),
                                )
                              : null,
                          onTap: () => widget.onOpen(s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _compactSessionTokens(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

class _ToolsetCountChip extends StatelessWidget {
  final String label;
  final String count;
  final bool selected;
  final VoidCallback? onTap;

  const _ToolsetCountChip({
    required this.label,
    required this.count,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(HermesRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HermesRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '$label：$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop-parity Ctrl+Z / Cmd+Z undo wrapper (see use-composer-undo.ts).
///
/// Listens for the platform undo intent and fires [onUndo]. Intentionally a
/// lightweight wrapper so the Shortcuts/Action layer doesn't double-trigger
/// on editable TextFields inside (composer already handles its own undo).
class _WithUndoShortcuts extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onUndo;
  final VoidCallback onFind;

  const _WithUndoShortcuts({
    required this.child,
    required this.onUndo,
    required this.onFind,
  });

  @override
  Widget build(BuildContext context) {
    // Ctrl+Z / Cmd+Z undo is a hardware-keyboard affordance; touch platforms
    // get the plain child without a Shortcuts layer intercepting key events.
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia) {
      return child;
    }
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true): _FindIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true): _FindIntent(),
      },
      child: Actions(
        actions: {
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) async {
              await onUndo();
              return null;
            },
          ),
          _FindIntent: CallbackAction<_FindIntent>(
            onInvoke: (_) {
              onFind();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

/// Parsed `session.context_breakdown` result: total usage plus the optional
/// per-source token categories (system prompt / tools / history / files —
/// desktop parity), used by the context-usage popover.
class ContextUsageSnapshot {
  final double used;
  final double max;
  final double percent;
  final List<Map<String, dynamic>> categories;

  const ContextUsageSnapshot({
    required this.used,
    required this.max,
    required this.percent,
    required this.categories,
  });
}

Color? _parseHexColor(dynamic value) {
  final hex = value?.toString().trim();
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
  final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// A slim colored segment bar plus a scrollable legend list — the mobile
/// take on desktop's `ContextUsagePanel`, which shows the same categories as
/// hover-labeled bar segments; here they're tappable-height rows instead.
class _ContextUsageBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const _ContextUsageBreakdown({required this.categories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackColors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
      theme.colorScheme.outline,
    ];
    final total = categories.fold<double>(
      0,
      (sum, c) => sum + (((c['tokens'] as num?) ?? 0).toDouble()),
    );
    Color colorFor(int index, Map<String, dynamic> category) =>
        _parseHexColor(category['color']) ??
        fallbackColors[index % fallbackColors.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 5,
            child: Row(
              children: [
                for (var i = 0; i < categories.length; i++)
                  Expanded(
                    flex: (((categories[i]['tokens'] as num?) ?? 0) * 1000)
                        .round()
                        .clamp(1, 1 << 30),
                    child: Container(color: colorFor(i, categories[i])),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < categories.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorFor(i, categories[i]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            categories[i]['label']?.toString() ??
                                categories[i]['id']?.toString() ??
                                '',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _ChatScreenState._formatContextLimit(
                            (((categories[i]['tokens'] as num?) ?? 0))
                                .toDouble(),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (total <= 0) const SizedBox.shrink(),
      ],
    );
  }
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _FindIntent extends Intent {
  const _FindIntent();
}
