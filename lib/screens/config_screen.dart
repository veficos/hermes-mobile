/// ConfigScreen — 统一配置中心
///
/// Wired today:
/// 1. Model — default model switch via api.setModel
/// 2. Chat / Memory — not wired to /api/v1/config (honest empty states)
/// 3. Tools & Keys — provider API key management

library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config_patch.dart';
import '../core/connection_reload_mixin.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_toast.dart';

enum _VoiceFieldType { text, number, switchType, elevenLabsVoice }

// Theme extensions
extension on ThemeData {
  Color get textTertiary => brightness == Brightness.dark
      ? HermesText.darkTertiary
      : HermesText.lightTertiary;
  Color get textPrimary => brightness == Brightness.dark
      ? HermesText.darkPrimary
      : HermesText.lightPrimary;
}

// ============================================================================
// Screen
// ============================================================================

class ConfigScreen extends StatefulWidget {
  final bool embedded;

  const ConfigScreen({super.key, this.embedded = false});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with SingleTickerProviderStateMixin, ConnectionReloadMixin<ConfigScreen> {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  String? _partialLoadError;

  // Data
  final List<ModelInfo> _providers = [];
  String? _currentProvider;
  String? _currentModel;
  Map<String, dynamic> _config = {};
  Map<String, dynamic>? _auxiliary;
  Map<String, dynamic>? _moa;
  Map<String, dynamic>? _recommended;
  String? _selectedMoaPreset;
  bool _saving = false;
  int _recommendationGeneration = 0;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  Future<List<CredentialProvider>>? _credentialProvidersFuture;
  SessionStore? _sessionStore;
  String? _observedProfile;

  String? get _profile {
    final session = context.read<SessionStore>();
    return session.profile ?? session.activeProfile;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _sessionStore?.removeListener(_onSessionChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    final api = context.read<ConnectionStore>().api;
    final session = context.read<SessionStore>();
    final profile = session.profile ?? session.activeProfile;
    if (api == null) {
      setState(() {
        _loading = false;
        _error = connectionOfflineErrorCode;
      });
      return;
    }
    try {
      final catalog = await api.modelCatalog();
      var config = _config;
      var auxiliary = _auxiliary;
      var moa = _moa;
      final partialErrors = <String>[];
      try {
        config = await api.getConfig(profile: profile);
      } catch (error) {
        partialErrors.add('config: $error');
      }
      try {
        auxiliary = await api.auxiliaryModels(profile: profile);
      } catch (error) {
        partialErrors.add('auxiliary: $error');
      }
      try {
        moa = await api.moaModels(profile: profile);
      } catch (error) {
        partialErrors.add('MoA: $error');
      }
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<ConnectionStore>().api) &&
          profile == (session.profile ?? session.activeProfile)) {
        final defaultPreset = moa?['default_preset']?.toString();
        final presets = moa?['presets'];
        setState(() {
          _providers.clear();
          _providers.addAll(catalog.providers);
          _currentProvider = catalog.currentProvider;
          _currentModel = catalog.currentModel;
          _config = config;
          _auxiliary = auxiliary;
          _moa = moa;
          _selectedMoaPreset =
              defaultPreset ??
              (presets is Map && presets.isNotEmpty
                  ? presets.keys.first.toString()
                  : null);
          _loading = false;
          _error = null;
          _partialLoadError = partialErrors.isEmpty
              ? null
              : partialErrors.join('; ');
        });
        unawaited(_loadRecommendation(catalog.currentProvider));
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<ConnectionStore>().api) &&
          profile == (session.profile ?? session.activeProfile)) {
        setState(() {
          _loading = false;
          _error = context.l10n.configLoadFailed('$e');
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForTarget);
    final session = context.read<SessionStore>();
    if (!identical(session, _sessionStore)) {
      _sessionStore?.removeListener(_onSessionChanged);
      _sessionStore = session..addListener(_onSessionChanged);
      _observedProfile = session.profile ?? session.activeProfile;
    }
  }

  void _onSessionChanged() {
    final session = _sessionStore;
    if (!mounted || session == null) return;
    final profile = session.profile ?? session.activeProfile;
    if (profile == _observedProfile) return;
    _observedProfile = profile;
    _reloadForTarget();
  }

  void _reloadForTarget() {
    if (!mounted) return;
    _mutationGeneration++;
    _recommendationGeneration++;
    setState(() {
      _loading = true;
      _error = null;
      _partialLoadError = null;
      _saving = false;
      _credentialProvidersFuture = null;
    });
    _loadData();
  }

  bool _ownsMutation(ApiClient api, int generation, String? profile) =>
      mounted &&
      generation == _mutationGeneration &&
      identical(api, context.read<ConnectionStore>().api) &&
      profile == _profile;

  void _requireMutationTarget(ApiClient api, String? profile) {
    _requireCurrentApi(api);
    if (profile != _profile) {
      throw StateError(context.l10n.backendDisconnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: [
        Tab(
          icon: const Icon(Icons.auto_awesome),
          text: context.l10n.configTabModel,
        ),
        Tab(
          icon: const Icon(Icons.chat_bubble),
          text: context.l10n.configTabChat,
        ),
        Tab(icon: const Icon(Icons.memory), text: context.l10n.configTabMemory),
        Tab(
          icon: const Icon(Icons.mic_none),
          text: context.l10n.configTabVoice,
        ),
        Tab(
          icon: const Icon(Icons.vpn_key),
          text: context.l10n.configTabToolsKeys,
        ),
      ],
    );
    final body = _buildBody();

    if (widget.embedded) {
      return Column(
        children: [
          Material(color: Theme.of(context).colorScheme.surface, child: tabs),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.configTitle), bottom: tabs),
      body: body,
    );
  }

  Widget _buildBody() {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _error == connectionOfflineErrorCode
                      ? context.l10n.backendDisconnected
                      : _error!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadData,
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            ),
          )
        : Column(
            children: [
              if (_partialLoadError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: HermesNoticeBar(
                    message: context.l10n.commonPartialDataLoadFailed(
                      _partialLoadError!,
                    ),
                    icon: Icons.warning_amber_outlined,
                    color: HermesSemantic.orange,
                    onTap: _loadData,
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _constrainContent(_buildModelTab()),
                    _constrainContent(_buildChatTab()),
                    _constrainContent(_buildMemoryTab()),
                    _constrainContent(_buildVoiceTab()),
                    _constrainContent(_buildToolsKeysTab()),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _constrainContent(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: child,
      ),
    );
  }

  // =====================================================================
  // Model Configuration Tab
  // =====================================================================
  Widget _buildModelTab() {
    final theme = Theme.of(context);
    final providers = _providers;
    final allModels = <String, List<String>>{};

    // Group models by provider
    for (final p in providers) {
      final providerName = p.provider;
      if (p.models.isNotEmpty) {
        allModels[providerName] = p.models;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main model selector (wired to api.setModel)
          _sectionTitle(theme, context.l10n.modelDefaultTitle),
          const SizedBox(height: 8),
          _buildModelSelectorCard(theme, allModels),
          if (_recommended != null) ...[
            const SizedBox(height: 8),
            _buildRecommendedRow(theme),
          ],
          const SizedBox(height: 24),
          _buildAuxiliarySection(theme),
          const SizedBox(height: 24),
          _buildMoaSection(theme),
          if (configHasPath(_config, 'fallback_providers')) ...[
            const SizedBox(height: 24),
            _sectionTitle(theme, context.l10n.modelFallbackTitle),
            const SizedBox(height: 8),
            HermesGlassCard(child: _buildFallbackProvidersField(theme)),
          ],
        ],
      ),
    );
  }

  Widget _buildModelSelectorCard(
    ThemeData theme,
    Map<String, List<String>> allModels,
  ) {
    return HermesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main model display
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _currentModel,
                  decoration: InputDecoration(
                    labelText: context.l10n.modelDefaultTitle,
                    border: OutlineInputBorder(),
                  ),
                  items: _buildModelDropdownItems(allModels),
                  onChanged: (value) async {
                    if (value == null) return;
                    await _switchModel(_currentProvider ?? '', value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Provider display
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _currentProvider,
                  decoration: InputDecoration(
                    labelText: context.l10n.modelProvider,
                    border: OutlineInputBorder(),
                  ),
                  items: _providers.map((p) {
                    final name = p.provider;
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _currentProvider = value;
                      final models = _providers
                          .where((provider) => provider.slug == value)
                          .expand((provider) => provider.models)
                          .toList();
                      if (!models.contains(_currentModel)) {
                        _currentModel = models.firstOrNull;
                      }
                      _recommended = null;
                    });
                    unawaited(_loadRecommendation(value));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildModelDropdownItems(
    Map<String, List<String>> allModels,
  ) {
    final items = <DropdownMenuItem<String>>[];
    final entries = _currentProvider == null
        ? allModels.entries
        : allModels.entries.where((entry) => entry.key == _currentProvider);
    for (final entry in entries) {
      for (final model in entry.value) {
        items.add(DropdownMenuItem(value: model, child: Text(model)));
      }
    }
    if (items.isEmpty) {
      items.add(
        DropdownMenuItem(value: '', child: Text(context.l10n.modelNoAvailable)),
      );
    }
    return items;
  }

  Future<void> _switchModel(String provider, String modelName) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final generation = ++_mutationGeneration;
    if (provider.isEmpty ||
        !_providers.any(
          (item) => item.slug == provider && item.models.contains(modelName),
        )) {
      showHermesToast(
        context,
        message: context.l10n.modelProviderNotFound,
        kind: HermesToastKind.error,
      );
      return;
    }

    try {
      final result = await _applyModelAssignment(
        api,
        {'scope': 'main', 'provider': provider, 'model': modelName},
        profile: profile,
        generation: generation,
      );
      if (result == null) return;
      if (mounted && _ownsMutation(api, generation, profile)) {
        setState(() {
          _currentModel = modelName;
          _currentProvider = provider;
        });
        final applied = result['applied']?.toString() ?? 'now';
        if (applied == 'deferred') {
          showHermesToast(context, message: context.l10n.modelSwitchDeferred);
        } else {
          showHermesToast(
            context,
            message: context.l10n.modelSwitchSucceeded(modelName),
          );
        }
      }
    } catch (e) {
      if (mounted && _ownsMutation(api, generation, profile)) {
        showHermesToast(
          context,
          message: context.l10n.modelSwitchFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _applyModelAssignment(
    ApiClient api,
    Map<String, dynamic> assignment, {
    required String? profile,
    required int generation,
  }) async {
    _requireMutationTarget(api, profile);
    var result = await api.setModelAssignment(assignment, profile: profile);
    if (!mounted || !_ownsMutation(api, generation, profile)) return null;
    if (result['confirm_required'] == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.modelConfirmSelection),
          content: Text(
            result['confirm_message']?.toString() ??
                context.l10n.modelExpensiveWarning,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.commonContinue),
            ),
          ],
        ),
      );
      if (confirmed != true) return null;
      if (!mounted || !_ownsMutation(api, generation, profile)) return null;
      _requireMutationTarget(api, profile);
      result = await api.setModelAssignment({
        ...assignment,
        'confirm_expensive_model': true,
      }, profile: profile);
    }
    _requireMutationTarget(api, profile);
    return result;
  }

  ApiClient _requireCurrentApi(ApiClient expected) {
    if (!identical(context.read<ConnectionStore>().api, expected)) {
      throw StateError(context.l10n.backendDisconnected);
    }
    return expected;
  }

  Future<void> _loadRecommendation(String? provider) async {
    final api = context.read<ConnectionStore>().api;
    if (api == null || provider == null || provider.isEmpty) return;
    final generation = ++_recommendationGeneration;
    final profile = _profile;
    try {
      final value = await api.recommendedDefaultModel(
        provider,
        profile: profile,
      );
      if (!mounted ||
          generation != _recommendationGeneration ||
          !identical(api, context.read<ConnectionStore>().api) ||
          profile != _profile) {
        return;
      }
      setState(() => _recommended = value);
    } catch (_) {
      if (mounted &&
          generation == _recommendationGeneration &&
          identical(api, context.read<ConnectionStore>().api) &&
          profile == _profile) {
        setState(() => _recommended = null);
      }
    }
  }

  Widget _buildRecommendedRow(ThemeData theme) {
    final provider = _recommended?['provider']?.toString() ?? '';
    final model = _recommended?['model']?.toString() ?? '';
    if (provider.isEmpty || model.isEmpty) return const SizedBox.shrink();
    final current = provider == _currentProvider && model == _currentModel;
    return Row(
      children: [
        Icon(
          Icons.recommend_outlined,
          size: 17,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.modelRecommended(model),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        TextButton(
          onPressed: current ? null : () => _switchModel(provider, model),
          child: Text(
            current ? context.l10n.modelCurrent : context.l10n.modelApply,
          ),
        ),
      ],
    );
  }

  String _auxiliaryLabel(String key) => switch (key) {
    'vision' => context.l10n.configAuxVision,
    'web_extract' => context.l10n.configAuxWebExtract,
    'compression' => context.l10n.configAuxCompression,
    'skills_hub' => context.l10n.configAuxSkillsHub,
    'approval' => context.l10n.configAuxApproval,
    'mcp' => context.l10n.configAuxMcp,
    'title_generation' => context.l10n.configAuxTitleGeneration,
    'review' => context.l10n.configAuxReview,
    'triage_specifier' => context.l10n.configAuxTriage,
    'kanban_decomposer' => context.l10n.configAuxKanban,
    'profile_describer' => context.l10n.configAuxProfile,
    'curator' => context.l10n.configAuxCurator,
    _ => key,
  };

  List<Map<String, dynamic>> get _auxiliaryTasks =>
      (_auxiliary?['tasks'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value.cast<String, dynamic>())
          .toList(growable: false);

  Future<({String provider, String model})?> _chooseCatalogModel({
    bool allowAuto = false,
    String? title,
  }) {
    final providers = _providers
        .where(
          (provider) =>
              provider.slug.toLowerCase() != 'moa' &&
              provider.models.isNotEmpty,
        )
        .toList(growable: false);
    return showModalBottomSheet<({String provider, String model})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              ListTile(title: Text(title ?? context.l10n.modelChoose)),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    if (allowAuto)
                      ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: Text(context.l10n.modelFollowMain),
                        onTap: () => Navigator.pop(context, (
                          provider: 'auto',
                          model: '',
                        )),
                      ),
                    for (final provider in providers)
                      ExpansionTile(
                        title: Text(provider.name),
                        subtitle: Text(provider.slug),
                        children: [
                          for (final model in provider.models)
                            ListTile(
                              title: Text(model),
                              onTap: () => Navigator.pop(context, (
                                provider: provider.slug,
                                model: model,
                              )),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAuxiliaryTask(Map<String, dynamic> task) async {
    final taskKey = task['task']?.toString() ?? '';
    if (taskKey.isEmpty) return;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final selected = await _chooseCatalogModel(
      allowAuto: true,
      title: _auxiliaryLabel(taskKey),
    );
    if (selected == null || !mounted) return;
    if (!identical(api, context.read<ConnectionStore>().api) ||
        profile != _profile) {
      return;
    }
    final generation = ++_mutationGeneration;
    setState(() => _saving = true);
    try {
      final result = await _applyModelAssignment(
        api,
        {
          'scope': 'auxiliary',
          'task': taskKey,
          'provider': selected.provider,
          'model': selected.model,
        },
        profile: profile,
        generation: generation,
      );
      if (result == null) return;
      final next = _auxiliaryTasks
          .map(
            (row) => row['task'] == taskKey
                ? {
                    ...row,
                    'provider': selected.provider,
                    'model': selected.model,
                  }
                : row,
          )
          .toList();
      if (mounted && _ownsMutation(api, generation, profile)) {
        setState(() => _auxiliary = {...?_auxiliary, 'tasks': next});
      }
    } catch (error) {
      if (mounted && _ownsMutation(api, generation, profile)) {
        showHermesToast(
          context,
          message: context.l10n.modelAuxiliarySaveFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && _ownsMutation(api, generation, profile)) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _resetAuxiliary() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final generation = ++_mutationGeneration;
    setState(() => _saving = true);
    try {
      final result = await _applyModelAssignment(
        api,
        {
          'scope': 'auxiliary',
          'task': '__reset__',
          'provider': 'auto',
          'model': '',
        },
        profile: profile,
        generation: generation,
      );
      if (result == null) return;
      if (mounted && _ownsMutation(api, generation, profile)) {
        setState(() {
          _auxiliary = {
            ...?_auxiliary,
            'tasks': [
              for (final row in _auxiliaryTasks)
                {...row, 'provider': 'auto', 'model': ''},
            ],
          };
        });
      }
    } finally {
      if (mounted && _ownsMutation(api, generation, profile)) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildAuxiliarySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(theme, context.l10n.modelAuxiliaryTitle),
            ),
            if (_auxiliaryTasks.any(
              (task) => (task['provider']?.toString() ?? 'auto') != 'auto',
            ))
              TextButton(
                onPressed: _saving ? null : _resetAuxiliary,
                child: Text(context.l10n.modelAllFollowMain),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_auxiliary == null)
          Text(
            context.l10n.modelAuxiliaryUnavailable,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTertiary,
            ),
          )
        else
          HermesGlassCard(
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < _auxiliaryTasks.length;
                    index++
                  ) ...[
                    Builder(
                      builder: (context) {
                        final task = _auxiliaryTasks[index];
                        final key = task['task']?.toString() ?? '';
                        final provider = task['provider']?.toString() ?? 'auto';
                        final model = task['model']?.toString() ?? '';
                        return ListTile(
                          title: Text(_auxiliaryLabel(key)),
                          subtitle: Text(
                            provider == 'auto'
                                ? context.l10n.modelFollowMain
                                : '$provider${model.isEmpty ? '' : ' · $model'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _saving
                              ? null
                              : () => _editAuxiliaryTask(task),
                        );
                      },
                    ),
                    if (index != _auxiliaryTasks.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Map<String, Map<String, dynamic>> get _moaPresets {
    final raw = _moa?['presets'];
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is Map ? value.cast<String, dynamic>() : <String, dynamic>{},
      ),
    );
  }

  Future<void> _saveMoa(ApiClient api, Map<String, dynamic> next) async {
    final profile = _profile;
    final generation = ++_mutationGeneration;
    setState(() => _saving = true);
    try {
      _requireMutationTarget(api, profile);
      final saved = await api.saveMoaModels(next, profile: profile);
      _requireMutationTarget(api, profile);
      if (mounted && _ownsMutation(api, generation, profile)) {
        setState(() => _moa = saved);
      }
    } catch (error) {
      if (mounted && _ownsMutation(api, generation, profile)) {
        showHermesToast(
          context,
          message: context.l10n.modelMoaSaveFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted && _ownsMutation(api, generation, profile)) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _editMoaPreset() async {
    final name = _selectedMoaPreset;
    final preset = name == null ? null : _moaPresets[name];
    if (name == null || preset == null) return;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final edited = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _MoaPresetEditor(name: name, initial: preset, providers: _providers),
    );
    if (edited == null ||
        !mounted ||
        !identical(api, context.read<ConnectionStore>().api) ||
        profile != _profile) {
      return;
    }
    final next = jsonDecode(jsonEncode(_moa)) as Map<String, dynamic>;
    (next['presets'] as Map)[name] = edited;
    await _saveMoa(api, next);
  }

  Future<void> _addMoaPreset() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final profile = _profile;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.modelMoaCreatePreset),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.modelPresetName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.modelCreate),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name == null ||
        name.isEmpty ||
        name.length > 64 ||
        _moaPresets.containsKey(name) ||
        !mounted ||
        !identical(api, context.read<ConnectionStore>().api) ||
        profile != _profile) {
      return;
    }
    final source = _moaPresets[_selectedMoaPreset] ?? _moaPresets.values.first;
    final next = jsonDecode(jsonEncode(_moa)) as Map<String, dynamic>;
    (next['presets'] as Map)[name] = jsonDecode(jsonEncode(source));
    setState(() => _selectedMoaPreset = name);
    await _saveMoa(api, next);
  }

  Future<void> _deleteMoaPreset() async {
    final name = _selectedMoaPreset;
    final presets = _moaPresets;
    if (name == null || presets.length <= 1) return;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final next = jsonDecode(jsonEncode(_moa)) as Map<String, dynamic>;
    (next['presets'] as Map).remove(name);
    final remaining = (next['presets'] as Map).keys.first.toString();
    if (next['default_preset'] == name) next['default_preset'] = remaining;
    if (next['active_preset'] == name) next['active_preset'] = remaining;
    setState(() => _selectedMoaPreset = remaining);
    await _saveMoa(api, next);
  }

  Future<void> _setDefaultMoaPreset() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final next = jsonDecode(jsonEncode(_moa)) as Map<String, dynamic>;
    next['default_preset'] = _selectedMoaPreset;
    await _saveMoa(api, next);
  }

  Widget _buildMoaSection(ThemeData theme) {
    final presets = _moaPresets;
    final selected = presets[_selectedMoaPreset];
    return Column(
      key: const ValueKey('model-moa-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(theme, 'Mixture of Agents'),
        const SizedBox(height: 8),
        if (_moa == null)
          Text(
            context.l10n.modelMoaUnavailable,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTertiary,
            ),
          )
        else if (presets.isEmpty)
          Text(context.l10n.modelMoaNoEditable)
        else
          HermesGlassCard(
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: presets.containsKey(_selectedMoaPreset)
                              ? _selectedMoaPreset
                              : presets.keys.first,
                          decoration: InputDecoration(
                            labelText: context.l10n.modelMoaPresetLabel,
                          ),
                          items: [
                            for (final name in presets.keys)
                              DropdownMenuItem(value: name, child: Text(name)),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedMoaPreset = value),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.modelMoaCreateTooltip,
                        onPressed: _saving ? null : _addMoaPreset,
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: context.l10n.modelMoaDeleteTooltip,
                        onPressed: _saving || presets.length <= 1
                            ? null
                            : _deleteMoaPreset,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.l10n.modelMoaReferenceCount(
                          (selected['reference_models'] as List? ?? const [])
                              .length,
                        ),
                      ),
                      subtitle: Text(
                        context.l10n.modelMoaAggregatorSummary(
                          ((selected['aggregator'] as Map?)?['provider'] ?? '—')
                              .toString(),
                          ((selected['aggregator'] as Map?)?['model'] ?? '—')
                              .toString(),
                        ),
                      ),
                      trailing: const Icon(Icons.tune),
                      onTap: _saving ? null : _editMoaPreset,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _moa?['default_preset'] == _selectedMoaPreset ||
                                    _saving
                                ? null
                                : _setDefaultMoaPreset,
                            child: Text(
                              _moa?['default_preset'] == _selectedMoaPreset
                                  ? context.l10n.modelMoaDefaultPreset
                                  : context.l10n.modelMoaSetDefault,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _editMoaPreset,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(context.l10n.modelMoaEditConfiguration),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  // =====================================================================
  // Chat Configuration Tab
  // =====================================================================
  Widget _buildChatTab() {
    final fields = <Widget>[];
    if (configHasPath(_config, 'display.personality')) {
      fields.add(
        _textField(
          path: 'display.personality',
          label: context.l10n.configPersonalityDisplay,
        ),
      );
    } else if (configHasPath(_config, 'personality')) {
      fields.add(
        _textField(path: 'personality', label: context.l10n.configPersonality),
      );
    }
    if (configHasPath(_config, 'timezone')) {
      fields.add(
        _textField(path: 'timezone', label: context.l10n.configTimezone),
      );
    }
    if (configHasPath(_config, 'display.show_reasoning')) {
      fields.add(
        _switchTile(
          path: 'display.show_reasoning',
          title: context.l10n.configShowReasoning,
        ),
      );
    }
    fields.add(
      _switchTile(
        path: 'display.message_reactions',
        title: context.l10n.configMessageReactions,
      ),
    );
    if (configHasPath(_config, 'approvals.mode')) {
      fields.add(
        _dropdownTile(
          path: 'approvals.mode',
          title: context.l10n.configApprovalMode,
          options: const ['manual', 'smart', 'off'],
        ),
      );
    }
    if (configHasPath(_config, 'yolo')) {
      fields.add(
        _switchTile(path: 'yolo', title: context.l10n.configYoloApproval),
      );
    }
    if (fields.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: HermesEmptyState(
          icon: Icons.chat_bubble_outline,
          title: context.l10n.configChatFieldsUnavailable,
          description: context.l10n.configChatFieldsUnavailableDescription,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final field in fields) ...[
          HermesGlassCard(child: field),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMemoryTab() {
    final fields = <Widget>[];
    if (configHasPath(_config, 'memory.memory_enabled')) {
      fields.add(
        _switchTile(
          path: 'memory.memory_enabled',
          title: context.l10n.configPersistentMemory,
        ),
      );
    }
    if (configHasPath(_config, 'memory.user_profile_enabled')) {
      fields.add(
        _switchTile(
          path: 'memory.user_profile_enabled',
          title: context.l10n.configUserProfile,
        ),
      );
    }
    if (configHasPath(_config, 'memory.memory_char_limit')) {
      fields.add(
        _numberField(
          path: 'memory.memory_char_limit',
          label: context.l10n.configMemoryBudget,
        ),
      );
    }
    if (configHasPath(_config, 'memory.user_char_limit')) {
      fields.add(
        _numberField(
          path: 'memory.user_char_limit',
          label: context.l10n.configProfileBudget,
        ),
      );
    }
    if (configHasPath(_config, 'memory.provider')) {
      fields.add(
        _textField(
          path: 'memory.provider',
          label: context.l10n.configMemoryProvider,
        ),
      );
    }
    if (configHasPath(_config, 'context.engine')) {
      fields.add(
        _textField(
          path: 'context.engine',
          label: context.l10n.configContextEngine,
        ),
      );
    }
    if (configHasPath(_config, 'compression.enabled')) {
      fields.add(
        _switchTile(
          path: 'compression.enabled',
          title: context.l10n.configAutoCompression,
        ),
      );
    }
    if (configHasPath(_config, 'compression.threshold')) {
      fields.add(
        _numberField(
          path: 'compression.threshold',
          label: context.l10n.configCompressionThreshold,
        ),
      );
    }
    if (configHasPath(_config, 'compression.target_ratio')) {
      fields.add(
        _numberField(
          path: 'compression.target_ratio',
          label: context.l10n.configCompressionRatio,
        ),
      );
    }
    if (configHasPath(_config, 'compression.protect_last_n')) {
      fields.add(
        _numberField(
          path: 'compression.protect_last_n',
          label: context.l10n.configProtectRecent,
        ),
      );
    }
    if (fields.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: HermesEmptyState(
          icon: Icons.memory_outlined,
          title: context.l10n.configMemoryFieldsUnavailable,
          description: context.l10n.configMemoryFieldsUnavailableDescription,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final field in fields) ...[
          HermesGlassCard(child: field),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// Per-provider TTS/STT sub-fields — desktop's `voiceProviderKeys()`
  /// (app/settings/voice-provider-fields.tsx) reads these off a shared
  /// SECTIONS table (constants.ts, `id: 'voice'`) and renders them
  /// dynamically for whichever provider is selected; mobile follows the
  /// same field-per-path convention as the rest of this screen instead of a
  /// schema-driven renderer, so the key list is spelled out here once.
  static const Map<String, List<(String, String, _VoiceFieldType)>>
  _voiceProviderFields = {
    'tts.edge': [('tts.edge.voice', 'voice', _VoiceFieldType.text)],
    'tts.openai': [
      ('tts.openai.model', 'model', _VoiceFieldType.text),
      ('tts.openai.voice', 'voice', _VoiceFieldType.text),
    ],
    'tts.elevenlabs': [
      ('tts.elevenlabs.voice_id', 'voiceId', _VoiceFieldType.elevenLabsVoice),
      ('tts.elevenlabs.model_id', 'modelId', _VoiceFieldType.text),
    ],
    'tts.xai': [
      ('tts.xai.voice_id', 'voiceId', _VoiceFieldType.text),
      ('tts.xai.language', 'language', _VoiceFieldType.text),
      ('tts.xai.speed', 'speed', _VoiceFieldType.number),
      (
        'tts.xai.auto_speech_tags',
        'autoSpeechTags',
        _VoiceFieldType.switchType,
      ),
      (
        'tts.xai.optimize_streaming_latency',
        'streamingLatency',
        _VoiceFieldType.number,
      ),
      ('tts.xai.sample_rate', 'sampleRate', _VoiceFieldType.number),
      ('tts.xai.bit_rate', 'bitRate', _VoiceFieldType.number),
    ],
    'tts.minimax': [
      ('tts.minimax.model', 'model', _VoiceFieldType.text),
      ('tts.minimax.voice_id', 'voiceId', _VoiceFieldType.text),
    ],
    'tts.mistral': [
      ('tts.mistral.model', 'model', _VoiceFieldType.text),
      ('tts.mistral.voice_id', 'voiceId', _VoiceFieldType.text),
    ],
    'tts.gemini': [
      ('tts.gemini.model', 'model', _VoiceFieldType.text),
      ('tts.gemini.voice', 'voice', _VoiceFieldType.text),
    ],
    'tts.neutts': [
      ('tts.neutts.model', 'model', _VoiceFieldType.text),
      ('tts.neutts.device', 'device', _VoiceFieldType.text),
    ],
    'tts.kittentts': [
      ('tts.kittentts.model', 'model', _VoiceFieldType.text),
      ('tts.kittentts.voice', 'voice', _VoiceFieldType.text),
    ],
    'tts.piper': [('tts.piper.voice', 'voice', _VoiceFieldType.text)],
    'tts.deepinfra': [
      ('tts.deepinfra.model', 'model', _VoiceFieldType.text),
      ('tts.deepinfra.voice', 'voice', _VoiceFieldType.text),
    ],
    'stt.local': [
      ('stt.local.model', 'model', _VoiceFieldType.text),
      ('stt.local.language', 'language', _VoiceFieldType.text),
    ],
    'stt.openai': [('stt.openai.model', 'model', _VoiceFieldType.text)],
    'stt.groq': [('stt.groq.model', 'model', _VoiceFieldType.text)],
    'stt.mistral': [('stt.mistral.model', 'model', _VoiceFieldType.text)],
    'stt.elevenlabs': [
      ('stt.elevenlabs.model_id', 'modelId', _VoiceFieldType.text),
      ('stt.elevenlabs.language_code', 'languageCode', _VoiceFieldType.text),
      (
        'stt.elevenlabs.tag_audio_events',
        'audioEvents',
        _VoiceFieldType.switchType,
      ),
      ('stt.elevenlabs.diarize', 'diarization', _VoiceFieldType.switchType),
    ],
  };

  String _voiceFieldLabel(String key) => switch (key) {
    'voice' => context.l10n.configVoice,
    'model' => context.l10n.configVoiceModel,
    'voiceId' => context.l10n.configVoiceId,
    'modelId' => context.l10n.configModelId,
    'language' => context.l10n.configLanguage,
    'speed' => context.l10n.configSpeechSpeed,
    'autoSpeechTags' => context.l10n.configAutoSpeechTags,
    'streamingLatency' => context.l10n.configStreamingLatency,
    'sampleRate' => context.l10n.configSampleRate,
    'bitRate' => context.l10n.configBitRate,
    'device' => context.l10n.configDevice,
    'languageCode' => context.l10n.configLanguageCode,
    'audioEvents' => context.l10n.configAudioEvents,
    'diarization' => context.l10n.configDiarization,
    _ => key,
  };

  List<Widget> _voiceProviderFieldWidgets(String section, String? provider) {
    if (provider == null || provider.isEmpty) return const [];
    final specs = _voiceProviderFields['$section.$provider'];
    if (specs == null) return const [];
    return [
      for (final (path, labelKey, type) in specs)
        if (configHasPath(_config, path))
          switch (type) {
            _VoiceFieldType.text => _textField(
              path: path,
              label: _voiceFieldLabel(labelKey),
            ),
            _VoiceFieldType.number => _numberField(
              path: path,
              label: _voiceFieldLabel(labelKey),
            ),
            _VoiceFieldType.switchType => _switchTile(
              path: path,
              title: _voiceFieldLabel(labelKey),
            ),
            _VoiceFieldType.elevenLabsVoice => _ElevenLabsVoiceField(
              current: configValueAt(_config, path)?.toString() ?? '',
              onSelected: (v) => _patchPath(path, v),
              saving: _saving,
            ),
          },
    ];
  }

  Widget _buildVoiceTab() {
    const sttProviders = [
      'local',
      'groq',
      'openai',
      'mistral',
      'xai',
      'elevenlabs',
    ];
    const ttsProviders = [
      'edge',
      'openai',
      'elevenlabs',
      'xai',
      'minimax',
      'mistral',
      'gemini',
      'neutts',
      'kittentts',
      'piper',
      'deepinfra',
    ];
    final fields = <Widget>[];
    if (configHasPath(_config, 'stt.enabled')) {
      fields.add(
        _switchTile(
          path: 'stt.enabled',
          title: context.l10n.configSpeechToText,
        ),
      );
    }
    if (configHasPath(_config, 'stt.echo_transcripts')) {
      fields.add(
        _switchTile(
          path: 'stt.echo_transcripts',
          title: context.l10n.configEchoTranscripts,
        ),
      );
    }
    if (configHasPath(_config, 'stt.provider')) {
      fields.add(
        _dropdownTile(
          path: 'stt.provider',
          title: context.l10n.configSttProvider,
          options: sttProviders,
        ),
      );
      fields.addAll(
        _voiceProviderFieldWidgets(
          'stt',
          configValueAt(_config, 'stt.provider')?.toString(),
        ),
      );
    }
    if (configHasPath(_config, 'tts.provider')) {
      fields.add(
        _dropdownTile(
          path: 'tts.provider',
          title: context.l10n.configTtsProvider,
          options: ttsProviders,
        ),
      );
      fields.addAll(
        _voiceProviderFieldWidgets(
          'tts',
          configValueAt(_config, 'tts.provider')?.toString(),
        ),
      );
    }
    if (configHasPath(_config, 'voice.auto_tts')) {
      fields.add(
        _switchTile(
          path: 'voice.auto_tts',
          title: context.l10n.configAutoReadReplies,
        ),
      );
    }
    if (configHasPath(_config, 'voice.max_recording_seconds')) {
      fields.add(
        _numberField(
          path: 'voice.max_recording_seconds',
          label: context.l10n.configMaxRecordingSeconds,
        ),
      );
    }
    if (configHasPath(_config, 'voice.record_key')) {
      fields.add(
        _textField(
          path: 'voice.record_key',
          label: context.l10n.configRecordShortcut,
        ),
      );
    }
    if (configHasPath(_config, 'voice.client_direct')) {
      fields.add(
        _switchTile(
          path: 'voice.client_direct',
          title: context.l10n.configDirectVoiceService,
        ),
      );
    }
    if (fields.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: HermesEmptyState(
          icon: Icons.mic_none,
          title: context.l10n.configVoiceFieldsUnavailable,
          description: context.l10n.configVoiceFieldsUnavailableDescription,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final field in fields) ...[
          HermesGlassCard(child: field),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // =====================================================================
  // Tools & Keys Tab
  // =====================================================================
  Widget _buildToolsKeysTab() {
    final theme = Theme.of(context);

    _credentialProvidersFuture ??= context
        .read<ConnectionStore>()
        .api
        ?.credentialProviders();
    return FutureBuilder<List<CredentialProvider>>(
      future: _credentialProvidersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.l10n.commonOperationFailed));
        }
        final providers = snapshot.data ?? const <CredentialProvider>[];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(theme, context.l10n.configProviderApiKeys),
              const SizedBox(height: 8),
              if (providers.isEmpty)
                HermesEmptyState(
                  icon: Icons.vpn_key_outlined,
                  title: context.l10n.configNoProviders,
                  description: context.l10n.configNoProvidersDescription,
                )
              else
                ...providers.map((p) => _buildProviderKeyCard(theme, p)),
              const SizedBox(height: 24),
              _sectionTitle(theme, context.l10n.configEnvironmentVariables),
              const SizedBox(height: 8),
              _EnvVarsSection(profile: _profile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderKeyCard(ThemeData theme, CredentialProvider provider) {
    final isConfigured = provider.authenticated;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HermesGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConfigured
                        ? HermesSemantic.green
                        : HermesSemantic.gray,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isConfigured
                        ? HermesSemantic.green.withValues(alpha: 0.1)
                        : HermesSemantic.gray.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isConfigured
                        ? context.l10n.configConfigured
                        : context.l10n.configNotConfigured,
                    style: TextStyle(
                      color: isConfigured
                          ? HermesSemantic.green
                          : HermesSemantic.gray,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (provider.models.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.configAvailableModels(provider.models.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isConfigured)
                  TextButton.icon(
                    onPressed: () async {
                      final connection = context.read<ConnectionStore>();
                      final api = connectedApiOrNotify(context, connection);
                      if (api == null) return;
                      final profile = _profile;
                      final generation = ++_mutationGeneration;
                      try {
                        await api.disconnectCredential(provider.slug);
                        if (mounted &&
                            _ownsMutation(api, generation, profile)) {
                          showHermesToast(
                            context,
                            message: context.l10n.configDisconnectedProvider(
                              provider.name,
                            ),
                          );
                          setState(() => _credentialProvidersFuture = null);
                        }
                      } catch (e) {
                        if (!mounted ||
                            !_ownsMutation(api, generation, profile)) {
                          return;
                        }
                        showHermesToast(
                          context,
                          message: context.l10n.configDisconnectFailed('$e'),
                          kind: HermesToastKind.error,
                        );
                      }
                    },
                    icon: const Icon(Icons.link_off, size: 16),
                    label: Text(context.l10n.commonDisconnect),
                  ),
                FilledButton.icon(
                  onPressed: () => _showApiKeyDialog(provider),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(
                    isConfigured
                        ? context.l10n.configUpdateKey
                        : context.l10n.configAddKey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApiKeyDialog(CredentialProvider provider) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final keyController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(context.l10n.configProviderApiKey(provider.name)),
          content: TextField(
            controller: keyController,
            decoration: InputDecoration(
              labelText: context.l10n.connectApiKey,
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      ),
    );

    final key = keyController.text;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => keyController.dispose(),
    );
    if (!mounted) return;

    if (result == true && key.isNotEmpty) {
      final profile = _profile;
      if (!identical(api, connection.api)) return;
      final generation = ++_mutationGeneration;
      try {
        _requireMutationTarget(api, profile);
        await api.saveCredentialKey(provider.slug, key);
        if (!mounted || !_ownsMutation(api, generation, profile)) return;
        showHermesToast(
          context,
          message: context.l10n.configProviderKeySaved(provider.name),
        );
        setState(() => _credentialProvidersFuture = null);
      } catch (e) {
        if (!mounted || !_ownsMutation(api, generation, profile)) return;
        showHermesToast(
          context,
          message: context.l10n.configSaveFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  // =====================================================================
  // Helpers
  // =====================================================================
  Future<void> _patchPath(String path, dynamic value) async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final session = context.read<SessionStore>();
    final profile = session.profile ?? session.activeProfile;
    final generation = ++_mutationGeneration;
    final patch = configPatchAt(_config, path, value);
    setState(() => _saving = true);
    try {
      await api.putConfig(patch, profile: profile);
      if (!mounted || !_ownsMutation(api, generation, profile)) return;
      session.applyProfileConfigPatch(profile, patch);
      final next = Map<String, dynamic>.from(_config);
      patch.forEach((key, val) {
        if (val is Map && next[key] is Map) {
          next[key] = {
            ...Map<String, dynamic>.from(next[key] as Map),
            ...Map<String, dynamic>.from(val),
          };
        } else {
          next[key] = val;
        }
      });
      setState(() {
        _config = next;
        _saving = false;
      });
      showHermesToast(context, message: context.l10n.configSaved);
    } catch (e) {
      if (!mounted || !_ownsMutation(api, generation, profile)) return;
      setState(() => _saving = false);
      showHermesToast(
        context,
        message: context.l10n.configSaveFailed('$e'),
        kind: HermesToastKind.error,
      );
    }
  }

  Widget _switchTile({required String path, required String title}) {
    final value = configValueAt(_config, path) == true;
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: _saving ? null : (v) => _patchPath(path, v),
    );
  }

  Widget _dropdownTile({
    required String path,
    required String title,
    required List<String> options,
  }) {
    final raw = configValueAt(_config, path)?.toString();
    final items = [...options];
    if (raw != null && raw.isNotEmpty && !items.contains(raw)) {
      items.add(raw);
    }
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: raw != null && items.contains(raw) ? raw : null,
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final opt in items) DropdownMenuItem(value: opt, child: Text(opt)),
      ],
      onChanged: _saving
          ? null
          : (v) {
              if (v != null) _patchPath(path, v);
            },
    );
  }

  Widget _textField({required String path, required String label}) {
    final current = configValueAt(_config, path)?.toString() ?? '';
    return TextFormField(
      key: ValueKey('$path:$current'),
      initialValue: current,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: context.l10n.configPressEnterToSave,
      ),
      enabled: !_saving,
      onFieldSubmitted: (v) => _patchPath(path, v),
    );
  }

  Widget _numberField({required String path, required String label}) {
    final current = configValueAt(_config, path);
    return TextFormField(
      key: ValueKey('$path:$current'),
      initialValue: current?.toString() ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      enabled: !_saving,
      onFieldSubmitted: (v) {
        final asInt = int.tryParse(v);
        final asDouble = double.tryParse(v);
        if (current is int && asInt != null) {
          _patchPath(path, asInt);
        } else if (asDouble != null) {
          _patchPath(path, current is int ? asDouble.round() : asDouble);
        } else {
          showHermesToast(
            context,
            message: context.l10n.configEnterNumber,
            kind: HermesToastKind.error,
          );
        }
      },
    );
  }

  /// `fallback_providers` is a list of `{provider, model}` dicts tried in
  /// order when the default model fails (legacy entries may be plain
  /// "provider/model" strings). Rendering it through the generic
  /// `_stringListField` stringified each map to Dart's `{provider: x, model:
  /// y}` toString and, on save, wrote that garbled text back as a raw
  /// string — corrupting the config. This structured editor mirrors
  /// `_MoaSlotEditor` instead.
  List<Map<String, dynamic>> _fallbackEntries() {
    final raw = configValueAt(_config, 'fallback_providers');
    if (raw is! List) return [];
    return raw.map((item) {
      if (item is Map) return item.cast<String, dynamic>();
      if (item is String) {
        final sep = item.contains('/') ? '/' : (item.contains(':') ? ':' : '');
        if (sep.isEmpty) return {'provider': '', 'model': item};
        final idx = item.indexOf(sep);
        return {
          'provider': item.substring(0, idx),
          'model': item.substring(idx + 1),
        };
      }
      return {'provider': '', 'model': ''};
    }).toList();
  }

  Widget _buildFallbackProvidersField(ThemeData theme) {
    final entries = _fallbackEntries();
    final providers = _providers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.modelFallbackHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(context.l10n.modelNoAvailable, style: theme.textTheme.bodySmall),
        for (var index = 0; index < entries.length; index++) ...[
          _MoaSlotEditor(
            label: context.l10n.modelMoaReferenceNumber(index + 1),
            value: entries[index],
            providers: providers,
            canRemove: true,
            onChanged: (value) {
              final next = _fallbackEntries();
              next[index] = value;
              _patchPath('fallback_providers', next);
            },
            onRemove: () {
              final next = _fallbackEntries()..removeAt(index);
              _patchPath('fallback_providers', next);
            },
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _saving || providers.isEmpty
                ? null
                : () {
                    final provider = providers.first;
                    final next = [
                      ..._fallbackEntries(),
                      {
                        'provider': provider.slug,
                        'model': provider.models.firstOrNull ?? '',
                      },
                    ];
                    _patchPath('fallback_providers', next);
                  },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.modelMoaAddReference),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: theme.textPrimary,
        letterSpacing: 0,
      ),
    );
  }
}

/// Provider/tool env vars (`GET/PUT/DELETE /api/env`, `POST /api/env/reveal`).
/// Excludes messaging-channel credentials — those live on the Messaging page.
class _EnvVarsSection extends StatefulWidget {
  final String? profile;
  const _EnvVarsSection({this.profile});

  @override
  State<_EnvVarsSection> createState() => _EnvVarsSectionState();
}

class _EnvVarsSectionState extends State<_EnvVarsSection>
    with ConnectionReloadMixin<_EnvVarsSection> {
  Map<String, ProviderEnvVar>? _vars;
  String? _error;
  bool _showAdvanced = false;
  final Set<String> _busyKeys = {};
  int _generation = 0;
  ApiClient? _loadedApi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _connectionChanged);
  }

  @override
  void didUpdateWidget(covariant _EnvVarsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _connectionChanged();
  }

  @override
  void dispose() {
    ++_generation;
    disposeConnectionObserver();
    super.dispose();
  }

  void _connectionChanged() {
    ++_generation;
    if (mounted) {
      setState(() {
        _vars = null;
        _error = null;
        _busyKeys.clear();
        _loadedApi = null;
      });
    }
    _load();
  }

  bool _owns(ApiClient api, int generation, String? profile) =>
      mounted &&
      generation == _generation &&
      profile == widget.profile &&
      identical(_loadedApi, api) &&
      identical(context.read<ConnectionStore>().api, api);

  Future<void> _load() async {
    final generation = ++_generation;
    final api = context.read<ConnectionStore>().api;
    final profile = widget.profile;
    if (api == null) {
      if (mounted && generation == _generation) {
        setState(() {
          _vars = null;
          _loadedApi = null;
          _error = context.l10n.backendDisconnected;
        });
      }
      return;
    }
    try {
      final raw = await api.providerEnvVars(profile: profile);
      final vars = raw.map(
        (key, value) => MapEntry(
          key,
          ProviderEnvVar.fromJson(key, (value as Map).cast<String, dynamic>()),
        ),
      );
      if (mounted &&
          generation == _generation &&
          profile == widget.profile &&
          identical(api, context.read<ConnectionStore>().api)) {
        setState(() {
          _vars = vars;
          _loadedApi = api;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _generation &&
          profile == widget.profile &&
          identical(api, context.read<ConnectionStore>().api)) {
        setState(() {
          _vars = null;
          _loadedApi = api;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _showEditDialog(String key, ProviderEnvVar info) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final generation = _generation;
    final profile = widget.profile;
    if (!_owns(api, generation, profile)) return;
    final ctrl = TextEditingController();
    var obscure = info.isPassword;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(key),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.description.isNotEmpty) ...[
                Text(
                  info.description,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: info.isSet
                      ? context.l10n.configNewValueOptional
                      : context.l10n.configValue,
                  border: const OutlineInputBorder(),
                  suffixIcon: info.isPassword
                      ? IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setDlg(() => obscure = !obscure),
                        )
                      : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    final value = ctrl.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (saved != true ||
        value.trim().isEmpty ||
        !_owns(api, generation, profile)) {
      return;
    }
    if (!mounted) return;
    setState(() => _busyKeys.add(key));
    try {
      requireActiveApi(context, context.read<ConnectionStore>(), api);
      await api.setProviderEnvVar(key, value.trim(), profile: profile);
      if (_owns(api, generation, profile)) {
        setState(() => _busyKeys.remove(key));
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      if (_owns(api, generation, profile)) {
        showHermesToast(
          context,
          message: context.l10n.configSaveFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (_owns(api, generation, profile)) {
        setState(() => _busyKeys.remove(key));
      }
    }
  }

  Future<void> _reveal(String key) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final generation = _generation;
    final profile = widget.profile;
    if (!_owns(api, generation, profile)) return;
    try {
      final value = await api.revealProviderEnvVar(key, profile: profile) ?? '';
      if (!mounted) return;
      if (!_owns(api, generation, profile)) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(key),
          content: SelectableText(value),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonClose),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (_owns(api, generation, profile)) {
        showHermesToast(
          context,
          message: context.l10n.configRevealFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _delete(String key) async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final generation = _generation;
    final profile = widget.profile;
    if (!_owns(api, generation, profile)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.configDeleteVariableQuestion(key)),
        content: Text(context.l10n.configDeleteVariableDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !_owns(api, generation, profile)) return;
    if (!mounted) return;
    setState(() => _busyKeys.add(key));
    try {
      requireActiveApi(context, context.read<ConnectionStore>(), api);
      await api.deleteProviderEnvVar(key, profile: profile);
      if (_owns(api, generation, profile)) {
        setState(() => _busyKeys.remove(key));
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      if (_owns(api, generation, profile)) {
        showHermesToast(
          context,
          message: context.l10n.configDeleteFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (_owns(api, generation, profile)) {
        setState(() => _busyKeys.remove(key));
      }
    }
  }

  Future<void> _addCustom() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final generation = _generation;
    final profile = widget.profile;
    if (!_owns(api, generation, profile)) return;
    final keyCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.configAddEnvironmentVariable),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.configVariableName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valueCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.configValue,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    final key = keyCtrl.text.trim();
    final value = valueCtrl.text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      keyCtrl.dispose();
      valueCtrl.dispose();
    });
    if (saved != true ||
        key.isEmpty ||
        value.isEmpty ||
        !_owns(api, generation, profile)) {
      return;
    }
    if (!mounted) return;
    try {
      requireActiveApi(context, context.read<ConnectionStore>(), api);
      await api.setProviderEnvVar(key, value, profile: profile);
      if (_owns(api, generation, profile)) await _load();
    } catch (e) {
      if (!mounted) return;
      if (_owns(api, generation, profile)) {
        showHermesToast(
          context,
          message: context.l10n.configSaveFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return HermesErrorState(description: _error, onRetry: _load);
    }
    final vars = _vars;
    if (vars == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final visible = vars.entries.where((e) => !e.value.channelManaged).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final basic = visible.where((e) => !e.value.advanced).toList();
    final advanced = visible.where((e) => e.value.advanced).toList();

    if (visible.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HermesEmptyState(
            icon: Icons.tune,
            title: context.l10n.configNoEnvironmentVariables,
            description: context.l10n.configNoEnvironmentVariablesDescription,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addCustom,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.commonAdd),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in basic) _buildRow(theme, entry.key, entry.value),
        if (advanced.isNotEmpty) ...[
          TextButton.icon(
            onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
            icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _showAdvanced
                  ? context.l10n.configHideAdvancedVariables
                  : context.l10n.configShowAdvancedVariables(advanced.length),
            ),
          ),
          if (_showAdvanced)
            for (final entry in advanced)
              _buildRow(theme, entry.key, entry.value),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addCustom,
          icon: const Icon(Icons.add),
          label: Text(context.l10n.commonAdd),
        ),
      ],
    );
  }

  Widget _buildRow(ThemeData theme, String key, ProviderEnvVar info) {
    final busy = _busyKeys.contains(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HermesGlassCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.providerLabel.isNotEmpty
                        ? '${info.providerLabel} · $key'
                        : key,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (info.description.isNotEmpty)
                    Text(
                      info.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    info.isSet
                        ? (info.redactedValue ?? context.l10n.configSet)
                        : context.l10n.configNotSet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: info.isSet
                          ? HermesSemantic.green
                          : theme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              if (info.isSet)
                IconButton(
                  tooltip: context.l10n.providerRevealValue,
                  onPressed: () => _reveal(key),
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                ),
              IconButton(
                tooltip: context.l10n.commonEdit,
                onPressed: () => _showEditDialog(key, info),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              if (info.isSet)
                IconButton(
                  tooltip: context.l10n.commonDelete,
                  onPressed: () => _delete(key),
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoaPresetEditor extends StatefulWidget {
  const _MoaPresetEditor({
    required this.name,
    required this.initial,
    required this.providers,
  });

  final String name;
  final Map<String, dynamic> initial;
  final List<ModelInfo> providers;

  @override
  State<_MoaPresetEditor> createState() => _MoaPresetEditorState();
}

class _MoaPresetEditorState extends State<_MoaPresetEditor> {
  late final Map<String, dynamic> _preset =
      jsonDecode(jsonEncode(widget.initial)) as Map<String, dynamic>;

  List<ModelInfo> get _providers => widget.providers
      .where(
        (provider) =>
            provider.slug.toLowerCase() != 'moa' && provider.models.isNotEmpty,
      )
      .toList(growable: false);

  List<Map<String, dynamic>> get _references =>
      (_preset['reference_models'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value.cast<String, dynamic>())
          .toList();

  Map<String, dynamic> get _aggregator {
    final value = _preset['aggregator'];
    return value is Map ? value.cast<String, dynamic>() : {};
  }

  bool get _complete {
    bool slot(Map<String, dynamic> value) =>
        (value['provider']?.toString().trim().isNotEmpty ?? false) &&
        (value['model']?.toString().trim().isNotEmpty ?? false);
    final refs = _references;
    return refs.isNotEmpty && refs.every(slot) && slot(_aggregator);
  }

  void _setReferences(List<Map<String, dynamic>> value) {
    setState(() => _preset['reference_models'] = value);
  }

  void _addReference() {
    final provider = _providers.firstOrNull;
    if (provider == null) return;
    _setReferences([
      ..._references,
      {'provider': provider.slug, 'model': provider.models.first},
    ]);
  }

  Widget _numberField(
    String key,
    String label, {
    bool integer = false,
    bool nullable = false,
  }) {
    final current = _preset[key];
    return TextFormField(
      initialValue: current?.toString() ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (raw) {
        final value = raw.trim();
        if (value.isEmpty && nullable) {
          _preset[key] = null;
          return;
        }
        final parsed = integer ? int.tryParse(value) : double.tryParse(value);
        if (parsed != null) _preset[key] = parsed;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final references = _references;
    final aggregator = _aggregator;
    final policy = _preset['degraded_reference_policy']?.toString() ?? 'loud';
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(context.l10n.modelMoaEditTitle(widget.name)),
              subtitle: Text(context.l10n.modelMoaDescription),
              trailing: IconButton(
                tooltip: context.l10n.commonClose,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.modelMoaEnablePreset),
                    value: _preset['enabled'] != false,
                    onChanged: (value) =>
                        setState(() => _preset['enabled'] = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.modelMoaReferenceModels,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < references.length; index++) ...[
                    _MoaSlotEditor(
                      label: context.l10n.modelMoaReferenceNumber(index + 1),
                      value: references[index],
                      providers: _providers,
                      canRemove: references.length > 1,
                      onChanged: (value) {
                        final next = _references;
                        next[index] = value;
                        _setReferences(next);
                      },
                      onRemove: () {
                        final next = _references..removeAt(index);
                        _setReferences(next);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _providers.isEmpty ? null : _addReference,
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.modelMoaAddReference),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.modelMoaAggregator,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _MoaSlotEditor(
                    label: context.l10n.modelMoaAggregatorModel,
                    value: aggregator,
                    providers: _providers,
                    onChanged: (value) =>
                        setState(() => _preset['aggregator'] = value),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.modelMoaRuntimeParameters,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          'reference_temperature',
                          context.l10n.modelMoaReferenceTemperature,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(
                          'aggregator_temperature',
                          context.l10n.modelMoaAggregatorTemperature,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          'max_tokens',
                          context.l10n.modelMoaAggregatorMaxTokens,
                          integer: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(
                          'reference_max_tokens',
                          context.l10n.modelMoaReferenceMaxTokens,
                          integer: true,
                          nullable: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          'reference_timeout',
                          context.l10n.modelMoaReferenceTimeout,
                          nullable: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
                              const {'loud', 'silent'}.contains(policy)
                              ? policy
                              : 'loud',
                          decoration: InputDecoration(
                            labelText: context.l10n.modelMoaDegradedPolicy,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'loud',
                              child: Text(context.l10n.modelMoaDegradedLoud),
                            ),
                            DropdownMenuItem(
                              value: 'silent',
                              child: Text(context.l10n.modelMoaDegradedSilent),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _preset['degraded_reference_policy'] = value;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _preset['fanout']?.toString() ?? '',
                    decoration: InputDecoration(
                      labelText: context.l10n.modelMoaFanoutCadence,
                      hintText: context.l10n.modelMoaFanoutHint,
                    ),
                    onChanged: (value) => _preset['fanout'] =
                        value.trim().isEmpty ? null : value.trim(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _complete
                      ? () => Navigator.pop(context, _preset)
                      : null,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _complete
                        ? context.l10n.modelMoaSaveConfiguration
                        : context.l10n.modelMoaCompleteModels,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoaSlotEditor extends StatelessWidget {
  const _MoaSlotEditor({
    required this.label,
    required this.value,
    required this.providers,
    required this.onChanged,
    this.canRemove = false,
    this.onRemove,
  });

  final String label;
  final Map<String, dynamic> value;
  final List<ModelInfo> providers;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool canRemove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final provider = value['provider']?.toString() ?? '';
    final model = value['model']?.toString() ?? '';
    final providerValues = [for (final item in providers) item.slug];
    if (provider.isNotEmpty && !providerValues.contains(provider)) {
      providerValues.insert(0, provider);
    }
    final providerRow = providers
        .where((item) => item.slug == provider)
        .firstOrNull;
    final models = [...?providerRow?.models];
    if (model.isNotEmpty && !models.contains(model)) models.insert(0, model);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            if (canRemove)
              IconButton(
                tooltip: context.l10n.modelRemove,
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline, size: 19),
              ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            Widget providerDropdown() => DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: providerValues.contains(provider) ? provider : null,
              decoration: InputDecoration(
                labelText: context.l10n.modelProvider,
              ),
              items: [
                for (final slug in providerValues)
                  DropdownMenuItem(
                    value: slug,
                    child: Text(
                      providers
                              .where((item) => item.slug == slug)
                              .firstOrNull
                              ?.name ??
                          slug,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (nextProvider) {
                if (nextProvider == null) return;
                final firstModel = providers
                    .where((item) => item.slug == nextProvider)
                    .firstOrNull
                    ?.models
                    .firstOrNull;
                onChanged({
                  ...value,
                  'provider': nextProvider,
                  'model': firstModel ?? '',
                });
              },
            );
            Widget modelDropdown() => DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: models.contains(model) ? model : null,
              decoration: InputDecoration(labelText: context.l10n.modelLabel),
              items: [
                for (final item in models)
                  DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (nextModel) {
                if (nextModel != null) {
                  onChanged({...value, 'model': nextModel});
                }
              },
            );

            if (constraints.maxWidth < 560) {
              return Column(
                children: [
                  providerDropdown(),
                  const SizedBox(height: 12),
                  modelDropdown(),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: providerDropdown()),
                const SizedBox(width: 12),
                Expanded(child: modelDropdown()),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Desktop parity: `voice-provider-fields.tsx`'s ElevenLabs voice picker —
/// the account's real voice catalog instead of a bare "paste the voice ID"
/// text field. Falls back to that same plain text field when no key is
/// configured or the fetch fails, so the setting stays editable either way.
class _ElevenLabsVoiceField extends StatefulWidget {
  final String current;
  final ValueChanged<String> onSelected;
  final bool saving;

  const _ElevenLabsVoiceField({
    required this.current,
    required this.onSelected,
    required this.saving,
  });

  @override
  State<_ElevenLabsVoiceField> createState() => _ElevenLabsVoiceFieldState();
}

class _ElevenLabsVoiceFieldState extends State<_ElevenLabsVoiceField>
    with ConnectionReloadMixin<_ElevenLabsVoiceField> {
  List<Map<String, dynamic>>? _voices;
  String? _loadError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _load);
  }

  @override
  void dispose() {
    ++_loadGeneration;
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final api = context.read<ConnectionStore>().api;
    if (api == null) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _voices = const [];
          _loadError = context.l10n.backendDisconnected;
        });
      }
      return;
    }
    try {
      final voices = await api.elevenLabsVoices();
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<ConnectionStore>().api)) {
        setState(() {
          _voices = voices;
          _loadError = null;
        });
      }
    } catch (error) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, context.read<ConnectionStore>().api)) {
        setState(() {
          _voices = const [];
          _loadError = '$error';
        });
      }
    }
  }

  String _label(Map<String, dynamic> v) {
    final name = (v['name'] ?? v['voice_id'] ?? 'Voice').toString();
    final category = (v['category'] ?? '').toString();
    return category.isNotEmpty ? '$name ($category)' : name;
  }

  @override
  Widget build(BuildContext context) {
    final voices = _voices;
    if (voices == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (voices.isEmpty) {
      return TextFormField(
        key: ValueKey('elevenlabs-voice-fallback:${widget.current}'),
        initialValue: widget.current,
        decoration: InputDecoration(
          labelText: context.l10n.configVoiceId,
          border: const OutlineInputBorder(),
          helperText: _loadError == null
              ? context.l10n.configVoiceIdManual
              : context.l10n.configVoicesLoadFailed(_loadError!),
        ),
        enabled: !widget.saving,
        onFieldSubmitted: widget.onSelected,
      );
    }
    final ids = [for (final v in voices) v['voice_id']?.toString() ?? ''];
    final hasCurrent = ids.contains(widget.current);
    return DropdownButtonFormField<String>(
      initialValue: hasCurrent ? widget.current : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.configVoiceId,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final v in voices)
          DropdownMenuItem(
            value: v['voice_id']?.toString() ?? '',
            child: Text(_label(v), overflow: TextOverflow.ellipsis),
          ),
        if (!hasCurrent && widget.current.isNotEmpty)
          DropdownMenuItem(
            value: widget.current,
            child: Text(widget.current, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: widget.saving
          ? null
          : (v) {
              if (v != null) widget.onSelected(v);
            },
    );
  }
}
