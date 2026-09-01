library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/external_links.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/profile_scope_selector.dart';
import '../l10n/l10n.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with ConnectionReloadMixin<MemoryScreen> {
  ProfileScopeStore? _scope;
  String? _lastProfile;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _curator;
  String? _error;
  String? _curatorError;
  bool _busy = false;
  int _loadToken = 0;

  String? get _profile => _scope?.override;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForTarget);
    final scope = context.read<ProfileScopeStore>();
    if (identical(scope, _scope)) return;
    _scope?.removeListener(_onScopeChanged);
    _scope = scope..addListener(_onScopeChanged);
    _lastProfile = _profile;
    unawaited(scope.ensureLoaded());
    unawaited(_load());
  }

  void _onScopeChanged() {
    final next = _profile;
    if (next == _lastProfile) return;
    _lastProfile = next;
    _reloadForTarget();
  }

  void _reloadForTarget() {
    if (!mounted) return;
    ++_loadToken;
    setState(() {
      _status = null;
      _curator = null;
      _curatorError = null;
      _error = null;
      _busy = false;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = context.read<ConnectionStore>().api;
    if (api == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = connectionOfflineErrorCode;
        });
      }
      return;
    }
    final token = ++_loadToken;
    final profile = _profile;
    if (mounted && _busy) setState(() => _busy = false);
    try {
      final status = await api.memoryStatus(profile: profile);
      Map<String, dynamic>? curator;
      String? curatorError;
      try {
        curator = await api.curatorStatus();
      } catch (error) {
        curatorError = '$error';
      }
      if (!mounted ||
          token != _loadToken ||
          profile != _profile ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _status = status;
        _curator = curator;
        _curatorError = curatorError;
        _error = null;
      });
    } catch (error) {
      if (!mounted ||
          token != _loadToken ||
          profile != _profile ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() => _error = '$error');
    }
  }

  Future<void> _selectProvider(String name) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    setState(() => _busy = true);
    try {
      await api.memorySetProvider(name, profile: profile);
      if (mounted && identical(api, connection.api) && profile == _profile) {
        await _load();
      }
    } catch (error) {
      if (mounted && identical(api, connection.api) && profile == _profile) {
        showHermesToast(
          context,
          message: context.l10n.memorySwitchFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && identical(api, connection.api) && profile == _profile) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _configureProvider(String name) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _MemoryProviderSheet(api: api, provider: name, profile: _profile),
    );
    if (changed == true &&
        mounted &&
        identical(api, connection.api) &&
        profile == _profile) {
      await _load();
    }
  }

  Future<void> _reset() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    final target = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.l10n.memoryResetScope),
              subtitle: Text(context.l10n.memoryResetScopeDescription),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(context.l10n.memoryAll),
              subtitle: Text(context.l10n.memoryAllFiles),
              onTap: () => Navigator.pop(ctx, 'all'),
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: Text(context.l10n.memoryLongTerm),
              subtitle: Text(context.l10n.memoryLongTermFile),
              onTap: () => Navigator.pop(ctx, 'memory'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(context.l10n.memoryUser),
              subtitle: Text(context.l10n.memoryUserFile),
              onTap: () => Navigator.pop(ctx, 'user'),
            ),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    if (!identical(api, connection.api) || profile != _profile) {
      showHermesToast(
        context,
        message: context.l10n.backendDisconnected,
        kind: HermesToastKind.error,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.memoryResetQuestion),
        content: Text(context.l10n.memoryResetWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.commonReset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!identical(api, connection.api) || profile != _profile) {
      showHermesToast(
        context,
        message: context.l10n.backendDisconnected,
        kind: HermesToastKind.error,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await api.memoryReset(target: target, profile: profile);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      if (profile != _profile) {
        throw StateError(context.l10n.backendDisconnected);
      }
      await _load();
      if (!mounted) return;
      final deleted = (result['deleted'] as List? ?? const []).join('、');
      showHermesToast(
        context,
        message: deleted.isEmpty
            ? context.l10n.memoryNothingDeleted
            : context.l10n.memoryDeleted(deleted),
        kind: HermesToastKind.success,
      );
    } catch (error) {
      if (mounted && identical(api, connection.api) && profile == _profile) {
        showHermesToast(
          context,
          message: context.l10n.memoryResetFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && identical(api, connection.api) && profile == _profile) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setCuratorPaused(bool paused) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    setState(() => _busy = true);
    try {
      final result = await api.setCuratorPaused(paused);
      if (!mounted || !identical(api, connection.api) || profile != _profile) {
        return;
      }
      setState(() => _curator = {...?_curator, ...result});
    } catch (error) {
      if (mounted && identical(api, connection.api) && profile == _profile) {
        showHermesToast(
          context,
          message: context.l10n.memoryCuratorUpdateFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && identical(api, connection.api) && profile == _profile) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _runCurator() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final profile = _profile;
    setState(() => _busy = true);
    try {
      await api.runCurator();
      if (mounted && identical(api, connection.api) && profile == _profile) {
        showHermesToast(
          context,
          message: context.l10n.memoryCuratorStarted,
          kind: HermesToastKind.success,
        );
      }
      if (mounted && identical(api, connection.api) && profile == _profile) {
        await _load();
      }
    } catch (error) {
      if (mounted && identical(api, connection.api) && profile == _profile) {
        showHermesToast(
          context,
          message: context.l10n.memoryCuratorRunFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && identical(api, connection.api) && profile == _profile) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.memoryTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final status = _status;
    if (status == null && _error == null) {
      return HermesLoadingState(label: context.l10n.memoryLoading);
    }
    if (status == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    final active = (status['active'] ?? '').toString();
    final providers = (status['providers'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .toList();
    final builtin =
        (status['builtin_files'] as Map?)?.cast<String, dynamic>() ?? {};
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
          const ProfileScopeChips(),
          HermesGlassCard(
            radius: HermesRadius.largeCard,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.memory_outlined, color: HermesSemantic.purple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.memoryCurrentProvider,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        active.isEmpty ? context.l10n.memoryDisabled : active,
                        style: HermesType.onSurface(
                          HermesType.headline,
                          Theme.of(context),
                        ),
                      ),
                    ],
                  ),
                ),
                HermesStatusChip(
                  color: active.isEmpty
                      ? HermesSemantic.gray
                      : HermesSemantic.green,
                  label: active.isEmpty
                      ? context.l10n.memoryDisabled
                      : context.l10n.memoryEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: HermesSpacing.lg),
          HermesSectionHeader(title: context.l10n.memoryProviders),
          if (providers.isEmpty)
            HermesEmptyState(
              icon: Icons.extension_off_outlined,
              title: context.l10n.memoryNoProviders,
            )
          else
            HermesMobileGroup(
              children: [
                for (final provider in providers)
                  _providerRow(provider, active),
              ],
            ),
          const SizedBox(height: HermesSpacing.lg),
          _curatorCard(),
          const SizedBox(height: HermesSpacing.lg),
          HermesSectionHeader(title: context.l10n.memoryBuiltInFiles),
          HermesMobileGroup(
            children: [
              HermesMobileRow(
                icon: Icons.psychology_outlined,
                title: 'MEMORY.md',
                trailing: Text(
                  context.l10n.commonBytes(builtin['memory'] ?? 0),
                ),
              ),
              HermesMobileRow(
                icon: Icons.person_outline,
                title: 'USER.md',
                trailing: Text(context.l10n.commonBytes(builtin['user'] ?? 0)),
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.md),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: HermesSemantic.red,
            ),
            onPressed: _busy ? null : _reset,
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(context.l10n.memoryReset),
          ),
        ],
      ),
    );
  }

  Widget _providerRow(Map<String, dynamic> provider, String active) {
    final name = (provider['name'] ?? '').toString();
    final description = (provider['description'] ?? '').toString();
    final status = (provider['status'] ?? '').toString();
    final available = provider['available'] != false && status != 'unavailable';
    final configured = provider['configured'] == true;
    final selected = name == active;
    return HermesMobileRow(
      icon: Icons.storage_outlined,
      tone: selected ? HermesSemantic.green : HermesSemantic.gray,
      title: name,
      subtitle: description,
      onTap: name.isEmpty ? null : () => _configureProvider(name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            HermesMobileStatusChip(
              color: HermesSemantic.green,
              label: context.l10n.memoryInUse,
            )
          else if (configured)
            HermesMobileStatusChip(
              color: HermesSemantic.blue,
              label: context.l10n.memoryConfigured,
            ),
          IconButton(
            tooltip: context.l10n.memoryConfigureProvider(name),
            onPressed: name.isEmpty ? null : () => _configureProvider(name),
            icon: const Icon(Icons.tune, size: 19),
          ),
          if (!selected)
            IconButton(
              tooltip: context.l10n.memoryEnableProvider(name),
              onPressed: _busy || !available
                  ? null
                  : () => _selectProvider(name),
              icon: const Icon(Icons.check_circle_outline, size: 19),
            ),
        ],
      ),
    );
  }

  Widget _curatorCard() {
    final curator = _curator;
    if (curator == null) {
      return HermesGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.auto_fix_high_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _curatorError == null
                    ? context.l10n.memoryCuratorLoading
                    : context.l10n.memoryCuratorUnavailable,
              ),
            ),
            if (_curatorError != null)
              IconButton(
                tooltip: _curatorError,
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      );
    }
    final enabled = curator['enabled'] == true;
    final paused = curator['paused'] == true;
    final interval = curator['interval_hours'];
    final lastRun = curator['last_run_at']?.toString();
    return HermesGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.memoryCuratorTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              HermesStatusChip(
                color: !enabled || paused
                    ? HermesSemantic.gray
                    : HermesSemantic.green,
                label: !enabled
                    ? context.l10n.memoryDisabled
                    : paused
                    ? context.l10n.memoryPaused
                    : context.l10n.commonRunning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (interval != null)
                context.l10n.memoryCuratorInterval('$interval'),
              if (lastRun != null && lastRun.isNotEmpty)
                context.l10n.memoryCuratorLastRun(lastRun),
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || !enabled
                      ? null
                      : () => _setCuratorPaused(!paused),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(
                    paused
                        ? context.l10n.memoryResume
                        : context.l10n.memoryPause,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || !enabled ? null : _runCurator,
                  icon: const Icon(Icons.bolt),
                  label: Text(context.l10n.memoryRunNow),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _scope?.removeListener(_onScopeChanged);
    super.dispose();
  }
}

class _MemoryProviderSheet extends StatefulWidget {
  final ApiClient api;
  final String provider;
  final String? profile;

  const _MemoryProviderSheet({
    required this.api,
    required this.provider,
    required this.profile,
  });

  @override
  State<_MemoryProviderSheet> createState() => _MemoryProviderSheetState();
}

class _MemoryProviderSheetState extends State<_MemoryProviderSheet>
    with ConnectionReloadMixin<_MemoryProviderSheet> {
  Map<String, dynamic>? _config;
  Map<String, dynamic>? _oauth;
  final Map<String, TextEditingController> _controllers = {};
  String? _configError;
  String? _oauthError;
  bool _oauthSupported = true;
  bool _saving = false;
  bool _pollInFlight = false;
  Timer? _poller;
  DateTime? _pollDeadline;
  ProfileScopeStore? _scopeStore;
  int _loadGeneration = 0;

  bool _ownsTarget() {
    return mounted &&
        identical(widget.api, context.read<ConnectionStore>().api) &&
        widget.profile == context.read<ProfileScopeStore>().override;
  }

  void _requireTarget() {
    requireActiveApi(context, context.read<ConnectionStore>(), widget.api);
    if (widget.profile != context.read<ProfileScopeStore>().override) {
      throw StateError(context.l10n.backendDisconnected);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _handleTargetChange);
    final scope = context.read<ProfileScopeStore>();
    if (identical(scope, _scopeStore)) return;
    _scopeStore?.removeListener(_handleTargetChange);
    _scopeStore = scope..addListener(_handleTargetChange);
  }

  void _handleTargetChange() {
    if (!mounted) return;
    ++_loadGeneration;
    _poller?.cancel();
    if (_ownsTarget()) {
      unawaited(_load());
      return;
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    setState(() {
      _config = null;
      _oauth = null;
      _saving = false;
      _configError = context.l10n.backendDisconnected;
      _oauthError = null;
    });
  }

  Future<void> _load() async {
    if (!_ownsTarget()) return;
    final generation = ++_loadGeneration;
    try {
      final config = await widget.api.memoryProviderConfig(
        widget.provider,
        profile: widget.profile,
      );
      if (_ownsTarget() && generation == _loadGeneration) {
        for (final controller in _controllers.values) {
          controller.dispose();
        }
        _controllers.clear();
        for (final field
            in (config['fields'] as List? ?? const []).whereType<Map>()) {
          final key = field['key']?.toString() ?? '';
          if (key.isEmpty) continue;
          final secret = field['kind'] == 'secret';
          _controllers[key] = TextEditingController(
            text: secret ? '' : field['value']?.toString() ?? '',
          );
        }
        setState(() {
          _config = config;
          _configError = null;
        });
      }
    } catch (error) {
      if (_ownsTarget() && generation == _loadGeneration) {
        setState(() => _configError = '$error');
      }
    }
    try {
      final oauth = await widget.api.memoryProviderOAuthStatus(
        widget.provider,
        profile: widget.profile,
      );
      if (!_ownsTarget() || generation != _loadGeneration) return;
      setState(() {
        _oauth = oauth;
        _oauthSupported = true;
        _oauthError = null;
      });
      if (oauth['state'] == 'pending') _startPolling();
    } on ApiException catch (error) {
      if (!_ownsTarget() || generation != _loadGeneration) return;
      setState(() {
        _oauthSupported = error.statusCode != 404;
        _oauthError = error.statusCode == 404 ? null : '$error';
      });
    } catch (error) {
      if (_ownsTarget() && generation == _loadGeneration) {
        setState(() => _oauthError = '$error');
      }
    }
  }

  List<Map<String, dynamic>> get _fields =>
      (_config?['fields'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value.cast<String, dynamic>())
          .toList();

  Future<void> _save() async {
    if (!_ownsTarget()) return;
    final values = <String, String>{};
    for (final field in _fields) {
      final key = field['key']?.toString() ?? '';
      final value = _controllers[key]?.text ?? '';
      if (field['kind'] == 'secret' && value.trim().isEmpty) continue;
      if (field['kind'] == 'json' && value.trim().isNotEmpty) {
        try {
          jsonDecode(value);
        } catch (_) {
          showHermesToast(
            context,
            message: context.l10n.memoryInvalidJson('${field['label'] ?? key}'),
            kind: HermesToastKind.error,
          );
          return;
        }
      }
      values[key] = value;
    }
    setState(() => _saving = true);
    try {
      _requireTarget();
      await widget.api.saveMemoryProviderConfig(
        widget.provider,
        values,
        profile: widget.profile,
      );
      _requireTarget();
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.memoryProviderSaved,
        kind: HermesToastKind.success,
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (_ownsTarget()) {
        showHermesToast(
          context,
          message: context.l10n.memoryProviderSaveFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (_ownsTarget()) setState(() => _saving = false);
    }
  }

  Future<void> _connect() async {
    if (!_ownsTarget()) return;
    setState(() {
      _saving = true;
      _oauthError = null;
    });
    try {
      _requireTarget();
      final result = await widget.api.startMemoryProviderOAuth(
        widget.provider,
        profile: widget.profile,
      );
      _requireTarget();
      if (!mounted) return;
      setState(() => _oauth = result);
      final rawUrl =
          result['authorization_url'] ??
          result['verification_url'] ??
          result['url'];
      final uri = Uri.tryParse(rawUrl?.toString() ?? '');
      if (uri != null && uri.hasScheme) {
        if (!await launchExternalOrNotify(context, uri)) return;
      }
      if (!_ownsTarget()) return;
      _startPolling();
    } catch (error) {
      if (_ownsTarget()) setState(() => _oauthError = '$error');
    } finally {
      if (_ownsTarget()) setState(() => _saving = false);
    }
  }

  void _startPolling() {
    _pollDeadline = DateTime.now().add(const Duration(minutes: 2));
    _poller?.cancel();
    _poller = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => unawaited(_pollOAuth()),
    );
  }

  Future<void> _pollOAuth() async {
    if (_pollInFlight || !_ownsTarget()) return;
    if (DateTime.now().isAfter(_pollDeadline ?? DateTime.now())) {
      _poller?.cancel();
      if (mounted) {
        setState(() => _oauthError = context.l10n.memoryOAuthTimeout);
      }
      return;
    }
    _pollInFlight = true;
    try {
      final next = await widget.api.memoryProviderOAuthStatus(
        widget.provider,
        profile: widget.profile,
      );
      if (!_ownsTarget()) return;
      setState(() => _oauth = next);
      if (next['state'] != 'pending') _poller?.cancel();
    } catch (error) {
      if (_ownsTarget()) setState(() => _oauthError = '$error');
    } finally {
      _pollInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          ListTile(
            title: Text(config?['label']?.toString() ?? widget.provider),
            subtitle: widget.profile == null
                ? Text(context.l10n.memoryCurrentProfile)
                : Text(context.l10n.memoryProfile(widget.profile!)),
            trailing: IconButton(
              tooltip: context.l10n.commonClose,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: config == null && _configError == null
                ? HermesLoadingState(
                    label: context.l10n.memoryProviderConfigLoading,
                  )
                : ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_configError != null)
                        HermesErrorState(
                          description: _configError,
                          onRetry: _load,
                        ),
                      if (_oauthSupported) _oauthCard(),
                      if (_oauthSupported) const SizedBox(height: 16),
                      for (final field in _fields) ...[
                        _fieldControl(field),
                        const SizedBox(height: 14),
                      ],
                      if (_fields.isEmpty && _configError == null)
                        HermesEmptyState(
                          icon: Icons.tune,
                          title: context.l10n.memoryNoProviderConfig,
                        ),
                      if ((config?['docs_url']?.toString() ?? '').isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            final uri = Uri.tryParse(
                              config!['docs_url'].toString(),
                            );
                            if (uri != null) {
                              unawaited(launchExternalOrNotify(context, uri));
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: Text(context.l10n.memoryViewProviderDocs),
                        ),
                    ],
                  ),
          ),
          if (_fields.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _saving
                          ? context.l10n.memorySaving
                          : context.l10n.memorySaveConfig,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _oauthCard() {
    final oauth = _oauth;
    final connected = oauth?['connected'] == true;
    final state = oauth?['state']?.toString() ?? 'idle';
    final detail = oauth?['detail']?.toString() ?? '';
    return HermesGlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            connected ? Icons.verified_user_outlined : Icons.link,
            color: connected ? HermesSemantic.green : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected
                      ? context.l10n.memoryAccountConnected
                      : context.l10n.memoryConnectAccount,
                ),
                if (_oauthError != null)
                  Text(
                    _oauthError!,
                    style: const TextStyle(color: HermesSemantic.red),
                  )
                else if (detail.isNotEmpty)
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (state == 'pending')
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _saving ? null : _connect,
              child: Text(
                connected
                    ? context.l10n.memoryReconnect
                    : context.l10n.memoryConnect,
              ),
            ),
        ],
      ),
    );
  }

  Widget _fieldControl(Map<String, dynamic> field) {
    final key = field['key']?.toString() ?? '';
    final kind = field['kind']?.toString() ?? 'text';
    final label = field['label']?.toString() ?? key;
    final description = field['description']?.toString() ?? '';
    final controller = _controllers.putIfAbsent(key, TextEditingController.new);
    if (kind == 'bool') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: description.isEmpty ? null : Text(description),
        value: controller.text == 'true',
        onChanged: (value) => setState(() => controller.text = '$value'),
      );
    }
    if (kind == 'select') {
      final options = (field['options'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value.cast<String, dynamic>())
          .toList();
      final values = options
          .map((option) => option['value']?.toString() ?? '')
          .toSet();
      return DropdownButtonFormField<String>(
        initialValue: values.contains(controller.text) ? controller.text : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: description.isEmpty ? null : description,
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option['value']?.toString() ?? '',
              child: Text(option['label']?.toString() ?? ''),
            ),
        ],
        onChanged: (value) => controller.text = value ?? '',
      );
    }
    return TextField(
      controller: controller,
      obscureText: kind == 'secret',
      keyboardType: kind == 'number'
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      minLines: kind == 'json' ? 3 : 1,
      maxLines: kind == 'json' ? 8 : 1,
      decoration: InputDecoration(
        labelText: label,
        helperText: description.isEmpty ? null : description,
        hintText: kind == 'secret' && field['is_set'] == true
            ? context.l10n.memoryKeepSecretHint
            : field['placeholder']?.toString(),
      ),
    );
  }

  @override
  void dispose() {
    ++_loadGeneration;
    disposeConnectionObserver();
    _scopeStore?.removeListener(_handleTargetChange);
    _poller?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
