/// Provider credential configuration grouped by provider category.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';

class _CredentialEntry {
  final String id;
  final String provider;
  final String group;
  final String name;
  final bool configured;
  final IconData icon;
  final Color color;

  const _CredentialEntry({
    required this.id,
    required this.provider,
    required this.group,
    required this.name,
    required this.configured,
    required this.icon,
    required this.color,
  });
}

class CredentialsScreen extends StatefulWidget {
  final bool embedded;

  const CredentialsScreen({super.key, this.embedded = false});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen>
    with ConnectionReloadMixin<CredentialsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'all';

  List<_CredentialEntry> _creds = const [];
  List<CredentialProvider> _providers = const [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  static const _groupKeys = ['cloud', 'provider', 'third'];

  static _CredentialEntry _entryFromProvider(CredentialProvider p) {
    final config = _providerVisuals(p.slug);
    return _CredentialEntry(
      id: p.slug,
      provider: p.name,
      group: config.$1,
      name: p.name,
      configured: p.authenticated,
      icon: config.$2,
      color: config.$3,
    );
  }

  static (String, IconData, Color) _providerVisuals(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('aws')) {
      return ('cloud', Icons.cloud_outlined, HermesProviderBrand.aws);
    }
    if (s.contains('gcp') || s.contains('google')) {
      return ('cloud', Icons.cloud_queue, HermesProviderBrand.gcp);
    }
    if (s.contains('azure')) {
      return ('cloud', Icons.cloud, HermesProviderBrand.azure);
    }
    if (s.contains('openai')) {
      return (
        'provider',
        Icons.psychology_outlined,
        HermesProviderBrand.openAi,
      );
    }
    if (s.contains('anthropic')) {
      return (
        'provider',
        Icons.auto_awesome_outlined,
        HermesProviderBrand.anthropic,
      );
    }
    if (s.contains('ollama')) {
      return ('provider', Icons.lan_outlined, const Color(0xFF000000));
    }
    if (s.contains('github')) {
      return ('third', Icons.code_outlined, HermesProviderBrand.github);
    }
    if (s.contains('jira')) {
      return ('third', Icons.task_outlined, HermesProviderBrand.jira);
    }
    if (s.contains('slack')) {
      return ('third', Icons.chat_outlined, HermesProviderBrand.slack);
    }
    return ('provider', Icons.extension_outlined, HermesSemantic.blue);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProviders();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _loadProviders);
  }

  Future<void> _loadProviders() async {
    final generation = ++_loadGeneration;
    final l10n = context.l10n;
    final api = context.read<ConnectionStore>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (api == null) {
        setState(() {
          _loading = false;
          _error = l10n.sessionServerNotConnected;
        });
        return;
      }
      final providers = await api.credentialProviders();
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _providers = providers;
        _creds = providers
            .where((provider) => provider.authType == 'api_key')
            .map(_entryFromProvider)
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _loading = false;
        _error = l10n.credentialsLoadFailed('$e');
      });
    }
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_CredentialEntry> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _creds.where((c) {
      if (_statusFilter == 'configured' && !c.configured) return false;
      if (_statusFilter == 'missing' && c.configured) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.provider.toLowerCase().contains(q);
    }).toList();
  }

  List<CredentialProvider> get _keyProviders =>
      _providers.where((provider) => provider.authType == 'api_key').toList();

  Future<void> _edit(_CredentialEntry c) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _CredentialEditorDialog(entry: c, providers: _keyProviders, api: api),
    );
    if (saved != true) return;
    if (!mounted || !identical(api, context.read<ConnectionStore>().api)) {
      return;
    }
    _loadProviders();
  }

  Future<void> _create() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _CredentialEditorDialog(providers: _keyProviders, api: api),
    );
    if (saved != true) return;
    if (!mounted || !identical(api, context.read<ConnectionStore>().api)) {
      return;
    }
    _loadProviders();
  }

  Future<void> _disconnect(_CredentialEntry credential) async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.credentialsDisconnectQuestion(credential.name)),
        content: Text(l10n.credentialsDisconnectDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      requireActiveApi(context, connection, api);
      await api.disconnectCredential(credential.id);
      if (!mounted || !identical(api, connection.api)) return;
      showHermesToast(
        context,
        message: l10n.configDisconnectedProvider(credential.name),
        kind: HermesToastKind.success,
      );
      await _loadProviders();
    } catch (error) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: l10n.configDisconnectFailed('$error'),
        kind: HermesToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(context.l10n.featureCredentials),
              actions: [
                IconButton(
                  tooltip: context.l10n.commonRefresh,
                  onPressed: _loading ? null : _loadProviders,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      floatingActionButton: Semantics(
        button: true,
        label: context.l10n.credentialsAddTitle,
        child: FloatingActionButton(
          heroTag: 'new-credential',
          onPressed: _keyProviders.isEmpty ? null : _create,
          tooltip: context.l10n.credentialsAddTitle,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HermesSpacing.md,
              HermesSpacing.sm,
              HermesSpacing.md,
              HermesSpacing.xs,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.l10n.credentialsSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HermesSpacing.md,
              vertical: HermesSpacing.xs,
            ),
            child: Wrap(
              spacing: HermesSpacing.xs,
              runSpacing: HermesSpacing.xs,
              children: [
                _filterChip('all', context.l10n.commonAll),
                _filterChip('configured', context.l10n.configConfigured),
                _filterChip('missing', context.l10n.credentialsMissing),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HermesSemantic.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(HermesRadius.smallCard),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: HermesSemantic.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: HermesSemantic.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? HermesEmptyState(
                    icon: Icons.vpn_key_outlined,
                    title: _creds.isEmpty
                        ? context.l10n.credentialsEmpty
                        : context.l10n.credentialsNoMatches,
                    description: _creds.isEmpty
                        ? context.l10n.credentialsEmptyDescription
                        : context.l10n.credentialsNoMatchesDescription,
                  )
                : RefreshIndicator(
                    onRefresh: _loadProviders,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        HermesSpacing.md,
                        HermesSpacing.xs,
                        HermesSpacing.md,
                        100,
                      ),
                      children: [
                        for (final key in _groupKeys)
                          _buildGroup(key, _groupLabel(context, key), filtered),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _groupLabel(BuildContext context, String key) => switch (key) {
    'cloud' => context.l10n.credentialsGroupCloud,
    'third' => context.l10n.credentialsGroupThirdParty,
    _ => context.l10n.credentialsGroupModelProviders,
  };

  Widget _filterChip(String kind, String label) {
    final selected = _statusFilter == kind;
    final theme = Theme.of(context);
    return FilterChip(
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = kind),
      label: Text(label),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildGroup(
    String groupKey,
    String groupLabel,
    List<_CredentialEntry> all,
  ) {
    final items = all.where((c) => c.group == groupKey).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HermesSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: HermesSpacing.xs,
              horizontal: HermesSpacing.xs,
            ),
            child: Wrap(
              spacing: HermesSpacing.xs,
              runSpacing: HermesSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(groupLabel, style: theme.textTheme.titleMedium),
                HermesStatusChip(
                  color: HermesSemantic.gray,
                  label:
                      '${items.where((x) => x.configured).length}/${items.length}',
                ),
              ],
            ),
          ),
          HermesGlassCard(
            radius: HermesRadius.largeCard,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _credentialTile(items[i]),
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 68),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _credentialTile(_CredentialEntry c) {
    final theme = Theme.of(context);
    final compact =
        MediaQuery.sizeOf(context).width < 400 ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final status = HermesStatusChip(
      color: c.configured ? HermesSemantic.green : HermesSemantic.red,
      label: c.configured
          ? context.l10n.configConfigured
          : context.l10n.credentialsMissing,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.sm,
        vertical: HermesSpacing.xs,
      ),
      leading: compact
          ? null
          : CircleAvatar(
              radius: 22,
              backgroundColor: c.color.withValues(alpha: 0.12),
              child: Icon(c.icon, color: c.color),
            ),
      title: Text(
        c.name,
        style: HermesType.onSurface(HermesType.headline, theme),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: HermesSpacing.xs),
        child: Wrap(
          spacing: HermesSpacing.xs,
          runSpacing: HermesSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              c.provider,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            status,
            if (c.configured)
              Text(
                '• • • • • • • •',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
          ],
        ),
      ),
      trailing: c.configured
          ? PopupMenuButton<String>(
              tooltip: context.l10n.commonMore,
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                if (action == 'edit') _edit(c);
                if (action == 'disconnect') _disconnect(c);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(context.l10n.commonEdit),
                  ),
                ),
                PopupMenuItem(
                  value: 'disconnect',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_off),
                    title: Text(context.l10n.commonDisconnect),
                  ),
                ),
              ],
            )
          : IconButton(
              onPressed: () => _edit(c),
              tooltip: context.l10n.commonAdd,
              icon: const Icon(Icons.add),
            ),
    );
  }
}

class _CredentialEditorDialog extends StatefulWidget {
  final _CredentialEntry? entry;
  final List<CredentialProvider> providers;
  final ApiClient api;

  const _CredentialEditorDialog({
    this.entry,
    required this.providers,
    required this.api,
  });

  @override
  State<_CredentialEditorDialog> createState() =>
      _CredentialEditorDialogState();
}

class _CredentialEditorDialogState extends State<_CredentialEditorDialog> {
  late String _providerSlug;
  late final TextEditingController _keyCtrl;
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _providerSlug =
        e?.id ??
        (widget.providers.isNotEmpty ? widget.providers.first.slug : '');
    _keyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    if (_providerSlug.isEmpty || _keyCtrl.text.trim().isEmpty) {
      showHermesToast(context, message: l10n.credentialsKeyRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final api = requireActiveApi(
        context,
        context.read<ConnectionStore>(),
        widget.api,
      );
      await api.saveCredentialKey(_providerSlug, _keyCtrl.text.trim());
      if (!mounted) return;
      requireActiveApi(context, context.read<ConnectionStore>(), widget.api);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showHermesToast(
        context,
        message: l10n.credentialsSaveFailed('$e'),
        kind: HermesToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.providers
        .where((x) => x.slug == _providerSlug)
        .firstOrNull;
    final displayName = p?.name ?? _providerSlug;
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.entry == null
            ? context.l10n.credentialsAddTitle
            : context.l10n.credentialsEditTitle,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _providerSlug,
            decoration: InputDecoration(
              labelText: context.l10n.chatProvider,
              prefixIcon: const Icon(Icons.category_outlined),
            ),
            items: [
              for (final pv in widget.providers)
                DropdownMenuItem<String>(
                  value: pv.slug,
                  child: Row(
                    children: [
                      Icon(
                        Icons.extension_outlined,
                        color: HermesSemantic.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(pv.name),
                    ],
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _providerSlug = v);
            },
          ),
          const SizedBox(height: HermesSpacing.sm),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: context.l10n.credentialsApiKey(displayName),
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? context.l10n.credentialsShowKey
                    : context.l10n.credentialsHideKey,
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            _saving ? context.l10n.credentialsSaving : context.l10n.commonSave,
          ),
        ),
      ],
    );
  }
}
