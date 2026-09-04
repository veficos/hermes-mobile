library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/connections/connection_registry.dart';
import '../core/external_links.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/hermes_adaptive_menu.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

const _exampleProviderEndpoint = 'https://api.example.com/v1';

/// Provider-facing configuration that is not part of the ordinary Config
/// document: process env, OpenAI-compatible endpoints, OAuth and toolsets.
class ProviderConfigScreen extends StatefulWidget {
  final bool embedded;
  const ProviderConfigScreen({super.key, this.embedded = false});

  @override
  State<ProviderConfigScreen> createState() => _ProviderConfigScreenState();
}

class _ProviderConfigScreenState extends State<ProviderConfigScreen>
    with ConnectionReloadMixin<ProviderConfigScreen> {
  ConnectionId? _connectionId;
  ConnectionId? _lastActiveConnectionId;
  String? _profile;
  List<ProfileInfo> _profiles = const [];
  Map<String, dynamic> _env = const {};
  List<dynamic> _endpoints = const [];
  List<dynamic> _oauth = const [];
  List<ToolsetInfo> _toolsets = const [];
  bool _loading = true;
  bool _profileInitialized = false;
  int _loadGeneration = 0, _oauthGeneration = 0;
  String? _oauthSessionId;
  ApiClient? _oauthApi;
  String? _oauthProfile;
  String _busy = '';
  String? _error;

  ConnectionStore get _store => context.read<ConnectionStore>();
  ConnectionRuntime? get _runtime =>
      _store.registry.runtime(_connectionId ?? _store.activeConnectionId);
  ApiClient? get _api {
    final runtime = _runtime;
    if (runtime != null) return runtime.api;
    return _connectionId == _store.activeConnectionId ? _store.api : null;
  }

  ApiClient? _apiOrNotify() {
    final api = _api;
    if (api != null) return api;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(context.l10n.backendDisconnected)));
    return null;
  }

  ProfileScopeStore? _scopeStore;
  bool get _viewingActiveConnection =>
      _connectionId == _store.activeConnectionId;

  @override
  void initState() {
    super.initState();
    _connectionId = context.read<ConnectionStore>().activeConnectionId;
    _lastActiveConnectionId = _connectionId;
    final scopeStore = context.read<ProfileScopeStore>();
    observeConnection(_store, _onActiveConnectionChanged);
    _scopeStore = scopeStore;
    if (scopeStore.override != null) {
      _profile = scopeStore.override;
      _profileInitialized = true;
    }
    scopeStore.addListener(_onScopeChanged);
    _load();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _oauthGeneration++;
    disposeConnectionObserver();
    _scopeStore?.removeListener(_onScopeChanged);
    super.dispose();
  }

  void _onActiveConnectionChanged() {
    final next = _store.activeConnectionId;
    final wasFollowing = _connectionId == _lastActiveConnectionId;
    final connectionChanged = next != _lastActiveConnectionId;
    _lastActiveConnectionId = next;
    if (!mounted || !wasFollowing) return;
    ++_loadGeneration;
    ++_oauthGeneration;
    setState(() {
      _connectionId = next;
      _busy = '';
      _error = null;
      if (connectionChanged) {
        _profile = _scopeStore?.override;
        _profileInitialized = _profile != null;
        _profiles = const [];
        _env = const {};
        _endpoints = const [];
        _oauth = const [];
        _toolsets = const [];
      }
    });
    _load(preserveProfile: !connectionChanged);
  }

  bool _ownsTarget(ApiClient api, ConnectionId? connectionId, String? profile) {
    return mounted &&
        connectionId == _connectionId &&
        profile == _profile &&
        identical(api, _api);
  }

  void _requireTarget(
    ApiClient api,
    ConnectionId? connectionId,
    String? profile,
  ) {
    if (!_ownsTarget(api, connectionId, profile)) {
      throw StateError(context.l10n.backendDisconnected);
    }
  }

  void _onScopeChanged() {
    if (!mounted || !_viewingActiveConnection) return;
    final scopeStore = _scopeStore;
    if (scopeStore == null || scopeStore.override == _profile) return;
    setState(() {
      _profile = scopeStore.override;
      _profileInitialized = true;
    });
    _load();
  }

  List<dynamic> _items(dynamic value, String key) {
    if (value is List) return value;
    if (value is Map && value[key] is List) return value[key] as List;
    if (value is Map) {
      return value.entries
          .map((e) => {'id': '${e.key}', 'name': '${e.key}', 'value': e.value})
          .toList();
    }
    return const [];
  }

  Future<void> _load({bool preserveProfile = true}) async {
    final api = _api;
    if (!mounted) return;
    if (api == null) {
      setState(() {
        _loading = false;
        _error = context.l10n.backendDisconnected;
      });
      return;
    }
    final generation = ++_loadGeneration;
    final connectionId = _connectionId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileData = await api.listProfiles();
      final profile = preserveProfile && _profileInitialized
          ? _profile
          : profileData.active;
      final values = await Future.wait([
        api.providerEnvVars(profile: profile),
        api.customEndpoints(profile: profile),
        api.oauthProviders(profile: profile),
        api.toolsets(profile: profile),
      ]);
      if (!mounted ||
          generation != _loadGeneration ||
          connectionId != _connectionId ||
          !identical(api, _api)) {
        return;
      }
      setState(() {
        _profile = profile;
        _profileInitialized = true;
        _profiles = profileData.profiles;
        _env = (values[0] as Map).cast<String, dynamic>();
        _endpoints = _items(values[1], 'endpoints');
        _oauth = _items(values[2], 'providers');
        _toolsets = values[3] as List<ToolsetInfo>;
        _loading = false;
      });
      if (_viewingActiveConnection) {
        await _scopeStore?.updateProfiles(profileData);
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          connectionId == _connectionId &&
          identical(api, _api)) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<String?> _textDialog(
    String title, {
    String initial = '',
    int lines = 1,
  }) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: initial);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final result = compact
        ? await showMobileSheet<String>(
            context,
            (context) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: lines,
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.commonCancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
                          child: Text(l10n.commonConfirm),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        : await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                maxLines: lines,
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: Text(l10n.commonConfirm),
                ),
              ],
            ),
          );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  void _showActionError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.providerActionFailed('$e'))),
    );
  }

  Future<void> _addEnv() async {
    final l10n = context.l10n;
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    final key = await _textDialog(l10n.providerEnvironmentVariableName);
    if (key == null || key.trim().isEmpty || !mounted) return;
    if (!_ownsTarget(api, connectionId, profile)) {
      _showActionError(StateError(l10n.backendDisconnected));
      return;
    }
    final value = await _textDialog(l10n.providerEnvironmentVariableValue);
    if (value == null) return;
    if (!_ownsTarget(api, connectionId, profile)) {
      _showActionError(StateError(l10n.backendDisconnected));
      return;
    }
    setState(() => _busy = 'env:${key.trim()}');
    try {
      await api.setProviderEnvVar(key.trim(), value, profile: profile);
      _requireTarget(api, connectionId, profile);
      await _load();
    } catch (e) {
      _showActionError(e);
    } finally {
      if (_ownsTarget(api, connectionId, profile)) setState(() => _busy = '');
    }
  }

  Future<void> _deleteEnv(String key) async {
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    setState(() => _busy = 'env:$key');
    try {
      await api.deleteProviderEnvVar(key, profile: profile);
      _requireTarget(api, connectionId, profile);
      await _load();
    } catch (e) {
      _showActionError(e);
    } finally {
      if (_ownsTarget(api, connectionId, profile)) setState(() => _busy = '');
    }
  }

  Future<void> _editEnv(String key) async {
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    final value = await _textDialog(
      context.l10n.providerSetEnvironmentVariable(key),
    );
    if (value == null || !mounted) return;
    if (!_ownsTarget(api, connectionId, profile)) {
      _showActionError(StateError(context.l10n.backendDisconnected));
      return;
    }
    setState(() => _busy = 'env:$key');
    try {
      await api.setProviderEnvVar(key, value, profile: profile);
      _requireTarget(api, connectionId, profile);
      await _load();
    } catch (e) {
      _showActionError(e);
    } finally {
      if (_ownsTarget(api, connectionId, profile)) setState(() => _busy = '');
    }
  }

  Future<void> _editEndpoint([Map<String, dynamic>? current]) async {
    final validationFailed = context.l10n.providerEndpointValidationFailed;
    final disconnected = context.l10n.backendDisconnected;
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final value = compact
        ? await showMobileSheet<Map<String, dynamic>>(
            context,
            (_) => _CustomEndpointDialog(current: current, compact: true),
          )
        : await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => _CustomEndpointDialog(current: current),
          );
    if (value == null) return;
    if (!_ownsTarget(api, connectionId, profile)) {
      _showActionError(StateError(disconnected));
      return;
    }
    try {
      final validation = await api.validateCustomEndpoint(
        value,
        profile: profile,
      );
      if (validation['ok'] != true) {
        throw ApiException(
          422,
          validation['message']?.toString() ?? validationFailed,
          validation,
        );
      }
      _requireTarget(api, connectionId, profile);
      await api.saveCustomEndpoint(value, profile: profile);
      _requireTarget(api, connectionId, profile);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.configSaveFailed('$e'))),
        );
      }
    }
  }

  Future<void> _revealEnv(String key) async {
    final l10n = context.l10n;
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    try {
      final value = await api.revealProviderEnvVar(key, profile: profile);
      if (!_ownsTarget(api, connectionId, profile) || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.providerRevealedValueTitle),
          content: SelectableText(
            value ?? '',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.providerRevealFailed('$e'))));
    }
  }

  Future<void> _oauthStart(Map<String, dynamic> row) async {
    final provider = '${row['id'] ?? row['name'] ?? row['provider'] ?? ''}';
    if (provider.isEmpty) return;
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    final generation = ++_oauthGeneration;
    _oauthApi = api;
    _oauthProfile = profile;
    setState(() => _busy = 'oauth:$provider');
    try {
      final result = await api.startProviderOAuth(provider, profile: profile);
      _requireTarget(api, connectionId, profile);
      final url =
          '${result['auth_url'] ?? result['verification_url'] ?? result['authorization_url'] ?? result['url'] ?? ''}';
      if (url.isNotEmpty) {
        if (!mounted) return;
        final opened = await launchExternalOrNotify(context, Uri.parse(url));
        if (!opened) return;
        _requireTarget(api, connectionId, profile);
      }
      final session = '${result['session_id'] ?? ''}';
      _oauthSessionId = session.isEmpty ? null : session;
      if (result['requires_code'] == true && mounted) {
        final code = await _textDialog(context.l10n.providerPasteOauthCode);
        if (code != null && code.isNotEmpty) {
          _requireTarget(api, connectionId, profile);
          await api.submitProviderOAuth(provider, {
            'code': code,
            if (session.isNotEmpty) 'session_id': session,
          }, profile: profile);
        }
      } else if (session.isNotEmpty) {
        final userCode = '${result['user_code'] ?? ''}';
        if (userCode.isNotEmpty && mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.l10n.providerDeviceAuthorization),
              content: SelectableText(
                context.l10n.providerEnterDeviceCode(userCode),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.commonDone),
                ),
              ],
            ),
          );
          _requireTarget(api, connectionId, profile);
        }
        final interval = Duration(
          seconds: ((result['poll_interval'] as num?)?.toInt() ?? 3).clamp(
            1,
            10,
          ),
        );
        for (var attempt = 0; attempt < 40; attempt++) {
          if (generation != _oauthGeneration ||
              !_ownsTarget(api, connectionId, profile)) {
            return;
          }
          final state = await api.pollProviderOAuth(
            provider,
            session,
            profile: profile,
          );
          final status = '${state['status'] ?? ''}';
          if (status != 'pending') break;
          await Future<void>.delayed(interval);
        }
      }
      if (generation == _oauthGeneration &&
          _ownsTarget(api, connectionId, profile)) {
        _oauthSessionId = null;
        _oauthApi = null;
        _oauthProfile = null;
        await _load();
      }
    } catch (e) {
      if (generation == _oauthGeneration) _showActionError(e);
    } finally {
      if (generation == _oauthGeneration &&
          _ownsTarget(api, connectionId, profile)) {
        setState(() => _busy = '');
      }
    }
  }

  Future<void> _cancelOAuth() async {
    final session = _oauthSessionId;
    final api = _oauthApi;
    final profile = _oauthProfile;
    _oauthGeneration++;
    _oauthSessionId = null;
    _oauthApi = null;
    _oauthProfile = null;
    if (mounted) setState(() => _busy = '');
    if (session != null && api != null) {
      try {
        await api.cancelProviderOAuthSession(session, profile: profile);
      } catch (e) {
        _showActionError(e);
      }
    }
  }

  Future<void> _disconnectOAuth(Map<String, dynamic> row) async {
    final provider = '${row['id'] ?? row['name'] ?? ''}';
    if (provider.isEmpty) return;
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    _oauthGeneration++;
    setState(() => _busy = 'oauthDisconnect:$provider');
    try {
      await api.disconnectProviderOAuth(provider, profile: profile);
      _requireTarget(api, connectionId, profile);
      await _load();
    } catch (e) {
      _showActionError(e);
    } finally {
      if (_ownsTarget(api, connectionId, profile)) setState(() => _busy = '');
    }
  }

  Future<void> _configureToolset(ToolsetInfo toolset) async {
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    setState(() => _busy = 'toolset:${toolset.name}');
    try {
      await _configureToolsetInner(
        api,
        toolset,
        connectionId: connectionId,
        profile: profile,
      );
    } catch (e) {
      _showActionError(e);
    } finally {
      if (_ownsTarget(api, connectionId, profile)) setState(() => _busy = '');
    }
  }

  Future<void> _configureToolsetInner(
    ApiClient api,
    ToolsetInfo toolset, {
    required ConnectionId? connectionId,
    required String? profile,
  }) async {
    final config = await api.toolsetConfig(toolset.name, profile: profile);
    _requireTarget(api, connectionId, profile);
    final providers = _items(config['providers'], 'providers');
    if (!mounted) return;
    final providerChoices = providers.map((raw) {
      final row = raw is Map ? raw : const {};
      final name = '${row['id'] ?? row['name'] ?? raw}';
      final status = '${row['status'] ?? ''}';
      final keys = (row['env_vars'] as List? ?? const [])
          .whereType<Map>()
          .where((env) => env['is_set'] != true)
          .map((env) => '${env['key'] ?? ''}')
          .where((key) => key.isNotEmpty)
          .join(', ');
      return (
        value: name,
        label: name,
        subtitle: [
          if (status.isNotEmpty) status,
          if (keys.isNotEmpty) context.l10n.providerMissingKeys(keys),
        ].join(' · '),
        selected: row['is_active'] == true,
      );
    }).toList();
    final provider = await _chooseOption(
      context.l10n.providerToolsetProviderTitle(toolset.name),
      providerChoices,
    );
    if (provider != null) {
      _requireTarget(api, connectionId, profile);
      await api.selectToolsetProvider(toolset.name, provider, profile: profile);
      final selected = providers.whereType<Map>().firstWhere(
        (row) => '${row['id'] ?? row['name']}' == provider,
        orElse: () => const {},
      );
      final postSetup = '${selected['post_setup'] ?? ''}';
      if (postSetup.isNotEmpty && mounted) {
        final run = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.providerRunSetupQuestion),
            content: Text(
              context.l10n.providerRunSetupDescription(provider, postSetup),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.commonLater),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.commonRun),
              ),
            ],
          ),
        );
        if (run == true) {
          _requireTarget(api, connectionId, profile);
          await api.runToolsetPostSetup(
            toolset.name,
            postSetup,
            profile: profile,
          );
        }
      }
      final catalog = await api.toolsetModels(
        toolset.name,
        provider: provider,
        profile: profile,
      );
      final models = (catalog['models'] as List? ?? const [])
          .map((row) => row is Map ? '${row['id'] ?? row['name']}' : '$row')
          .where((name) => name.isNotEmpty)
          .toList();
      if (models.isNotEmpty && mounted) {
        final model =
            await _chooseOption(context.l10n.providerModelTitle(provider), [
              for (final name in models)
                (value: name, label: name, subtitle: '', selected: false),
            ]);
        if (model != null) {
          _requireTarget(api, connectionId, profile);
          await api.selectToolsetModel(
            toolset.name,
            model,
            provider: provider,
            profile: profile,
          );
        }
      }
      _requireTarget(api, connectionId, profile);
      await _load();
    }
  }

  Future<String?> _chooseOption(
    String title,
    List<({String value, String label, String subtitle, bool selected})>
    choices,
  ) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return showMobileSheet<String>(
        context,
        (context) => _MobileChoiceSheet<String>(
          title: title,
          current: choices
              .where((choice) => choice.selected)
              .firstOrNull
              ?.value,
          choices: [
            for (final choice in choices)
              (
                value: choice.value,
                label: choice.subtitle.isEmpty
                    ? choice.label
                    : '${choice.label} · ${choice.subtitle}',
              ),
          ],
        ),
      );
    }
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final choice in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, choice.value),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(choice.label),
                subtitle: choice.subtitle.isEmpty
                    ? null
                    : Text(choice.subtitle),
                trailing: choice.selected
                    ? const Icon(Icons.check_circle)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _scope() {
    final l10n = context.l10n;
    final runtimes = _store.registry.runtimes;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<ConnectionId>(
            initialValue: _connectionId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.configConnectionLabel,
              border: const OutlineInputBorder(),
            ),
            items: runtimes
                .map(
                  (r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.id.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) async {
              await _cancelOAuth();
              if (!mounted) return;
              setState(() {
                _connectionId = id;
                _profile = null;
                _profileInitialized = false;
              });
              _load(preserveProfile: false);
            },
          ),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String?>(
            initialValue: _profile,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.providerProfileLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  l10n.providerActiveDefault,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._profiles.map(
                (p) => DropdownMenuItem<String?>(
                  value: p.name,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) async {
              await _cancelOAuth();
              if (!mounted) return;
              setState(() {
                _profile = value;
                _profileInitialized = true;
              });
              if (_viewingActiveConnection) {
                _scopeStore?.setOverride(value);
              }
              _load();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _selectMobileConnection() async {
    final runtimes = _store.registry.runtimes.toList();
    final selected = await showMobileSheet<ConnectionId>(
      context,
      (context) => _MobileChoiceSheet<ConnectionId>(
        title: context.l10n.configConnectionLabel,
        current: _connectionId,
        choices: [
          if (runtimes.isEmpty)
            (value: _connectionId!, label: _connectionId!.value),
          for (final runtime in runtimes)
            (value: runtime.id, label: runtime.id.value),
        ],
      ),
    );
    if (selected == null || selected == _connectionId || !mounted) return;
    await _cancelOAuth();
    if (!mounted) return;
    setState(() {
      _connectionId = selected;
      _profile = null;
      _profileInitialized = false;
    });
    _load(preserveProfile: false);
  }

  Future<void> _selectMobileProfile() async {
    final selected = await showMobileSheet<_ProfileChoice>(
      context,
      (context) => _MobileChoiceSheet<_ProfileChoice>(
        title: context.l10n.providerProfileLabel,
        current: _ProfileChoice(_profile),
        choices: [
          (
            value: const _ProfileChoice(null),
            label: context.l10n.providerActiveDefault,
          ),
          for (final profile in _profiles)
            (value: _ProfileChoice(profile.name), label: profile.name),
        ],
      ),
    );
    if (selected == null || selected.value == _profile || !mounted) return;
    await _cancelOAuth();
    if (!mounted) return;
    setState(() {
      _profile = selected.value;
      _profileInitialized = true;
    });
    if (_viewingActiveConnection) _scopeStore?.setOverride(selected.value);
    _load();
  }

  Future<void> _showEnvActions(String key, bool isSet) async {
    final action = await _showMobileActions(
      title: key,
      actions: [
        (
          value: 'edit',
          icon: Icons.edit_outlined,
          label: context.l10n.commonEdit,
        ),
        if (isSet)
          (
            value: 'reveal',
            icon: Icons.visibility_outlined,
            label: context.l10n.providerRevealValue,
          ),
        (
          value: 'delete',
          icon: Icons.delete_outline,
          label: context.l10n.commonDelete,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _editEnv(key);
      case 'reveal':
        await _revealEnv(key);
      case 'delete':
        await _deleteEnv(key);
    }
  }

  Future<void> _showEndpointActions(Map<String, dynamic> row) async {
    final action = await _showMobileActions(
      title:
          '${row['name'] ?? row['id'] ?? context.l10n.providerEndpointFallback}',
      actions: [
        (
          value: 'edit',
          icon: Icons.edit_outlined,
          label: context.l10n.commonEdit,
        ),
        (
          value: 'activate',
          icon: Icons.check_circle_outline,
          label: context.l10n.providerSetActive,
        ),
        (
          value: 'delete',
          icon: Icons.delete_outline,
          label: context.l10n.commonDelete,
        ),
      ],
    );
    if (action == null || !mounted) return;
    if (action == 'edit') {
      await _editEndpoint(row);
      return;
    }
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    try {
      final id = '${row['id'] ?? ''}';
      if (action == 'activate') {
        await api.activateCustomEndpoint(id, profile: profile);
      } else if (action == 'delete') {
        await api.deleteCustomEndpoint(id, profile: profile);
      }
      _requireTarget(api, connectionId, profile);
      await _load();
    } catch (error) {
      _showActionError(error);
    }
  }

  Future<void> _showOAuthActions(Map<String, dynamic> row) async {
    final action = await _showMobileActions(
      title: '${row['name'] ?? row['id'] ?? row['provider']}',
      actions: [
        (
          value: 'authorize',
          icon: Icons.refresh,
          label: context.l10n.commonReauthorize,
        ),
        (
          value: 'disconnect',
          icon: Icons.link_off,
          label: context.l10n.commonDisconnect,
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'authorize') await _oauthStart(row);
    if (action == 'disconnect') await _disconnectOAuth(row);
  }

  Future<String?> _showMobileActions({
    required String title,
    required List<({String value, IconData icon, String label})> actions,
  }) => showMobileSheet<String>(
    context,
    (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          HermesMobileGroup(
            children: [
              for (final action in actions)
                HermesMobileRow(
                  icon: action.icon,
                  title: action.label,
                  trailing: const SizedBox.shrink(),
                  onTap: () => Navigator.pop(context, action.value),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _mobileBody(bool Function() ownsRenderedTarget) {
    final l10n = context.l10n;
    final palette = HermesPalette.of(context);
    final connectionLabel = _runtime?.id.value ?? _connectionId?.value ?? '—';
    final profileLabel = _profile ?? l10n.providerActiveDefault;
    Widget addButton(Key key, VoidCallback action) => IconButton.filledTonal(
      key: key,
      tooltip: l10n.commonAdd,
      visualDensity: VisualDensity.compact,
      onPressed: _busy.isEmpty
          ? () {
              if (ownsRenderedTarget()) action();
            }
          : null,
      icon: const Icon(Icons.add, size: 18),
    );

    final scopeRows = <Widget>[
      HermesMobileRow(
        key: const ValueKey('provider-connection-row'),
        icon: Icons.dns_outlined,
        title: l10n.configConnectionLabel,
        subtitle: connectionLabel,
        onTap: _selectMobileConnection,
      ),
      HermesMobileRow(
        key: const ValueKey('provider-profile-row'),
        icon: Icons.person_outline,
        title: l10n.providerProfileLabel,
        subtitle: profileLabel,
        onTap: _selectMobileProfile,
      ),
    ];

    return ListView(
      key: const ValueKey('provider-mobile-list'),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      children: [
        HermesMobileSectionLabel(title: l10n.configAppliesToProfile, top: 8),
        HermesMobileGroup(children: scopeRows),
        HermesMobileSectionLabel(
          title: l10n.providerEnvironmentSection,
          trailing: addButton(const ValueKey('provider-add-env'), _addEnv),
        ),
        HermesMobileGroup(
          children: _env.entries.isEmpty
              ? [
                  HermesMobileRow(
                    icon: Icons.data_object,
                    title: l10n.providerNoConfiguration,
                    trailing: const SizedBox.shrink(),
                  ),
                ]
              : [
                  for (final entry in _env.entries)
                    Builder(
                      builder: (context) {
                        final value = entry.value;
                        final isSet = value is Map
                            ? value['is_set'] == true
                            : '$value'.isNotEmpty;
                        final description = value is Map
                            ? '${value['description'] ?? ''}'.trim()
                            : '';
                        final redacted = value is Map
                            ? '${value['redacted_value'] ?? (isSet ? '••••••' : l10n.providerNotSet)}'
                            : '$value';
                        return HermesMobileRow(
                          key: ValueKey('provider-env-${entry.key}'),
                          icon: Icons.key_outlined,
                          title: entry.key,
                          subtitle: [
                            if (description.isNotEmpty) description,
                            redacted,
                          ].join(' · '),
                          trailing: _busy == 'env:${entry.key}'
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : HermesMobileStatusChip(
                                  label: isSet
                                      ? l10n.configConfigured
                                      : l10n.providerNotSet,
                                  color: isSet
                                      ? HermesSemantic.green
                                      : palette.text3,
                                ),
                          onTap: _busy.isEmpty
                              ? () => _showEnvActions(entry.key, isSet)
                              : null,
                        );
                      },
                    ),
                ],
        ),
        HermesMobileSectionLabel(
          title: l10n.providerCustomEndpointsSection,
          trailing: addButton(
            const ValueKey('provider-add-endpoint'),
            _editEndpoint,
          ),
        ),
        HermesMobileGroup(
          children: _endpoints.isEmpty
              ? [
                  HermesMobileRow(
                    icon: Icons.hub_outlined,
                    title: l10n.providerNoConfiguration,
                    trailing: const SizedBox.shrink(),
                  ),
                ]
              : [
                  for (final endpoint in _endpoints)
                    Builder(
                      builder: (context) {
                        final row = (endpoint as Map).cast<String, dynamic>();
                        return HermesMobileRow(
                          key: ValueKey('provider-endpoint-${row['id']}'),
                          icon: Icons.hub_outlined,
                          title:
                              '${row['name'] ?? row['id'] ?? l10n.providerEndpointFallback}',
                          subtitle: '${row['base_url'] ?? row['url'] ?? ''}',
                          onTap: () => _showEndpointActions(row),
                        );
                      },
                    ),
                ],
        ),
        HermesMobileSectionLabel(title: l10n.providerOauthSection),
        HermesMobileGroup(
          children: _oauth.isEmpty
              ? [
                  HermesMobileRow(
                    icon: Icons.link_outlined,
                    title: l10n.providerNoConfiguration,
                    trailing: const SizedBox.shrink(),
                  ),
                ]
              : [
                  for (final provider in _oauth)
                    Builder(
                      builder: (context) {
                        final row = (provider as Map).cast<String, dynamic>();
                        final id =
                            '${row['id'] ?? row['name'] ?? row['provider']}';
                        final connected =
                            (row['status'] as Map?)?['logged_in'] == true ||
                            row['connected'] == true;
                        final working =
                            _busy == 'oauth:$id' ||
                            _busy == 'oauthDisconnect:$id';
                        return HermesMobileRow(
                          icon: Icons.link_outlined,
                          title: '${row['name'] ?? id}',
                          subtitle: connected
                              ? l10n.commonConnected
                              : l10n.commonDisconnected,
                          trailing: working
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : HermesMobileStatusChip(
                                  label: connected
                                      ? l10n.commonConnected
                                      : l10n.commonAuthorize,
                                  color: connected
                                      ? HermesSemantic.green
                                      : palette.accent,
                                ),
                          onTap: _busy.isEmpty
                              ? () {
                                  if (!ownsRenderedTarget()) return;
                                  connected
                                      ? _showOAuthActions(row)
                                      : _oauthStart(row);
                                }
                              : _oauthSessionId != null
                              ? _cancelOAuth
                              : null,
                        );
                      },
                    ),
                ],
        ),
        HermesMobileSectionLabel(title: l10n.providerToolsetProvidersSection),
        HermesMobileGroup(
          children: _toolsets.isEmpty
              ? [
                  HermesMobileRow(
                    icon: Icons.extension_outlined,
                    title: l10n.providerNoConfiguration,
                    trailing: const SizedBox.shrink(),
                  ),
                ]
              : [
                  for (final toolset in _toolsets)
                    HermesMobileRow(
                      icon: Icons.extension_outlined,
                      title: toolset.name,
                      subtitle:
                          toolset.description ??
                          l10n.providerToolsCount(toolset.toolCount),
                      onTap: () {
                        if (ownsRenderedTarget()) _configureToolset(toolset);
                      },
                    ),
                ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final renderedApi = _api;
    final renderedConnectionId = _connectionId;
    final renderedProfile = _profile;
    bool ownsRenderedTarget() {
      final api = renderedApi;
      if (api != null &&
          _ownsTarget(api, renderedConnectionId, renderedProfile)) {
        return true;
      }
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.backendDisconnected)));
      return false;
    }

    final compact = MediaQuery.sizeOf(context).width < 600;
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? HermesErrorState(description: _error!, onRetry: _load)
        : compact
        ? _mobileBody(ownsRenderedTarget)
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _scope(),
              const SizedBox(height: 20),
              _Section(
                title: l10n.providerEnvironmentSection,
                action: IconButton(
                  tooltip: l10n.commonAdd,
                  onPressed: () {
                    if (ownsRenderedTarget()) _addEnv();
                  },
                  icon: const Icon(Icons.add),
                ),
                children: _env.entries.map((e) {
                  final isSet = e.value is Map
                      ? (e.value as Map)['is_set'] == true
                      : '${e.value}'.isNotEmpty;
                  return ListTile(
                    title: Text(e.key),
                    subtitle: Text(
                      e.value is Map
                          ? '${(e.value as Map)['description'] ?? ''}\n${(e.value as Map)['redacted_value'] ?? (isSet ? '••••••' : l10n.providerNotSet)}'
                          : '${e.value}',
                    ),
                    isThreeLine:
                        e.value is Map &&
                        '${(e.value as Map)['description'] ?? ''}'.isNotEmpty,
                    onTap: _busy.isEmpty
                        ? () {
                            if (ownsRenderedTarget()) _editEnv(e.key);
                          }
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSet)
                          IconButton(
                            tooltip: l10n.providerRevealValue,
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () {
                              if (ownsRenderedTarget()) _revealEnv(e.key);
                            },
                          ),
                        IconButton(
                          tooltip: l10n.commonDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            if (ownsRenderedTarget()) _deleteEnv(e.key);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              _Section(
                title: l10n.providerCustomEndpointsSection,
                action: IconButton(
                  tooltip: l10n.commonAdd,
                  onPressed: () {
                    if (ownsRenderedTarget()) _editEndpoint();
                  },
                  icon: const Icon(Icons.add),
                ),
                children: _endpoints.map((e) {
                  final row = (e as Map).cast<String, dynamic>();
                  return ListTile(
                    title: Text(
                      '${row['name'] ?? row['id'] ?? l10n.providerEndpointFallback}',
                    ),
                    subtitle: Text(
                      (row['base_url'] ?? row['url'] ?? '').toString(),
                    ),
                    trailing: HermesAdaptiveMenuButton<String>(
                      onSelected: (action) async {
                        if (!ownsRenderedTarget()) return;
                        final id = '${row['id'] ?? ''}';
                        if (action == 'edit') {
                          await _editEndpoint(row);
                          return;
                        }
                        final api = renderedApi!;
                        try {
                          if (action == 'activate') {
                            await api.activateCustomEndpoint(
                              id,
                              profile: renderedProfile,
                            );
                          }
                          if (action == 'delete') {
                            await api.deleteCustomEndpoint(
                              id,
                              profile: renderedProfile,
                            );
                          }
                          _requireTarget(
                            api,
                            renderedConnectionId,
                            renderedProfile,
                          );
                          await _load();
                        } catch (e) {
                          _showActionError(e);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.commonEdit),
                        ),
                        PopupMenuItem(
                          value: 'activate',
                          child: Text(l10n.providerSetActive),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.commonDelete),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              _Section(
                title: l10n.providerOauthSection,
                children: _oauth.map((e) {
                  final row = (e as Map).cast<String, dynamic>();
                  return ListTile(
                    title: Text(
                      '${row['name'] ?? row['id'] ?? row['provider']}',
                    ),
                    subtitle: Text(
                      ((row['status'] as Map?)?['logged_in'] == true ||
                              row['connected'] == true)
                          ? l10n.commonConnected
                          : l10n.commonDisconnected,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy == 'oauth:${row['id']}' &&
                            _oauthSessionId != null)
                          IconButton(
                            tooltip: l10n.commonStop,
                            onPressed: _cancelOAuth,
                            icon: const Icon(Icons.stop_circle_outlined),
                          ),
                        if ((row['status'] as Map?)?['logged_in'] == true)
                          IconButton(
                            tooltip: l10n.commonDisconnect,
                            onPressed: () {
                              if (ownsRenderedTarget()) _disconnectOAuth(row);
                            },
                            icon: const Icon(Icons.link_off),
                          ),
                        FilledButton.tonal(
                          onPressed: _busy.isEmpty
                              ? () {
                                  if (ownsRenderedTarget()) _oauthStart(row);
                                }
                              : null,
                          child: _busy == 'oauth:${row['id']}'
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  ((row['status'] as Map?)?['logged_in'] ==
                                              true ||
                                          row['connected'] == true)
                                      ? l10n.commonReauthorize
                                      : l10n.commonAuthorize,
                                ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              _Section(
                title: l10n.providerToolsetProvidersSection,
                children: _toolsets
                    .map(
                      (e) => ListTile(
                        title: Text(e.name),
                        subtitle: Text(
                          e.description ?? l10n.providerToolsCount(e.toolCount),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (ownsRenderedTarget()) _configureToolset(e);
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          );
    return widget.embedded
        ? body
        : compact
        ? MobilePageScaffold(title: l10n.settingsProvidersTitle, body: body)
        : Scaffold(
            appBar: AppBar(title: Text(l10n.settingsProvidersTitle)),
            body: body,
          );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? action;
  final List<Widget> children;
  const _Section({required this.title, this.action, required this.children});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?action,
            ],
          ),
          if (children.isEmpty)
            ListTile(title: Text(context.l10n.providerNoConfiguration))
          else
            ...children,
        ],
      ),
    ),
  );
}

class _ProfileChoice {
  final String? value;
  const _ProfileChoice(this.value);

  @override
  bool operator ==(Object other) =>
      other is _ProfileChoice && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class _MobileChoiceSheet<T> extends StatelessWidget {
  const _MobileChoiceSheet({
    required this.title,
    required this.current,
    required this.choices,
  });

  final String title;
  final T? current;
  final List<({T value, String label})> choices;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: HermesMobileGroup(
              children: [
                for (final choice in choices)
                  HermesMobileRow(
                    icon: Icons.circle_outlined,
                    title: choice.label,
                    trailing: choice.value == current
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : const SizedBox.shrink(),
                    onTap: () => Navigator.pop(context, choice.value),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Structured form for an OpenAI-compatible custom endpoint — replaces the
/// old raw-JSON textarea dialog (desktop parity: `custom-endpoints-settings`
/// is a real form, not a JSON blob users had to hand-edit).
class _CustomEndpointDialog extends StatefulWidget {
  final Map<String, dynamic>? current;
  final bool compact;
  const _CustomEndpointDialog({this.current, this.compact = false});

  @override
  State<_CustomEndpointDialog> createState() => _CustomEndpointDialogState();
}

class _CustomEndpointDialogState extends State<_CustomEndpointDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _modelsCtrl;
  late bool _discoverModels;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _nameCtrl = TextEditingController(text: '${c?['name'] ?? ''}');
    _baseUrlCtrl = TextEditingController(
      text: '${c?['base_url'] ?? c?['url'] ?? ''}',
    );
    _apiKeyCtrl = TextEditingController(text: '${c?['api_key'] ?? ''}');
    _modelCtrl = TextEditingController(text: '${c?['model'] ?? ''}');
    final models = c?['models'];
    _modelsCtrl = TextEditingController(
      text: models is List ? models.join('\n') : '',
    );
    _discoverModels = c?['discover_models'] != false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _modelsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.providerEndpointNameRequired)),
      );
      return;
    }
    if (_baseUrlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.providerEndpointUrlRequired)));
      return;
    }
    final models = _modelsCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.pop(context, {
      // Carry over fields the form doesn't edit (e.g. `id` on an existing
      // endpoint) so saving an edit updates it instead of creating a new one.
      ...?widget.current,
      'name': _nameCtrl.text.trim(),
      'base_url': _baseUrlCtrl.text.trim(),
      'api_key': _apiKeyCtrl.text,
      'model': _modelCtrl.text.trim(),
      'models': models,
      'discover_models': _discoverModels,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.current == null
        ? l10n.providerAddEndpointTitle
        : l10n.providerEditEndpointTitle;
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.providerEndpointName),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baseUrlCtrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.providerEndpointBaseUrl,
            hintText: _exampleProviderEndpoint,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyCtrl,
          obscureText: _obscureKey,
          decoration: InputDecoration(
            labelText: l10n.providerEndpointApiKey,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
              icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _modelCtrl,
          decoration: InputDecoration(
            labelText: l10n.providerEndpointDefaultModel,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _modelsCtrl,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: l10n.providerEndpointModelsList,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.providerEndpointDiscoverModels),
          value: _discoverModels,
          onChanged: (v) => setState(() => _discoverModels = v),
        ),
      ],
    );
    final actions = [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.commonCancel),
      ),
      FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
    ];
    if (!widget.compact) {
      return AlertDialog(
        scrollable: true,
        title: Text(title),
        content: fields,
        actions: actions,
      );
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: fields)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: actions[0].onPressed,
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(l10n.commonSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
