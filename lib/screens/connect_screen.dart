import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/cloud_discovery.dart';
import '../core/gateway_oauth.dart';
import '../core/native_gateway_login.dart';
import '../core/settings_store.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import 'cloud_discovery_screen.dart';

/// First-run / re-setup screen: enter the hermes-mobile-server URL + API key.
///
/// Two ways to reach this screen, both handled on successful connect:
/// - C1 (first run): rendered inline as AppShell's own body while
///   unconfigured, never pushed — AppShell's own `ConnectionStore` watch
///   rebuilds it away once `isConfigured` flips true, so this screen must
///   NOT pop itself (there's nothing to pop).
/// - Re-configure/reconnect (更多 → 连接, or the reconnect banner): pushed
///   as its own route on top of an already-configured app — nothing else
///   rebuilds it away, so it pops itself to reveal the tabs underneath.
/// `Navigator.canPop()` tells the two cases apart at the call site.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _sshHostCtrl;
  late final TextEditingController _sshUserCtrl;
  late final TextEditingController _sshPortCtrl;
  late final TextEditingController _sshKeyCtrl;
  late final TextEditingController _sshKeyPassphraseCtrl;
  late final TextEditingController _sshPasswordCtrl;
  late final TextEditingController _sshHermesPathCtrl;
  late final TextEditingController _sshProfileCtrl;
  final _profileNameCtrl = TextEditingController();
  final List<_HeaderDraft> _headerDrafts = [];
  List<ServerProfile> _profiles = [];
  bool _busy = false;
  bool _keyVisible = false;
  bool _sshKeyVisible = false;
  bool _sshKeyPassphraseVisible = false;
  bool _sshPasswordVisible = false;
  bool _saveAsProfile = false;
  bool _allowInsecureTransport = false;

  bool get _canAllowPublicCleartext =>
      currentCleartextTransportPolicy == CleartextTransportPolicy.unrestricted;
  ConnectionTransport _transport = ConnectionTransport.companion;
  ConnectionAuthMode _authMode = ConnectionAuthMode.token;
  GatewayOAuthTokens? _oauthTokens;
  String? _error;

  @override
  void initState() {
    super.initState();
    final connection = context.read<ConnectionStore>();
    _urlCtrl = TextEditingController(text: connection.settings.serverUrl);
    _keyCtrl = TextEditingController(text: connection.settings.apiKey);
    _sshHostCtrl = TextEditingController(text: connection.settings.sshHost);
    _sshUserCtrl = TextEditingController(text: connection.settings.sshUser);
    _sshPortCtrl = TextEditingController(
      text: '${connection.settings.sshPort}',
    );
    _sshKeyCtrl = TextEditingController(
      text: connection.settings.sshPrivateKey,
    );
    _sshKeyPassphraseCtrl = TextEditingController(
      text: connection.settings.sshPrivateKeyPassphrase,
    );
    _sshPasswordCtrl = TextEditingController(
      text: connection.settings.sshPassword,
    );
    _sshHermesPathCtrl = TextEditingController(
      text: connection.settings.sshRemoteHermesPath,
    );
    _sshProfileCtrl = TextEditingController(
      text: connection.settings.sshRemoteProfile,
    );
    _transport = connection.settings.transport;
    _authMode = connection.settings.authMode;
    _allowInsecureTransport = connection.settings.allowInsecureTransport;
    if (_authMode == ConnectionAuthMode.oauth &&
        connection.settings.apiKey.isNotEmpty) {
      _oauthTokens = GatewayOAuthTokens(
        accessToken: connection.settings.apiKey,
        refreshToken: connection.settings.refreshToken,
        expiresAt: connection.settings.oauthExpiresAt,
        provider: connection.settings.oauthProvider,
        userId: connection.settings.oauthUserId,
      );
    }
    _replaceHeaderDrafts(connection.settings.normalizedHeaders);
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await context.read<ConnectionStore>().store.profiles();
    if (mounted) setState(() => _profiles = profiles);
  }

  Future<void> _deleteProfile(ServerProfile profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<ConnectionStore>().store.deleteProfile(profile.name);
      await _loadProfiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commonOperationFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _sshHostCtrl.dispose();
    _sshUserCtrl.dispose();
    _sshPortCtrl.dispose();
    _sshKeyCtrl.dispose();
    _sshKeyPassphraseCtrl.dispose();
    _sshPasswordCtrl.dispose();
    _sshHermesPathCtrl.dispose();
    _sshProfileCtrl.dispose();
    _profileNameCtrl.dispose();
    for (final draft in _headerDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _replaceHeaderDrafts(Map<String, String> headers) {
    for (final draft in _headerDrafts) {
      draft.dispose();
    }
    _headerDrafts
      ..clear()
      ..addAll(
        headers.entries.map(
          (entry) => _HeaderDraft(name: entry.key, value: entry.value),
        ),
      );
  }

  Map<String, String> _connectionHeaders() => {
    for (final draft in _headerDrafts)
      if (draft.name.text.trim().isNotEmpty &&
          draft.value.text.trim().isNotEmpty)
        draft.name.text.trim(): draft.value.text.trim(),
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final connection = context.read<ConnectionStore>();
    var url = _transport == ConnectionTransport.sshTunnel
        ? 'ssh://${_sshHostCtrl.text.trim()}:${int.tryParse(_sshPortCtrl.text.trim()) ?? 22}'
        : _urlCtrl.text.trim();
    if (_transport != ConnectionTransport.sshTunnel &&
        !url.startsWith('http://') &&
        !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final settings = ConnectionSettings(
      serverUrl: url,
      apiKey: _transport == ConnectionTransport.sshTunnel
          ? ''
          : _authMode == ConnectionAuthMode.oauth
          ? _oauthTokens?.accessToken ?? ''
          : _keyCtrl.text.trim(),
      headers: _connectionHeaders(),
      kind: _transport == ConnectionTransport.sshTunnel
          ? ConnectionKind.ssh
          : _transport == ConnectionTransport.directGateway
          ? ConnectionKind.cloud
          : ConnectionKind.remote,
      transport: _transport,
      authMode: _authMode,
      refreshToken: _oauthTokens?.refreshToken ?? '',
      oauthProvider: _oauthTokens?.provider ?? '',
      oauthUserId: _oauthTokens?.userId ?? '',
      oauthExpiresAt: _oauthTokens?.expiresAt ?? 0,
      allowInsecureTransport:
          _canAllowPublicCleartext && _allowInsecureTransport,
      label: _profileNameCtrl.text.trim(),
      sshHost: _sshHostCtrl.text.trim(),
      sshUser: _sshUserCtrl.text.trim(),
      sshPort: int.tryParse(_sshPortCtrl.text.trim()) ?? 22,
      sshPrivateKey: _sshKeyCtrl.text.trim(),
      sshPrivateKeyPassphrase: _sshKeyPassphraseCtrl.text,
      sshPassword: _sshPasswordCtrl.text,
      sshRemoteHermesPath: _sshHermesPathCtrl.text.trim(),
      sshRemoteProfile: _sshProfileCtrl.text.trim(),
    );
    try {
      // Never replace a working configuration with unverified credentials.
      await connection.validateConnection(settings);
      await connection.saveConnection(settings);
      await connection.connect();
      if (_saveAsProfile && connection.isConnected) {
        try {
          final store = connection.store;
          final name = _profileNameCtrl.text.trim().isNotEmpty
              ? _profileNameCtrl.text.trim()
              : Uri.tryParse(url)?.host ?? url;
          await store.saveProfile(name, settings);
          await store.activateProfile(name);
          await _loadProfiles();
        } catch (_) {
          // The primary connection has already committed successfully. A
          // secondary label/bookmark failure must not present it as offline.
        }
      }
      if (!mounted) return;
      if (connection.isConnected) {
        // C1 (first run): rendered inline as AppShell's own body while
        // unconfigured — nothing pushed it, so there's nothing to pop;
        // AppShell's `context.watch<ConnectionStore>()` rebuild swaps to
        // the tabs on its own once `isConfigured` flips true.
        //
        // Re-configure/reconnect from 更多 → 连接 (or the reconnect
        // banner): this instance WAS pushed as its own route on top of an
        // already-configured app, so nothing rebuilds it away — pop back
        // to reveal the tabs underneath.
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      } else {
        setState(() {
          _busy = false;
          _error = connection.error ?? context.l10n.connectValidationFailed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.connectValidationNetworkFailed;
      });
    }
  }

  Future<void> _discoverCloudAgent() async {
    final agent = await Navigator.of(context).push<HermesCloudAgent>(
      MaterialPageRoute(builder: (_) => const CloudDiscoveryScreen()),
    );
    if (agent?.dashboardUrl == null || !mounted) return;
    setState(() {
      _transport = ConnectionTransport.directGateway;
      _authMode = ConnectionAuthMode.oauth;
      _urlCtrl.text = agent!.dashboardUrl!;
      _profileNameCtrl.text = agent.name;
      _saveAsProfile = true;
      _oauthTokens = null;
      _error = null;
    });
  }

  String _normalizedUrl() {
    var url = _urlCtrl.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> _signInWithGateway() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = GatewayOAuthClient(
      baseUrl: _normalizedUrl(),
      extraHeaders: _connectionHeaders(),
    );
    try {
      final status = await client.status();
      final flows = (status['auth_flows'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet();
      if (!flows.contains('native_pkce')) {
        throw GatewayOAuthException(l10n.connectPkceUnavailable);
      }
      final tokens = await runNativeGatewayLogin(
        baseUrl: _normalizedUrl(),
        client: client,
        openUrl: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
      );
      if (!mounted) return;
      setState(() {
        _oauthTokens = tokens;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    } finally {
      client.close();
    }
  }

  Future<void> _connectProfile(ServerProfile profile) async {
    final connection = context.read<ConnectionStore>();
    setState(() {
      _busy = true;
      _error = null;
      _urlCtrl.text = profile.settings.serverUrl;
      _keyCtrl.text = profile.settings.apiKey;
      _transport = profile.settings.transport;
      _authMode = profile.settings.authMode;
      _allowInsecureTransport = profile.settings.allowInsecureTransport;
      _sshHostCtrl.text = profile.settings.sshHost;
      _sshUserCtrl.text = profile.settings.sshUser;
      _sshPortCtrl.text = '${profile.settings.sshPort}';
      _sshKeyCtrl.text = profile.settings.sshPrivateKey;
      _sshKeyPassphraseCtrl.text = profile.settings.sshPrivateKeyPassphrase;
      _sshPasswordCtrl.text = profile.settings.sshPassword;
      _sshHermesPathCtrl.text = profile.settings.sshRemoteHermesPath;
      _sshProfileCtrl.text = profile.settings.sshRemoteProfile;
      _oauthTokens = _authMode == ConnectionAuthMode.oauth
          ? GatewayOAuthTokens(
              accessToken: profile.settings.apiKey,
              refreshToken: profile.settings.refreshToken,
              expiresAt: profile.settings.oauthExpiresAt,
              provider: profile.settings.oauthProvider,
              userId: profile.settings.oauthUserId,
            )
          : null;
      _replaceHeaderDrafts(profile.settings.normalizedHeaders);
    });
    try {
      final id = ConnectionStore.savedConnectionId(profile.name);
      if (connection.registry.runtime(id) == null) {
        await connection.addConnection(id, profile.settings, makeActive: true);
      } else {
        await connection.registry.runtime(id)!.connect();
        connection.activateConnection(id);
      }
      await connection.store.activateProfile(profile.name);
      if (!mounted) return;
      if (connection.isConnected) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      } else {
        setState(() {
          _busy = false;
          _error = connection.error ?? context.l10n.connectUnableServer;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = connection.error ?? '$e';
        });
      }
    }
  }

  Widget _sshFields() => Column(
    children: [
      TextFormField(
        controller: _sshHostCtrl,
        decoration: InputDecoration(
          labelText: context.l10n.connectSshHost,
          prefixIcon: const Icon(Icons.dns_outlined),
        ),
        validator: (value) => value?.trim().isEmpty ?? true
            ? context.l10n.connectSshHostRequired
            : null,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _sshUserCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.connectSshUser,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) => value?.trim().isEmpty ?? true
                  ? context.l10n.connectSshUserRequired
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: TextFormField(
              controller: _sshPortCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.l10n.connectPort),
              validator: (value) {
                final port = int.tryParse(value?.trim() ?? '');
                return port == null || port < 1 || port > 65535
                    ? '1-65535'
                    : null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _sshKeyCtrl,
        obscureText: !_sshKeyVisible,
        minLines: _sshKeyVisible ? 2 : 1,
        maxLines: _sshKeyVisible ? 5 : 1,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: InputDecoration(
          labelText: context.l10n.connectPrivateKey,
          hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
          prefixIcon: const Icon(Icons.key_outlined),
          suffixIcon: IconButton(
            tooltip: _sshKeyVisible
                ? context.l10n.connectHidePrivateKey
                : context.l10n.connectShowPrivateKey,
            icon: Icon(
              _sshKeyVisible ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () => setState(() => _sshKeyVisible = !_sshKeyVisible),
          ),
        ),
        validator: (value) =>
            (value?.trim().isEmpty ?? true) && _sshPasswordCtrl.text.isEmpty
            ? context.l10n.connectSshCredentialRequired
            : null,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _sshKeyPassphraseCtrl,
              obscureText: !_sshKeyPassphraseVisible,
              decoration: InputDecoration(
                labelText: context.l10n.connectPrivateKeyPassphrase,
                suffixIcon: IconButton(
                  tooltip: _sshKeyPassphraseVisible
                      ? context.l10n.connectHidePassphrase
                      : context.l10n.connectShowPassphrase,
                  icon: Icon(
                    _sshKeyPassphraseVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _sshKeyPassphraseVisible = !_sshKeyPassphraseVisible,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _sshPasswordCtrl,
              obscureText: !_sshPasswordVisible,
              decoration: InputDecoration(
                labelText: context.l10n.connectSshPassword,
                suffixIcon: IconButton(
                  tooltip: _sshPasswordVisible
                      ? context.l10n.connectHidePassword
                      : context.l10n.connectShowPassword,
                  icon: Icon(
                    _sshPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _sshPasswordVisible = !_sshPasswordVisible,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _sshHermesPathCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.connectRemoteHermesPath,
                hintText: '~/.local/bin/hermes',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _sshProfileCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.connectRemoteProfile,
              ),
              validator: (value) {
                final profile = value?.trim() ?? '';
                return profile.isNotEmpty &&
                        !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(profile)
                    ? context.l10n.connectProfileNameInvalid
                    : null;
              },
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.connectTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_profiles.isNotEmpty) ...[
                    HermesMobileSectionLabel(
                      title: context.l10n.connectSavedBackends,
                    ),
                    HermesMobileGroup(
                      children: [
                        for (final p in _profiles)
                          HermesMobileRow(
                            icon: p.settings.kind == ConnectionKind.cloud
                                ? Icons.cloud_outlined
                                : p.settings.kind == ConnectionKind.ssh
                                ? Icons.terminal_outlined
                                : Icons.dns_outlined,
                            title: p.name,
                            subtitle: p.settings.baseUrl,
                            trailing: IconButton(
                              tooltip: context.l10n.connectDeleteProfile,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: HermesSemantic.red,
                                size: 19,
                              ),
                              onPressed: _busy ? null : () => _deleteProfile(p),
                            ),
                            onTap: _busy ? null : () => _connectProfile(p),
                          ),
                      ],
                    ),
                  ],
                  HermesMobileSectionLabel(
                    title: context.l10n.connectConfiguration,
                  ),
                  HermesMobileCard(
                    child: Column(
                      children: [
                        Material(
                          type: MaterialType.transparency,
                          child: SegmentedButton<ConnectionTransport>(
                            segments: [
                              ButtonSegment(
                                value: ConnectionTransport.companion,
                                icon: const Icon(Icons.phone_android_outlined),
                                label: Text(
                                  context.l10n.connectTransportMobileServer,
                                ),
                              ),
                              ButtonSegment(
                                value: ConnectionTransport.directGateway,
                                icon: const Icon(Icons.cloud_outlined),
                                label: Text(
                                  context.l10n.connectTransportDirectGateway,
                                ),
                              ),
                              ButtonSegment(
                                value: ConnectionTransport.sshTunnel,
                                icon: const Icon(Icons.terminal_outlined),
                                label: Text(context.l10n.connectTransportSsh),
                              ),
                            ],
                            selected: {_transport},
                            onSelectionChanged: _busy
                                ? null
                                : (value) => setState(() {
                                    _transport = value.single;
                                    if (_transport !=
                                        ConnectionTransport.directGateway) {
                                      _authMode = ConnectionAuthMode.token;
                                    }
                                    _oauthTokens = null;
                                  }),
                          ),
                        ),
                        if (_transport ==
                            ConnectionTransport.directGateway) ...[
                          const SizedBox(height: 12),
                          Material(
                            type: MaterialType.transparency,
                            child: SegmentedButton<ConnectionAuthMode>(
                              segments: [
                                ButtonSegment(
                                  value: ConnectionAuthMode.oauth,
                                  icon: const Icon(Icons.login),
                                  label: Text(context.l10n.connectAuthOauth),
                                ),
                                ButtonSegment(
                                  value: ConnectionAuthMode.token,
                                  icon: const Icon(Icons.key_outlined),
                                  label: Text(context.l10n.connectAuthToken),
                                ),
                              ],
                              selected: {_authMode},
                              onSelectionChanged: _busy
                                  ? null
                                  : (value) => setState(() {
                                      _authMode = value.single;
                                      _oauthTokens = null;
                                    }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _busy ? null : _discoverCloudAgent,
                              icon: const Icon(Icons.travel_explore, size: 18),
                              label: Text(context.l10n.connectDiscoverCloud),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_transport == ConnectionTransport.sshTunnel)
                          _sshFields()
                        else ...[
                          TextFormField(
                            key: const ValueKey('connect-server-url'),
                            controller: _urlCtrl,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              labelText: context.l10n.connectServerAddress,
                              hintText:
                                  _transport == ConnectionTransport.companion
                                  ? 'http://192.168.1.5:8877'
                                  : 'https://agent.example.com',
                              prefixIcon: const Icon(Icons.dns_outlined),
                            ),
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) {
                                return context.l10n.connectServerRequired;
                              }
                              final normalized =
                                  raw.startsWith('http://') ||
                                      raw.startsWith('https://')
                                  ? raw
                                  : 'https://$raw';
                              final uri = Uri.tryParse(normalized);
                              if (uri == null ||
                                  uri.host.isEmpty ||
                                  !{'http', 'https'}.contains(uri.scheme)) {
                                return context.l10n.connectServerInvalid;
                              }
                              if (!connectionTransportAllowed(
                                normalized,
                                allowInsecure: _allowInsecureTransport,
                              )) {
                                if (uri.scheme == 'http' &&
                                    isLocalConnectionHost(uri.host) &&
                                    !nativeCleartextHostSupported(uri.host)) {
                                  return context
                                      .l10n
                                      .connectNativeCleartextRestricted;
                                }
                                return context.l10n.connectHttpsRequired;
                              }
                              return null;
                            },
                          ),
                          if (_canAllowPublicCleartext)
                            Material(
                              type: MaterialType.transparency,
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                secondary: const Icon(
                                  Icons.warning_amber_outlined,
                                ),
                                title: Text(
                                  context.l10n.connectAllowPublicHttp,
                                ),
                                subtitle: Text(
                                  context.l10n.connectAllowPublicHttpWarning,
                                ),
                                value: _allowInsecureTransport,
                                onChanged: _busy
                                    ? null
                                    : (value) => setState(
                                        () => _allowInsecureTransport = value,
                                      ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (_authMode == ConnectionAuthMode.token)
                            TextFormField(
                              key: const ValueKey('connect-api-key'),
                              controller: _keyCtrl,
                              obscureText: !_keyVisible,
                              decoration: InputDecoration(
                                labelText:
                                    _transport == ConnectionTransport.companion
                                    ? context.l10n.connectApiKey
                                    : context.l10n.connectGatewayToken,
                                hintText:
                                    _transport == ConnectionTransport.companion
                                    ? 'hm_...'
                                    : context.l10n.connectAuthToken,
                                prefixIcon: const Icon(Icons.key_outlined),
                                suffixIcon: IconButton(
                                  tooltip: _keyVisible
                                      ? context.l10n.connectHideKey
                                      : context.l10n.connectShowKey,
                                  icon: Icon(
                                    _keyVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () => setState(
                                    () => _keyVisible = !_keyVisible,
                                  ),
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? context.l10n.connectCredentialRequired
                                  : null,
                            )
                          else
                            Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  _oauthTokens == null
                                      ? Icons.lock_outline
                                      : Icons.verified_user_outlined,
                                  color: _oauthTokens == null
                                      ? null
                                      : HermesSemantic.green,
                                ),
                                title: Text(
                                  _oauthTokens == null
                                      ? context.l10n.connectNotSignedIn
                                      : context.l10n.connectOauthSignedIn,
                                ),
                                subtitle:
                                    _oauthTokens?.userId.isNotEmpty == true
                                    ? Text(_oauthTokens!.userId)
                                    : null,
                                trailing: OutlinedButton.icon(
                                  onPressed: _busy ? null : _signInWithGateway,
                                  icon: const Icon(
                                    Icons.open_in_browser,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _oauthTokens == null
                                        ? context.l10n.connectSignIn
                                        : context.l10n.connectSignInAgain,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.connectExtraHeaders,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.connectAddHeader,
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _headerDrafts.add(_HeaderDraft()),
                                    ),
                              icon: const Icon(Icons.add, size: 20),
                            ),
                          ],
                        ),
                        if (_headerDrafts.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              context.l10n.connectHeadersDescription,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        for (final (index, draft) in _headerDrafts.indexed) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  controller: draft.name,
                                  enabled: !_busy,
                                  decoration: InputDecoration(
                                    labelText: context.l10n.connectHeaderName,
                                    hintText: 'CF-Access-Client-Id',
                                    isDense: true,
                                  ),
                                  validator: (value) {
                                    final name = value?.trim() ?? '';
                                    if (name.isEmpty &&
                                        draft.value.text.trim().isEmpty) {
                                      return null;
                                    }
                                    if (!isValidConnectionHeaderName(name)) {
                                      return context
                                          .l10n
                                          .connectHeaderNameInvalid;
                                    }
                                    if (isReservedConnectionHeaderName(name)) {
                                      return context.l10n.connectHeaderManaged;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: draft.value,
                                  enabled: !_busy,
                                  obscureText: !draft.visible,
                                  decoration: InputDecoration(
                                    labelText: context.l10n.connectHeaderValue,
                                    isDense: true,
                                    suffixIcon: IconButton(
                                      tooltip: draft.visible
                                          ? context.l10n.connectHideValue
                                          : context.l10n.connectShowValue,
                                      onPressed: () => setState(
                                        () => draft.visible = !draft.visible,
                                      ),
                                      icon: Icon(
                                        draft.visible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      draft.name.text.trim().isNotEmpty &&
                                          (value?.trim().isEmpty ?? true)
                                      ? context.l10n.connectHeaderValueRequired
                                      : null,
                                ),
                              ),
                              IconButton(
                                tooltip: context.l10n.connectDeleteHeader,
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        final removed = _headerDrafts.removeAt(
                                          index,
                                        );
                                        removed.dispose();
                                      }),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _saveAsProfile,
                            onChanged: (v) =>
                                setState(() => _saveAsProfile = v ?? false),
                            title: Text(context.l10n.connectSaveProfile),
                            subtitle: Text(
                              context.l10n.connectSaveProfileDescription,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        ),
                        if (_saveAsProfile)
                          TextField(
                            controller: _profileNameCtrl,
                            decoration: InputDecoration(
                              labelText: context.l10n.connectProfileName,
                              isDense: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const ValueKey('connect-submit'),
                    onPressed:
                        _busy ||
                            (_authMode == ConnectionAuthMode.oauth &&
                                _oauthTokens == null)
                        ? null
                        : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _busy
                          ? context.l10n.connectConnecting
                          : context.l10n.connectAction,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

class _HeaderDraft {
  final TextEditingController name;
  final TextEditingController value;
  bool visible = false;

  _HeaderDraft({String name = '', String value = ''})
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  void dispose() {
    name.dispose();
    value.dispose();
  }
}
