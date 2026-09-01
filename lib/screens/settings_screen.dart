import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/connection_store.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/terminal_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';

/// System, security, terminal, backend, and connection settings.
class SettingsScreen extends StatefulWidget {
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with ConnectionReloadMixin<SettingsScreen> {
  static const _terminalFontSuggestions = [
    'Consolas',
    'JetBrains Mono',
    'Fira Code',
    'Cascadia Code',
    'DejaVu Sans Mono',
    'Liberation Mono',
    'MesloLGS NF',
    'JetBrainsMono Nerd Font',
    'CaskaydiaCove Nerd Font',
    'FiraCode Nerd Font',
    'Hack Nerd Font',
    'SauceCodePro Nerd Font',
    'SF Mono',
    'Menlo',
  ];

  Map<String, dynamic>? _config;
  String? _error;
  bool _busy = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    setState(() {
      _config = null;
      _error = null;
      _busy = true;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await api.get('/api/v1/config');
      final config = ((response as Map)['config'] as Map?)
          ?.cast<String, dynamic>();
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() {
        _config = config;
        _error = null;
        _busy = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() {
        _error = '$error';
        _busy = false;
      });
    }
  }

  String get _terminalFontFamily {
    final terminal = _config?['terminal'] as Map?;
    return terminal?['font_family']?.toString().trim() ?? '';
  }

  Future<void> _editTerminalFont() async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final ownerApi = connectedApiOrNotify(context, connection);
    if (ownerApi == null) return;
    final controller = TextEditingController(text: _terminalFontFamily);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.terminalFontTitle),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.terminalFontHint),
                onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
              ),
              const SizedBox(height: HermesSpacing.md),
              Wrap(
                spacing: HermesSpacing.xs,
                runSpacing: HermesSpacing.xs,
                children: [
                  for (final font in _terminalFontSuggestions)
                    ActionChip(
                      label: Text(font),
                      onPressed: () => controller.text = font,
                    ),
                ],
              ),
              const SizedBox(height: HermesSpacing.md),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, _) => Text(
                  l10n.terminalFontPreview,
                  style: TextStyle(
                    fontFamily: value.text.trim().isEmpty
                        ? 'Cascadia Code'
                        : value.text
                              .trim()
                              .split(',')
                              .first
                              .replaceAll(RegExp(r'''^['"]|['"]$'''), ''),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: controller.clear,
            child: Text(l10n.commonReset),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (selected == null || !mounted) return;
    try {
      requireActiveApi(context, connection, ownerApi);
      await context.read<TerminalStore>().setFontFamily(
        selected,
        expectedApi: ownerApi,
      );
      if (!mounted) return;
      requireActiveApi(context, connection, ownerApi);
      setState(() {
        _config ??= <String, dynamic>{};
        final terminal = ((_config!['terminal'] as Map?) ?? const {})
            .cast<String, dynamic>();
        _config!['terminal'] = {...terminal, 'font_family': selected.trim()};
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.terminalFontSaved)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.terminalFontSaveFailed('$error'))),
      );
    }
  }

  Future<void> _restartBackend() async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsRestartBackendQuestion),
        content: Text(l10n.settingsRestartBackendWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonRestart),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      requireActiveApi(context, connection, api);
      await api.restartBackend();
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsBackendRestarted)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsBackendRestartFailed('$error'))),
      );
    }
  }

  Future<void> _clearConnection() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsChangeConnectionQuestion),
        content: Text(l10n.settingsChangeConnectionWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ConnectionStore>().clearConnection();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = _buildBody();
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsSystemConnectionTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    final canRestart =
        context.watch<ConnectionStore>().api?.capabilities.backendRestart ==
        true;
    if (_busy && _config == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.all(HermesSpacing.lg),
          children: [
            if (widget.embedded)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsSystemConnectionTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonRefresh,
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            if (widget.embedded) const SizedBox(height: HermesSpacing.lg),
            if (_error != null) ...[
              MaterialBanner(
                content: Text(
                  _error == connectionOfflineErrorCode
                      ? context.l10n.backendDisconnected
                      : _error!,
                ),
                actions: [
                  TextButton(onPressed: _load, child: Text(l10n.commonRetry)),
                ],
              ),
              const SizedBox(height: HermesSpacing.md),
            ],
            _sectionTitle(l10n.settingsTerminalSection),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.terminal),
              title: Text(l10n.terminalFontTitle),
              subtitle: Text(
                _terminalFontFamily.isEmpty
                    ? l10n.terminalDefaultMonospace
                    : _terminalFontFamily,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editTerminalFont,
            ),
            const Divider(height: HermesSpacing.xl),
            _sectionTitle(l10n.settingsBackendConnectionSection),
            if (canRestart)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt),
                title: Text(l10n.settingsRestartBackend),
                subtitle: Text(l10n.settingsRestartBackendDesc),
                onTap: _restartBackend,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_off),
              title: Text(l10n.settingsChangeConnection),
              subtitle: Text(l10n.settingsChangeConnectionDesc),
              onTap: _clearConnection,
            ),
            if (_config != null) ...[
              const Divider(height: HermesSpacing.xl),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_applications_outlined),
                title: Text(l10n.settingsBackendConfigSummary),
                subtitle: Text(l10n.settingsBackendConfigSummaryDesc),
                children: [
                  for (final entry in _configEntries(_config!))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(entry.$1),
                      subtitle: Text(
                        entry.$2,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.xs),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  List<(String, String)> _configEntries(Map<String, dynamic> config) {
    const keys = [
      'model',
      'provider',
      'approvals',
      'toolsets',
      'timezone',
      'personality',
    ];
    final entries = <(String, String)>[];
    for (final key in keys) {
      if (config[key] != null) entries.add((key, config[key].toString()));
    }
    if (config['display'] is Map) {
      final display = config['display'] as Map;
      for (final key in ['personality', 'show_reasoning', 'tool_progress']) {
        if (display[key] != null) {
          entries.add(('display.$key', display[key].toString()));
        }
      }
    }
    return entries;
  }
}
