/// Profile-scoped messaging platform administration.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/external_links.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/profile_scope_selector.dart';

class MessagingScreen extends StatefulWidget {
  final bool embedded;

  const MessagingScreen({super.key, this.embedded = false});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen>
    with ConnectionReloadMixin<MessagingScreen> {
  List<MessagingPlatform> _platforms = const [];
  MessagingPairings _pairings = const MessagingPairings();
  final Set<String> _busyPlatforms = {};
  bool _loading = true;
  bool _restarting = false;
  String? _error;
  String? _loadedProfile;
  Timer? _pollTimer;
  StreamSubscription? _eventSubscription;
  ProfileScopeStore? _scopeStore;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  ApiClient? _loadedApi;

  String? get _profile {
    final scope = _scopeStore;
    final value = (scope?.override ?? scope?.activeProfile)?.trim();
    // Hermes treats an explicit `profile=default` as an isolated profile
    // read, which excludes root WEIXIN_* environment values. Other named
    // profiles still need their explicit scope.
    if (value == null ||
        value.isEmpty ||
        value.toLowerCase() == 'default' ||
        value.toLowerCase() == 'current') {
      return null;
    }
    return value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _handleConnectionChange);
    final scope = context.read<ProfileScopeStore>();
    if (!identical(_scopeStore, scope)) {
      _scopeStore?.removeListener(_onScopeChanged);
      _scopeStore = scope..addListener(_onScopeChanged);
      unawaited(scope.ensureLoaded());
    }
    _eventSubscription ??= context.read<ConnectionStore>().events.listen((
      event,
    ) {
      if (event.type == 'platforms.changed' ||
          event.type == 'pairing.changed') {
        unawaited(_loadData(silent: true));
      }
    });
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 6),
      (_) => unawaited(_loadData(silent: true)),
    );
    if (_loadedProfile == null && _loading) unawaited(_loadData());
  }

  void _handleConnectionChange() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _platforms = const [];
      _pairings = const MessagingPairings();
      _loadedProfile = null;
      _loadedApi = null;
      _busyPlatforms.clear();
      _restarting = false;
      _loading = true;
      _error = null;
    });
    unawaited(_loadData());
  }

  void _onScopeChanged() {
    final profile = _profile;
    if (profile == _loadedProfile) return;
    _mutationGeneration++;
    setState(() {
      _platforms = const [];
      _pairings = const MessagingPairings();
      _loadedApi = null;
      _busyPlatforms.clear();
      _loading = true;
      _error = null;
    });
    unawaited(_loadData());
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _scopeStore?.removeListener(_onScopeChanged);
    _eventSubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    final generation = ++_loadGeneration;
    final api = context.read<ConnectionStore>().api;
    final requestedProfile = _profile;
    if (api == null) {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
          _error = context.l10n.chatServerNotConnected;
        });
      }
      return;
    }
    try {
      final platforms = await api.messagingPlatforms(profile: requestedProfile);
      var pairings = _pairings;
      try {
        pairings = await api.messagingPairings(profile: requestedProfile);
      } catch (_) {
        // Pairing is optional on older gateways. Keep the last known rows; a
        // missing admin endpoint must not hide otherwise configurable channels.
      }
      if (!mounted ||
          generation != _loadGeneration ||
          requestedProfile != _profile ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _platforms = platforms;
        _pairings = pairings;
        _loadedProfile = requestedProfile;
        _loadedApi = api;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!silent &&
          mounted &&
          generation == _loadGeneration &&
          requestedProfile == _profile &&
          identical(api, context.read<ConnectionStore>().api)) {
        setState(() {
          _loading = false;
          _error = context.l10n.messagingLoadFailed('$error');
        });
      }
    }
  }

  Future<void> _togglePlatform(MessagingPlatform platform, bool enabled) async {
    final api = _loadedApi;
    final profile = _loadedProfile;
    if (api == null || !_ownsTarget(api, profile)) return;
    final persistenceFailed = context.l10n.messagingTestNotPassed;
    final generation = _mutationGeneration;
    setState(() => _busyPlatforms.add(platform.id));
    try {
      await api.updateMessagingPlatform(
        platform.id,
        enabled: enabled,
        profile: profile,
      );
      final verified = await api.messagingPlatforms(profile: profile);
      final persisted = verified
          .where((item) => item.id == platform.id)
          .firstOrNull;
      if (persisted == null || persisted.enabled != enabled) {
        throw StateError(persistenceFailed);
      }
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: enabled
              ? context.l10n.messagingPlatformEnabled(platform.displayName)
              : context.l10n.messagingPlatformDisabled(platform.displayName),
          kind: HermesToastKind.success,
        );
      }
      if (generation == _mutationGeneration && _ownsTarget(api, profile)) {
        await _loadData(silent: true);
      }
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        final restart = await _offerRestart(
          enabled
              ? context.l10n.messagingPlatformEnabled(platform.displayName)
              : context.l10n.messagingPlatformDisabled(platform.displayName),
        );
        if (restart && mounted) await _restartGateway(confirm: false);
      }
    } catch (error) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.messagingUpdateFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busyPlatforms.remove(platform.id));
      }
    }
  }

  Future<void> _testPlatform(MessagingPlatform platform) async {
    final api = _loadedApi;
    final profile = _loadedProfile;
    if (api == null || !_ownsTarget(api, profile)) return;
    final generation = _mutationGeneration;
    setState(() => _busyPlatforms.add(platform.id));
    try {
      final result = await api.testMessagingPlatform(
        platform.id,
        profile: profile,
      );
      final ok = result['ok'] == true || result['success'] == true;
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, profile)) {
        return;
      }
      showHermesToast(
        context,
        message: ok
            ? context.l10n.messagingTestPassed(platform.displayName)
            : (result['message'] ??
                      result['error'] ??
                      context.l10n.messagingTestNotPassed)
                  .toString(),
        kind: ok ? HermesToastKind.success : HermesToastKind.error,
      );
      await _loadData(silent: true);
    } catch (error) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.messagingTestFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busyPlatforms.remove(platform.id));
      }
    }
  }

  Future<void> _editPlatform(MessagingPlatform platform) async {
    final connection = context.read<ConnectionStore>();
    final api = _loadedApi;
    final profile = _loadedProfile;
    if (api == null || !_ownsTarget(api, profile)) return;
    final generation = _mutationGeneration;
    final result = await showDialog<_PlatformEdits>(
      context: context,
      builder: (_) => _PlatformConfigDialog(platform: platform),
    );
    if (result == null || !mounted) return;
    if (result.env.isEmpty && result.clearEnv.isEmpty) return;
    final disconnected = context.l10n.backendDisconnected;
    final platformNotFound = context.l10n.errorMessagingPlatformNotFound;
    final persistenceFailed = context.l10n.messagingTestNotPassed;
    setState(() => _busyPlatforms.add(platform.id));
    try {
      requireActiveApi(context, connection, api);
      if (profile != _profile) {
        throw StateError(disconnected);
      }
      await api.updateMessagingPlatform(
        platform.id,
        env: result.env,
        clearEnv: result.clearEnv,
        profile: profile,
      );
      final verified = await api.messagingPlatforms(profile: profile);
      final persisted = verified
          .where((item) => item.id == platform.id)
          .firstOrNull;
      if (persisted == null) {
        throw StateError(platformNotFound);
      }
      for (final key in result.env.keys) {
        final field = persisted.envVars
            .where((item) => item.key == key)
            .firstOrNull;
        if (field == null || !field.isSet) {
          throw StateError('$key: $persistenceFailed');
        }
      }
      for (final key in result.clearEnv) {
        final field = persisted.envVars
            .where((item) => item.key == key)
            .firstOrNull;
        if (field != null && field.isSet) {
          throw StateError('$key: $persistenceFailed');
        }
      }
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, profile)) {
        return;
      }
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.messagingConfigSaved(platform.displayName),
          kind: HermesToastKind.success,
        );
      }
      await _loadData(silent: true);
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        final restart = await _offerRestart(
          context.l10n.messagingConfigSaved(platform.displayName),
        );
        if (restart && mounted) await _restartGateway(confirm: false);
      }
    } catch (error) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.messagingSaveFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busyPlatforms.remove(platform.id));
      }
    }
  }

  Future<bool> _offerRestart(String message) async {
    final restart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.messagingRestartQuestion),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonRestart),
          ),
        ],
      ),
    );
    return restart == true;
  }

  Future<void> _approve(MessagingPairing pairing) async {
    final api = _loadedApi;
    final profile = _loadedProfile;
    if (api == null || !_ownsTarget(api, profile)) return;
    final generation = _mutationGeneration;
    final before = _pairings;
    setState(() {
      _pairings = MessagingPairings(
        pending: before.pending.where((item) => item.id != pairing.id).toList(),
        approved: before.approved,
      );
    });
    try {
      await api.messagingApprovePairing(
        pairing.platform,
        pairing.id,
        profile: profile,
      );
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, profile)) {
        return;
      }
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.messagingApproved(
            pairing.userName ?? pairing.userId,
          ),
          kind: HermesToastKind.success,
        );
      }
      await _loadData(silent: true);
    } catch (error) {
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, profile)) {
        return;
      }
      setState(() => _pairings = before);
      showHermesToast(
        context,
        message: context.l10n.messagingApproveFailed('$error'),
        kind: HermesToastKind.error,
      );
    }
  }

  Future<void> _revoke(MessagingPairing pairing) async {
    final connection = context.read<ConnectionStore>();
    final api = _loadedApi;
    final profile = _loadedProfile;
    if (api == null || !_ownsTarget(api, profile)) return;
    final generation = _mutationGeneration;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.messagingRevokeTitle),
        content: Text(
          context.l10n.messagingRevokeQuestion(
            pairing.userName ?? pairing.userId,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.messagingRevoke),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      requireActiveApi(context, connection, api);
      if (profile != _profile) {
        throw StateError(context.l10n.backendDisconnected);
      }
      await api.messagingRevokePairing(
        pairing.platform,
        pairing.userId,
        profile: profile,
      );
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, profile)) {
        return;
      }
      await _loadData(silent: true);
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, profile)) {
        showHermesToast(
          context,
          message: context.l10n.messagingRevoked,
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.messagingRevokeFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _restartGateway({bool confirm = true}) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final generation = _mutationGeneration;
    final confirmed = !confirm
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.l10n.messagingRestartQuestion),
              content: Text(context.l10n.messagingRestartWarning),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.commonRestart),
                ),
              ],
            ),
          );
    if (confirmed != true || !mounted) return;
    setState(() => _restarting = true);
    try {
      requireActiveApi(context, connection, api);
      await api.restartGateway();
      if (mounted && generation == _mutationGeneration) {
        requireActiveApi(context, connection, api);
        showHermesToast(
          context,
          message: context.l10n.messagingRestarting,
          kind: HermesToastKind.success,
        );
      }
    } catch (error) {
      if (mounted && generation == _mutationGeneration) {
        showHermesToast(
          context,
          message: context.l10n.messagingRestartFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _restarting = false);
      }
    }
  }

  bool _ownsTarget(ApiClient api, String? profile) =>
      identical(context.read<ConnectionStore>().api, api) &&
      identical(_loadedApi, api) &&
      profile == _profile &&
      profile == _loadedProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(context.l10n.messagingTitle),
              actions: [
                IconButton(
                  tooltip: context.l10n.messagingRestartGateway,
                  onPressed: _restarting ? null : _restartGateway,
                  icon: _restarting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt),
                ),
                IconButton(
                  tooltip: context.l10n.commonRefresh,
                  onPressed: _loading ? null : _loadData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return HermesLoadingState(label: context.l10n.messagingLoading);
    }
    if (_error != null) {
      return HermesErrorState(description: _error, onRetry: _loadData);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(HermesSpacing.md),
        children: [
          const ProfileScopeChips(),
          if (widget.embedded)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: context.l10n.messagingRestartGateway,
                onPressed: _restarting ? null : _restartGateway,
                icon: const Icon(Icons.restart_alt),
              ),
            ),
          if (_pairings.pending.isNotEmpty) ...[
            HermesSectionHeader(title: context.l10n.messagingPendingApproval),
            ..._pairings.pending.map(
              (item) => _pairingCard(item, pending: true),
            ),
            const SizedBox(height: HermesSpacing.lg),
          ],
          HermesSectionHeader(title: context.l10n.messagingPlatforms),
          if (_platforms.isEmpty)
            HermesEmptyState(
              icon: Icons.chat_outlined,
              title: context.l10n.messagingEmpty,
              description: context.l10n.messagingEmptyDescription,
            )
          else
            ..._platforms.map(_platformCard),
          if (_pairings.approved.isNotEmpty) ...[
            const SizedBox(height: HermesSpacing.lg),
            HermesSectionHeader(title: context.l10n.messagingAuthorizedUsers),
            ..._pairings.approved.map(
              (item) => _pairingCard(item, pending: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _platformCard(MessagingPlatform platform) {
    final palette = HermesPalette.of(context);
    final busy = _busyPlatforms.contains(platform.id);
    final color = switch (platform.state) {
      'connected' => HermesSemantic.green,
      'fatal' || 'startup_failed' => HermesSemantic.red,
      _ when platform.enabled => HermesSemantic.orange,
      _ => HermesSemantic.gray,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HermesGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(_platformIcon(platform.kind), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platform.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _stateLabel(platform),
                        style: TextStyle(fontSize: 12, color: palette.text3),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: platform.enabled,
                    onChanged: (value) => _togglePlatform(platform, value),
                  ),
              ],
            ),
            if (platform.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                platform.description,
                style: TextStyle(color: palette.text2),
              ),
            ],
            if (platform.homeChannelName != null) ...[
              const SizedBox(height: 6),
              Text(
                context.l10n.chatHomeChannel(platform.homeChannelName!),
                style: TextStyle(fontSize: 12, color: palette.text3),
              ),
            ],
            if (platform.errorMessage?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                platform.errorMessage!,
                style: const TextStyle(color: HermesSemantic.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _editPlatform(platform),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(context.l10n.messagingConfigure),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _testPlatform(platform),
                  icon: const Icon(Icons.network_check, size: 18),
                  label: Text(context.l10n.messagingTest),
                ),
                if (platform.docsUrl != null)
                  IconButton(
                    tooltip: context.l10n.messagingOpenDocs,
                    onPressed: () =>
                        launchExternalOrNotify(context, platform.docsUrl!),
                    icon: const Icon(Icons.open_in_new),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pairingCard(MessagingPairing pairing, {required bool pending}) {
    final palette = HermesPalette.of(context);
    final label =
        pairing.userName ??
        (pairing.userId.isEmpty
            ? pairing.deviceInfo ?? context.l10n.messagingUnknownUser
            : pairing.userId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HermesGlassCard(
        child: Row(
          children: [
            Icon(pending ? Icons.person_add_alt : Icons.verified_user_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${pairing.platform}${pairing.userName != null ? ' · ${pairing.userId}' : ''}',
                    style: TextStyle(fontSize: 12, color: palette.text3),
                  ),
                ],
              ),
            ),
            if (pending)
              FilledButton.icon(
                onPressed: pairing.id.isEmpty ? null : () => _approve(pairing),
                icon: const Icon(Icons.check, size: 18),
                label: Text(context.l10n.messagingApprove),
              )
            else
              IconButton(
                tooltip: context.l10n.messagingRevokeTitle,
                onPressed: pairing.userId.isEmpty
                    ? null
                    : () => _revoke(pairing),
                icon: const Icon(Icons.person_remove_outlined),
              ),
          ],
        ),
      ),
    );
  }

  String _stateLabel(MessagingPlatform platform) {
    if (!platform.enabled) return context.l10n.messagingStateDisabled;
    return switch (platform.state) {
      'connected' =>
        platform.gatewayRunning
            ? context.l10n.commonConnected
            : context.l10n.messagingStateGatewayStopped,
      'fatal' => context.l10n.messagingStateFatal,
      'startup_failed' => context.l10n.messagingStateStartupFailed,
      '' =>
        platform.configured
            ? context.l10n.messagingStateConfigured
            : context.l10n.messagingStateNeedsConfig,
      final value => value.replaceAll('_', ' '),
    };
  }

  IconData _platformIcon(String kind) => switch (kind.toLowerCase()) {
    'telegram' => Icons.send,
    'discord' => Icons.forum,
    'whatsapp' => Icons.phone,
    'bluebubbles' => Icons.message,
    'signal' => Icons.lock,
    'slack' => Icons.business,
    _ => Icons.chat_outlined,
  };
}

class _PlatformEdits {
  final Map<String, String> env;
  final List<String> clearEnv;

  const _PlatformEdits({required this.env, required this.clearEnv});
}

class _PlatformConfigDialog extends StatefulWidget {
  final MessagingPlatform platform;

  const _PlatformConfigDialog({required this.platform});

  @override
  State<_PlatformConfigDialog> createState() => _PlatformConfigDialogState();
}

class _PlatformConfigDialogState extends State<_PlatformConfigDialog> {
  static const _desktopAdvancedKeys = {
    'TELEGRAM_PROXY',
    'DISCORD_REPLY_TO_MODE',
    'DISCORD_ALLOW_ALL_USERS',
    'DISCORD_HOME_CHANNEL',
    'DISCORD_HOME_CHANNEL_NAME',
    'BLUEBUBBLES_ALLOW_ALL_USERS',
    'MATTERMOST_ALLOW_ALL_USERS',
    'MATTERMOST_HOME_CHANNEL',
    'QQ_ALLOW_ALL_USERS',
    'QQBOT_HOME_CHANNEL',
    'QQBOT_HOME_CHANNEL_NAME',
    'WHATSAPP_ENABLED',
    'WHATSAPP_MODE',
  };
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _clear = {};
  final Set<String> _visiblePasswords = {};

  @override
  void initState() {
    super.initState();
    for (final field in widget.platform.envVars) {
      _controllers[field.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final required = widget.platform.envVars
        .where((field) => field.required)
        .toList();
    final recommended = widget.platform.envVars
        .where(
          (field) =>
              !field.required &&
              !field.advanced &&
              !_desktopAdvancedKeys.contains(field.key),
        )
        .toList();
    final advanced = widget.platform.envVars
        .where(
          (field) =>
              !field.required &&
              (field.advanced || _desktopAdvancedKeys.contains(field.key)),
        )
        .toList();
    return AlertDialog(
      title: Text(
        context.l10n.messagingPlatformConfig(widget.platform.displayName),
      ),
      content: SizedBox(
        width: 480,
        child: widget.platform.envVars.isEmpty
            ? Text(context.l10n.messagingNoEditableConfig)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.mcpRequired,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    if (required.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(context.l10n.messagingNoEditableConfig),
                      )
                    else
                      ...required.map(_field),
                    if (recommended.isNotEmpty) ...[
                      Text(
                        context.l10n.mcpOptional,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      ...recommended.map(_field),
                    ],
                    if (advanced.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(context.l10n.messagingAdvancedSettings),
                        children: advanced.map(_field).toList(),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(context.l10n.commonSave),
        ),
      ],
    );
  }

  Widget _field(MessagingEnvVar field) {
    final isCleared = _clear.contains(field.key);
    final showPassword = _visiblePasswords.contains(field.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${field.prompt.isEmpty ? field.key : field.prompt}${field.required ? ' *' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (field.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              field.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 7),
          TextField(
            controller: _controllers[field.key],
            enabled: !isCleared,
            obscureText: field.isPassword && !showPassword,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: field.isSet
                  ? (field.redactedValue ?? context.l10n.messagingSetLeaveBlank)
                  : context.l10n.messagingEnterNewValue,
              suffixIcon: field.isPassword
                  ? IconButton(
                      tooltip: showPassword
                          ? context.l10n.commonHide
                          : context.l10n.messagingShow,
                      onPressed: () => setState(() {
                        showPassword
                            ? _visiblePasswords.remove(field.key)
                            : _visiblePasswords.add(field.key);
                      }),
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    )
                  : null,
            ),
          ),
          if (field.isSet)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: isCleared,
              onChanged: (value) => setState(() {
                value == true
                    ? _clear.add(field.key)
                    : _clear.remove(field.key);
              }),
              title: Text(context.l10n.messagingClearSavedValue),
            ),
        ],
      ),
    );
  }

  void _save() {
    final env = <String, String>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty && !_clear.contains(entry.key)) {
        env[entry.key] = value;
      }
    }
    final missing = widget.platform.envVars.where((field) {
      if (!field.required || _clear.contains(field.key)) return false;
      return !field.isSet && (env[field.key]?.isNotEmpty != true);
    }).toList();
    if (missing.isNotEmpty) {
      final field = missing.first;
      final label = field.prompt.isEmpty ? field.key : field.prompt;
      final requiredMessage = '$label: ${context.l10n.pluginFieldRequired}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(requiredMessage)));
      return;
    }
    Navigator.pop(
      context,
      _PlatformEdits(env: env, clearEnv: _clear.toList(growable: false)),
    );
  }
}
