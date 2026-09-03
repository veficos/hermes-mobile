library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config_patch.dart';
import '../core/connection_reload_mixin.dart';
import '../core/connections/connection_registry.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/profile_scope_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';

class SchemaConfigScreen extends StatefulWidget {
  final bool embedded;
  const SchemaConfigScreen({super.key, this.embedded = false});

  @override
  State<SchemaConfigScreen> createState() => _SchemaConfigScreenState();
}

class _SchemaConfigScreenState extends State<SchemaConfigScreen>
    with ConnectionReloadMixin<SchemaConfigScreen> {
  ConnectionId? _connectionId;
  ConnectionId? _lastActiveConnectionId;
  String? _profile;
  List<ProfileInfo> _profiles = const [];
  Map<String, dynamic> _config = const {};
  Map<String, dynamic> _fields = const {};
  List<String> _categories = const [];
  String _category = 'general';
  String _query = '';
  bool _loading = true, _saving = false;
  bool _profileInitialized = false;
  int _loadGeneration = 0, _saveGeneration = 0;
  String? _error;

  ConnectionStore get _connection => context.read<ConnectionStore>();
  ConnectionRuntime? get _runtime => _connection.registry.runtime(
    _connectionId ?? _connection.activeConnectionId,
  );
  ApiClient? get _api {
    final runtime = _runtime;
    if (runtime != null) return runtime.api;
    return _connectionId == _connection.activeConnectionId
        ? _connection.api
        : null;
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
      _connectionId == _connection.activeConnectionId;

  @override
  void initState() {
    super.initState();
    _connectionId = context.read<ConnectionStore>().activeConnectionId;
    _lastActiveConnectionId = _connectionId;
    observeConnection(_connection, _onActiveConnectionChanged);
    final scopeStore = context.read<ProfileScopeStore>();
    _scopeStore = scopeStore;
    // Cross-screen scope override — desktop parity for `SettingsProfileScope`
    // (apps/desktop/src/store/settings-scope.ts). Only applies while viewing
    // the app's actual live connection; a profile picked here while viewing
    // a different connection (via the Connection dropdown below) stays local
    // to that connection, same as `_load`'s existing per-connection reset.
    if (scopeStore.override != null) {
      _profile = scopeStore.override;
      _profileInitialized = true;
    }
    scopeStore.addListener(_onScopeChanged);
    _load();
  }

  @override
  void dispose() {
    ++_loadGeneration;
    ++_saveGeneration;
    disposeConnectionObserver();
    _scopeStore?.removeListener(_onScopeChanged);
    super.dispose();
  }

  void _onActiveConnectionChanged() {
    final next = _connection.activeConnectionId;
    final wasFollowing = _connectionId == _lastActiveConnectionId;
    final connectionChanged = next != _lastActiveConnectionId;
    _lastActiveConnectionId = next;
    if (!mounted || !wasFollowing) return;
    ++_loadGeneration;
    ++_saveGeneration;
    setState(() {
      _connectionId = next;
      _saving = false;
      _error = null;
      if (connectionChanged) {
        _profile = _scopeStore?.override;
        _profileInitialized = _profile != null;
        _profiles = const [];
        _config = const {};
        _fields = const {};
        _categories = const [];
      }
    });
    if (_api == null) {
      setState(() {
        _loading = false;
        _error = connectionOfflineErrorCode;
      });
      return;
    }
    _load(preserveProfile: !connectionChanged);
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

  Future<void> _load({bool preserveProfile = true}) async {
    final api = _api;
    if (api == null) return;
    final generation = ++_loadGeneration;
    final connectionId = _connectionId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profilesPayload = await api.listProfiles();
      final nextProfile = preserveProfile && _profileInitialized
          ? _profile
          : profilesPayload.active;
      final results = await Future.wait([
        api.getConfig(profile: nextProfile),
        api.getConfigSchema(profile: nextProfile),
      ]);
      final schema = results[1];
      final fields =
          (schema['fields'] as Map?)?.cast<String, dynamic>() ?? const {};
      final declared = (schema['category_order'] as List? ?? const [])
          .map((e) => '$e')
          .toList();
      final discovered = fields.values
          .whereType<Map>()
          .map((e) => e['category']?.toString() ?? 'general')
          .toSet();
      final categories = <String>[
        ...declared.where(discovered.contains),
        ...discovered.where((e) => !declared.contains(e)).toList()..sort(),
      ];
      if (!mounted ||
          generation != _loadGeneration ||
          connectionId != _connectionId ||
          !identical(api, _api)) {
        return;
      }
      setState(() {
        _profiles = profilesPayload.profiles;
        _profile = nextProfile;
        _profileInitialized = true;
        _config = results[0];
        _fields = fields;
        _categories = categories;
        if (!categories.contains(_category)) {
          _category = categories.firstOrNull ?? 'general';
        }
        _loading = false;
      });
      if (_viewingActiveConnection) {
        await _scopeStore?.updateProfiles(profilesPayload);
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

  Future<void> _savePatch(String path, dynamic value) async {
    if (_saving) return;
    final api = _apiOrNotify();
    if (api == null) return;
    final generation = ++_saveGeneration;
    final profile = _profile;
    final connectionId = _connectionId;
    final before = _config;
    final optimistic = {..._config, ...configPatchAt(_config, path, value)};
    final patch = configPatchAt(_config, path, value);
    setState(() => _saving = true);
    setState(() => _config = optimistic);
    try {
      await api.putConfig(patch, profile: profile);
      final truth = await api.getConfig(profile: profile);
      if (!mounted ||
          generation != _saveGeneration ||
          connectionId != _connectionId ||
          profile != _profile ||
          !identical(api, _api)) {
        return;
      }
      setState(() => _config = truth);
      if (jsonEncode(configValueAt(truth, path)) != jsonEncode(value)) {
        throw StateError(context.l10n.configServerRejected(path));
      }
    } catch (e) {
      if (mounted &&
          generation == _saveGeneration &&
          connectionId == _connectionId &&
          profile == _profile &&
          identical(api, _api)) {
        try {
          final truth = await api.getConfig(profile: profile);
          if (mounted &&
              generation == _saveGeneration &&
              connectionId == _connectionId &&
              profile == _profile &&
              identical(api, _api)) {
            setState(() => _config = truth);
          }
        } catch (_) {
          if (mounted &&
              generation == _saveGeneration &&
              connectionId == _connectionId &&
              profile == _profile &&
              identical(api, _api)) {
            setState(() => _config = before);
          }
        }
        if (mounted) {
          showHermesToast(
            context,
            message: context.l10n.configSaveFailed('$e'),
          );
        }
      }
    } finally {
      if (mounted &&
          generation == _saveGeneration &&
          connectionId == _connectionId &&
          profile == _profile &&
          identical(api, _api)) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _editJson() async {
    final l10n = context.l10n;
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(_config),
    );
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.configFullJson),
        content: SizedBox(
          width: 760,
          height: 540,
          child: TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            minLines: null,
            style: HermesType.code,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              try {
                if (jsonDecode(controller.text) is! Map) {
                  throw FormatException(l10n.configTopLevelObject);
                }
                Navigator.pop(ctx, controller.text);
              } catch (e) {
                showHermesToast(ctx, message: l10n.configInvalidJson('$e'));
              }
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (text == null || !mounted) return;
    if (connectionId != _connectionId ||
        profile != _profile ||
        !identical(api, _api)) {
      showHermesToast(context, message: l10n.backendDisconnected);
      return;
    }
    setState(() => _saving = true);
    try {
      final value = (jsonDecode(text) as Map).cast<String, dynamic>();
      final generation = ++_saveGeneration;
      await api.replaceConfig(value, profile: profile);
      final rawTruth = await api.getRawConfig(profile: profile);
      final truth = await api.getConfig(profile: profile);
      if (!mounted ||
          generation != _saveGeneration ||
          connectionId != _connectionId ||
          profile != _profile ||
          !identical(api, _api)) {
        return;
      }
      if (mounted) setState(() => _config = truth);
      if (jsonEncode(rawTruth) != jsonEncode(value)) {
        throw StateError(l10n.configServerMismatch);
      }
    } catch (e) {
      if (mounted &&
          connectionId == _connectionId &&
          profile == _profile &&
          identical(api, _api)) {
        showHermesToast(context, message: l10n.configSaveFailed('$e'));
      }
    } finally {
      if (mounted &&
          connectionId == _connectionId &&
          profile == _profile &&
          identical(api, _api)) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _resetDefaults() async {
    final l10n = context.l10n;
    final api = _apiOrNotify();
    if (api == null) return;
    final connectionId = _connectionId;
    final profile = _profile;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.configRestoreDefaultsQuestion),
        content: Text(
          l10n.configRestoreDefaultsDescription(
            _profile ?? l10n.configCurrentProfile,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.configRestore),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (connectionId != _connectionId ||
        profile != _profile ||
        !identical(api, _api)) {
      showHermesToast(context, message: l10n.backendDisconnected);
      return;
    }
    setState(() => _saving = true);
    try {
      final defaults = await api.getConfigDefaults(profile: profile);
      await api.replaceConfig(defaults, profile: profile);
      await _load();
    } catch (e) {
      if (mounted &&
          connectionId == _connectionId &&
          profile == _profile &&
          identical(api, _api)) {
        showHermesToast(context, message: l10n.configSaveFailed('$e'));
      }
    } finally {
      if (mounted &&
          connectionId == _connectionId &&
          profile == _profile &&
          identical(api, _api)) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < HermesBreakpoints.phone;
    final content = Column(
      children: [
        _scopeBar(compact: compact),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        if (_categories.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final category in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: category == _category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(child: _body(compact: compact)),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.configTitle), actions: _actions()),
      body: content,
    );
  }

  List<Widget> _actions() => [
    IconButton(
      tooltip: context.l10n.configFullJson,
      onPressed: _saving ? null : _editJson,
      icon: const Icon(Icons.data_object),
    ),
    IconButton(
      tooltip: context.l10n.configRestoreDefaults,
      onPressed: _saving ? null : _resetDefaults,
      icon: const Icon(Icons.restore),
    ),
    IconButton(
      tooltip: context.l10n.commonRefresh,
      onPressed: _loading ? null : _load,
      icon: const Icon(Icons.refresh),
    ),
  ];

  Widget _scopeBar({required bool compact}) {
    final l10n = context.l10n;
    final runtimes = _connection.registry.runtimes.toList();
    final connectionPicker = DropdownButtonFormField<ConnectionId>(
      initialValue: _connectionId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.configConnectionLabel,
        isDense: true,
      ),
      items: [
        for (final runtime in runtimes)
          DropdownMenuItem(
            value: runtime.id,
            child: Text(runtime.id.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id == null) return;
        setState(() {
          _connectionId = id;
          _profile = null;
          _profileInitialized = false;
        });
        _load(preserveProfile: false);
      },
    );
    final profilePicker = DropdownButtonFormField<String?>(
      initialValue: _profile,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.configAppliesToProfile,
        isDense: true,
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            l10n.configDefaultProcessProfile,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final profile in _profiles)
          DropdownMenuItem<String?>(
            value: profile.name,
            child: Text(profile.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (profile) {
        setState(() {
          _profile = profile;
          _profileInitialized = true;
        });
        if (_viewingActiveConnection) {
          _scopeStore?.setOverride(profile);
        }
        _load();
      },
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (widget.embedded)
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.configTitle, style: HermesType.title),
                  ),
                  ..._actions(),
                ],
              ),
            if (compact)
              ExpansionTile(
                key: const ValueKey('schema-config-scope'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: const Icon(Icons.layers_outlined),
                title: Text(
                  l10n.configAppliesToProfile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile ?? l10n.configDefaultProcessProfile,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(l10n.configConnectionLabel),
                  ],
                ),
                children: [
                  connectionPicker,
                  const SizedBox(height: 8),
                  profilePicker,
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: connectionPicker),
                  const SizedBox(width: 12),
                  Expanded(child: profilePicker),
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.configSearchHint,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({required bool compact}) {
    final l10n = context.l10n;
    if (_loading) return HermesLoadingState(label: l10n.configLoading);
    if (_error != null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? l10n.backendDisconnected
            : _error!,
        onRetry: _load,
      );
    }
    final entries = _fields.entries.where((entry) {
      final schema = (entry.value as Map?)?.cast<String, dynamic>() ?? const {};
      final categoryMatch =
          (schema['category']?.toString() ?? 'general') == _category;
      return categoryMatch &&
          (_query.isEmpty ||
              entry.key.toLowerCase().contains(_query) ||
              (schema['description']?.toString().toLowerCase().contains(
                    _query,
                  ) ??
                  false));
    }).toList();
    if (entries.isEmpty) {
      return HermesEmptyState(icon: Icons.tune, title: l10n.configNoMatches);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        for (final entry in entries)
          _field(
            entry.key,
            (entry.value as Map).cast<String, dynamic>(),
            compact: compact,
          ),
      ],
    );
  }

  Widget _field(
    String path,
    Map<String, dynamic> schema, {
    required bool compact,
  }) {
    final type = schema['type']?.toString() ?? 'string';
    final value = configValueAt(_config, path);
    final description = schema['description']?.toString() ?? path;
    if (compact) return _compactField(path, schema, type, value, description);
    Widget control;
    if (type == 'boolean') {
      control = Switch(
        value: value == true,
        onChanged: _saving ? null : (v) => _savePatch(path, v),
      );
    } else if (type == 'select') {
      final options = (schema['options'] as List? ?? const [])
          .map((e) => '$e')
          .toList();
      final current = value?.toString() ?? '';
      if (current.isNotEmpty && !options.contains(current)) {
        options.insert(0, current);
      }
      control = SizedBox(
        width: 220,
        child: DropdownButtonFormField<String>(
          initialValue: options.contains(current) ? current : null,
          items: [
            if (schema['clearable'] == true)
              DropdownMenuItem(
                value: '',
                child: Text(context.l10n.configUseDefault),
              ),
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _saving ? null : (v) => _savePatch(path, v ?? ''),
          isExpanded: true,
        ),
      );
    } else {
      control = SizedBox(
        width: 240,
        child: TextFormField(
          key: ValueKey('$path:${jsonEncode(value)}'),
          initialValue: _displayValue(value),
          keyboardType: type == 'number'
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : TextInputType.text,
          maxLines: type == 'object' || type == 'list' ? 4 : 1,
          onFieldSubmitted: _saving
              ? null
              : (raw) {
                  try {
                    _savePatch(path, _parseValue(type, raw));
                  } catch (e) {
                    showHermesToast(
                      context,
                      message: context.l10n.configInvalidFieldValue(path, '$e'),
                    );
                  }
                },
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(path, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(child: control),
            IconButton(
              tooltip: context.l10n.configRemoveOverride,
              onPressed: _saving || !configHasPath(_config, path)
                  ? null
                  : () => _deleteField(path),
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactField(
    String path,
    Map<String, dynamic> schema,
    String type,
    dynamic value,
    String description,
  ) {
    final hasOverride = configHasPath(_config, path);
    final valueLabel = _compactValueLabel(type, value, schema);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HermesGlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              key: ValueKey('schema-setting-$path'),
              minTileHeight: 66,
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
              title: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HermesType.code.copyWith(
                  color: HermesPalette.of(context).text3,
                  fontSize: 11,
                ),
              ),
              trailing: type == 'boolean'
                  ? Switch(
                      value: value == true,
                      onChanged: _saving
                          ? null
                          : (next) => _savePatch(path, next),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 112),
                          child: Text(
                            valueLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: HermesPalette.of(context).text3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
              onTap: type == 'boolean' || _saving
                  ? null
                  : () => _editCompactField(path, schema, type, value),
            ),
            if (hasOverride) ...[
              const Divider(height: 1, indent: 16),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: _saving ? null : () => _deleteField(path),
                  icon: const Icon(Icons.restart_alt, size: 17),
                  label: Text(context.l10n.configUseDefault),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _compactValueLabel(
    String type,
    dynamic value,
    Map<String, dynamic> schema,
  ) {
    if (value == null || value.toString().isEmpty) {
      return context.l10n.configUseDefault;
    }
    if (type == 'list') {
      return value is List ? '${value.length}' : _displayValue(value);
    }
    if (type == 'object') {
      return value is Map ? '${value.length}' : _displayValue(value);
    }
    return _displayValue(value);
  }

  Future<void> _editCompactField(
    String path,
    Map<String, dynamic> schema,
    String type,
    dynamic value,
  ) async {
    final description = schema['description']?.toString() ?? path;
    if (type == 'select') {
      final options = (schema['options'] as List? ?? const [])
          .map((item) => '$item')
          .toList();
      final current = value?.toString() ?? '';
      if (current.isNotEmpty && !options.contains(current)) {
        options.insert(0, current);
      }
      final selected = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              ListTile(
                title: Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(path, style: HermesType.code),
              ),
              if (schema['clearable'] == true)
                _compactChoiceTile('', current, context.l10n.configUseDefault),
              for (final option in options)
                _compactChoiceTile(option, current, option),
            ],
          ),
        ),
      );
      if (selected != null && selected != current && mounted) {
        await _savePatch(path, selected);
      }
      return;
    }

    final raw = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SchemaValueEditor(
        path: path,
        title: description,
        initialValue: _displayValue(value),
        multiline: type == 'object' || type == 'list',
        numeric: type == 'number',
      ),
    );
    if (raw == null || !mounted || raw == _displayValue(value)) return;
    try {
      await _savePatch(path, _parseValue(type, raw));
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.configInvalidFieldValue(path, '$error'),
        );
      }
    }
  }

  Widget _compactChoiceTile(String value, String current, String label) {
    return ListTile(
      minTileHeight: 54,
      title: Text(label),
      trailing: value == current
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _deleteField(String path) async {
    final api = _api;
    if (api == null || _saving) return;
    final before = _config;
    final next = configWithoutPath(before, path);
    final generation = ++_saveGeneration;
    final profile = _profile;
    final connectionId = _connectionId;
    setState(() {
      _saving = true;
      _config = next;
    });
    try {
      await api.replaceConfig(next, profile: profile);
      final rawTruth = await api.getRawConfig(profile: profile);
      final truth = await api.getConfig(profile: profile);
      if (!mounted ||
          generation != _saveGeneration ||
          connectionId != _connectionId ||
          profile != _profile ||
          !identical(api, _api)) {
        return;
      }
      setState(() => _config = truth);
      if (configHasPath(rawTruth, path)) {
        throw StateError(context.l10n.configServerDidNotDelete(path));
      }
    } catch (e) {
      if (mounted &&
          generation == _saveGeneration &&
          connectionId == _connectionId &&
          profile == _profile &&
          identical(api, _api)) {
        setState(() => _config = before);
        showHermesToast(
          context,
          message: context.l10n.configDeleteFailed('$e'),
        );
      }
    } finally {
      if (mounted &&
          generation == _saveGeneration &&
          connectionId == _connectionId &&
          profile == _profile &&
          identical(api, _api)) {
        setState(() => _saving = false);
      }
    }
  }

  String _displayValue(dynamic value) => value is Map || value is List
      ? const JsonEncoder.withIndent('  ').convert(value)
      : value?.toString() ?? '';
  dynamic _parseValue(String type, String raw) {
    if (type == 'number') return num.parse(raw.trim());
    if (type == 'list' || type == 'object') {
      final value = jsonDecode(raw);
      if (type == 'list' && value is! List) {
        throw FormatException(context.l10n.configListJsonError);
      }
      if (type == 'object' && value is! Map) {
        throw FormatException(context.l10n.configObjectJsonError);
      }
      return value;
    }
    return raw;
  }
}

class _SchemaValueEditor extends StatefulWidget {
  const _SchemaValueEditor({
    required this.path,
    required this.title,
    required this.initialValue,
    required this.multiline,
    required this.numeric,
  });

  final String path;
  final String title;
  final String initialValue;
  final bool multiline;
  final bool numeric;

  @override
  State<_SchemaValueEditor> createState() => _SchemaValueEditorState();
}

class _SchemaValueEditorState extends State<_SchemaValueEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonCancel),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: _save,
                child: Text(context.l10n.commonSave),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('schema-setting-editor-${widget.path}'),
            controller: _controller,
            autofocus: true,
            keyboardType: widget.numeric
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  )
                : TextInputType.text,
            minLines: widget.multiline ? 5 : 1,
            maxLines: widget.multiline ? 12 : 1,
            textInputAction: widget.multiline
                ? TextInputAction.newline
                : TextInputAction.done,
            decoration: InputDecoration(
              labelText: widget.path,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: widget.multiline ? null : (_) => _save(),
          ),
        ],
      ),
    );
  }
}
